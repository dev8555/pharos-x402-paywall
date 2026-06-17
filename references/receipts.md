# Receipts Contract Operation Instructions

> **Network Configuration:** Read `rpcUrl` from [`assets/networks.json`](../assets/networks.json).
> **Private Key:** Pass `--private-key $PRIVATE_KEY` on all Foundry writes. Foundry does NOT auto-read env vars.

---

## Deploy X402Receipts {#deploy}

### Overview

Deploys the USDC custody ledger with dispute window, withdrawal aggregation, and `getEarningsSummary` dashboard view.

### Command Template

```bash
export PRIVATE_KEY=0x...
export RPC=https://atlantic.dplabs-internal.com
export DISPUTE_WINDOW_SECONDS=300
export RECORDER_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
export FACILITATOR_SIGNER_ADDRESS=$RECORDER_ADDRESS
forge script script/DeployX402Receipts.s.sol:DeployX402Receipts \
  --rpc-url $RPC \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `DISPUTE_WINDOW_SECONDS` | uint256 | No | Default `300` demo; use `86400` prod |
| `RECORDER_ADDRESS` | address | No | Authorized `logReceipt` caller (default: deployer) |
| `FACILITATOR_SIGNER_ADDRESS` | address | No | Facilitator EIP-712 signer (default: deployer) |
| `--private-key` | hex | Yes | Deployer wallet |

### Output Parsing

| Field | Description |
|-------|-------------|
| `X402Receipts:` | Contract address in forge logs |
| `returns.receipts.value` | Same address in broadcast JSON (use extraction below) |

### Extract deployed address (agent-ready)

Do not copy-paste from console output. Read `broadcast/DeployX402Receipts.s.sol/688689/run-latest.json` after `--broadcast`:

**Node (cross-platform — recommended):**

```bash
export RECEIPTS=$(node -e "const j=require('./broadcast/DeployX402Receipts.s.sol/688689/run-latest.json'); console.log(j.returns.receipts.value)")
export PAY_TO_ADDRESS=$RECEIPTS
echo "RECEIPTS=$RECEIPTS"
```

**jq (Linux / macOS / Git Bash):**

```bash
export RECEIPTS=$(jq -r '.returns.receipts.value' broadcast/DeployX402Receipts.s.sol/688689/run-latest.json)
export PAY_TO_ADDRESS=$RECEIPTS
```

**PowerShell:**

```powershell
$j = Get-Content broadcast/DeployX402Receipts.s.sol/688689/run-latest.json | ConvertFrom-Json
$env:RECEIPTS_ADDRESS = $j.returns.receipts.value
$env:PAY_TO_ADDRESS = $env:RECEIPTS_ADDRESS
```

Append to `.env`:

```bash
echo "RECEIPTS_ADDRESS=$RECEIPTS" >> .env
echo "PAY_TO_ADDRESS=$RECEIPTS" >> .env
```

Set `PAYEE_ADDRESS` to deployer: `cast wallet address --private-key $PRIVATE_KEY`

### Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `insufficient funds` | No PHRS | `cast balance $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url $RPC --ether` |

> **Agent Guidelines:**
> 1. Complete Write Operation Pre-checks (see `SKILL.md`)
> 2. Save address to `.env` and README
> 3. Proceed to `#verify`

---

## Verify Contract {#verify}

### Command Template

```bash
sleep 10
forge verify-contract <RECEIPTS_ADDRESS> contracts/X402Receipts.sol:X402Receipts \
  --chain-id 688689 \
  --verifier-url https://api.socialscan.io/pharos-atlantic-testnet/v1/explorer/command_api/contract \
  --verifier blockscout \
  --constructor-args $(cast abi-encode "constructor(uint256)" 300)
```

### Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `contract not found` | Indexer lag | Wait 10–15s and retry |

---

## Log Receipt {#log}

### Command Template

```bash
cast send $RECEIPTS "logReceipt(address,address,address,uint256,bytes32,bytes32)" \
  $PAYER $PAYEE $USDC <amount_raw> $RESOURCE_ID $SETTLE_TX_HASH \
  --private-key $PRIVATE_KEY --rpc-url $RPC
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `amount_raw` | USDC base units (6 dp). `10000` = $0.01 |
| `RESOURCE_ID` | `cast keccak "GET /insight"` |
| `SETTLE_TX_HASH` | `bytes32` padded tx hash (idempotency) |

### Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `unauthorized recorder` | Caller not in `authorizedRecorders` | Use `RECORDER_ADDRESS` key or `logReceiptWithProof` |
| `payer required` | Zero payer | Set valid payer address |
| `asset required` | Zero asset | Set valid USDC address |
| `settle tx required` | Zero `settleTxHash` | Pass padded tx hash (`cast --to-bytes32 0x…`) |
| `settle tx already used` | Duplicate log | Expected on retry — payment already recorded |
| `payee required` | Zero payee | Set valid `PAYEE_ADDRESS` |

---

## Dispute Receipt {#dispute}

### Command Template

```bash
cast send $RECEIPTS "disputeReceipt(uint256,string)" <id> "reason" \
  --private-key $PAYER_KEY --rpc-url $RPC
```

### Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `not payer` | Wrong key | Use payer's private key |
| `dispute window closed` | Window elapsed | Use `#finalize` instead |

---

## Finalize Receipt {#finalize}

### Pre-check (do not finalize twice)

Receipt `status` must be **Pending (0)**. Skip if already Finalized (2) or Refunded (3).

```bash
export RECEIPT_ID=0
STATUS_RAW=$(cast call $RECEIPTS \
  "getReceipt(uint256)((address,address,address,uint256,bytes32,bytes32,uint256,uint8))" \
  $RECEIPT_ID --rpc-url $RPC | awk -F',' '{print $NF}' | tr -d ' )')
STATUS_DEC=$(cast to-dec "$STATUS_RAW")
# 0=Pending, 1=Disputed, 2=Finalized, 3=Refunded
if [ "$STATUS_DEC" -ne 0 ]; then
  echo "Abort: receipt $RECEIPT_ID status=$STATUS_DEC (not Pending)"
  exit 1
fi
```

PowerShell: parse last tuple field, then `[int](cast to-dec $STATUS_RAW) -ne 0` → abort.

### Command Template

```bash
cast send $RECEIPTS "finalizeReceipt(uint256)" <id> \
  --private-key $PRIVATE_KEY --rpc-url $RPC
```

### Overview

After `disputeWindowSeconds`, moves pending credits to withdrawable balance. Callable by anyone.

### Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `dispute window open` | Too early | Wait or warp time in tests |

---

## Force-Finalize Dispute {#force-finalize}

### Overview

Permissionless escape hatch: if owner never calls `resolveDispute`, anyone can finalize in payee's favor after `disputeWindowSeconds * 7`.

### Command Template

```bash
cast send $RECEIPTS "forceFinalize(uint256)" <id> \
  --private-key $PRIVATE_KEY --rpc-url $RPC
```

### Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `not disputed` | Receipt not in Disputed state | Dispute first or use `#finalize` |
| `force finalize too early` | Before 7× window | Wait `loggedAt + disputeWindowSeconds * 7` |

> **Agent Guidelines:**
> 1. Explain this removes owner centralization risk for stuck disputes
> 2. Upholds payee — funds move to `withdrawableBalance`

---

## Resolve Dispute (Owner, Optional) {#resolve}

### Command Template

```bash
# Refund payer
cast send $RECEIPTS "resolveDispute(uint256,bool)" <id> true \
  --private-key $OWNER_KEY --rpc-url $RPC

# Uphold payee
cast send $RECEIPTS "resolveDispute(uint256,bool)" <id> false \
  --private-key $OWNER_KEY --rpc-url $RPC
```

### Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `Not owner` | Not contract owner | Use deployer key |

---

## Withdraw Earnings {#withdraw}

### Pre-check (do not withdraw before finalize)

`withdrawAll` reverts with `nothing to withdraw` if credits are still **pending** (dispute window open). Check `withdrawableBalance` first:

```bash
export RECEIPTS=0xB9b98cC2cCF067F710A7DCc92d8FC558F5b12160
export PAYEE=0x73c37e8eddD9beF70FBbbe2861a8A776FABf1AA7
export USDC=0xeAeb66E869C43FB5FeB0A18729A2fbaAEB30B618
export RPC=https://atlantic.dplabs-internal.com

WITHDRAWABLE_RAW=$(cast call $RECEIPTS "withdrawableBalance(address,address)(uint256)" $PAYEE $USDC --rpc-url $RPC)
WITHDRAWABLE_DEC=$(cast to-dec "$WITHDRAWABLE_RAW")

if [ "$WITHDRAWABLE_DEC" -eq 0 ]; then
  echo "Abort: withdrawable=0 — call finalizeReceipt first or wait dispute window"
  exit 1
fi
echo "Withdrawable: $WITHDRAWABLE_DEC raw"
```

**PowerShell:**

```powershell
$w = cast call $env:RECEIPTS_ADDRESS "withdrawableBalance(address,address)(uint256)" $env:PAYEE_ADDRESS $env:USDC_ADDRESS --rpc-url $env:RPC
if ([bigint](cast to-dec $w) -eq 0) { throw "Abort: nothing withdrawable — finalize first" }
```

> **Critical:** Use `cast to-dec` — never compare hex balances with `-eq 0` / `-gt 0` in Bash or PowerShell. In PowerShell use `[bigint]`, not `[int64]`, for uint256 values (18-decimal PHRS can overflow `[int64]`).

### Command Template

```bash
cast call $RECEIPTS "withdrawableBalance(address,address)(uint256)" $PAYEE $USDC --rpc-url $RPC

cast send $RECEIPTS "withdrawAll(address,address)" $USDC $PAYEE \
  --private-key $PAYEE_KEY --rpc-url $RPC
```

### Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `nothing to withdraw` | Not finalized | Call `#finalize` first |
| `insufficient withdrawable` | Amount too high | Check balance |

---

## Earnings Dashboard {#earnings-summary}

### Overview

**Demo closing beat.** Single view for agent dashboard — lifetime, pending, withdrawable, disputed, payment count.

### Command Template

```bash
cast call $RECEIPTS "getEarningsSummary(address,address)(uint256,uint256,uint256,uint256,uint256)" \
  $PAYEE $USDC --rpc-url $RPC
```

### Output Parsing

| Field | Raw | Agent displays |
|-------|-----|----------------|
| `lifetimeEarned` | uint256 (6 dp) | `Lifetime: $X.XX USDC` — divide by 1e6 |
| `pending` | uint256 | `Pending (dispute window): $X.XX` |
| `withdrawable` | uint256 | `Ready to withdraw: $X.XX` |
| `disputed` | uint256 | `In dispute: $X.XX` |
| `paymentCount` | uint256 | `Total payments: N` |

### Example

Raw: `(10000 [1e4], 10000 [1e4], 0, 0, 1)`

Agent says:
```
Earnings dashboard for 0xPayee...
Lifetime: $0.01 USDC
Pending: $0.01
Withdrawable: $0.00
In dispute: $0.00
Total payments: 1
```

> **Agent Guidelines:**
> 1. Always format USDC amounts for humans (6 decimals)
> 2. Call again after `#finalize` to show withdrawable increase
> 3. Link explorer: `https://atlantic.pharosscan.xyz/address/$RECEIPTS`

---

## Per-Route Analytics {#analytics}

### Command Template

```bash
export RESOURCE_ID=$(cast keccak "GET /insight")
cast call $RECEIPTS "getResourceRevenue(bytes32)(uint256,uint256,uint256)" \
  $RESOURCE_ID --rpc-url $RPC
```

---

## Read Receipt {#read}

```bash
cast call $RECEIPTS "getReceipt(uint256)((address,address,address,uint256,bytes32,bytes32,uint256,uint8))" \
  <id> --rpc-url $RPC
```

---

## Query Events {#query}

```bash
cast logs --rpc-url $RPC --address $RECEIPTS \
  "ReceiptLogged(uint256,address,address,address,uint256,bytes32,bytes32)"
```
