import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { BANDS, FACET_HASHES, SETTINGS, bandCalldata, feltString, routedCalldata,
  settingsCalldata, u256 } from '../scripts/initialize-routed-game.mjs';

test('canonical initialization has 35 ordered keys and ten bands', () => {
  assert.equal(SETTINGS.length, 35);
  assert.equal(new Set(SETTINGS.map(([key]) => key)).size, 35);
  assert.equal(SETTINGS[8][0], 'hideSurvivedBelowThreshold');
  assert.equal(BANDS.length, 10);
  assert.equal(FACET_HASHES.length, 14);
  assert.deepEqual(BANDS.map(([kind, index]) => `${kind}:${index}`),
    ['0:0', '0:1', '0:2', '0:3', '1:0', '1:1', '1:2', '1:3', '1:4', '1:5']);
  assert.equal(BANDS[3][2], (1n << 128n) - 1n);
  assert.equal(BANDS[9][2], (1n << 128n) - 1n);
});

test('Cairo serialization nests the arrays inside root route calldata', () => {
  const call = settingsCalldata();
  assert.equal(call.length, 107);
  assert.equal(call[0], 35n);
  assert.equal(call[1], feltString('rewardHide'));
  assert.equal(call[36], 35n);
  assert.deepEqual(call.slice(37, 39), u256(30000000000000000000n));
  const routed = routedCalldata(9, '0x123', call);
  assert.deepEqual(routed.slice(0, 3), ['9', '291', '107']);
  assert.equal(routed.length, 110);
  assert.deepEqual(bandCalldata(BANDS[0]), [0n, 0n, 25n, 0n, 5000n, 0n, 0n, 0n]);
});

const wrapper = path.join(path.dirname(fileURLToPath(import.meta.url)), '../scripts/initialize-routed-game.sh');

function runWrapper(args, overrides = {}) {
  const directory = mkdtempSync(path.join(os.tmpdir(), 'roz-initialize-'));
  const bin = path.join(directory, 'bin');
  mkdirSync(bin);
  const npmLog = path.join(directory, 'npm.log');
  const initLog = path.join(directory, 'init.log');
  const commands = {
    npm: `#!/usr/bin/env bash
printf '%s\\n' "$DOPPLER_CONFIG" > "$TEST_NPM_LOG"
[[ "$1" == exec && "$2" == -- && "$3" == varlock && "$4" == run && "$5" == -- ]] || exit 8
shift 5
exec "$@"
`,
    node: `#!/usr/bin/env bash
[[ "$1" == *sum-fees.mjs ]] && exec "$TEST_REAL_NODE" "$@"
shift
printf '%s\\n' "$*" > "$TEST_INIT_LOG"
printf 'Estimated set_params:\\nOverall Fee: 4000000000000000 Fri (~0.004 STRK)\\n'
exit "$TEST_INIT_STATUS"
`,
  };
  for (const [name, contents] of Object.entries(commands)) {
    writeFileSync(path.join(bin, name), contents);
    chmodSync(path.join(bin, name), 0o755);
  }
  try {
    const result = spawnSync('bash', [wrapper, ...args], {
      cwd: directory,
      encoding: 'utf8',
      env: {
        ...process.env,
        PATH: `${bin}:${process.env.PATH}`,
        TEST_NPM_LOG: npmLog,
        TEST_INIT_LOG: initLog,
        TEST_INIT_STATUS: '0',
        TEST_REAL_NODE: process.execPath,
        STARKNET_NETWORK: 'sepolia',
        STARKNET_RPC_URL: 'https://rpc.example.invalid',
        ...overrides,
      },
    });
    if (result.error) throw result.error;
    const read = (file) => { try { return readFileSync(file, 'utf8').trim(); } catch { return null; } };
    return { ...result, config: read(npmLog), init: read(initLog) };
  } finally {
    rmSync(directory, { recursive: true });
  }
}

test('wrapper defaults to a read-only Sepolia check without a fee summary', () => {
  const result = runWrapper([]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.config, 'dev');
  assert.equal(result.init, '--check');
  assert.doesNotMatch(result.stdout, /total fee/i);
});

test('wrapper passes mode and mainnet confirmation and totals estimated fees', () => {
  const result = runWrapper(
    ['--network', 'mainnet', '--doppler-config', 'prd', '--send', '--confirm-mainnet'],
    { STARKNET_NETWORK: 'mainnet' },
  );
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.config, 'prd');
  assert.equal(result.init, '--send --confirm-mainnet');
  assert.match(result.stdout, /Estimated total fee: 0\.004 STRK across 1 transaction\(s\)/);

  const failed = runWrapper(['--estimate'], { TEST_INIT_STATUS: '1' });
  assert.equal(failed.status, 1);
  assert.match(failed.stdout, /Estimated total fee: 0\.004 STRK/);
});

test('wrapper refuses implicit mainnet configs and network mismatches', () => {
  const implicit = runWrapper(['--network', 'mainnet', '--send']);
  assert.equal(implicit.status, 2);
  assert.match(implicit.stderr, /explicit --doppler-config/);
  assert.equal(implicit.config, null);

  const mismatch = runWrapper(['--network', 'mainnet', '--doppler-config', 'stg', '--estimate']);
  assert.equal(mismatch.status, 2);
  assert.match(mismatch.stderr, /targets sepolia, not mainnet/);
  assert.equal(mismatch.init, null);
});
