#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const TARGETS = new Set(["game", "roz", "starterpack"]);
const FORBIDDEN_SIGNING_VARIABLES = [
  "PRIVATE_KEY",
  "STARKNET_PRIVATE_KEY",
  "DEPLOYER_PRIVATE_KEY",
  "MNEMONIC",
  "SEED_PHRASE",
];
const SEPOLIA_CHAIN_ID = "0x534e5f5345504f4c4941";
const ADDRESS_PATTERN = /^0x[0-9a-fA-F]{1,64}$/;
const ACCOUNT_PATTERN = /^[A-Za-z][A-Za-z0-9_-]*$/;

const TARGET_VARIABLES = {
  game: [
    "VRF_PROVIDER_ADDRESS",
    "USDC_TOKEN_ADDRESS",
    "ROZ_TOKEN_ADDRESS",
    "ROUND_KEEPER_ADDRESS",
    "ADMIN_ADDRESS",
    "PAUSER_ADDRESS",
    "PAUSER_SNCAST_ACCOUNT",
    "UPGRADE_DELAY",
  ],
  roz: ["ROZ_RECIPIENT_ADDRESS", "ROZ_OWNER_ADDRESS"],
  starterpack: [
    "STARTERPACK_OWNER_ADDRESS",
    "ARCADE_REGISTRY_ADDRESS",
    "USDC_TOKEN_ADDRESS",
    "STRK_TOKEN_ADDRESS",
    "ROZ_TOKEN_ADDRESS",
  ],
};

function hasValue(value) {
  return typeof value === "string" && value.trim() !== "";
}

function normalizedAddress(value) {
  return BigInt(value).toString(16);
}

function validateAddress(name, env, errors) {
  const value = env[name];
  if (!hasValue(value)) return;
  if (!ADDRESS_PATTERN.test(value)) {
    errors.push(`${name} must be a 0x-prefixed Starknet felt address`);
    return;
  }
  if (BigInt(value) === 0n) errors.push(`${name} must not be the zero address`);
}

function validateAccount(name, env, errors) {
  const value = env[name];
  if (hasValue(value) && !ACCOUNT_PATTERN.test(value)) {
    errors.push(`${name} must be a valid sncast account alias`);
  }
}

function requireVariables(names, env, errors) {
  for (const name of names) {
    if (!hasValue(env[name])) errors.push(`${name} is required`);
  }
}

function requireDistinct(names, env, errors) {
  const seen = new Map();
  for (const name of names) {
    const value = env[name];
    if (!hasValue(value) || !ADDRESS_PATTERN.test(value)) continue;
    const normalized = normalizedAddress(value);
    const earlier = seen.get(normalized);
    if (earlier) errors.push(`${name} must be different from ${earlier}`);
    else seen.set(normalized, name);
  }
}

export function validateEnvironment(target, env = process.env) {
  const errors = [];
  if (!TARGETS.has(target)) {
    return [`target must be exactly one of: ${[...TARGETS].join(", ")}`];
  }

  requireVariables(
    ["STARKNET_NETWORK", "STARKNET_RPC_URL", "SNCAST_ACCOUNT", "DEPLOYER_ADDRESS"],
    env,
    errors,
  );
  requireVariables(TARGET_VARIABLES[target], env, errors);

  if ((env.DOPPLER_CONFIG ?? "dev") !== "dev") {
    errors.push("DOPPLER_CONFIG must be dev for this repository setup");
  }
  if (hasValue(env.STARKNET_NETWORK) && env.STARKNET_NETWORK !== "sepolia") {
    errors.push("STARKNET_NETWORK must be sepolia");
  }
  if (hasValue(env.STARKNET_RPC_URL)) {
    try {
      const rpc = new URL(env.STARKNET_RPC_URL);
      if (rpc.protocol !== "https:") throw new Error("not HTTPS");
    } catch {
      errors.push("STARKNET_RPC_URL must be a valid HTTPS URL");
    }
  }

  validateAccount("SNCAST_ACCOUNT", env, errors);
  validateAddress("DEPLOYER_ADDRESS", env, errors);
  for (const name of TARGET_VARIABLES[target]) {
    if (name.endsWith("_ADDRESS")) validateAddress(name, env, errors);
  }

  for (const name of FORBIDDEN_SIGNING_VARIABLES) {
    if (hasValue(env[name])) {
      errors.push(`${name} must not be supplied; signing keys belong in the sncast account store`);
    }
  }

  if (target === "game") {
    validateAccount("PAUSER_SNCAST_ACCOUNT", env, errors);
    requireDistinct(
      ["VRF_PROVIDER_ADDRESS", "USDC_TOKEN_ADDRESS", "ROZ_TOKEN_ADDRESS"],
      env,
      errors,
    );
    requireDistinct(["ADMIN_ADDRESS", "PAUSER_ADDRESS"], env, errors);
    if (hasValue(env.UPGRADE_DELAY)) {
      try {
        if (!/^(0|[1-9][0-9]*)$/.test(env.UPGRADE_DELAY)) {
          throw new Error("not an unsigned integer");
        }
        const delay = BigInt(env.UPGRADE_DELAY);
        if (delay < 0n || delay > 18446744073709551615n) throw new Error("outside u64");
      } catch {
        errors.push("UPGRADE_DELAY must be an unsigned 64-bit integer");
      }
    }
  }

  if (target === "starterpack") {
    requireDistinct(
      ["USDC_TOKEN_ADDRESS", "STRK_TOKEN_ADDRESS", "ROZ_TOKEN_ADDRESS"],
      env,
      errors,
    );
  }

  return errors;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function readSncastAccount(output, alias) {
  const match = output.match(
    new RegExp(`^- ${escapeRegExp(alias)}:\\n((?: {2}.+(?:\\n|$))*)`, "m"),
  );
  if (!match) return undefined;
  const fields = Object.fromEntries(
    match[1]
      .trim()
      .split("\n")
      .map((line) => line.trim().split(/:\s+/, 2)),
  );
  return { address: fields.address, network: fields.network };
}

function verifyLocalAccount(alias, expectedAddress, output, label) {
  const account = readSncastAccount(output, alias);
  if (!account) throw new Error(`${label} sncast account alias was not found locally`);
  if (!account.network?.toLowerCase().includes("sepolia")) {
    throw new Error(`${label} sncast account is not configured for Sepolia`);
  }
  if (
    !ADDRESS_PATTERN.test(account.address ?? "") ||
    normalizedAddress(account.address) !== normalizedAddress(expectedAddress)
  ) {
    throw new Error(`${label} sncast account address does not match its configured address`);
  }
}

export async function runOnlineChecks(target, env = process.env) {
  const response = await fetch(env.STARKNET_RPC_URL, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "starknet_chainId", params: [] }),
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) throw new Error(`Starknet RPC returned HTTP ${response.status}`);
  const payload = await response.json();
  if (payload.error) throw new Error("Starknet RPC rejected starknet_chainId");
  if (String(payload.result).toLowerCase() !== SEPOLIA_CHAIN_ID) {
    throw new Error("Starknet RPC is not connected to Sepolia");
  }

  const accountOutput = execFileSync("sncast", ["account", "list"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  verifyLocalAccount(env.SNCAST_ACCOUNT, env.DEPLOYER_ADDRESS, accountOutput, "deployer");
  if (target === "game") {
    verifyLocalAccount(
      env.PAUSER_SNCAST_ACCOUNT,
      env.PAUSER_ADDRESS,
      accountOutput,
      "pauser",
    );
  }
}

function parseArguments(argv) {
  const online = argv.includes("--online");
  const positional = argv.filter((argument) => !argument.startsWith("--"));
  const unknownFlags = argv.filter(
    (argument) => argument.startsWith("--") && argument !== "--online",
  );
  if (positional.length !== 1 || unknownFlags.length > 0 || !TARGETS.has(positional[0])) {
    throw new Error("usage: npm run env:check -- <game|roz|starterpack> [--online]");
  }
  return { target: positional[0], online };
}

async function main() {
  const { target, online } = parseArguments(process.argv.slice(2));
  const errors = validateEnvironment(target);
  if (errors.length > 0) {
    throw new Error(`environment is not ready for ${target}:\n- ${errors.join("\n- ")}`);
  }
  if (online) await runOnlineChecks(target);
  console.log(`Environment check passed for ${target}${online ? " (including online checks)" : ""}.`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
