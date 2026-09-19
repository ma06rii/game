import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const checker = path.join(root, "scripts/check-declaration.mjs");
const dryRun = path.join(root, "scripts/dry-run-routed-classes.sh");
const classHash = "0x007babbfe571caf1a047b808d2c7bf3e01e3084c7ebc67a491bb3699052c6534";
const chainId = "0x534e5f5345504f4c4941";

function withMockRpc(replies, run) {
  const directory = mkdtempSync(path.join(os.tmpdir(), "roz-declaration-rpc-"));
  const preload = path.join(directory, "mock-fetch.cjs");
  const log = path.join(directory, "methods.log");
  writeFileSync(preload, `
const { appendFileSync } = require("node:fs");
global.fetch = async (_url, options) => {
  const { method } = JSON.parse(options.body);
  appendFileSync(process.env.TEST_RPC_LOG, method + "\\n");
  const reply = JSON.parse(process.env.TEST_RPC_REPLIES)[method];
  return { ok: true, json: async () => ({ jsonrpc: "2.0", id: 1, ...reply }) };
};
`);
  writeFileSync(log, "");
  try {
    const result = spawnSync(process.execPath, ["--require", preload, checker, ...run.args], {
      cwd: root,
      encoding: "utf8",
      env: {
        ...process.env,
        STARKNET_RPC_URL: "https://mock.sepolia.invalid",
        DEPLOYER_ADDRESS: "",
        TEST_RPC_REPLIES: JSON.stringify(replies),
        TEST_RPC_LOG: log,
        ...run.env,
      },
    });
    if (result.error) throw result.error;
    const methods = readFileSync(log, "utf8").trim().split("\n").filter(Boolean);
    return { status: result.status, stdout: result.stdout, stderr: result.stderr, methods };
  } finally {
    rmSync(directory, { recursive: true });
  }
}

test("require-declared succeeds at Sepolia latest without needing a deployer nonce", () => {
  const result = withMockRpc({
    starknet_chainId: { result: chainId },
    starknet_getClass: { result: { sierra_program: [] } },
  }, { args: [classHash, "--require-declared"] });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Class at latest: declared/);
  assert.deepEqual(result.methods, ["starknet_chainId", "starknet_getClass"]);
});

test("require-declared fails closed when the class is missing or the RPC errors", () => {
  for (const code of [28, 31]) {
    const result = withMockRpc({
      starknet_chainId: { result: chainId },
      starknet_getClass: { error: { code, message: "Class lookup failed" } },
    }, { args: [classHash, "--require-declared"] });
    assert.equal(result.status, 1);
    assert.match(result.stderr, code === 28 ? /not declared at latest/ : /Class lookup failed/);
  }
});

test("require-declared rejects a non-Sepolia RPC", () => {
  const result = withMockRpc({
    starknet_chainId: { result: "0x534e5f4d41494e" },
  }, { args: [classHash, "--require-declared"] });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /not Starknet Sepolia/);
  assert.deepEqual(result.methods, ["starknet_chainId"]);
});

test("diagnostic mode still checks transaction and nonce", () => {
  const result = withMockRpc({
    starknet_chainId: { result: chainId },
    starknet_getClass: { result: { sierra_program: [] } },
    starknet_getTransactionStatus: { result: { finality_status: "ACCEPTED_ON_L2" } },
    starknet_getNonce: { result: "0x2" },
  }, { args: [classHash, "0x123"], env: { DEPLOYER_ADDRESS: "0x456" } });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Deployer nonce at latest: 2/);
  assert.deepEqual(result.methods, [
    "starknet_chainId", "starknet_getClass", "starknet_getTransactionStatus", "starknet_getNonce",
  ]);
});

function withFakeCommands(options, run) {
  const directory = mkdtempSync(path.join(os.tmpdir(), "roz-routed-dry-run-"));
  const bin = path.join(directory, "bin");
  mkdirSync(bin);
  if (options.artifact !== false) {
    const release = path.join(directory, "target", "release");
    mkdirSync(release, { recursive: true });
    writeFileSync(path.join(release, "project_name_GameRoundActionsFacet.contract_class.json"), "{}");
  }
  const fakeSncast = path.join(bin, "sncast");
  writeFileSync(fakeSncast, `#!/usr/bin/env bash
if [[ "$1" == "utils" ]]; then
  printf 'Class Hash: %s\\n' "$TEST_LOCAL_HASH"
  exit 0
fi
if [[ "$TEST_DECLARE_MODE" == "unrelated" ]]; then
  printf 'Error: insufficient balance\\n' >&2
  exit 1
fi
if [[ "$TEST_DECLARE_MODE" == "missing-estimate" ]]; then
  printf 'Success: Dry run completed\\n'
  exit 0
fi
if [[ "$*" == *"GameRoundActionsFacet"* ]]; then
  printf 'Command: declare\\nError: Failed to estimate fee for dry run: TransactionExecutionError: TransactionExecutionErrorData { transaction_index: 0, execution_error: Message("Class with hash %s is already declared.") }\\n' "$TEST_REPORTED_HASH" >&2
  exit 1
fi
printf 'Success: Dry run completed\\nL2 Gas Consumed: 123\\nOverall Fee: 456\\n'
`);
  chmodSync(fakeSncast, 0o755);
  const fakeNpm = path.join(bin, "npm");
  writeFileSync(fakeNpm, `#!/usr/bin/env bash
if [[ "$TEST_RPC_MODE" == "declared" ]]; then
  printf 'Class at latest: declared\\n'
  exit 0
fi
printf 'Declaration check failed: class is not declared at latest\\n' >&2
exit 1
`);
  chmodSync(fakeNpm, 0o755);
  const fakeRg = path.join(bin, "rg");
  writeFileSync(fakeRg, `#!/usr/bin/env bash
printf 'rg must not be called\\n' >&2
exit 127
`);
  chmodSync(fakeRg, 0o755);
  try {
    return run(directory, bin);
  } finally {
    rmSync(directory, { recursive: true });
  }
}

function runDryRun(options = {}) {
  return withFakeCommands(options, (cwd, bin) => {
    const result = spawnSync("bash", [dryRun], {
      cwd,
      encoding: "utf8",
      env: {
        ...process.env,
        PATH: `${bin}:${process.env.PATH}`,
        SNCAST_ACCOUNT: "account_braavos",
        TEST_LOCAL_HASH: options.localHash ?? classHash,
        TEST_REPORTED_HASH: options.reportedHash ?? classHash,
        TEST_DECLARE_MODE: options.declareMode ?? "already-declared",
        TEST_RPC_MODE: options.rpcMode ?? "declared",
      },
    });
    if (result.error) throw result.error;
    return result;
  });
}

test("dry-run skips a matching already-declared class and reaches later classes", () => {
  const result = runDryRun();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Already declared at Sepolia latest: GameRoundActionsFacet/);
  assert.match(result.stdout, /GameRoundViewsFacet[\s\S]*L2 Gas Consumed: 123/);
  assert.match(result.stdout, /HelloStarknet[\s\S]*Overall Fee: 456/);
  assert.doesNotMatch(result.stderr, /rg must not be called/);
});

test("dry-run fails rather than hiding missing fee or gas fields", () => {
  const result = runDryRun({ declareMode: "missing-estimate" });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /lacked a success line, L2 gas, or fee estimate/);
  assert.doesNotMatch(result.stdout, /GameRoundViewsFacet/);
});

test("dry-run stops on mismatched local and reported hashes", () => {
  const result = runDryRun({ localHash: "0x123" });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /does not match local release hash/);
  assert.doesNotMatch(result.stdout, /GameRoundViewsFacet/);
});

test("dry-run stops when latest lookup fails", () => {
  const result = runDryRun({ rpcMode: "not-declared" });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Could not confirm GameRoundActionsFacet at Sepolia latest/);
  assert.doesNotMatch(result.stdout, /GameRoundViewsFacet/);
});

test("dry-run stops on an unrelated error or missing release artifact", () => {
  const unrelated = runDryRun({ declareMode: "unrelated" });
  assert.equal(unrelated.status, 1);
  assert.match(unrelated.stdout, /insufficient balance/);
  const missingArtifact = runDryRun({ artifact: false });
  assert.equal(missingArtifact.status, 1);
  assert.match(missingArtifact.stderr, /Missing release artifact/);
});
