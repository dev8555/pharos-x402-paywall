// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {X402Receipts} from "../contracts/X402Receipts.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract X402ReceiptsTest is Test {
    X402Receipts internal receipts;
    MockUSDC internal usdc;

    address internal payer = makeAddr("payer");
    address internal payee = makeAddr("payee");
    address internal other = makeAddr("other");
    address internal recorder = makeAddr("recorder");

    uint256 internal constant FACILITATOR_PK = 0xA11CE;
    address internal facilitator;

    bytes32 internal constant RESOURCE = keccak256("GET /insight");
    bytes32 internal constant TX_HASH = keccak256("tx1");

    uint256 internal constant AMOUNT = 10_000; // $0.01 USDC
    uint256 internal constant WINDOW = 300;

    function setUp() public {
        facilitator = vm.addr(FACILITATOR_PK);
        receipts = new X402Receipts(WINDOW);
        usdc = new MockUSDC();
        usdc.mint(address(receipts), 1_000_000_000);

        receipts.setAuthorizedRecorder(address(this), true);
        receipts.setAuthorizedRecorder(recorder, true);
        receipts.setFacilitatorSigner(facilitator);
    }

    function _log() internal returns (uint256 id) {
        id = receipts.logReceipt(payer, payee, address(usdc), AMOUNT, RESOURCE, TX_HASH);
    }

    function _signProof(
        address _payer,
        address _payee,
        bytes32 resourceId,
        bytes32 settleTxHash
    ) internal view returns (bytes memory) {
        bytes32 digest =
            receipts.hashSettlementProof(_payer, _payee, address(usdc), AMOUNT, resourceId, settleTxHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(FACILITATOR_PK, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_logReceipt_happyPath() public {
        uint256 id = _log();
        assertEq(id, 0);
        assertEq(receipts.receiptCount(), 1);
        assertEq(receipts.pendingBalance(payee, address(usdc)), AMOUNT);
        assertEq(receipts.lifetimeRevenue(payee, address(usdc)), AMOUNT);

        (uint256 revenue, uint256 count,) = receipts.getResourceRevenue(RESOURCE);
        assertEq(revenue, AMOUNT);
        assertEq(count, 1);
    }

    function test_logReceipt_revertsUnauthorized() public {
        vm.prank(other);
        vm.expectRevert("unauthorized recorder");
        receipts.logReceipt(payer, payee, address(usdc), AMOUNT, RESOURCE, keccak256("tx-unauth"));
    }

    function test_logReceipt_authorizedRecorder() public {
        bytes32 txHash = keccak256("tx-recorder");
        vm.prank(recorder);
        uint256 id = receipts.logReceipt(payer, payee, address(usdc), AMOUNT, RESOURCE, txHash);
        assertEq(id, 0);
    }

    function test_logReceipt_facilitatorSigner() public {
        bytes32 txHash = keccak256("tx-facilitator");
        vm.prank(facilitator);
        uint256 id = receipts.logReceipt(payer, payee, address(usdc), AMOUNT, RESOURCE, txHash);
        assertEq(id, 0);
    }

    function test_logReceiptWithProof_happyPath() public {
        bytes32 txHash = keccak256("tx-proof");
        bytes memory sig = _signProof(payer, payee, RESOURCE, txHash);
        vm.prank(other);
        uint256 id = receipts.logReceiptWithProof(
            payer, payee, address(usdc), AMOUNT, RESOURCE, txHash, sig
        );
        assertEq(id, 0);
    }

    function test_logReceiptWithProof_revertsInvalidSignature() public {
        bytes32 txHash = keccak256("tx-bad-proof");
        bytes memory sig = _signProof(payer, payee, RESOURCE, keccak256("wrong-hash"));
        vm.expectRevert("invalid settlement proof");
        receipts.logReceiptWithProof(payer, payee, address(usdc), AMOUNT, RESOURCE, txHash, sig);
    }

    function test_logReceipt_revertsOnDuplicateSettleTx() public {
        _log();
        vm.expectRevert("settle tx already used");
        receipts.logReceipt(payer, payee, address(usdc), AMOUNT, RESOURCE, TX_HASH);
    }

    function test_logReceipt_revertsZeroPayer() public {
        vm.expectRevert("payer required");
        receipts.logReceipt(address(0), payee, address(usdc), AMOUNT, RESOURCE, keccak256("tx2"));
    }

    function test_logReceipt_revertsZeroPayee() public {
        vm.expectRevert("payee required");
        receipts.logReceipt(payer, address(0), address(usdc), AMOUNT, RESOURCE, keccak256("tx2"));
    }

    function test_logReceipt_revertsZeroAsset() public {
        vm.expectRevert("asset required");
        receipts.logReceipt(payer, payee, address(0), AMOUNT, RESOURCE, keccak256("tx2a"));
    }

    function test_logReceipt_revertsZeroSettleTxHash() public {
        vm.expectRevert("settle tx required");
        receipts.logReceipt(payer, payee, address(usdc), AMOUNT, RESOURCE, bytes32(0));
    }

    function test_logReceipt_revertsZeroAmount() public {
        vm.expectRevert("amount must be > 0");
        receipts.logReceipt(payer, payee, address(usdc), 0, RESOURCE, keccak256("tx3"));
    }

    function test_disputeReceipt_withinWindow() public {
        _log();
        vm.prank(payer);
        receipts.disputeReceipt(0, "bad content");
        assertEq(uint256(receipts.getReceipt(0).status), uint256(X402Receipts.ReceiptStatus.Disputed));
        assertEq(receipts.pendingBalance(payee, address(usdc)), 0);
        assertEq(receipts.disputedBalance(payee, address(usdc)), AMOUNT);
    }

    function test_disputeReceipt_revertsAfterWindow() public {
        _log();
        vm.warp(block.timestamp + WINDOW + 1);
        vm.prank(payer);
        vm.expectRevert("dispute window closed");
        receipts.disputeReceipt(0, "late");
    }

    function test_disputeReceipt_revertsNotPayer() public {
        _log();
        vm.prank(other);
        vm.expectRevert("not payer");
        receipts.disputeReceipt(0, "not me");
    }

    function test_finalizeReceipt_afterWindow() public {
        _log();
        vm.warp(block.timestamp + WINDOW);
        receipts.finalizeReceipt(0);
        assertEq(receipts.withdrawableBalance(payee, address(usdc)), AMOUNT);
        assertEq(receipts.pendingBalance(payee, address(usdc)), 0);
    }

    function test_finalizeReceipt_revertsDuringWindow() public {
        _log();
        vm.expectRevert("dispute window open");
        receipts.finalizeReceipt(0);
    }

    function test_resolveDispute_refund() public {
        _log();
        vm.prank(payer);
        receipts.disputeReceipt(0, "refund please");
        receipts.resolveDispute(0, true);
        assertEq(usdc.balanceOf(payer), AMOUNT);
        assertEq(receipts.lifetimeRevenue(payee, address(usdc)), 0);
    }

    function test_resolveDispute_uphold() public {
        _log();
        vm.prank(payer);
        receipts.disputeReceipt(0, "dispute");
        receipts.resolveDispute(0, false);
        assertEq(receipts.withdrawableBalance(payee, address(usdc)), AMOUNT);
    }

    function test_forceFinalize_afterSevenWindows() public {
        _log();
        vm.prank(payer);
        receipts.disputeReceipt(0, "stuck");
        vm.warp(block.timestamp + WINDOW * 7);
        receipts.forceFinalize(0);
        assertEq(receipts.withdrawableBalance(payee, address(usdc)), AMOUNT);
        assertEq(receipts.disputedBalance(payee, address(usdc)), 0);
    }

    function test_forceFinalize_revertsTooEarly() public {
        _log();
        vm.prank(payer);
        receipts.disputeReceipt(0, "stuck");
        vm.warp(block.timestamp + WINDOW * 6);
        vm.expectRevert("force finalize too early");
        receipts.forceFinalize(0);
    }

    function test_getEarningsSummary() public {
        _log();
        (
            uint256 lifetime,
            uint256 pending,
            uint256 withdrawable,
            uint256 disputed,
            uint256 count
        ) = receipts.getEarningsSummary(payee, address(usdc));
        assertEq(lifetime, AMOUNT);
        assertEq(pending, AMOUNT);
        assertEq(withdrawable, 0);
        assertEq(disputed, 0);
        assertEq(count, 1);

        vm.warp(block.timestamp + WINDOW);
        receipts.finalizeReceipt(0);
        (, pending, withdrawable,,) = receipts.getEarningsSummary(payee, address(usdc));
        assertEq(pending, 0);
        assertEq(withdrawable, AMOUNT);
    }

    function test_withdraw() public {
        _log();
        vm.warp(block.timestamp + WINDOW);
        receipts.finalizeReceipt(0);
        vm.prank(payee);
        receipts.withdraw(address(usdc), AMOUNT, payee);
        assertEq(usdc.balanceOf(payee), AMOUNT);
    }

    function test_withdrawAll() public {
        _log();
        vm.warp(block.timestamp + WINDOW);
        receipts.finalizeReceipt(0);
        vm.prank(payee);
        receipts.withdrawAll(address(usdc), payee);
        assertEq(usdc.balanceOf(payee), AMOUNT);
    }

    function test_withdraw_revertsInsufficient() public {
        _log();
        vm.warp(block.timestamp + WINDOW);
        receipts.finalizeReceipt(0);
        vm.prank(payee);
        vm.expectRevert("insufficient withdrawable");
        receipts.withdraw(address(usdc), AMOUNT + 1, payee);
    }

    function test_getPayeeResourceStats_isolated() public {
        _log();
        (uint256 revenue, uint256 count,) = receipts.getPayeeResourceStats(payee, RESOURCE);
        assertEq(revenue, AMOUNT);
        assertEq(count, 1);
    }

    function test_setDisputeWindow_ownerOnly() public {
        vm.prank(other);
        vm.expectRevert();
        receipts.setDisputeWindow(600);
        receipts.setDisputeWindow(600);
        assertEq(receipts.disputeWindowSeconds(), 600);
    }
}
