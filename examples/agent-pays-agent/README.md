# Agent Pays Agent (A2A)

Two wallets:

- **Seller:** runs facilitator + paywall (`PAYEE_ADDRESS` = seller wallet)
- **Buyer:** runs autopay client with buyer's `EVM_PRIVATE_KEY`

Agent prompts:

1. Seller: "Monetize /insight at $0.01 USDC"
2. Buyer: "Pay for http://localhost:4021/insight and show the transaction hash"
3. Seller: "Show my earnings dashboard" → `getEarningsSummary`

Expected: USDC in receipts contract; dashboard shows 1 payment; after finalize + withdraw, seller wallet receives USDC.

Phase 2 narrative: autonomous agents paying each other without human intervention.
