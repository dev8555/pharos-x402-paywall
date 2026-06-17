import dotenv from "dotenv";
import express from "express";
import { privateKeyToAccount } from "viem/accounts";
import { createPublicClient, createWalletClient, http, defineChain } from "viem";
import { x402Facilitator } from "@x402/core/facilitator";
import { registerExactEvmScheme } from "@x402/evm/exact/facilitator";
import { toFacilitatorEvmSigner } from "@x402/evm";
import { env, getPrivateKey } from "./config.js";

dotenv.config({ override: true });

const pharos = defineChain({
  id: 688_689,
  name: "Pharos Atlantic Testnet",
  nativeCurrency: { name: "PHRS", symbol: "PHRS", decimals: 18 },
  rpcUrls: { default: { http: [env.rpc] } },
  testnet: true,
});

const account = privateKeyToAccount(getPrivateKey());
const rpcTransport = http(env.rpc, { timeout: 30_000 });

const publicClient = createPublicClient({
  chain: pharos,
  transport: rpcTransport,
});

const walletClient = createWalletClient({
  account,
  chain: pharos,
  transport: rpcTransport,
});

const signer = toFacilitatorEvmSigner({
  address: account.address,
  getCode: (args) => publicClient.getCode(args),
  readContract: (args) =>
    publicClient.readContract({ ...args, args: (args.args ?? []) as readonly unknown[] }),
  verifyTypedData: (args) =>
    publicClient.verifyTypedData(args as Parameters<typeof publicClient.verifyTypedData>[0]),
  writeContract: (args) =>
    walletClient.writeContract({ ...args, args: (args.args ?? []) as readonly unknown[] }),
  sendTransaction: (args) => walletClient.sendTransaction(args),
  waitForTransactionReceipt: (args) => publicClient.waitForTransactionReceipt(args),
});

const facilitator = new x402Facilitator();
registerExactEvmScheme(facilitator, {
  signer,
  networks: env.pharosNetwork,
});

const app = express();
app.use(express.json());

app.post("/verify", async (req, res) => {
  try {
    const { paymentPayload, paymentRequirements } = req.body;
    const result = await facilitator.verify(paymentPayload, paymentRequirements);
    res.json(result);
  } catch (e) {
    res.status(500).json({ error: (e as Error).message });
  }
});

app.post("/settle", async (req, res) => {
  try {
    const { paymentPayload, paymentRequirements } = req.body;
    const result = await facilitator.settle(paymentPayload, paymentRequirements);
    res.json(result);
  } catch (e) {
    res.status(500).json({ error: (e as Error).message });
  }
});

app.get("/supported", (_req, res) => {
  res.json(facilitator.getSupported());
});

app.listen(env.facilitatorPort, () => {
  console.log(`Facilitator running on http://localhost:${env.facilitatorPort}`);
  console.log(`Network: ${env.pharosNetwork} (Pharos Atlantic)`);
  console.log(`Signer: ${account.address}`);
});
