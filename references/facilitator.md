# Facilitator Operation Instructions

> **Network Configuration:** Read `rpcUrl` from [`assets/networks.json`](../assets/networks.json).
> **Private Key:** `EVM_PRIVATE_KEY` — facilitator wallet needs PHRS for gas.

---

## Start Self-Hosted Facilitator

### Overview

Runs `@x402/core/facilitator` with `ExactEvmScheme` on Pharos Atlantic. Exposes `/verify`, `/settle`, `/supported` for the paywall server.

### Command Template

```bash
export EVM_PRIVATE_KEY=0x...
export RPC=https://atlantic.dplabs-internal.com
npm run facilitator
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `EVM_PRIVATE_KEY` | hex | Yes | Facilitator signer (gas) |
| `FACILITATOR_PORT` | number | No | Default `3000` |

### Output Parsing

| Field | Description |
|-------|-------------|
| `Facilitator running on http://localhost:3000` | Ready |
| `Network: eip155:688689` | Pharos Atlantic registered |

### Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `insufficient funds` | No PHRS for gas | Fund facilitator wallet |
| RPC timeout | Slow node | Increase viem timeout (30s default) |

> **Agent Guidelines:**
> 1. Start facilitator **before** paywall server
> 2. Health check: `curl http://localhost:3000/supported`
> 3. Set `FACILITATOR_URL=http://localhost:3000` in server `.env`

---

## Hosted Facilitator Fallback {#hosted}

### Overview

If self-hosting fails, set `FACILITATOR_URL` to a team-provided hosted facilitator (if available).

### Command Template

```bash
export FACILITATOR_URL=https://your-hosted-facilitator.example
```

### Agent Guidelines

1. Document SPOF risk — monitor `/supported` health
2. Facilitator wallet must hold PHRS for settlement gas

---

## Health Check {#health}

### Command Template

```bash
curl http://localhost:3000/supported
```

### Output Parsing

| Field | Description |
|-------|-------------|
| JSON array | Supported schemes/networks; must include `eip155:688689` |
