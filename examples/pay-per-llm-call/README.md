# Pay-Per-LLM-Call

Model a $0.01 inference endpoint:

1. Add route in `src/server.ts` (or prompt agent to copy template):

```typescript
"POST /v1/chat": {
  accepts: { scheme: "exact", price: "$0.01", network: "eip155:688689", payTo },
  description: "LLM inference call",
  mimeType: "application/json",
},
```

2. Agent prompt: "Charge $0.01 per LLM call on POST /v1/chat"

3. Client: `npm run client -- http://localhost:4021/v1/chat`

Expected: same x402 loop; `getResourceRevenue(keccak("POST /v1/chat"))` tracks per-route revenue.
