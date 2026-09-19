#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { readSncastAccount } from "./check-contract-env.mjs";

const CHAIN_IDS = {
  sepolia: "0x534e5f5345504f4c4941",
  mainnet: "0x534e5f4d41494e",
};
const ADDRESS = /^0x[0-9a-fA-F]{1,64}$/;
const ALIAS = /^[A-Za-z][A-Za-z0-9_-]*$/;
const U64_MAX = (1n << 64n) - 1n;
const CLASS_NAMES = [
  "HelloStarknet",
  "GameRoundActionsFacet", "GameRoundViewsFacet",
  "GameHideActionsFacet", "GameHideViewsFacet",
  "GameFinderValidationFacet", "GameFinderActionsFacet", "GameFinderViewsFacet",
  "GameUsdcClaimsFacet", "GameRozClaimsFacet",
  "GameSettingsActionsFacet", "GameSettingsViewsFacet",
  "GameTreasuryFacet", "GameAdminUpgradeFacet", "GameAdminActionsFacet",
];
const CONSTRUCTOR_ADDRESSES = [
  "VRF_PROVIDER_ADDRESS", "USDC_TOKEN_ADDRESS", "ROZ_TOKEN_ADDRESS",
  "ROUND_KEEPER_ADDRESS", "ADMIN_ADDRESS", "PAUSER_ADDRESS",
];

function normalizedAddress(value) {
  return BigInt(value).toString(16);
}

export function validateDeploymentEnvironment(network, config, hashes, env = process.env) {
  const errors = [];
  if (!Object.hasOwn(CHAIN_IDS, network)) errors.push("network must be sepolia or mainnet");
  if (!config || env.DOPPLER_CONFIG !== config) {
    errors.push("Varlock did not load the requested Doppler config");
  }
  if (env.STARKNET_NETWORK !== network) {
    errors.push(`STARKNET_NETWORK must be ${network}`);
  }
  try {
    const url = new URL(env.STARKNET_RPC_URL);
    if (url.protocol !== "https:") throw new Error("not HTTPS");
  } catch {
    errors.push("STARKNET_RPC_URL must be a valid HTTPS URL");
  }
  for (const name of ["SNCAST_ACCOUNT", "PAUSER_SNCAST_ACCOUNT"]) {
    if (!ALIAS.test(env[name] ?? "")) errors.push(`${name} must be a valid sncast account alias`);
  }
  for (const name of ["DEPLOYER_ADDRESS", ...CONSTRUCTOR_ADDRESSES]) {
    const value = env[name];
    if (!ADDRESS.test(value ?? "") || BigInt(value) === 0n) {
      errors.push(`${name} must be a nonzero 0x-prefixed Starknet address`);
    }
  }
  for (const [left, right] of [
    ["VRF_PROVIDER_ADDRESS", "USDC_TOKEN_ADDRESS"],
    ["VRF_PROVIDER_ADDRESS", "ROZ_TOKEN_ADDRESS"],
    ["USDC_TOKEN_ADDRESS", "ROZ_TOKEN_ADDRESS"],
    ["ADMIN_ADDRESS", "PAUSER_ADDRESS"],
  ]) {
    if (ADDRESS.test(env[left] ?? "") && ADDRESS.test(env[right] ?? "") &&
        normalizedAddress(env[left]) === normalizedAddress(env[right])) {
      errors.push(`${left} and ${right} must be different`);
    }
  }
  const delayText = env.UPGRADE_DELAY ?? "";
  if (!/^(0|[1-9][0-9]*)$/.test(delayText) || BigInt(delayText || "0") > U64_MAX) {
    errors.push("UPGRADE_DELAY must be an unsigned 64-bit integer");
  } else if (network === "mainnet" && BigInt(delayText) < 259200n) {
    errors.push("Mainnet UPGRADE_DELAY must be at least 259200 seconds (3 days)");
  }
  for (const name of ["PRIVATE_KEY", "STARKNET_PRIVATE_KEY", "DEPLOYER_PRIVATE_KEY", "MNEMONIC", "SEED_PHRASE"]) {
    if (env[name]?.trim()) errors.push(`${name} must not be loaded through Varlock`);
  }
  if (hashes.length !== 15) errors.push("expected the root class hash and exactly 14 facet hashes");
  for (const [index, hash] of hashes.entries()) {
    if (!ADDRESS.test(hash) || BigInt(hash) === 0n) {
      errors.push(`class hash ${index} is not a nonzero 0x-prefixed hash`);
    }
  }
  return errors;
}

function verifyAccount(alias, expectedAddress, network, accountOutput, label) {
  const account = readSncastAccount(accountOutput, alias);
  if (!account) throw new Error(`${label} sncast account alias was not found locally`);
  const configuredNetwork = account.network?.toLowerCase() ?? "";
  if (!configuredNetwork.includes(network)) {
    throw new Error(`${label} sncast account is not configured for ${network}`);
  }
  if (!ADDRESS.test(account.address ?? "") ||
      normalizedAddress(account.address) !== normalizedAddress(expectedAddress)) {
    throw new Error(`${label} sncast account address does not match its configured address`);
  }
}

export async function verifyDeploymentOnline(network, hashes, env = process.env, options = {}) {
  const accountOutput = options.accountOutput ?? execFileSync("sncast", ["account", "list"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  verifyAccount(env.SNCAST_ACCOUNT, env.DEPLOYER_ADDRESS, network, accountOutput, "deployer");
  verifyAccount(env.PAUSER_SNCAST_ACCOUNT, env.PAUSER_ADDRESS, network, accountOutput, "pauser");

  const fetchImpl = options.fetchImpl ?? fetch;
  async function rpc(method, params) {
    let response;
    try {
      response = await fetchImpl(env.STARKNET_RPC_URL, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
        signal: AbortSignal.timeout(15_000),
      });
    } catch {
      throw new Error("RPC connection failed; check the configured endpoint");
    }
    if (!response.ok) throw new Error(`RPC returned HTTP ${response.status}`);
    const payload = await response.json();
    if (payload.error) {
      const error = new Error(`${method} failed: ${payload.error.code} ${payload.error.message}`);
      error.rpcCode = Number(payload.error.code);
      throw error;
    }
    if (payload.result === undefined || payload.result === null) {
      throw new Error(`${method} returned no result`);
    }
    return payload.result;
  }

  const chainId = await rpc("starknet_chainId", []);
  if (BigInt(chainId) !== BigInt(CHAIN_IDS[network])) {
    throw new Error(`Configured RPC is not Starknet ${network}`);
  }
  const missing = [];
  for (const [index, hash] of hashes.entries()) {
    try {
      await rpc("starknet_getClass", { block_id: "latest", class_hash: hash });
    } catch (error) {
      if (error.rpcCode === 28) {
        missing.push(`${CLASS_NAMES[index]} (${hash})`);
        continue;
      }
      throw new Error(`${CLASS_NAMES[index]} (${hash}) lookup failed: ${error.message}`);
    }
  }
  if (missing.length > 0) {
    throw new Error(`Classes not declared at ${network} latest:\n- ${missing.join("\n- ")}`);
  }
}

async function main() {
  const [network, config, ...hashes] = process.argv.slice(2);
  const errors = validateDeploymentEnvironment(network, config, hashes);
  if (errors.length > 0) throw new Error(errors.join("\n- "));
  await verifyDeploymentOnline(network, hashes);
  console.log(`Deployment preflight passed: ${hashes.length} classes declared on ${network} latest.`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((error) => {
    console.error(`Deployment preflight failed: ${error.message}`);
    process.exitCode = 1;
  });
}
