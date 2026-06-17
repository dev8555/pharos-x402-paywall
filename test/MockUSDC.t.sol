// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockUSDC} from "../contracts/MockUSDC.sol";

contract MockUSDCTest is Test {
    MockUSDC internal token;
    uint256 internal payerKey = 0xA11CE;
    address internal payer;
    address internal payee = makeAddr("payee");

    function setUp() public {
        payer = vm.addr(payerKey);
        token = new MockUSDC();
        token.mint(payer, 1_000_000);
    }

    function test_eip3009_metadata() public view {
        assertEq(token.name(), "USDC");
        assertEq(token.version(), "2");
        assertEq(token.decimals(), 6);
    }

    function test_transferWithAuthorization_vrs() public {
        uint256 validAfter = 0;
        uint256 validBefore = block.timestamp + 1 hours;
        bytes32 nonce = keccak256("nonce-1");
        uint256 value = 10_000;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
                ),
                payer,
                payee,
                value,
                validAfter,
                validBefore,
                nonce
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(payerKey, digest);

        token.transferWithAuthorization(payer, payee, value, validAfter, validBefore, nonce, v, r, s);

        assertEq(token.balanceOf(payee), value);
        assertTrue(token.authorizationState(payer, nonce));
    }
}
