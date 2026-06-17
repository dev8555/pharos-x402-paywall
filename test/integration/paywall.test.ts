import { beforeEach, describe, expect, it, vi } from "vitest";
import request from "supertest";
import type { Express } from "express";

const logReceiptOnChain = vi.fn().mockResolvedValue(0n);
const settleTxHashFromTransaction = vi.fn();

vi.mock("../../src/receipts.js", () => ({
  logReceiptOnChain,
}));

vi.mock("../../src/settleTxHash.js", () => ({
  settleTxHashFromTransaction,
}));

vi.mock("@x402/express", () => {
  type Handler = (
    req: unknown,
    res: {
      status: (n: number) => { json: (b: unknown) => void; end: () => void };
      setHeader: (k: string, v: string) => void;
    },
    next: () => void
  ) => void;

  class MockResourceServer {
    handlers: Array<(ctx: unknown) => Promise<void>> = [];

    register() {}
    async initialize() {}
    onAfterSettle(fn: (ctx: unknown) => Promise<void>) {
      this.handlers.push(fn);
    }
  }

  return {
    x402ResourceServer: MockResourceServer,
    paymentMiddleware: (_routes: unknown, resourceServer: MockResourceServer): Handler => {
      return (req, res, next) => {
        const r = req as {
          method: string;
          path: string;
          headers: Record<string, string | undefined>;
        };
        const paid = r.headers["payment-signature"] || r.headers["x-payment-signature"];
        if (!paid && r.path === "/insight") {
          res.status(402).json({ error: "Payment Required" });
          return;
        }
        if (paid && resourceServer.handlers.length > 0) {
          const tx = "0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789";
          settleTxHashFromTransaction.mockReturnValue(
            "0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
          );
          void resourceServer.handlers[0]({
            result: { transaction: tx },
            paymentPayload: {
              payload: { authorization: { from: "0x1111111111111111111111111111111111111111" } },
            },
            requirements: { amount: "10000" },
            transportContext: { path: "/insight", method: "GET" },
          });
        }
        next();
      };
    },
  };
});

describe("paywall integration", () => {
  let app: Express;

  beforeEach(async () => {
    vi.clearAllMocks();
    const { createPaywallApp } = await import("../../src/paywallApp.js");
    ({ app } = await createPaywallApp({
      payTo: "0xE0d0FCb866e02435A116ff62dD6caBb341b95466",
      payee: "0x73c37e8eddD9beF70FBbbe2861a8A776FABf1AA7",
    }));
  });

  it("returns 402 for unpaid /insight", async () => {
    const res = await request(app).get("/insight");
    expect(res.status).toBe(402);
    expect(logReceiptOnChain).not.toHaveBeenCalled();
  });

  it("returns 200 for paid /insight and logs receipt", async () => {
    const res = await request(app).get("/insight").set("payment-signature", "mock-signature");
    expect(res.status).toBe(200);
    expect(res.body.insight).toBeDefined();
    expect(settleTxHashFromTransaction).toHaveBeenCalled();
    expect(logReceiptOnChain).toHaveBeenCalledWith(
      expect.objectContaining({
        payer: "0x1111111111111111111111111111111111111111",
        payee: "0x73c37e8eddD9beF70FBbbe2861a8A776FABf1AA7",
        amount: 10_000n,
      })
    );
  });

  it("health endpoint is free", async () => {
    const res = await request(app).get("/health");
    expect(res.status).toBe(200);
    expect(res.body.status).toBe("ok");
  });
});
