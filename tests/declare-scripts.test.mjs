import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { chmodSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { formatStrk, parseFeeLog, summarize } from "../scripts/sum-fees.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const declareScript = path.join(root, "scripts/declare-routed-classes.sh");
const tokenScript = path.join(root, "scripts/deploy-reward-token.sh");
const packScript = path.join(root, "scripts/deploy-starterpack.sh");
const facets = [
  "GameRoundActionsFacet", "GameRoundViewsFacet",
  "GameHideActionsFacet", "GameHideViewsFacet",
  "GameFinderValidationFacet", "GameFinderActionsFacet", "GameFinderViewsFacet",
  "GameUsdcClaimsFacet", "GameRozClaimsFacet",
  "GameSettingsActionsFacet", "GameSettingsViewsFacet",
  "GameTreasuryFacet", "GameAdminUpgradeFacet", "GameAdminActionsFacet",
];
const env = {
  STARKNET_NETWORK: "sepolia",
  STARKNET_RPC_URL: "https://rpc.example.invalid/path",
  SNCAST_ACCOUNT: "account_braavos",
  ROZ_RECIPIENT_ADDRESS: "0x7",
  ROZ_OWNER_ADDRESS: "0x8",
  STARTERPACK_OWNER_ADDRESS: "0x11",
  ARCADE_REGISTRY_ADDRESS: "0x12",
  USDC_TOKEN_ADDRESS: "0x13",
  STRK_TOKEN_ADDRESS: "0x14",
  ROZ_TOKEN_ADDRESS: "0x15",
};

// Must match the fake sncast below: 0x + first 12 hex digits of sha1(class).
const hashOf = (name) => `0x${createHash("sha1").update(name).digest("hex").slice(0, 12)}`;

function run(script, args, overrides = {}) {
  const directory = mkdtempSync(path.join(os.tmpdir(), "roz-declare-scripts-"));
  const bin = path.join(directory, "bin");
  mkdirSync(bin);
  const logs = {
    npm: path.join(directory, "npm.log"),
    env: path.join(directory, "env.log"),
    sncast: path.join(directory, "sncast.log"),
  };
  const commands = {
    npm: `#!/usr/bin/env bash
printf '%s\\n' "$DOPPLER_CONFIG" > "$TEST_NPM_LOG"
[[ "$1" == exec && "$2" == -- && "$3" == varlock && "$4" == run && "$5" == -- ]] || exit 8
shift 5
exec "$@"
`,
    node: `#!/usr/bin/env bash
case "$1" in
  *sum-fees.mjs) exec "$TEST_REAL_NODE" "$@" ;;
  *check-contract-env.mjs) printf '%s\\n' "$*" >> "$TEST_ENV_LOG"; exit "$TEST_ENV_STATUS" ;;
  *check-declaration.mjs)
    if [[ "$3" == --require-declared ]]; then exit "$TEST_LANDED_STATUS"; fi
    [[ " $TEST_DECLARED " == *" $2 "* ]] && exit 0
    exit 3
    ;;
esac
exit 9
`,
    sncast: `#!/usr/bin/env bash
if [[ "$1" == utils ]]; then
  class=$(basename "$4" .contract_class.json)
  class=\${class#project_name_}
  printf 'Class Hash: 0x%s\\n' "$(printf '%s' "$class" | sha1sum | cut -c1-12)"
  exit 0
fi
printf '%s\\n' "$*" >> "$TEST_SNCAST_LOG"
if [[ " $* " == *" --dry-run "* ]]; then printf 'Overall Fee: 1250000000000000 Fri (~0.00125 STRK)\\n'
else printf 'Transaction Hash: 0x%s\\n' "$(printf '%s' "$*" | sha1sum | cut -c1-8)"; fi
`,
  };
  for (const [name, contents] of Object.entries(commands)) {
    writeFileSync(path.join(bin, name), contents);
    chmodSync(path.join(bin, name), 0o755);
  }
  try {
    const result = spawnSync("bash", [script, ...args], {
      cwd: directory,
      encoding: "utf8",
      env: {
        ...process.env,
        PATH: `${bin}:${process.env.PATH}`,
        TEST_NPM_LOG: logs.npm,
        TEST_ENV_LOG: logs.env,
        TEST_SNCAST_LOG: logs.sncast,
        TEST_ENV_STATUS: "0",
        TEST_LANDED_STATUS: "0",
        TEST_DECLARED: "",
        TEST_REAL_NODE: process.execPath,
        ...env,
        ...overrides,
      },
    });
    if (result.error) throw result.error;
    const read = (file) => {
      try { return readFileSync(file, "utf8").trim().split("\n"); }
      catch { return null; }
    };
    return {
      ...result,
      config: read(logs.npm)?.[0] ?? null,
      envChecks: read(logs.env),
      sncast: read(logs.sncast),
    };
  } finally {
    rmSync(directory, { recursive: true });
  }
}

test("declare dry-run estimates only missing classes and prints Doppler hashes in facet order", () => {
  const declared = [...facets.slice(0, 13), "HelloStarknet"].map(hashOf).join(" ");
  const result = run(declareScript, [], { TEST_DECLARED: declared });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.config, "dev");
  assert.deepEqual(result.envChecks, ["scripts/check-contract-env.mjs classes --online"]);
  assert.deepEqual(result.sncast, [
    `--account account_braavos declare --dry-run --detailed --contract-name GameAdminActionsFacet --url ${env.STARKNET_RPC_URL}`,
  ]);
  assert.match(result.stdout, new RegExp(`GAME_CLASS_HASH=${hashOf("HelloStarknet")}\n`));
  assert.match(result.stdout, new RegExp(`FACET_CLASS_HASHES="${facets.map(hashOf).join(" ")}"`));
  assert.match(result.stdout, /1 class\(es\) are not declared on sepolia yet/);
  assert.match(result.stdout, /Estimated total fee: 0\.00125 STRK across 1 transaction\(s\)/);
});

test("declare --send waits for each missing class and confirms it landed", () => {
  const result = run(declareScript, ["--network", "mainnet", "--doppler-config", "prd", "--send"], {
    STARKNET_NETWORK: "mainnet",
  });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.config, "prd");
  assert.equal(result.sncast.length, 15);
  for (const line of result.sncast) {
    assert.match(line, /^--account account_braavos --wait --wait-timeout 600 declare --contract-name \w+ --url /);
  }
  assert.doesNotMatch(result.stdout, /not declared/);

  const unconfirmed = run(declareScript, ["--send"], { TEST_LANDED_STATUS: "1" });
  assert.equal(unconfirmed.status, 1);
  assert.match(unconfirmed.stderr, /was submitted but .* is not at sepolia latest/);
  assert.equal(unconfirmed.sncast.length, 1);
  // The fee total still prints when a run stops part-way.
  assert.match(unconfirmed.stdout, /Total fee paid: 0 STRK[\s\S]*receipt unavailable/);
});

test("declare refuses mismatched or implicit mainnet configs before signing", () => {
  const implicit = run(declareScript, ["--network", "mainnet", "--send"]);
  assert.equal(implicit.status, 2);
  assert.match(implicit.stderr, /explicit --doppler-config/);
  assert.equal(implicit.config, null);

  const mismatch = run(declareScript, ["--network", "mainnet", "--doppler-config", "stg", "--send"]);
  assert.equal(mismatch.status, 2);
  assert.match(mismatch.stderr, /targets sepolia, not mainnet/);
  assert.equal(mismatch.sncast, null);

  const failedEnv = run(declareScript, ["--send"], { TEST_ENV_STATUS: "1" });
  assert.equal(failedEnv.status, 1);
  assert.equal(failedEnv.sncast, null);
});

test("token dry-run skips the deploy estimate while ROZToken is undeclared", () => {
  const result = run(tokenScript, []);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.envChecks, ["scripts/check-contract-env.mjs roz --online"]);
  assert.deepEqual(result.sncast, [
    `--account account_braavos declare --dry-run --detailed --contract-name ROZToken --url ${env.STARKNET_RPC_URL}`,
  ]);
  assert.match(result.stdout, /not declared on sepolia, so a deploy cannot be estimated yet/);
});

test("token deploy passes (recipient, owner) and only waits with --send", () => {
  const tokenHash = hashOf("ROZToken");
  const dry = run(tokenScript, [], { TEST_DECLARED: tokenHash });
  assert.equal(dry.status, 0, dry.stderr);
  assert.deepEqual(dry.sncast, [
    `--account account_braavos deploy --dry-run --detailed --url ${env.STARKNET_RPC_URL} ` +
      `--class-hash ${tokenHash} --constructor-calldata 0x7 0x8`,
  ]);
  assert.match(dry.stdout, /Estimated total fee: 0\.00125 STRK across 1 transaction\(s\)/);

  const sent = run(tokenScript, ["--network", "mainnet", "--doppler-config", "prd", "--send"], {
    STARKNET_NETWORK: "mainnet",
  });
  assert.equal(sent.status, 0, sent.stderr);
  assert.deepEqual(sent.sncast, [
    `--account account_braavos --wait --wait-timeout 600 declare --contract-name ROZToken --url ${env.STARKNET_RPC_URL}`,
    `--account account_braavos --wait --wait-timeout 600 deploy --url ${env.STARKNET_RPC_URL} ` +
      `--class-hash ${tokenHash} --constructor-calldata 0x7 0x8`,
  ]);
  assert.match(sent.stdout, /set ROZ_TOKEN_ADDRESS in Doppler prd/);
  // Both transactions are found; the fake RPC host cannot return their receipts.
  assert.match(sent.stdout, /Total fee paid: 0 STRK across 0 transaction\(s\)/);
  assert.equal(sent.stdout.match(/Fee not counted, receipt unavailable/g).length, 2);
});

test("fee totals parse sncast estimates and format exact STRK amounts", () => {
  const log = `Success: Dry run completed
Overall Fee: 1500000000000000000 Fri (~1.5 STRK)
Overall Fee: 250000000000000 Fri (~0.00025 STRK)
Transaction Hash: 0xabc
Transaction Hash: 0xabc
`;
  assert.deepEqual(parseFeeLog(log), {
    estimates: [1500000000000000000n, 250000000000000n],
    transactions: ["0xabc"],
  });
  assert.equal(formatStrk(1500250000000000000n), "1.50025 STRK");
  assert.equal(formatStrk(3n * 10n ** 18n), "3 STRK");
  assert.equal(formatStrk(1n), "0.000000000000000001 STRK");
});

test("fee totals sum receipt actual_fee for sent transactions", async () => {
  const fees = { "0x1": "0xde0b6b3a7640000", "0x2": "0x6f05b59d3b20000" };
  const fetchImpl = async (_url, options) => {
    const { params } = JSON.parse(options.body);
    const amount = fees[params.transaction_hash];
    return { ok: true, json: async () => amount
      ? { result: { actual_fee: { amount, unit: "FRI" } } }
      : { error: { code: 29, message: "Transaction hash not found" } } };
  };
  const lines = await summarize(
    "Transaction Hash: 0x1\nTransaction Hash: 0x2\nTransaction Hash: 0x3\n",
    "https://rpc.example.invalid", fetchImpl,
  );
  assert.deepEqual(lines, [
    "Total fee paid: 1.5 STRK across 2 transaction(s)",
    "  Fee not counted, receipt unavailable: 0x3",
  ]);
});

test("starter pack dry-run estimates only the declaration while the class is undeclared", () => {
  const result = run(packScript, []);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.envChecks, ["scripts/check-contract-env.mjs starterpack --online"]);
  assert.deepEqual(result.sncast, [
    `--account account_braavos declare --dry-run --detailed --contract-name TreasureGameStarterpack --url ${env.STARKNET_RPC_URL}`,
  ]);
  assert.match(result.stdout, /TreasureGameStarterpack is not declared on sepolia/);
});

test("starter pack deploy passes the five constructor addresses in order", () => {
  const packHash = hashOf("TreasureGameStarterpack");
  const calldata = "--constructor-calldata 0x11 0x12 0x13 0x14 0x15";
  const dry = run(packScript, [], { TEST_DECLARED: packHash });
  assert.equal(dry.status, 0, dry.stderr);
  assert.deepEqual(dry.sncast, [
    `--account account_braavos deploy --dry-run --detailed --url ${env.STARKNET_RPC_URL} ` +
      `--class-hash ${packHash} ${calldata}`,
  ]);
  assert.doesNotMatch(dry.stdout, /Next steps/);

  const sent = run(packScript, ["--network", "mainnet", "--doppler-config", "prd", "--send"], {
    STARKNET_NETWORK: "mainnet", TEST_DECLARED: packHash,
  });
  assert.equal(sent.status, 0, sent.stderr);
  assert.deepEqual(sent.sncast, [
    `--account account_braavos --wait --wait-timeout 600 deploy --url ${env.STARKNET_RPC_URL} ` +
      `--class-hash ${packHash} ${calldata}`,
  ]);
  assert.match(sent.stdout, /Set STARTERPACK_ADDRESS in Doppler prd/);
  assert.match(sent.stdout, /register-starterpacks\.sh --network mainnet --doppler-config prd --send/);

  const implicit = run(packScript, ["--network", "mainnet", "--send"]);
  assert.equal(implicit.status, 2);
  assert.match(implicit.stderr, /explicit --doppler-config/);
  assert.equal(implicit.sncast, null);
});
