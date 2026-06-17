# Autopay Client Operation Instructions

> **Network Configuration:** Read `rpcUrl` from [`assets/networks.json`](../assets/networks.json).
> **x402 Network ID:** `eip155:688689`
> **Private Key:** `EVM_PRIVATE_KEY` env only — never pass to the model.

---

## Run Autopay Client

### Overview

Wraps `fetch` with `@x402/fetch` to detect HTTP 402, sign USDC payment on Pharos Atlantic, retry with `PAYMENT-SIGNATURE`, and return paid content.

### Command Template

```bash
export EVM_PRIVATE_KEY=0x...
npm run client -- http://localhost:4021/insight
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `EVM_PRIVATE_KEY` | hex | Yes | Payer wallet with USDC + PHRS for gas |
| URL arg | string | Yes | Paid endpoint URL |

### Output Parsing

| Field | Description |
|-------|-------------|
| `Request succeeded!` | HTTP 200 after payment |
| `Transaction hash:` | On-chain USDC settlement tx |
| `Payer:` | Payer address from `PAYMENT-RESPONSE` |

### Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `insufficient funds` | Low USDC or PHRS | Fund wallet; see `#precheck` |
| `Failed to create payment payload` | Wrong network or USDC | Confirm facilitator supports `eip155:688689` |
| Connection refused | Server/facilitator down | Start both services |

> **Agent Guidelines:**
> 1. Complete Write Operation Pre-checks (see `SKILL.md`)
> 2. Run `#precheck` with `cast to-dec` before `npm run client`
> 3. Show explorer link: `https://atlantic.pharosscan.xyz/tx/<hash>`

---

## Precheck USDC Balance {#precheck}

### Overview

Verify payer has enough USDC before attempting autopay.

### Command Template

```bash
export RPC=https://atlantic.dplabs-internal.com
export USDC=0xeAeb66E869C43FB5FeB0A18729A2fbaAEB30B618
export PAYER=$(cast wallet address --private-key $EVM_PRIVATE_KEY)
export MIN_USDC_RAW=10000   # $0.01 — match route price

BALANCE_RAW=$(cast call $USDC "balanceOf(address)(uint256)" $PAYER --rpc-url $RPC)
BALANCE_DEC=$(cast to-dec "$BALANCE_RAW")

# Bash — never compare hex with -gt/-lt (cast may return 0x...)
if [ "$BALANCE_DEC" -lt "$MIN_USDC_RAW" ]; then
  echo "Insufficient USDC: have $BALANCE_DEC raw, need >= $MIN_USDC_RAW"
  exit 1
fi
echo "USDC OK: $BALANCE_DEC raw ($(echo "scale=6; $BALANCE_DEC / 1000000" | bc) USDC)"
```

**PowerShell (Windows):**

```powershell
$env:RPC = "https://atlantic.dplabs-internal.com"
$env:USDC = "0xeAeb66E869C43FB5FeB0A18729A2fbaAEB30B618"
$env:MIN_USDC_RAW = 10000
$PAYER = cast wallet address --private-key $env:EVM_PRIVATE_KEY
$BALANCE_RAW = cast call $env:USDC "balanceOf(address)(uint256)" $PAYER --rpc-url $env:RPC
$BALANCE_DEC = [bigint](cast to-dec $BALANCE_RAW)
if ($BALANCE_DEC -lt $env:MIN_USDC_RAW) { throw "Insufficient USDC: $BALANCE_DEC raw" }
Write-Host "USDC OK: $BALANCE_DEC raw"
```

> **Critical:** Always pipe `cast call` uint256 results through `cast to-dec` before numeric comparison. Raw values may be hex (`0x2710`) or decimal (`10000`) depending on shell/RPC — `[ "$x" -gt 10000 ]` fails on hex and breaks on PowerShell. In PowerShell use `[bigint]`, not `[int64]` — 18-decimal PHRS balances exceed `[int64]::MaxValue`.

### Output Parsing

| Field | Description |
|-------|-------------|
| Return value | Raw USDC (6 decimals). `10000` = $0.01 |

### Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `connection refused` | Missing `--rpc-url` | Pass `$RPC` explicitly |

---

## Idempotency and Retry {#idempotency}

### Overview

On network failure after settle, retry with the same payment proof. The receipts contract deduplicates via `usedSettleTx[settleTxHash]`.

### Agent Guidelines

1. Save `transaction` hash from `PAYMENT-RESPONSE` before retrying
2. Do not create a new payment if settlement already succeeded
3. Server `logReceipt` reverts with `"settle tx already used"` if duplicate — this is expected
