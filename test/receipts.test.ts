import { describe, expect, it } from "vitest";
import { formatEarningsDashboard, formatUsdc } from "../src/receipts.js";

describe("formatUsdc", () => {
  it("formats 6-decimal USDC amounts", () => {
    expect(formatUsdc(10_000n)).toBe("$0.01");
    expect(formatUsdc(5_000_000n)).toBe("$5.00");
  });
});

describe("formatEarningsDashboard", () => {
  it("renders dashboard lines", () => {
    const output = formatEarningsDashboard({
      lifetimeEarned: 10_000n,
      pending: 10_000n,
      withdrawable: 0n,
      disputed: 0n,
      paymentCount: 1n,
    });
    expect(output).toContain("Lifetime: $0.01 USDC");
    expect(output).toContain("Pending: $0.01");
    expect(output).toContain("Withdrawable: $0");
    expect(output).toContain("Total payments: 1");
  });
});
