import type { Hex } from "viem";

const TX_HASH_RE = /^0x[0-9a-fA-F]{64}$/;

/** Returns the settlement transaction hash as bytes32 (already 32 bytes). */
export function settleTxHashFromTransaction(tx: string): Hex {
  if (!TX_HASH_RE.test(tx)) {
    throw new Error(`invalid settle tx hash: ${tx}`);
  }
  return tx as Hex;
}
