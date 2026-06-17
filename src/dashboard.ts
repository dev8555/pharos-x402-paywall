import { config } from "dotenv";
import { env } from "./config.js";
import { formatEarningsDashboard, getEarningsSummary } from "./receipts.js";

config();

const payee = (process.argv[2] || env.payeeAddress) as `0x${string}` | undefined;
if (!payee) {
  console.error("Usage: npm run dashboard -- <payee_address>");
  console.error("Or set PAYEE_ADDRESS in .env");
  process.exit(1);
}

const summary = await getEarningsSummary(payee, env.usdcAddress);
console.log(`Earnings dashboard for ${payee}:\n`);
console.log(formatEarningsDashboard(summary));
