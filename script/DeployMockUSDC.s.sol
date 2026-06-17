// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockUSDC} from "../contracts/MockUSDC.sol";

/// @notice Deploy MockUSDC on Pharos Atlantic and mint test balance to the payer wallet.
/// @dev Env: MINT_TO (default broadcaster), MINT_AMOUNT raw 6dp (default 1_000_000_000 = 1000 USDC).
contract DeployMockUSDC is Script {
    function run() external returns (MockUSDC token) {
        address mintTo = vm.envOr("MINT_TO", msg.sender);
        uint256 mintAmount = vm.envOr("MINT_AMOUNT", uint256(1_000_000_000));

        vm.startBroadcast();
        token = new MockUSDC();
        token.mint(mintTo, mintAmount);
        vm.stopBroadcast();

        console.log("=== MockUSDC Deploy ===");
        console.log("MockUSDC:", address(token));
        console.log("Minted to:", mintTo);
        console.log("Mint amount (raw 6dp):", mintAmount);
        console.log("Set USDC_ADDRESS in .env and update assets/tokens.json");
    }
}
