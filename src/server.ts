import { config } from "dotenv";
import { env } from "./config.js";
import { createPaywallApp } from "./paywallApp.js";

config({ override: true });

const payTo = env.payToAddress || env.receiptsAddress;
if (!payTo) {
  console.error("Set PAY_TO_ADDRESS or RECEIPTS_ADDRESS (treasury mode: use receipts contract)");
  process.exit(1);
}

const payee = (env.payeeAddress || payTo) as `0x${string}`;

async function main() {
  const { app } = await createPaywallApp({ payTo: payTo as `0x${string}`, payee });
  app.listen(env.port, () => {
    console.log(`Paywall server http://localhost:${env.port}`);
    console.log(`Pay to (treasury): ${payTo}`);
    console.log(`Payee (receipts): ${payee}`);
    console.log(`Facilitator: ${env.facilitatorUrl}`);
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
