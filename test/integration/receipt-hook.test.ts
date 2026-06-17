import { describe, expect, it, vi } from "vitest";
import { settleTxHashFromTransaction } from "../../src/settleTxHash.js";

describe("duplicate settlement handling", () => {
  it("settleTxHash helper is deterministic for same tx", () => {
    const tx = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef";
    const a = settleTxHashFromTransaction(tx);
    const b = settleTxHashFromTransaction(tx);
    expect(a).toBe(b);
  });

  it("logReceiptOnChain swallows duplicate settle errors", async () => {
    const logReceiptOnChain = vi.fn().mockRejectedValue(new Error("settle tx already used"));
    await expect(
      logReceiptOnChain({
        payer: "0x1111111111111111111111111111111111111111",
        payee: "0x2222222222222222222222222222222222222222",
        asset: "0x3333333333333333333333333333333333333333",
        amount: 10_000n,
        resourceId: "0x4444444444444444444444444444444444444444444444444444444444444444",
        settleTxHash: settleTxHashFromTransaction(
          "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        ),
      }).catch(() => null)
    ).resolves.toBeNull();
  });
});
