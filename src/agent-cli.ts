import { config } from "dotenv";
import { env } from "./config.js";
import { formatEarningsDashboard, getEarningsSummary, getReceipt } from "./receipts.js";

config();

const [command, ...rest] = process.argv.slice(2);

async function facilitatorHealth() {
  const res = await fetch(`${env.facilitatorUrl}/supported`);
  console.log(`Facilitator ${env.facilitatorUrl}/supported → ${res.status}`);
  console.log(await res.text());
}

async function paywallProbe() {
  const url = rest[0] || `http://localhost:${env.port}/insight`;
  const res = await fetch(url);
  console.log(`GET ${url} → ${res.status}`);
  console.log(await res.text());
}

async function earnings() {
  const payee = (rest[0] || env.payeeAddress) as `0x${string}` | undefined;
  if (!payee) throw new Error("Usage: agent earnings [payeeAddress]");
  const summary = await getEarningsSummary(payee, env.usdcAddress);
  console.log(`Earnings dashboard for ${payee}`);
  console.log(formatEarningsDashboard(summary));
}

async function receipt() {
  const id = rest[0];
  if (!id) throw new Error("Usage: agent receipt <id>");
  const data = await getReceipt(BigInt(id));
  console.log(JSON.stringify(data, (_, v) => (typeof v === "bigint" ? v.toString() : v), 2));
}

const commands: Record<string, () => Promise<void>> = {
  health: facilitatorHealth,
  probe: paywallProbe,
  earnings,
  receipt,
};

if (!command || command === "help" || command === "--help") {
  console.log(`pharos-x402 agent CLI

Commands:
  health              Facilitator /supported check
  probe [url]         Unpaid paywall request (expect 402)
  earnings [payee]    getEarningsSummary dashboard
  receipt <id>        getReceipt by id

Examples:
  npm run agent -- health
  npm run agent -- probe http://localhost:4021/insight
  npm run agent -- earnings
  npm run agent -- receipt 0
`);
  process.exit(0);
}

const fn = commands[command];
if (!fn) {
  console.error(`Unknown command: ${command}`);
  process.exit(1);
}

fn().catch((err) => {
  console.error(err);
  process.exit(1);
});
