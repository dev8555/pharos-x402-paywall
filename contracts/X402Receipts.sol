// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title X402Receipts — USDC custody ledger for x402 micropayments on Pharos
/// @notice Logs settlements, dispute windows, payee withdrawals, and revenue analytics
contract X402Receipts is Ownable, EIP712 {
    using SafeERC20 for IERC20;

    enum ReceiptStatus {
        Pending,
        Disputed,
        Finalized,
        Refunded
    }

    struct Receipt {
        address payer;
        address payee;
        address asset;
        uint256 amount;
        bytes32 resourceId;
        bytes32 settleTxHash;
        uint256 loggedAt;
        ReceiptStatus status;
    }

    struct ResourceAnalytics {
        uint256 totalRevenue;
        uint256 paymentCount;
        uint256 lastPaymentAt;
    }

    bytes32 public constant SETTLEMENT_PROOF_TYPEHASH = keccak256(
        "SettlementProof(address payer,address payee,address asset,uint256 amount,bytes32 resourceId,bytes32 settleTxHash,uint256 chainId,address receiptsContract)"
    );

    uint256 public constant FORCE_FINALIZE_MULTIPLIER = 7;

    uint256 public receiptCount;
    uint256 public disputeWindowSeconds;

    address public facilitatorSigner;
    mapping(address => bool) public authorizedRecorders;

    mapping(uint256 => Receipt) public receipts;
    mapping(address => uint256[]) public receiptsByPayee;
    mapping(address => mapping(address => uint256)) public pendingBalance;
    mapping(address => mapping(address => uint256)) public disputedBalance;
    mapping(address => mapping(address => uint256)) public withdrawableBalance;
    mapping(address => mapping(address => uint256)) public lifetimeRevenue;
    mapping(bytes32 => ResourceAnalytics) public resourceStats;
    mapping(address => mapping(bytes32 => ResourceAnalytics)) public payeeResourceStats;
    mapping(bytes32 => bool) public usedSettleTx;

    event ReceiptLogged(
        uint256 indexed id,
        address indexed payer,
        address indexed payee,
        address asset,
        uint256 amount,
        bytes32 resourceId,
        bytes32 settleTxHash
    );
    event ReceiptDisputed(uint256 indexed id, address indexed payer, string reason);
    event ReceiptFinalized(uint256 indexed id, address indexed payee, uint256 amount);
    event ReceiptRefunded(uint256 indexed id, address indexed payer, uint256 amount);
    event Withdrawn(address indexed payee, address indexed asset, uint256 amount, address indexed to);
    event DisputeWindowUpdated(uint256 oldWindow, uint256 newWindow);
    event AuthorizedRecorderUpdated(address indexed recorder, bool authorized);
    event FacilitatorSignerUpdated(address indexed oldSigner, address indexed newSigner);

    constructor(uint256 _disputeWindowSeconds) Ownable(msg.sender) EIP712("X402Receipts", "1") {
        require(_disputeWindowSeconds > 0, "invalid dispute window");
        disputeWindowSeconds = _disputeWindowSeconds;
    }

    function setAuthorizedRecorder(address recorder, bool authorized) external onlyOwner {
        authorizedRecorders[recorder] = authorized;
        emit AuthorizedRecorderUpdated(recorder, authorized);
    }

    function setFacilitatorSigner(address signer) external onlyOwner {
        address old = facilitatorSigner;
        facilitatorSigner = signer;
        emit FacilitatorSignerUpdated(old, signer);
    }

    /// @notice Log a receipt when caller is an authorized recorder or the facilitator signer
    function logReceipt(
        address payer,
        address payee,
        address asset,
        uint256 amount,
        bytes32 resourceId,
        bytes32 settleTxHash
    ) external returns (uint256 id) {
        _requireAuthorizedRecorder();
        return _logReceipt(payer, payee, asset, amount, resourceId, settleTxHash);
    }

    /// @notice Log a receipt with a facilitator EIP-712 settlement attestation
    function logReceiptWithProof(
        address payer,
        address payee,
        address asset,
        uint256 amount,
        bytes32 resourceId,
        bytes32 settleTxHash,
        bytes calldata signature
    ) external returns (uint256 id) {
        _verifySettlementProof(payer, payee, asset, amount, resourceId, settleTxHash, signature);
        return _logReceipt(payer, payee, asset, amount, resourceId, settleTxHash);
    }

    function disputeReceipt(uint256 id, string calldata reason) external {
        Receipt storage r = receipts[id];
        require(r.status == ReceiptStatus.Pending, "not pending");
        require(msg.sender == r.payer, "not payer");
        require(block.timestamp < r.loggedAt + disputeWindowSeconds, "dispute window closed");
        r.status = ReceiptStatus.Disputed;
        pendingBalance[r.payee][r.asset] -= r.amount;
        disputedBalance[r.payee][r.asset] += r.amount;
        emit ReceiptDisputed(id, msg.sender, reason);
    }

    function finalizeReceipt(uint256 id) external {
        Receipt storage r = receipts[id];
        require(r.status == ReceiptStatus.Pending, "not pending");
        require(block.timestamp >= r.loggedAt + disputeWindowSeconds, "dispute window open");
        r.status = ReceiptStatus.Finalized;
        pendingBalance[r.payee][r.asset] -= r.amount;
        withdrawableBalance[r.payee][r.asset] += r.amount;
        emit ReceiptFinalized(id, r.payee, r.amount);
    }

    function resolveDispute(uint256 id, bool refundToPayer) external onlyOwner {
        Receipt storage r = receipts[id];
        require(r.status == ReceiptStatus.Disputed, "not disputed");
        disputedBalance[r.payee][r.asset] -= r.amount;
        if (refundToPayer) {
            r.status = ReceiptStatus.Refunded;
            lifetimeRevenue[r.payee][r.asset] -= r.amount;
            _updateAnalytics(r.payee, r.resourceId, r.amount, true);
            IERC20(r.asset).safeTransfer(r.payer, r.amount);
            emit ReceiptRefunded(id, r.payer, r.amount);
        } else {
            r.status = ReceiptStatus.Finalized;
            withdrawableBalance[r.payee][r.asset] += r.amount;
            emit ReceiptFinalized(id, r.payee, r.amount);
        }
    }

    /// @notice Permissionless escape hatch — payee credited if owner never resolves
    function forceFinalize(uint256 id) external {
        Receipt storage r = receipts[id];
        require(r.status == ReceiptStatus.Disputed, "not disputed");
        require(
            block.timestamp >= r.loggedAt + disputeWindowSeconds * FORCE_FINALIZE_MULTIPLIER,
            "force finalize too early"
        );
        r.status = ReceiptStatus.Finalized;
        disputedBalance[r.payee][r.asset] -= r.amount;
        withdrawableBalance[r.payee][r.asset] += r.amount;
        emit ReceiptFinalized(id, r.payee, r.amount);
    }

    function withdraw(address asset, uint256 amount, address to) external {
        require(to != address(0), "zero recipient");
        uint256 bal = withdrawableBalance[msg.sender][asset];
        require(bal >= amount, "insufficient withdrawable");
        withdrawableBalance[msg.sender][asset] = bal - amount;
        IERC20(asset).safeTransfer(to, amount);
        emit Withdrawn(msg.sender, asset, amount, to);
    }

    function withdrawAll(address asset, address to) external {
        require(to != address(0), "zero recipient");
        uint256 bal = withdrawableBalance[msg.sender][asset];
        require(bal > 0, "nothing to withdraw");
        withdrawableBalance[msg.sender][asset] = 0;
        IERC20(asset).safeTransfer(to, bal);
        emit Withdrawn(msg.sender, asset, bal, to);
    }

    function getResourceRevenue(bytes32 resourceId)
        external
        view
        returns (uint256 totalRevenue, uint256 paymentCount, uint256 lastPaymentAt)
    {
        ResourceAnalytics memory s = resourceStats[resourceId];
        return (s.totalRevenue, s.paymentCount, s.lastPaymentAt);
    }

    function getPayeeResourceStats(address payee, bytes32 resourceId)
        external
        view
        returns (uint256 totalRevenue, uint256 paymentCount, uint256 lastPaymentAt)
    {
        ResourceAnalytics memory s = payeeResourceStats[payee][resourceId];
        return (s.totalRevenue, s.paymentCount, s.lastPaymentAt);
    }

    function getReceipt(uint256 id) external view returns (Receipt memory) {
        return receipts[id];
    }

    function payeeReceiptCount(address payee) external view returns (uint256) {
        return receiptsByPayee[payee].length;
    }

    function getEarningsSummary(address payee, address asset)
        external
        view
        returns (
            uint256 lifetimeEarned,
            uint256 pending,
            uint256 withdrawable,
            uint256 disputed,
            uint256 paymentCount
        )
    {
        return (
            lifetimeRevenue[payee][asset],
            pendingBalance[payee][asset],
            withdrawableBalance[payee][asset],
            disputedBalance[payee][asset],
            receiptsByPayee[payee].length
        );
    }

    function setDisputeWindow(uint256 newWindow) external onlyOwner {
        require(newWindow > 0, "invalid dispute window");
        emit DisputeWindowUpdated(disputeWindowSeconds, newWindow);
        disputeWindowSeconds = newWindow;
    }

    /// @dev Exposed for off-chain signing and tests
    function hashSettlementProof(
        address payer,
        address payee,
        address asset,
        uint256 amount,
        bytes32 resourceId,
        bytes32 settleTxHash
    ) external view returns (bytes32) {
        return _hashSettlementProof(payer, payee, asset, amount, resourceId, settleTxHash);
    }

    function _requireAuthorizedRecorder() internal view {
        require(
            authorizedRecorders[msg.sender] || msg.sender == facilitatorSigner,
            "unauthorized recorder"
        );
    }

    function _verifySettlementProof(
        address payer,
        address payee,
        address asset,
        uint256 amount,
        bytes32 resourceId,
        bytes32 settleTxHash,
        bytes calldata signature
    ) internal view {
        require(facilitatorSigner != address(0), "facilitator signer not set");
        bytes32 digest = _hashSettlementProof(payer, payee, asset, amount, resourceId, settleTxHash);
        address recovered = ECDSA.recover(digest, signature);
        require(recovered == facilitatorSigner, "invalid settlement proof");
    }

    function _hashSettlementProof(
        address payer,
        address payee,
        address asset,
        uint256 amount,
        bytes32 resourceId,
        bytes32 settleTxHash
    ) internal view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                SETTLEMENT_PROOF_TYPEHASH,
                payer,
                payee,
                asset,
                amount,
                resourceId,
                settleTxHash,
                block.chainid,
                address(this)
            )
        );
        return _hashTypedDataV4(structHash);
    }

    function _logReceipt(
        address payer,
        address payee,
        address asset,
        uint256 amount,
        bytes32 resourceId,
        bytes32 settleTxHash
    ) internal returns (uint256 id) {
        require(payer != address(0), "payer required");
        require(payee != address(0), "payee required");
        require(asset != address(0), "asset required");
        require(amount > 0, "amount must be > 0");
        require(settleTxHash != bytes32(0), "settle tx required");
        require(!usedSettleTx[settleTxHash], "settle tx already used");
        usedSettleTx[settleTxHash] = true;

        id = receiptCount++;
        receipts[id] = Receipt({
            payer: payer,
            payee: payee,
            asset: asset,
            amount: amount,
            resourceId: resourceId,
            settleTxHash: settleTxHash,
            loggedAt: block.timestamp,
            status: ReceiptStatus.Pending
        });
        receiptsByPayee[payee].push(id);
        pendingBalance[payee][asset] += amount;
        lifetimeRevenue[payee][asset] += amount;

        _updateAnalytics(payee, resourceId, amount);
        emit ReceiptLogged(id, payer, payee, asset, amount, resourceId, settleTxHash);
    }

    function _updateAnalytics(address payee, bytes32 resourceId, uint256 amount) internal {
        _updateAnalytics(payee, resourceId, amount, false);
    }

    function _updateAnalytics(address payee, bytes32 resourceId, uint256 amount, bool decrement)
        internal
    {
        _bumpStats(resourceStats[resourceId], amount, decrement);
        _bumpStats(payeeResourceStats[payee][resourceId], amount, decrement);
    }

    function _bumpStats(ResourceAnalytics storage s, uint256 amount, bool decrement) private {
        if (decrement) {
            s.totalRevenue -= amount;
            s.paymentCount -= 1;
        } else {
            s.totalRevenue += amount;
            s.paymentCount += 1;
            s.lastPaymentAt = block.timestamp;
        }
    }
}
