// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {X402Receipts} from "../contracts/X402Receipts.sol";

contract DeployX402Receipts is Script {
    function run() external returns (X402Receipts receipts) {
        uint256 disputeWindow = vm.envOr("DISPUTE_WINDOW_SECONDS", uint256(300));
        address recorder = vm.envOr("RECORDER_ADDRESS", msg.sender);
        address facilitatorSigner = vm.envOr("FACILITATOR_SIGNER_ADDRESS", msg.sender);

        vm.startBroadcast();
        receipts = new X402Receipts(disputeWindow);
        receipts.setAuthorizedRecorder(recorder, true);
        receipts.setFacilitatorSigner(facilitatorSigner);
        vm.stopBroadcast();

        console.log("=== Deploy Result ===");
        console.log("X402Receipts:", address(receipts));
        console.log("Dispute window (seconds):", disputeWindow);
        console.log("Authorized recorder:", recorder);
        console.log("Facilitator signer:", facilitatorSigner);
        console.log("Set PAY_TO_ADDRESS and RECEIPTS_ADDRESS to:", address(receipts));
    }
}
