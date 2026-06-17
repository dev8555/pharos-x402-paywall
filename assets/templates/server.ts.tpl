import { config } from "dotenv";
import express from "express";
import { paymentMiddleware, x402ResourceServer } from "@x402/express";
import { HTTPFacilitatorClient } from "@x402/core/server";
import { ExactEvmScheme } from "@x402/evm/exact/server";
import { env, resourceIdForRoute } from "./config.js";
import { logReceiptOnChain } from "./receipts.js";
import { settleTxHashFromTransaction } from "./settleTxHash.js";

config();

const payTo = env.payToAddress || env.receiptsAddress;
if (!payTo) {
  console.error("Set PAY_TO_ADDRESS or RECEIPTS_ADDRESS (treasury mode: use receipts contract)");
  process.exit(1);
}

const payee = env.payeeAddress || payTo;
const facilitatorUrl = env.facilitatorUrl;

const facilitatorClient = new HTTPFacilitatorClient({ url: facilitatorUrl });
const resourceServer = new x402ResourceServer(facilitatorClient);

const evmScheme = new ExactEvmScheme();
evmScheme.registerMoneyParser(async (amount, network) => {
  if (network === env.pharosNetwork) {
    return {
      amount: Math.round(amount * 1e6).toString(),
      asset: env.usdcAddress,
      extra: {
        token: env.usdcName,
        name: env.usdcName,
        version: "2",
      },
    };
  }
  return null;
});

resourceServer.register(env.pharosNetwork, evmScheme);

resourceServer.onAfterSettle(async (ctx) => {
  try {
    const tx = ctx.result.transaction;
    if (!tx) return;

    const payer = (ctx.paymentPayload as { payload?: { authorization?: { from?: string } } })
      ?.payload?.authorization?.from as `0x${string}` | undefined;
    const amount = BigInt(ctx.requirements.amount);
    const transport = ctx.transportContext as { path?: string; method?: string } | undefined;
    const path = transport?.path || "/insight";
    const method = transport?.method || "GET";
    const resourceId = resourceIdForRoute(method, path);
    const settleTxHash = settleTxHashFromTransaction(tx);

    if (payer) {
      await logReceiptOnChain({
        payer,
        payee,
        asset: env.usdcAddress,
        amount,
        resourceId,
        settleTxHash,
      });
    }
  } catch (e) {
    console.error("afterSettle receipt hook:", e);
  }
});

const routes = {
  "GET /insight": {
    accepts: {
      scheme: "exact" as const,
      price: "$0.01",
      network: env.pharosNetwork,
      payTo,
    },
    description: "Paid market insight",
    mimeType: "application/json",
  },
  "GET /api/info": {
    accepts: {
      scheme: "exact" as const,
      price: "$0.005",
      network: env.pharosNetwork,
      payTo,
    },
    description: "Low-cost info endpoint",
    mimeType: "application/json",
  },
};

const app = express();

async function main() {
  await resourceServer.initialize();
  app.use(paymentMiddleware(routes, resourceServer));

  app.get("/health", (_req, res) => {
    res.json({ status: "ok", network: env.pharosNetwork });
  });

  app.get("/insight", (_req, res) => {
    res.json({
      insight: "Pharos Atlantic yields remain attractive vs. TradFi money markets.",
      timestamp: Date.now(),
    });
  });

  app.get("/api/info", (_req, res) => {
    res.json({
      name: "pharos-x402-paywall",
      network: "Pharos Atlantic Testnet",
      chainId: env.chainId,
      timestamp: Date.now(),
    });
  });

  app.listen(env.port, () => {
    console.log(`Paywall server http://localhost:${env.port}`);
    console.log(`Pay to (treasury): ${payTo}`);
    console.log(`Payee (receipts): ${payee}`);
    console.log(`Facilitator: ${facilitatorUrl}`);
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
