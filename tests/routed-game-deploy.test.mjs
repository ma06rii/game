import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  validateDeploymentEnvironment,
  verifyDeploymentOnline,
} from "../scripts/preflight-routed-game-deploy.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const script = path.join(root, "scripts/deploy-routed-game.sh");
const gameHash = "0x05c62564e2163b40ed87e846bfb06fd79b11c1fd9a0719a2d4ea91e4022644df";
const facetHashes = [
  "0x007babbfe571caf1a047b808d2c7bf3e01e3084c7ebc67a491bb3699052c6534",
  "0x024232d93f567ee49ed7e7f186b060877012f4caff1cd69bf84b8c3186254f91",
  "0x0716b9541dfeb1cf20952062ada1d417f8d41375e980e573e7873692525adb1d",
  "0x03cc8a2a12d584d79dce60ae24b545ff84cc11ed1609f623aee6887000cf489e",
  "0x06f5777735e21219846dab8d822a24971e193ed39bdd233ba4ca0be1824701df",
  "0x017e6b72aa8cb9d311001cca0952371378ad7ed1a6f4f5cb15bfe201511929b4",
  "0x061a3f4ec8f6402fba2f90673a886ae60489dbbe8b9f009280cb697f22718405",
  "0x01ecac72c39ccb7583d066efd4eefa45ba0fca0d79a22c615bc6c162eb26bf29",
  "0x05d52ab6c6d8054a40e5bad19a0d97747bf0867ea757a4b223c7d63d73a47e0a",
  "0x016e04a316028511c6c37f8a1ea738e55dbff1b817fe7e6d6bf215a1530422df",
  "0x00d287a5c994d04d14e450066c0e7a0eead70deb80de3832d5ec681b5035d38f",
  "0x00060888e5f10ad35c719a9c9ab6d32f7937568f678f824f7d641fad246ea152",
  "0x036f4b18dc52af7edec3f8187513ca1475af4b5845ce8496946d572f2f4f222d",
  "0x0609086696cddca40e66aad9752c106addbeb45c3f6843ab9010a877f1e68af7",
];
const hashes = [gameHash, ...facetHashes];
const env = {
  DOPPLER_CONFIG: "dev",
  STARKNET_NETWORK: "sepolia",
  STARKNET_RPC_URL: "https://rpc.example.invalid/path",
  SNCAST_ACCOUNT: "account_braavos",
  DEPLOYER_ADDRESS: "0xa",
  PAUSER_SNCAST_ACCOUNT: "account_pauser",
  VRF_PROVIDER_ADDRESS: "0x1",
  USDC_TOKEN_ADDRESS: "0x2",
  ROZ_TOKEN_ADDRESS: "0x3",
  ROUND_KEEPER_ADDRESS: "0x4",
  ADMIN_ADDRESS: "0x5",
  PAUSER_ADDRESS: "0x6",
  UPGRADE_DELAY: "0",
};

function withMockCommands(run, overrides = {}) {
  const directory = mkdtempSync(path.join(os.tmpdir(), "roz-routed-deploy-"));
  const bin = path.join(directory, "bin");
  mkdirSync(bin);
  const npmLog = path.join(directory, "npm.log");
  const preflightLog = path.join(directory, "preflight.log");
  const sncastLog = path.join(directory, "sncast.log");
  const commands = {
    npm: `#!/usr/bin/env bash
printf '%s\\n' "$DOPPLER_CONFIG" > "$TEST_NPM_LOG"
[[ "$1" == exec && "$2" == -- && "$3" == varlock && "$4" == run && "$5" == -- ]] || exit 8
shift 5
exec "$@"
`,
    node: `#!/usr/bin/env bash
printf '%s\\n' "$@" > "$TEST_PREFLIGHT_LOG"
exit "$TEST_PREFLIGHT_STATUS"
`,
    sncast: `#!/usr/bin/env bash
printf '%s\\n' "$@" > "$TEST_SNCAST_LOG"
`,
  };
  for (const [name, contents] of Object.entries(commands)) {
    const command = path.join(bin, name);
    writeFileSync(command, contents);
    chmodSync(command, 0o755);
  }
  try {
    const result = spawnSync("bash", [script, ...run], {
      cwd: directory,
      encoding: "utf8",
      env: {
        ...process.env,
        PATH: `${bin}:${process.env.PATH}`,
        TEST_NPM_LOG: npmLog,
        TEST_PREFLIGHT_LOG: preflightLog,
        TEST_SNCAST_LOG: sncastLog,
        TEST_PREFLIGHT_STATUS: "0",
        ...env,
        ...overrides,
      },
    });
    if (result.error) throw result.error;
    const readArgs = (file) => {
      try { return readFileSync(file, "utf8").trim().split("\n"); }
      catch { return null; }
    };
    return {
      ...result,
      config: readArgs(npmLog)?.[0] ?? null,
      preflight: readArgs(preflightLog),
      sncast: readArgs(sncastLog),
    };
  } finally {
    rmSync(directory, { recursive: true });
  }
}

test("defaults to a Sepolia dry-run with the exact 14-hash constructor array", () => {
  const result = withMockCommands([]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.config, "dev");
  assert.deepEqual(result.preflight, [
    "scripts/preflight-routed-game-deploy.mjs", "sepolia", "dev", ...hashes,
  ]);
  assert.deepEqual(result.sncast, [
    "--account", env.SNCAST_ACCOUNT, "--dry-run", "--detailed", "deploy",
    "--url", env.STARKNET_RPC_URL, "--class-hash", gameHash,
    "--constructor-calldata", env.VRF_PROVIDER_ADDRESS, env.USDC_TOKEN_ADDRESS,
    env.ROZ_TOKEN_ADDRESS, env.ROUND_KEEPER_ADDRESS, env.ADMIN_ADDRESS,
    env.PAUSER_ADDRESS, env.UPGRADE_DELAY, "14", ...facetHashes,
  ]);
});

test("--send enables a fee-bearing deployment and mainnet needs an explicit config", () => {
  const missing = withMockCommands(["--network", "mainnet", "--send"]);
  assert.equal(missing.status, 2);
  assert.match(missing.stderr, /explicit --doppler-config/);
  assert.equal(missing.sncast, null);

  const result = withMockCommands([
    "--network", "mainnet", "--doppler-config", "prd", "--send",
  ]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.config, "prd");
  assert.deepEqual(result.preflight?.slice(0, 3), [
    "scripts/preflight-routed-game-deploy.mjs", "mainnet", "prd",
  ]);
  assert.deepEqual(result.sncast?.slice(0, 7), [
    "--account", env.SNCAST_ACCOUNT, "--wait", "--wait-timeout", "600", "deploy", "--url",
  ]);
  assert.ok(!result.sncast.includes("--dry-run"));
});

test("invalid network and failed preflight never reach sncast", () => {
  const invalid = withMockCommands(["--network", "devnet", "--send"]);
  assert.equal(invalid.status, 2);
  assert.equal(invalid.sncast, null);
  const failed = withMockCommands(["--send"], { TEST_PREFLIGHT_STATUS: "1" });
  assert.equal(failed.status, 1);
  assert.equal(failed.sncast, null);
});

test("preflight validates deployment variables and mainnet delay", () => {
  assert.deepEqual(validateDeploymentEnvironment("sepolia", "dev", hashes, env), []);
  assert.deepEqual(validateDeploymentEnvironment("mainnet", "prd", hashes, {
    ...env, DOPPLER_CONFIG: "prd", STARKNET_NETWORK: "mainnet", UPGRADE_DELAY: "259200",
  }), []);
  const errors = validateDeploymentEnvironment("mainnet", "prd", hashes.slice(1), {
    ...env, STARKNET_NETWORK: "sepolia", UPGRADE_DELAY: "0", PRIVATE_KEY: "secret",
  });
  assert.ok(errors.some((error) => error.includes("Doppler config")));
  assert.ok(errors.some((error) => error.includes("STARKNET_NETWORK")));
  assert.ok(errors.some((error) => error.includes("259200")));
  assert.ok(errors.some((error) => error.includes("PRIVATE_KEY")));
  assert.ok(errors.some((error) => error.includes("exactly 14 facet")));
});

test("online preflight checks the selected chain and all 15 declared classes", async () => {
  const methods = [];
  const accountOutput = `Available accounts:
- account_braavos:
  network: alpha-sepolia
  public key: 0x1
  address: 0xa
  deployed: true
- account_pauser:
  network: alpha-sepolia
  public key: 0x2
  address: 0x6
  deployed: true
`;
  const fetchImpl = async (_url, options) => {
    const request = JSON.parse(options.body);
    methods.push(request.method);
    return { ok: true, json: async () => ({
      result: request.method === "starknet_chainId"
        ? "0x534e5f5345504f4c4941" : { sierra_program: [] },
    }) };
  };
  await verifyDeploymentOnline("sepolia", hashes, env, { accountOutput, fetchImpl });
  assert.deepEqual(methods, ["starknet_chainId", ...Array(15).fill("starknet_getClass")]);
});

test("online preflight stops at a wrong chain or missing class", async () => {
  const accountOutput = `- account_braavos:
  network: alpha-sepolia
  address: 0xa
- account_pauser:
  network: alpha-sepolia
  address: 0x6
`;
  const wrongChain = async () => ({ ok: true, json: async () => ({ result: "0x534e5f4d41494e" }) });
  await assert.rejects(
    verifyDeploymentOnline("sepolia", hashes, env, { accountOutput, fetchImpl: wrongChain }),
    /not Starknet sepolia/,
  );
  const missingClass = async (_url, options) => {
    const { method } = JSON.parse(options.body);
    return { ok: true, json: async () => method === "starknet_chainId"
      ? { result: "0x534e5f5345504f4c4941" }
      : { error: { code: 28, message: "Class hash not found" } } };
  };
  await assert.rejects(
    verifyDeploymentOnline("sepolia", hashes, env, { accountOutput, fetchImpl: missingClass }),
    /Classes not declared at sepolia latest:[\s\S]*HelloStarknet/,
  );
});

test("online preflight accepts mainnet accounts and rejects signer address mismatches", async () => {
  const mainnetEnv = {
    ...env, DOPPLER_CONFIG: "prd", STARKNET_NETWORK: "mainnet", UPGRADE_DELAY: "259200",
  };
  const accountOutput = `- account_braavos:
  network: mainnet
  address: 0xa
- account_pauser:
  network: mainnet
  address: 0x6
`;
  const fetchImpl = async (_url, options) => {
    const { method } = JSON.parse(options.body);
    return { ok: true, json: async () => ({
      result: method === "starknet_chainId" ? "0x534e5f4d41494e" : { sierra_program: [] },
    }) };
  };
  await verifyDeploymentOnline("mainnet", hashes, mainnetEnv, { accountOutput, fetchImpl });
  await assert.rejects(
    verifyDeploymentOnline("mainnet", hashes, { ...mainnetEnv, DEPLOYER_ADDRESS: "0xb" }, {
      accountOutput, fetchImpl,
    }),
    /deployer sncast account address does not match/,
  );
});
