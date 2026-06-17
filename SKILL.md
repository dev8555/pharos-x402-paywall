---
name: pharos-x402-paywall
description: >
  Use when an agent needs to earn USDC per API call, pay another agent or API
  that returns HTTP 402, run a payment facilitator, or manage on-chain payment
  receipts with dispute windows and withdrawal aggregation on Pharos Atlantic
  (688689). Trigger phrases: monetize endpoint, paywall, pay per call, auto-pay
  402, x402, receipt ledger, agent earnings, getEarningsSummary, forceFinalize,
  micropayments, HTTP 402, USDC settlement.
license: MIT
---

# pharos-x402-paywall

The cash register and wallet for the Pharos agent economy — sell side (x402 paywall), buy side (autopay client), facilitator settlement, and on-chain `X402Receipts` ledger.

## Installation

Run these before any other step. Do not assume dependencies are already installed.

```bash
git clone https://github.com/dev8555/pharos-x402-paywall && cd pharos-x402-paywall
npm install
cp .env.example .env          # set EVM_PRIVATE_KEY (addresses pre-filled)
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Foundry uses OpenZeppelin from `node_modules` (see `foundry.toml`). After `npm install`, run:

```bash
forge build
forge install foundry-rs/forge-std
forge test -vv
```

Set in `.env` before demo (see `.env.example`):

- `EVM_PRIVATE_KEY` — payer/facilitator/deployer (never send to the model)
- `RECEIPTS_ADDRESS` — `0xB9b98cC2cCF067F710A7DCc92d8FC558F5b12160` (v1.1 auth)
- `PAY_TO_ADDRESS` — must equal `RECEIPTS_ADDRESS` (treasury mode)
- `PAYEE_ADDRESS` — `0x73c37e8eddD9beF70FBbbe2861a8A776FABf1AA7`
- `RECORDER_ADDRESS` — paywall operator wallet (authorized for `logReceipt`)
- `FACILITATOR_SIGNER_ADDRESS` — facilitator signing key

## Judge Quick Path (< 5 min)

1. `npm install && cp .env.example .env` (set `EVM_PRIVATE_KEY`)
2. `npm run facilitator` + `npm run server`
3. `curl -i http://localhost:4021/insight` → **402**
4. `npm run client -- http://localhost:4021/insight` → **200** + tx hash
5. `npm run dashboard -- $PAYEE_ADDRESS` → Pending **$0.01**

See [JUDGE.md](JUDGE.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Quick Start (Happy Path)

Full sell-side flow: paywall → settle → receipt → finalize → withdraw.

```bash
export RPC=https://atlantic.dplabs-internal.com
export RECEIPTS=0xB9b98cC2cCF067F710A7DCc92d8FC558F5b12160
export PAYEE=0x73c37e8eddD9beF70FBbbe2861a8A776FABf1AA7
export USDC=0xeAeb66E869C43FB5FeB0A18729A2fbaAEB30B618
export PRIVATE_KEY=0x...   # from .env

# 1. Start facilitator (terminal 1)
npm run facilitator

# 2. Start paywall (terminal 2)
npm run server

# 3. Pay for content — x402 settle + server auto-calls logReceipt (terminal 3)
npm run client -- http://localhost:4021/insight
# Expect 200 + insight JSON; receipt id 0 logged on-chain (first payment)

# 4. Dashboard — pending balance (dispute window still open)
npm run dashboard -- $PAYEE
# Pending: $0.01 | Withdrawable: $0.00

# 5. After disputeWindowSeconds (300s default), finalize receipt 0
# Pre-check: receipt still Pending (see references/receipts.md#finalize)
cast send $RECEIPTS "finalizeReceipt(uint256)" 0 \
  --private-key $PRIVATE_KEY --rpc-url $RPC

# 6. Dashboard — funds now withdrawable
npm run dashboard -- $PAYEE
# Withdrawable: $0.01

# 7. Sweep USDC to payee wallet
# Pre-check: withdrawable > 0 (see references/receipts.md#withdraw)
cast send $RECEIPTS "withdrawAll(address,address)" $USDC $PAYEE \
  --private-key $PRIVATE_KEY --rpc-url $RPC
```

Manual `logReceipt` (only if not using the paywall hook):

```bash
export RESOURCE_ID=$(cast keccak "GET /insight")
export SETTLE_TX=$(cast --to-bytes32 0x<settle_tx_hash>)
cast send $RECEIPTS \
  "logReceipt(address,address,address,uint256,bytes32,bytes32)" \
  $PAYER $PAYEE $USDC 10000 $RESOURCE_ID $SETTLE_TX \
  --private-key $PRIVATE_KEY --rpc-url $RPC
```

`10000` = $0.01 USDC (6 decimals). More examples: [`references/receipts.md`](references/receipts.md).

## Prerequisites

- **Node.js 20+** with `npm` — run `npm install` first
- **Foundry** (`cast`, `forge`) — `foundryup` after install
- **Wallet** on Pharos Atlantic with PHRS (gas) and testnet USDC
- **Environment:** `.env` from `.env.example`; never send `EVM_PRIVATE_KEY` to the model

## Network Configuration

Canonical values (also in [`assets/networks.json`](assets/networks.json)):

| Network | chainId | x402 ID | RPC | Explorer |
|---------|---------|---------|-----|----------|
| Atlantic (testnet) | 688689 | `eip155:688689` | `https://atlantic.dplabs-internal.com` | `https://atlantic.pharosscan.xyz` |
| ⚠️ Pacific (mainnet) | 1672 | `eip155:1672` | `https://rpc.pharos.xyz` | `https://pharosscan.xyz` |

**Demo default:** Atlantic testnet (`688689`) only. Do **not** point `$RPC` at Pacific unless you intend real mainnet transactions with real assets.

**USDC (Atlantic MockUSDC, EIP-3009):** `0xeAeb66E869C43FB5FeB0A18729A2fbaAEB30B618` — see [`assets/tokens.json`](assets/tokens.json) and [`references/mock-usdc.md`](references/mock-usdc.md). Circle USDC is not available on Atlantic; deploy your own with `forge script script/DeployMockUSDC.s.sol:DeployMockUSDC`.

Default `$RPC` for all commands: `https://atlantic.dplabs-internal.com`

## Token Decimals

Always pass **raw base units** to contract calls and x402 amounts. Do not use human floats on-chain.

| Token | Symbol | Decimals | Example raw | Human |
|-------|--------|----------|-------------|-------|
| Native gas | PHRS | 18 | `1000000000000000000` | 1 PHRS |
| Stablecoin | USDC | 6 | `10000` | $0.01 |
| Stablecoin | USDC | 6 | `5000000` | $5.00 |

`getEarningsSummary`, `logReceipt`, `withdraw`, and x402 `amount` fields all use **USDC raw (6 dp)**. Divide dashboard output by `1e6` for dollars.

## Inline Contract ABI (X402Receipts)

Use these signatures directly with `cast send` / `cast call`. Contract: `$RECEIPTS` on Atlantic.

| Function | Signature | Who calls | Notes |
|----------|-----------|-----------|-------|
| `logReceipt` | `logReceipt(address,address,address,uint256,bytes32,bytes32)` | Authorized recorder or facilitator signer | Requires auth; `settleTxHash` is idempotency key |
| `logReceiptWithProof` | `logReceiptWithProof(...,bytes)` | Anyone with facilitator EIP-712 proof | x402 settlement attestation |
| `disputeReceipt` | `disputeReceipt(uint256,string)` | Payer | Within `disputeWindowSeconds` of `loggedAt` |
| `finalizeReceipt` | `finalizeReceipt(uint256)` | Anyone | After dispute window; pending → withdrawable |
| `forceFinalize` | `forceFinalize(uint256)` | Anyone | Disputed only; after `disputeWindowSeconds × 7` |
| `resolveDispute` | `resolveDispute(uint256,bool)` | Owner | `true` = refund payer; `false` = uphold payee |
| `withdraw` | `withdraw(address,uint256,address)` | Payee | Partial sweep from `withdrawableBalance` |
| `withdrawAll` | `withdrawAll(address,address)` | Payee | Full sweep to `to` |
| `getEarningsSummary` | `getEarningsSummary(address,address)(uint256,uint256,uint256,uint256,uint256)` | Anyone (view) | Returns: lifetime, pending, withdrawable, disputed, count |
| `getReceipt` | `getReceipt(uint256)(tuple)` | Anyone (view) | Full receipt struct by id |
| `withdrawableBalance` | `withdrawableBalance(address,address)(uint256)` | Anyone (view) | Per payee + asset |

Paywall server calls `logReceipt` automatically in `onAfterSettle` after a successful x402 settle when `RECEIPTS_ADDRESS` is set.

## Contract Revert Strings

Match these exact strings when `cast send` reverts:

| Revert string | Function | Meaning | Fix |
|---------------|----------|---------|-----|
| `invalid dispute window` | constructor / `setDisputeWindow` | Window is 0 | Use `DISPUTE_WINDOW_SECONDS` > 0 |
| `unauthorized recorder` | `logReceipt` | Caller not authorized | Set `RECORDER_ADDRESS` at deploy |
| `payer required` | `logReceipt` | Zero payer address | Pass valid payer from x402 payload |
| `payee required` | `logReceipt` | Zero payee address | Set valid `PAYEE_ADDRESS` |
| `asset required` | `logReceipt` | Zero asset address | Pass valid USDC address |
| `settle tx required` | `logReceipt` | Zero settleTxHash | Pass 32-byte settle tx hash |
| `invalid settlement proof` | `logReceiptWithProof` | Bad facilitator signature | Sign with `FACILITATOR_SIGNER_ADDRESS` key |
| `amount must be > 0` | `logReceipt` | Zero amount | Pass USDC raw > 0 (e.g. `10000`) |
| `settle tx already used` | `logReceipt` | Duplicate settle hash | Idempotency — receipt already logged |
| `not pending` | `disputeReceipt` / `finalizeReceipt` | Wrong status | Check receipt status via `getReceipt` |
| `not payer` | `disputeReceipt` | Wrong signer | Use payer's key |
| `dispute window closed` | `disputeReceipt` | Too late to dispute | Call `finalizeReceipt` instead |
| `dispute window open` | `finalizeReceipt` | Too early to finalize | Wait `disputeWindowSeconds` after `logReceipt` |
| `not disputed` | `forceFinalize` / `resolveDispute` | Receipt not in Disputed | Dispute first or use `finalizeReceipt` |
| `force finalize too early` | `forceFinalize` | Before 7× window | Wait `loggedAt + disputeWindowSeconds × 7` |
| `zero recipient` | `withdraw` / `withdrawAll` | Zero `to` address | Pass valid payee address |
| `insufficient withdrawable` | `withdraw` | Amount > balance | Finalize first; check `withdrawableBalance` |
| `nothing to withdraw` | `withdrawAll` | Zero withdrawable | Call `finalizeReceipt` before withdraw |
| `OwnableUnauthorizedAccount` | `resolveDispute` / `setDisputeWindow` | Not contract owner | Use deployer key |

## Write Operation Pre-checks

Before any transaction or x402 demo:

1. **Wallet address:** `cast wallet address --private-key $PRIVATE_KEY`
2. **Network:** confirm `--rpc-url $RPC` is Atlantic (`https://atlantic.dplabs-internal.com`)
3. **PHRS balance:** `cast balance $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url $RPC --ether` (gas)
4. **Payer USDC:** `cast call $USDC "balanceOf(address)(uint256)" $PAYER --rpc-url $RPC` — then `cast to-dec` before comparing (see [`references/autopay.md#precheck`](references/autopay.md#precheck))
5. **Facilitator running:** `curl http://localhost:3000/supported` — must return `eip155:688689` before starting server
6. **PAY_TO_ADDRESS set:** confirm `PAY_TO_ADDRESS` equals `RECEIPTS_ADDRESS` (treasury mode)
7. **USDC in receipts contract:** after a paid request, `cast call $USDC "balanceOf(address)(uint256)" $RECEIPTS --rpc-url $RPC` should be > 0
8. **Explicit key:** always pass `--private-key $PRIVATE_KEY` — Foundry does NOT read env automatically

## Capability Index

Detailed walkthroughs: [`references/`](references/). Core signatures are inline above.

| User Need | Capability | Detailed Instructions |
|-----------|------------|----------------------|
| Deploy mock USDC on Atlantic / no Circle USDC | `DeployMockUSDC` script | → [`references/mock-usdc.md`](references/mock-usdc.md) |
| Monetize my endpoint / charge per call / put a paywall on this | Scaffold x402 Express server | → [`references/paywall.md`](references/paywall.md) |
| Test paywall returns 402 / curl without payment | `curl -i` unpaid request | → [`references/paywall.md#test-402`](references/paywall.md#test-402) |
| Issue JWT after payment for repeat access | JWT middleware | → [`references/paywall.md#jwt`](references/paywall.md#jwt) |
| Wire receipt logging after settle | `onAfterSettle` hook | → [`references/paywall.md#receipt-hook`](references/paywall.md#receipt-hook) |
| Let my agent pay this paid API / auto-pay 402 / pay another agent | `wrapFetchWithPayment` client | → [`references/autopay.md`](references/autopay.md) |
| Check payer USDC before paying | `cast call balanceOf` + `cast to-dec` | [`references/autopay.md#precheck`](references/autopay.md#precheck) |
| Retry failed payment without double-charging | Idempotency + settleTx hash | → [`references/autopay.md#idempotency`](references/autopay.md#idempotency) |
| Run a payment verifier and settler / self-host facilitator | Express facilitator | → [`references/facilitator.md`](references/facilitator.md) |
| Connect to hosted facilitator | Set `FACILITATOR_URL` | → [`references/facilitator.md#hosted`](references/facilitator.md#hosted) |
| Health-check facilitator | `GET /supported` | → [`references/facilitator.md#health`](references/facilitator.md#health) |
| Deploy receipts contract / log payments on-chain | `forge script` deploy | Address extraction + [`references/receipts.md#deploy`](references/receipts.md#deploy) |
| Verify receipts contract on explorer | `forge verify-contract` + `sleep 10` | → [`references/receipts.md#verify`](references/receipts.md#verify) |
| Log a receipt after settlement | `logReceipt` | Inline ABI + [`references/receipts.md#log`](references/receipts.md#log) |
| Dispute a payment / challenge a receipt | `disputeReceipt` | Inline ABI + [`references/receipts.md#dispute`](references/receipts.md#dispute) |
| Finalize receipt after dispute window | `finalizeReceipt` | Pre-check + [`references/receipts.md#finalize`](references/receipts.md#finalize) |
| Force-finalize stuck dispute / owner absent | `forceFinalize` after 7× window | Inline ABI + [`references/receipts.md#force-finalize`](references/receipts.md#force-finalize) |
| Resolve dispute (owner, optional) | `resolveDispute` | Inline ABI + [`references/receipts.md#resolve`](references/receipts.md#resolve) |
| Withdraw my aggregated earnings / sweep USDC | `withdraw` / `withdrawAll` | Pre-check + [`references/receipts.md#withdraw`](references/receipts.md#withdraw) |
| Show my earnings dashboard / AUM summary | `getEarningsSummary` | → [`references/receipts.md#earnings-summary`](references/receipts.md#earnings-summary) |
| Show revenue per endpoint / route analytics | `getResourceRevenue` | → [`references/receipts.md#analytics`](references/receipts.md#analytics) |
| List payments / receipt events | `cast logs` | → [`references/receipts.md#query`](references/receipts.md#query) |
| Read a receipt by ID | `getReceipt` | → [`references/receipts.md#read`](references/receipts.md#read) |
| MCP tools / agent CLI | `npm run mcp` / `npm run agent` | → [`docs/MCP.md`](docs/MCP.md) |
| Phase 2 autonomous vendor | Insight Vendor Agent | → [`examples/insight-vendor-agent/`](examples/insight-vendor-agent/) |

## General Error Handling

### x402 and paywall errors

| Error | Cause | Fix |
|-------|-------|-----|
| `402` on every request | Payment not attached | Use autopay client: `npm run client -- <url>` |
| `Please set PAY_TO_ADDRESS` | Missing env | `export PAY_TO_ADDRESS=$RECEIPTS_ADDRESS` |
| Facilitator connection refused | Facilitator not running | `npm run facilitator` first (terminal 1) |
| `invalid_exact_evm_eip3009_not_supported` | USDC lacks EIP-3009 | Use EIP-3009 token or Permit2 path |
| `Failed to create payment payload` | Wrong network / no USDC | Confirm `eip155:688689` and fund payer USDC |

### Foundry and CLI errors

| Error | Cause | Fix |
|-------|-------|-----|
| `invalid address` | Malformed address | 0x + 40 hex chars |
| `connection refused` | Missing `--rpc-url` | Pass `$RPC` explicitly |
| `insufficient funds` | Low PHRS/USDC | Fund wallet |
| `execution reverted` | Contract revert | Match string in **Contract Revert Strings** above |
| `contract not found` on verify | Indexer lag | `sleep 10` and retry |
| `PRIVATE_KEY not set` | Env not exported | `export PRIVATE_KEY=0x...` |
| `forge/cast: command not found` | Foundry not installed | `foundryup` |
| `Cannot find module '@x402/...'` | Missing npm deps | Run `npm install` |

## Security Reminders

Full model: [docs/SECURITY.md](docs/SECURITY.md)

- Never hardcode private keys in source or git
- Never paste `EVM_PRIVATE_KEY` into LLM prompts
- Add `.env` to `.gitignore`
- Treasury mode: `PAY_TO_ADDRESS` = receipts contract holds USDC until payee withdraws
- ⚠️ **Pacific (chain 1672) is mainnet** — real PHRS and real USDC. Default all demos to Atlantic (`688689`) unless explicitly targeting production
