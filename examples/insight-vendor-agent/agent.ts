/**
 * Insight Vendor Agent — polls earnings and optionally pays upstream data APIs.
 * Run from repo root: npx tsx examples/insight-vendor-agent/agent.ts
 */
import { config } from "dotenv";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import {
  formatEarningsDashboard,
  getEarningsSummary,
} from "../../src/receipts.js";
import { env } from "../../src/config.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
config({ path: resolve(__dirname, ".env") });
config({ path: resolve(__dirname, "../../.env") });

const pollMs = parseInt(process.env.POLL_INTERVAL_MS || "60000", 10);
const upstreamUrl = process.env.UPSTREAM_URL;
const paywallUrl = process.env.PAYWALL_URL || `http://localhost:${env.port}/insight`;

type Snapshot = Awaited<ReturnType<typeof getEarningsSummary>>;

let last: Snapshot | null = null;

async function pollEarnings() {
  const payee = env.payeeAddress;
  if (!payee) {
    console.error("Set PAYEE_ADDRESS in .env");
    process.exit(1);
  }

  const summary = await getEarningsSummary(payee, env.usdcAddress);
  console.log(`\n[${new Date().toISOString()}] Earnings update`);
  console.log(formatEarningsDashboard(summary));

  if (last) {
    const delta = summary.lifetimeEarned - last.lifetimeEarned;
    if (delta > 0n) {
      console.log(`Revenue delta: +${delta} raw USDC (${Number(delta) / 1e6} USD)`);
    }
  }
  last = summary;
}

async function maybeFetchUpstream() {
  if (!upstreamUrl) return;
  try {
    const { default: runClient } = await import("../../src/client.js").catch(() => ({ default: null }));
    void runClient;
    console.log(`Upstream configured: ${upstreamUrl} (use npm run client -- ${upstreamUrl})`);
  } catch {
    console.log(`Upstream URL set; run: npm run client -- ${upstreamUrl}`);
  }
}

console.log("Insight Vendor Agent started");
console.log(`Paywall: ${paywallUrl}`);
console.log(`Poll interval: ${pollMs}ms`);

await maybeFetchUpstream();
await pollEarnings();

setInterval(() => {
  pollEarnings().catch((err) => console.error("Poll failed:", err));
}, pollMs);
