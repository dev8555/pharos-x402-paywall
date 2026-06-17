# Launch Insight Paywall

Agent prompt sequence:

1. "Deploy X402Receipts on Pharos Atlantic with 300 second dispute window"
2. "Set PAY_TO_ADDRESS to the receipts contract"
3. "Start the x402 facilitator and paywall server"
4. "Test that GET /insight returns 402 without payment"

Expected: verified contract on pharosscan; `curl -i http://localhost:4021/insight` returns 402.

See [`references/receipts.md`](../../references/receipts.md) and [`references/paywall.md`](../../references/paywall.md).
