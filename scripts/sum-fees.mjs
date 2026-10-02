#!/usr/bin/env node

// Totals the STRK fees from captured sncast output. Dry-run estimates are read
// from "Overall Fee: N Fri" lines. Sent transactions print no fee, so each
// "Transaction Hash:" is looked up and its receipt's actual_fee is summed. Run
// inside Varlock so STARKNET_RPC_URL is available for the receipt lookups.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const FRI_PER_STRK = 10n ** 18n;

export function parseFeeLog(text) {
  const estimates = [...text.matchAll(/Overall Fee:\s*(\d+)\s*Fri/gi)].map((m) => BigInt(m[1]));
  const transactions = [
    ...new Set([...text.matchAll(/Transaction Hash:\s*(0x[0-9a-fA-F]+)/g)].map((m) => m[1])),
  ];
  return { estimates, transactions };
}

export function formatStrk(fri) {
  const whole = fri / FRI_PER_STRK;
  const fraction = (fri % FRI_PER_STRK).toString().padStart(18, "0").replace(/0+$/, "");
  return `${whole}${fraction ? `.${fraction}` : ""} STRK`;
}

export async function sumActualFees(transactions, rpcUrl, fetchImpl = fetch) {
  let total = 0n;
  const unavailable = [];
  for (const hash of transactions) {
    try {
      const response = await fetchImpl(rpcUrl, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          jsonrpc: "2.0", id: 1, method: "starknet_getTransactionReceipt",
          params: { transaction_hash: hash },
        }),
        signal: AbortSignal.timeout(15_000),
      });
      const payload = await response.json();
      const fee = payload.result?.actual_fee;
      if (!response.ok || payload.error || fee?.unit !== "FRI") throw new Error("no STRK fee");
      total += BigInt(fee.amount);
    } catch {
      unavailable.push(hash);
    }
  }
  return { total, unavailable };
}

export async function summarize(text, rpcUrl, fetchImpl = fetch) {
  const { estimates, transactions } = parseFeeLog(text);
  const lines = [];
  if (estimates.length > 0) {
    const total = estimates.reduce((sum, fee) => sum + fee, 0n);
    lines.push(`Estimated total fee: ${formatStrk(total)} across ${estimates.length} transaction(s)`);
  }
  if (transactions.length > 0) {
    const { total, unavailable } = await sumActualFees(transactions, rpcUrl, fetchImpl);
    lines.push(`Total fee paid: ${formatStrk(total)} across ${transactions.length - unavailable.length} transaction(s)`);
    for (const hash of unavailable) lines.push(`  Fee not counted, receipt unavailable: ${hash}`);
  }
  if (lines.length === 0) lines.push("Total fee: 0 STRK (no transactions were estimated or sent)");
  return lines;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const lines = await summarize(readFileSync(process.argv[2], "utf8"), process.env.STARKNET_RPC_URL);
  console.log(`\n${lines.join("\n")}`);
}
