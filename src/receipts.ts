import { createWalletClient, http, publicActions, type Hex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { defineChain } from "viem";
import { env, getPrivateKey, X402_RECEIPTS_ABI } from "./config.js";

const pharos = defineChain({
  id: 688_689,
  name: "Pharos Atlantic Testnet",
  nativeCurrency: { name: "PHRS", symbol: "PHRS", decimals: 18 },
  rpcUrls: { default: { http: [env.rpc] } },
  testnet: true,
});

export type LogReceiptParams = {
  payer: `0x${string}`;
  payee: `0x${string}`;
  asset: `0x${string}`;
  amount: bigint;
  resourceId: Hex;
  settleTxHash: Hex;
};

export async function logReceiptOnChain(params: LogReceiptParams): Promise<bigint | null> {
  const receiptsAddress = env.receiptsAddress;
  if (!receiptsAddress) {
    console.warn("RECEIPTS_ADDRESS not set — skipping on-chain receipt log");
    return null;
  }

  try {
    const account = privateKeyToAccount(getPrivateKey());
    const client = createWalletClient({
      account,
      chain: pharos,
      transport: http(env.rpc),
    }).extend(publicActions);

    const hash = await client.writeContract({
      address: receiptsAddress,
      abi: X402_RECEIPTS_ABI,
      functionName: "logReceipt",
      args: [
        params.payer,
        params.payee,
        params.asset,
        params.amount,
        params.resourceId,
        params.settleTxHash,
      ],
    });
    console.log("Receipt logged on-chain:", hash);
    return hash as unknown as bigint;
  } catch (err) {
    console.error("logReceipt failed (non-blocking):", err);
    return null;
  }
}

export async function getReceipt(id: bigint) {
  const receiptsAddress = env.receiptsAddress;
  if (!receiptsAddress) throw new Error("RECEIPTS_ADDRESS not set");

  const account = privateKeyToAccount(getPrivateKey());
  const client = createWalletClient({
    account,
    chain: pharos,
    transport: http(env.rpc),
  }).extend(publicActions);

  return client.readContract({
    address: receiptsAddress,
    abi: X402_RECEIPTS_ABI,
    functionName: "getReceipt",
    args: [id],
  });
}

export async function getEarningsSummary(payee: `0x${string}`, asset: `0x${string}`) {
  const receiptsAddress = env.receiptsAddress;
  if (!receiptsAddress) throw new Error("RECEIPTS_ADDRESS not set");

  const account = privateKeyToAccount(getPrivateKey());
  const client = createWalletClient({
    account,
    chain: pharos,
    transport: http(env.rpc),
  }).extend(publicActions);

  const [lifetimeEarned, pending, withdrawable, disputed, paymentCount] = await client.readContract(
    {
      address: receiptsAddress,
      abi: X402_RECEIPTS_ABI,
      functionName: "getEarningsSummary",
      args: [payee, asset],
    }
  );

  return { lifetimeEarned, pending, withdrawable, disputed, paymentCount };
}

export function formatUsdc(amount: bigint): string {
  const whole = amount / 1_000_000n;
  const frac = amount % 1_000_000n;
  return `$${whole}.${frac.toString().padStart(6, "0").replace(/0+$/, "") || "00"}`;
}

export function formatEarningsDashboard(
  summary: Awaited<ReturnType<typeof getEarningsSummary>>
): string {
  return [
    `Lifetime: ${formatUsdc(summary.lifetimeEarned)} USDC`,
    `Pending: ${formatUsdc(summary.pending)}`,
    `Withdrawable: ${formatUsdc(summary.withdrawable)}`,
    `In dispute: ${formatUsdc(summary.disputed)}`,
    `Total payments: ${summary.paymentCount}`,
  ].join("\n");
}
