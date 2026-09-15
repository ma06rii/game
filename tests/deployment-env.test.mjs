import assert from "node:assert/strict";
import test from "node:test";

import { readSncastAccount, validateEnvironment } from "../scripts/check-contract-env.mjs";

const DEPLOYER = "0x52a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833";

function common(overrides = {}) {
  return {
    DOPPLER_CONFIG: "dev",
    STARKNET_NETWORK: "sepolia",
    STARKNET_RPC_URL: "https://rpc.example.invalid/path",
    SNCAST_ACCOUNT: "account_braavos",
    DEPLOYER_ADDRESS: DEPLOYER,
    ...overrides,
  };
}

function game(overrides = {}) {
  return common({
    VRF_PROVIDER_ADDRESS: "0x1",
    USDC_TOKEN_ADDRESS: "0x2",
    ROZ_TOKEN_ADDRESS: "0x3",
    ROUND_KEEPER_ADDRESS: "0x4",
    ADMIN_ADDRESS: "0x5",
    PAUSER_ADDRESS: "0x6",
    PAUSER_SNCAST_ACCOUNT: "account_pauser",
    UPGRADE_DELAY: "100",
    ...overrides,
  });
}

test("accepts complete deployment environments for every target", () => {
  assert.deepEqual(validateEnvironment("game", game()), []);
  assert.deepEqual(
    validateEnvironment("roz", common({ ROZ_RECIPIENT_ADDRESS: "0x7", ROZ_OWNER_ADDRESS: "0x8" })),
    [],
  );
  assert.deepEqual(
    validateEnvironment(
      "starterpack",
      common({
        STARTERPACK_OWNER_ADDRESS: "0x9",
        ARCADE_REGISTRY_ADDRESS: "0xa",
        USDC_TOKEN_ADDRESS: "0xb",
        STRK_TOKEN_ADDRESS: "0xc",
        ROZ_TOKEN_ADDRESS: "0xd",
      }),
    ),
    [],
  );
});

test("reports intentionally missing game role configuration", () => {
  const errors = validateEnvironment(
    "game",
    game({ PAUSER_ADDRESS: "", PAUSER_SNCAST_ACCOUNT: "" }),
  );
  assert.deepEqual(errors, ["PAUSER_ADDRESS is required", "PAUSER_SNCAST_ACCOUNT is required"]);
});

test("reports the intentionally missing Arcade registry", () => {
  const errors = validateEnvironment(
    "starterpack",
    common({
      STARTERPACK_OWNER_ADDRESS: "0x9",
      USDC_TOKEN_ADDRESS: "0xb",
      STRK_TOKEN_ADDRESS: "0xc",
      ROZ_TOKEN_ADDRESS: "0xd",
    }),
  );
  assert.ok(errors.includes("ARCADE_REGISTRY_ADDRESS is required"));
});

test("rejects unsafe networks, RPCs, addresses, aliases, and delays", () => {
  const errors = validateEnvironment(
    "game",
    game({
      DOPPLER_CONFIG: "prd",
      STARKNET_NETWORK: "mainnet",
      STARKNET_RPC_URL: "http://rpc.example.invalid",
      SNCAST_ACCOUNT: "bad alias",
      ADMIN_ADDRESS: "0x0",
      UPGRADE_DELAY: "-1",
    }),
  );
  assert.ok(errors.includes("DOPPLER_CONFIG must be dev for this repository setup"));
  assert.ok(errors.includes("STARKNET_NETWORK must be sepolia"));
  assert.ok(errors.includes("STARKNET_RPC_URL must be a valid HTTPS URL"));
  assert.ok(errors.includes("SNCAST_ACCOUNT must be a valid sncast account alias"));
  assert.ok(errors.includes("ADMIN_ADDRESS must not be the zero address"));
  assert.ok(errors.includes("UPGRADE_DELAY must be an unsigned 64-bit integer"));
});

test("requires distinct role and token addresses", () => {
  const errors = validateEnvironment(
    "game",
    game({ ADMIN_ADDRESS: "0x05", PAUSER_ADDRESS: "0x5", ROZ_TOKEN_ADDRESS: "0x02" }),
  );
  assert.ok(errors.includes("ROZ_TOKEN_ADDRESS must be different from USDC_TOKEN_ADDRESS"));
  assert.ok(errors.includes("PAUSER_ADDRESS must be different from ADMIN_ADDRESS"));
});

test("rejects non-canonical and overflowing upgrade delays", () => {
  assert.ok(
    validateEnvironment("game", game({ UPGRADE_DELAY: "+1" })).includes(
      "UPGRADE_DELAY must be an unsigned 64-bit integer",
    ),
  );
  assert.ok(
    validateEnvironment("game", game({ UPGRADE_DELAY: "18446744073709551616" })).includes(
      "UPGRADE_DELAY must be an unsigned 64-bit integer",
    ),
  );
});

test("rejects signing material from the process environment", () => {
  const errors = validateEnvironment("roz", {
    ...common({ ROZ_RECIPIENT_ADDRESS: "0x7", ROZ_OWNER_ADDRESS: "0x8" }),
    STARKNET_PRIVATE_KEY: "do-not-store-this",
  });
  assert.ok(
    errors.includes(
      "STARKNET_PRIVATE_KEY must not be supplied; signing keys belong in the sncast account store",
    ),
  );
});

test("rejects missing and unknown targets", () => {
  assert.match(validateEnvironment(undefined, {})[0], /target must be exactly one of/);
  assert.match(validateEnvironment("unknown", {})[0], /target must be exactly one of/);
});

test("parses the current sncast account-list format", () => {
  const output = `Available accounts:
- account_braavos:
  network: alpha-sepolia
  public key: 0x1
  address: ${DEPLOYER}
  deployed: true

To show private keys too, use the explicit flag
`;
  assert.deepEqual(readSncastAccount(output, "account_braavos"), {
    address: DEPLOYER,
    network: "alpha-sepolia",
  });
});
