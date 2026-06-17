# Judge Quick Path

Live verification checklist — under 5 minutes.

## Prerequisites

- Node.js 20+, Foundry (`forge`, `cast`)
- `.env` with `EVM_PRIVATE_KEY` (payer + recorder)
- Pharos Atlantic PHRS + **MockUSDC** balance (pre-deployed in `.env.example`; mint more via [`references/mock-usdc.md`](references/mock-usdc.md))

## Steps

1. **Install**

```bash
git clone https://github.com/dev8555/pharos-x402-paywall && cd pharos-x402-paywall
npm install
forge install foundry-rs/forge-std
cp .env.example .env   # set EVM_PRIVATE_KEY
```

2. **Start services** (two terminals)

```bash
npm run facilitator   # terminal 1 → :3000
npm run server        # terminal 2 → :4021
```

3. **Unpaid probe → 402**

```bash
curl -i http://localhost:4021/insight
```

Expected: `HTTP/1.1 402 Payment Required`

4. **Autopay → 200**

```bash
npm run client -- http://localhost:4021/insight
```

Expected: `Request succeeded!` + JSON insight + `Transaction hash: 0x...`

5. **Dashboard**

```bash
npm run dashboard -- 0x73c37e8eddD9beF70FBbbe2861a8A776FABf1AA7
```

Expected:

```
Lifetime: $0.01 USDC
Pending: $0.01
Withdrawable: $0.00
In dispute: $0.00
Total payments: 1
```

6. **On-chain proofs** — open links in [README.md](../README.md#live-proofs)

7. **Automated tests**

```bash
npm run test:all
```

## Submit

- Public GitHub repo (no `.env`, `node_modules/`, `out/`, `cache/`, private keys)
- DoraHacks submission before deadline
