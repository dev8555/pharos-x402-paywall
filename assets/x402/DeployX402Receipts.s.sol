// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {X402Receipts} from "../contracts/X402Receipts.sol";

contract DeployX402Receipts is Script {
    function run() external returns (X402Receipts receipts) {
        uint256 disputeWindow = vm.envOr("DISPUTE_WINDOW_SECONDS", uint256(300));

        vm.startBroadcast();
        receipts = new X402Receipts(disputeWindow);
        vm.stopBroadcast();
    }
}
