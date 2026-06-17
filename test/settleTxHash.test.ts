import { describe, expect, it } from "vitest";
import { settleTxHashFromTransaction } from "../src/settleTxHash.js";

describe("settleTxHashFromTransaction", () => {
  const tx = "0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789";

  it("returns tx hash directly as bytes32 (not ASCII-encoded)", () => {
    const result = settleTxHashFromTransaction(tx);
    expect(result).toBe(tx);
    // Legacy bug: stringToHex("0xabc...") produces UTF-8 bytes of the hash string
    expect(result).not.toBe("0x307862636465663031"); // would differ from real hash
  });

  it("rejects missing 0x prefix", () => {
    expect(() => settleTxHashFromTransaction(tx.slice(2))).toThrow("invalid settle tx hash");
  });

  it("rejects wrong length", () => {
    expect(() => settleTxHashFromTransaction("0xabc")).toThrow("invalid settle tx hash");
  });

  it("accepts zero hash", () => {
    expect(
      settleTxHashFromTransaction(
        "0x0000000000000000000000000000000000000000000000000000000000000000"
      )
    ).toBe("0x0000000000000000000000000000000000000000000000000000000000000000");
  });
});
