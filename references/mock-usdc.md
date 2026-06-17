# Mock USDC (Atlantic testnet)

Circle USDC is not available (or not practical to swap) on Pharos Atlantic. Deploy this repo's **EIP-3009 MockUSDC** for x402 `exact` payments.

**Atlantic demo token:** `0xeAeb66E869C43FB5FeB0A18729A2fbaAEB30B618` ([explorer](https://atlantic.pharosscan.xyz/address/0xeAeb66E869C43FB5FeB0A18729A2fbaAEB30B618)) — 1000 USDC minted to `0x73c37e8eddD9beF70FBbbe2861a8A776FABf1AA7`.

## Deploy

```bash
export PRIVATE_KEY=0x...
export RPC=https://atlantic.dplabs-internal.com
export MINT_TO=$(cast wallet address --private-key $PRIVATE_KEY)   # payer wallet
export MINT_AMOUNT=1000000000   # 1000 USDC (6 dp) — optional

forge script script/DeployMockUSDC.s.sol:DeployMockUSDC \
  --rpc-url $RPC \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## Configure

1. Copy `MockUSDC:` address from forge logs into `.env`:

```bash
USDC_ADDRESS=0x...
USDC_NAME=USDC
```

2. Update [`assets/tokens.json`](../assets/tokens.json) `atlantic.USDC.address` to the same value.

## Verify EIP-3009 support

```bash
cast call $USDC_ADDRESS "name()(string)" --rpc-url $RPC          # USDC
cast call $USDC_ADDRESS "version()(string)" --rpc-url $RPC      # 2
cast call $USDC_ADDRESS "balanceOf(address)(uint256)" $MINT_TO --rpc-url $RPC
```

`name` and `version` must match paywall `extra` (`USDC` / `2`) or x402 returns `invalid_exact_evm_eip3009_not_supported`.

## Mint more

Anyone can call `mint(to, amount)` on the test token:

```bash
cast send $USDC_ADDRESS "mint(address,uint256)" $PAYER 100000000 \
  --private-key $PRIVATE_KEY --rpc-url $RPC
```
