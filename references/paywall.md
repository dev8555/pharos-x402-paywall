# Paywall Operation Instructions

> **Network Configuration:** Read `rpcUrl` from [`assets/networks.json`](../assets/networks.json) (default: Atlantic).
> **x402 Network ID:** `eip155:688689`
> **USDC on Atlantic:** Use repo **MockUSDC** (EIP-3009) — see [`mock-usdc.md`](mock-usdc.md). Set `USDC_ADDRESS` from [`assets/tokens.json`](../assets/tokens.json).

---

## Scaffold x402 Paywall Server

### Overview

Creates an Express server with `@x402/express` middleware. Protected routes return HTTP 402 until the client pays USDC on Pharos Atlantic. **Treasury mode:** set `PAY_TO_ADDRESS` to the deployed `X402Receipts` contract so settlements accumulate on-chain.

### Command Template

```bash
cp assets/templates/server.ts.tpl src/server.ts
# Fill .env from .env.example
npm run facilitator   # terminal 1
npm run server        # terminal 2
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `PAY_TO_ADDRESS` | address | Yes | Deployed `X402Receipts` contract (treasury) |
| `PAYEE_ADDRESS` | address | Yes | Agent wallet credited in receipts / withdrawals |
| `FACILITATOR_URL` | URL | Yes | e.g. `http://localhost:3000` |
| `USDC_ADDRESS` | address | Yes | From `assets/tokens.json` |
| `RECEIPTS_ADDRESS` | address | Yes | Same as `PAY_TO_ADDRESS` for receipt logging |

### Output Parsing

| Field | Description |
|-------|-------------|
| `Paywall server http://localhost:4021` | Server started |
| `Pay to (treasury)` | USDC settlement destination |

### Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `Set PAY_TO_ADDRESS` | Missing env | Deploy receipts first; set address |
| Facilitator connection refused | Facilitator not running | `npm run facilitator` |
| `402` on every request | No payment attached | Use autopay client |

> **Agent Guidelines:**
> 1. Deploy `X402Receipts` first (see `references/receipts.md#deploy`)
> 2. Set `PAY_TO_ADDRESS` and `RECEIPTS_ADDRESS` to contract address
> 3. Start facilitator, then server
> 4. Test with `curl -i` (expect 402) then autopay client

---

## Test 402 Response {#test-402}

### Overview

Unpaid requests must return HTTP 402 with payment requirements.

### Command Template

```bash
curl -i http://localhost:4021/insight
```

### Output Parsing

| Field | Description |
|-------|-------------|
| `HTTP/1.1 402` | Payment required |
| `PAYMENT-REQUIRED` or JSON body | Payment instructions |

### Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| Connection refused | Server not running | `npm run server` |
| `200` instead of `402` | Wrong URL or middleware skipped | Use `/insight` not `/health` |

---

## JWT Post-Payment Access {#jwt}

### Overview

Optional: issue a short-lived JWT after successful payment so repeat calls within TTL skip re-payment. Document for production; not required for demo.

### Agent Guidelines

1. After settle success, sign JWT with `JWT_SECRET` from `.env`
2. Client sends `Authorization: Bearer <token>` on repeat requests
3. Server middleware bypasses x402 when JWT valid

---

## Wire Receipt Hook {#receipt-hook}

### Overview

After x402 settle, `src/server.ts` calls `logReceiptOnChain` via `onAfterSettle` hook. Non-blocking — HTTP 200 still returns if log fails.

### Agent Guidelines

1. Ensure `RECEIPTS_ADDRESS` is set
2. `settleTxHash` from settlement tx prevents double-credit (idempotency)
3. `resourceId` = `keccak256("GET /insight")` for `/insight` route
