import { config } from "dotenv";
import { wrapFetchWithPayment, decodePaymentResponseHeader } from "@x402/fetch";
import { x402Client } from "@x402/core/client";
import { ExactEvmScheme } from "@x402/evm/exact/client";
import { toClientEvmSigner } from "@x402/evm";
import { privateKeyToAccount } from "viem/accounts";
import { createWalletClient, http, publicActions } from "viem";
import { defineChain } from "viem";
import { getPrivateKey, env } from "./config.js";

config();

const pharos = defineChain({
  id: 688_689,
  name: "Pharos Atlantic Testnet",
  nativeCurrency: { name: "PHRS", symbol: "PHRS", decimals: 18 },
  rpcUrls: { default: { http: [env.rpc] } },
  testnet: true,
});

const account = privateKeyToAccount(getPrivateKey());
const walletClient = createWalletClient({
  account,
  chain: pharos,
  transport: http(env.rpc),
}).extend(publicActions);

const evmSigner = toClientEvmSigner(
  {
    address: account.address,
    signTypedData: (msg) => walletClient.signTypedData(msg),
  },
  walletClient
);

const client = new x402Client();
client.register(env.pharosNetwork, new ExactEvmScheme(evmSigner));

const fetchWithPayment = wrapFetchWithPayment(fetch, client);

const url = process.argv[2] || `http://localhost:${env.port}/insight`;

console.log(`Request URL: ${url}`);
console.log(`Payer: ${account.address}`);

try {
  const response = await fetchWithPayment(url);
  const data = await response.json();
  console.log("Request succeeded!");
  console.log("Response:", JSON.stringify(data, null, 2));

  const paymentHeader =
    response.headers.get("PAYMENT-RESPONSE") || response.headers.get("X-PAYMENT-RESPONSE");
  if (paymentHeader) {
    const paymentResponse = decodePaymentResponseHeader(paymentHeader);
    console.log("Transaction hash:", paymentResponse.transaction);
    console.log("Network:", paymentResponse.network);
    console.log("Payer:", paymentResponse.payer);
  }
} catch (error) {
  console.error("Request failed:", error);
  process.exit(1);
}
