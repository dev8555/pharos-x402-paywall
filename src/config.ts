import { config } from "dotenv";
import { readFileSync, existsSync } from "fs";
import { keccak256, toBytes } from "viem";

config({ override: true });

const PHAROS_NETWORK = "eip155:688689" as const;

export function getPrivateKey(): `0x${string}` {
  const key =
    process.env.EVM_PRIVATE_KEY ||
    process.env.PRIVATE_KEY ||
    (existsSync(".private_key") ? readFileSync(".private_key", "utf-8").trim() : undefined);
  if (!key) {
    throw new Error("Set EVM_PRIVATE_KEY or PRIVATE_KEY (never share with LLM)");
  }
  return key as `0x${string}`;
}

export const env = {
  rpc: process.env.RPC || "https://atlantic.dplabs-internal.com",
  facilitatorUrl: process.env.FACILITATOR_URL || "http://localhost:3000",
  usdcAddress: (process.env.USDC_ADDRESS ||
    "0xeAeb66E869C43FB5FeB0A18729A2fbaAEB30B618") as `0x${string}`,
  usdcName: process.env.USDC_NAME || "USDC",
  payToAddress: process.env.PAY_TO_ADDRESS as `0x${string}` | undefined,
  payeeAddress: process.env.PAYEE_ADDRESS as `0x${string}` | undefined,
  receiptsAddress: process.env.RECEIPTS_ADDRESS as `0x${string}` | undefined,
  recorderAddress: process.env.RECORDER_ADDRESS as `0x${string}` | undefined,
  facilitatorSignerAddress: process.env.FACILITATOR_SIGNER_ADDRESS as `0x${string}` | undefined,
  port: parseInt(process.env.PORT || "4021", 10),
  facilitatorPort: parseInt(process.env.FACILITATOR_PORT || "3000", 10),
  pharosNetwork: PHAROS_NETWORK,
  chainId: 688689,
};

export const X402_RECEIPTS_ABI = [
  {
    type: "function",
    name: "logReceipt",
    inputs: [
      { name: "payer", type: "address" },
      { name: "payee", type: "address" },
      { name: "asset", type: "address" },
      { name: "amount", type: "uint256" },
      { name: "resourceId", type: "bytes32" },
      { name: "settleTxHash", type: "bytes32" },
    ],
    outputs: [{ name: "id", type: "uint256" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "logReceiptWithProof",
    inputs: [
      { name: "payer", type: "address" },
      { name: "payee", type: "address" },
      { name: "asset", type: "address" },
      { name: "amount", type: "uint256" },
      { name: "resourceId", type: "bytes32" },
      { name: "settleTxHash", type: "bytes32" },
      { name: "signature", type: "bytes" },
    ],
    outputs: [{ name: "id", type: "uint256" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "getReceipt",
    inputs: [{ name: "id", type: "uint256" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "payer", type: "address" },
          { name: "payee", type: "address" },
          { name: "asset", type: "address" },
          { name: "amount", type: "uint256" },
          { name: "resourceId", type: "bytes32" },
          { name: "settleTxHash", type: "bytes32" },
          { name: "loggedAt", type: "uint256" },
          { name: "status", type: "uint8" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getEarningsSummary",
    inputs: [
      { name: "payee", type: "address" },
      { name: "asset", type: "address" },
    ],
    outputs: [
      { name: "lifetimeEarned", type: "uint256" },
      { name: "pending", type: "uint256" },
      { name: "withdrawable", type: "uint256" },
      { name: "disputed", type: "uint256" },
      { name: "paymentCount", type: "uint256" },
    ],
    stateMutability: "view",
  },
] as const;

export function resourceIdForRoute(method: string, path: string): `0x${string}` {
  return keccak256(toBytes(`${method} ${path}`));
}
