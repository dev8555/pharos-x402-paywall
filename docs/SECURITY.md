# Security

## Custody model (treasury mode)

- x402 settle sends USDC to **`X402Receipts`** (`PAY_TO_ADDRESS` = `RECEIPTS_ADDRESS`)
- The contract holds USDC until the payee calls **`withdraw`** / **`withdrawAll`**
- `logReceipt` credits **accounting balances** (`pendingBalance` → `withdrawableBalance`); it does not transfer tokens again

## Trusted roles

| Role | Capability | Set by |
|------|------------|--------|
| **Owner** | `resolveDispute`, `setDisputeWindow`, `setAuthorizedRecorder`, `setFacilitatorSigner` | Deployer |
| **Authorized recorder** | Call `logReceipt` directly | Owner (`setAuthorizedRecorder`) |
| **Facilitator signer** | Call `logReceipt` or sign settlement proofs | Owner (`setFacilitatorSigner`) |
| **Payer** | `disputeReceipt` within dispute window | Payment signer |
| **Payee** | `withdraw` / `withdrawAll` after finalize | Receipt beneficiary |

## Dispute assumptions

- Default **`disputeWindowSeconds`** = 300 (5 min) on Atlantic demo deploy
- Payer may **`disputeReceipt`** while status is Pending and window is open
- Owner may **`resolveDispute`** (refund payer or uphold payee)
- If owner is absent: **`forceFinalize`** after **7×** dispute window credits payee

## Settlement proof limitations

`logReceiptWithProof` verifies an **EIP-712 signature** from `facilitatorSigner` attesting:

`(payer, payee, asset, amount, resourceId, settleTxHash, chainId, receiptsContract)`

This proves the facilitator attested to an x402 settlement off-chain. It does **not**:

- Replay-verify the settle transaction on-chain inside the contract
- Guarantee USDC balance equals logged amounts (operators should monitor `balanceOf(RECEIPTS)`)

Production deployments should combine facilitator attestation with off-chain monitoring or indexers.

## Operational security

- Never commit **`EVM_PRIVATE_KEY`** — use `.env` (gitignored)
- Never paste private keys into LLM prompts
- **`RECORDER_ADDRESS`** should be the paywall server wallet only
- **`FACILITATOR_SIGNER_ADDRESS`** should match the facilitator's signing key
- Atlantic (688689) is testnet; Pacific (1672) is mainnet with real assets

## Known limitations

- Paywall JWT repeat-access is documented but not implemented in `src/server.ts`
- `logReceipt` hook failures are non-blocking (HTTP 200 still returned)
- Self-hosted facilitator only; hosted fallback is env-configured URL
- Permissionless read functions (`getEarningsSummary`, `getReceipt`) expose ledger data
