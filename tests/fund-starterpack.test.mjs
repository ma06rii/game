import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { STRK_GAS_RESERVE, planFunding } from '../scripts/fund-starterpack.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const script = path.join(root, 'scripts/fund-starterpack.mjs');
const wrapper = path.join(root, 'scripts/fund-starterpack.sh');
const E18 = 10n ** 18n;
const WELCOME = [6_000_000n, 25n * E18 / 10n, 1000n * E18];
const WEEK = [18_000_000n, 6n * E18, 3000n * E18];

test('plan sends only each shortfall and keeps STRK back for gas', () => {
  const plan = planFunding({
    welcome: 5, week: 1, welcomeAmounts: WELCOME, weekAmounts: WEEK,
    contractBalances: [6_000_000n, 0n, 100_000n * E18],
    senderBalances: [100_000_000n, 19n * E18, 0n],
    senderPaysGasInStrk: true,
  });
  assert.deepEqual(plan.map((row) => row.target), [48_000_000n, 185n * E18 / 10n, 8000n * E18]);
  assert.deepEqual(plan.map((row) => row.send), [42_000_000n, 185n * E18 / 10n, 0n]);
  assert.equal(plan[1].available, 19n * E18 - STRK_GAS_RESERVE);
  assert.equal(plan[1].shortBy, 5n * E18 / 10n);
  assert.equal(plan[0].shortBy, 0n);
  assert.equal(plan[2].shortBy, 0n);
});

// Fake sncast as a Node script: balances live in a JSON file so a sent
// transfer moves tokens and the post-funding readback sees it.
function run(args, { balances = {}, tokens = ['0x13', '0x14', '0x15'], env = {} } = {}) {
  const directory = mkdtempSync(path.join(os.tmpdir(), 'roz-fund-pack-'));
  const bin = path.join(directory, 'bin');
  mkdirSync(bin);
  const state = path.join(directory, 'balances.json');
  const log = path.join(directory, 'invoke.log');
  writeFileSync(state, JSON.stringify({
    '0x13:0xa': '100000000', '0x14:0xa': String(2243n * E18 / 100n), '0x15:0xa': String(5n * 10n ** 27n),
    ...balances,
  }));
  writeFileSync(path.join(bin, 'sncast'), `#!${process.execPath}
const fs = require('node:fs');
const argv = process.argv.slice(2);
const opt = (name) => argv[argv.indexOf(name) + 1];
const u256 = (v) => { const b = BigInt(v); return [b & ((1n << 128n) - 1n), b >> 128n]; };
const out = (felts) => console.log('Response Raw: [' + felts.map((f) => '0x' + BigInt(f).toString(16)).join(', ') + ']');
const balances = JSON.parse(fs.readFileSync(process.env.TEST_STATE, 'utf8'));
if (argv[0] === 'account') {
  console.log('- funder:\\n  network: alpha-sepolia\\n  address: 0xa');
} else if (argv[0] === 'call') {
  const fn = opt('--function'), contract = opt('--contract-address'), args = opt('--arguments');
  if (fn === 'get_token_addresses') out(${JSON.stringify(tokens)});
  else if (fn === 'are_pack_ids_configured') out([1]);
  else if (fn === 'get_pack_ids') out([14, 15]);
  else if (fn === 'pack_amounts') out((args === '14' ? ${JSON.stringify(WELCOME.map(String))} : ${JSON.stringify(WEEK.map(String))}).flatMap(u256));
  else if (fn === 'balance_of') out(u256(balances[contract + ':' + args] ?? 0));
} else {
  fs.appendFileSync(process.env.TEST_LOG, argv.join(' ') + '\\n');
  if (argv.includes('--dry-run')) { console.log('Overall Fee: 1000 Fri (~0.000000000000001 STRK)'); process.exit(0); }
  const token = opt('--contract-address');
  const [to, amount] = opt('--arguments').split(', ');
  const value = BigInt(amount.replace('_u256', ''));
  balances[token + ':' + to] = String(BigInt(balances[token + ':' + to] ?? 0) + value);
  balances[token + ':0xa'] = String(BigInt(balances[token + ':0xa']) - value);
  fs.writeFileSync(process.env.TEST_STATE, JSON.stringify(balances));
  console.log('Transaction Hash: 0xabc');
}
`);
  chmodSync(path.join(bin, 'sncast'), 0o755);
  const preload = path.join(directory, 'mock-fetch.cjs');
  writeFileSync(preload, `global.fetch = async () => ({ ok: true, json: async () => ({ result: '0x534e5f5345504f4c4941' }) });`);
  try {
    const result = spawnSync(process.execPath, ['--require', preload, script, ...args], {
      cwd: root,
      encoding: 'utf8',
      env: {
        ...process.env,
        PATH: `${bin}:${process.env.PATH}`,
        STARKNET_NETWORK: 'sepolia',
        STARKNET_RPC_URL: 'https://rpc.example.invalid',
        STARTERPACK_ADDRESS: '0x5',
        USDC_TOKEN_ADDRESS: '0x13',
        STRK_TOKEN_ADDRESS: '0x14',
        ROZ_TOKEN_ADDRESS: '0x15',
        STARTERPACK_OWNER_SNCAST_ACCOUNT: 'funder',
        TEST_STATE: state,
        TEST_LOG: log,
        ...env,
      },
    });
    if (result.error) throw result.error;
    return {
      ...result,
      invokes: existsSync(log) ? readFileSync(log, 'utf8').trim().split('\n') : [],
      balances: JSON.parse(readFileSync(state, 'utf8')),
    };
  } finally {
    rmSync(directory, { recursive: true });
  }
}

test('dry-run estimates the three shortfall transfers without moving tokens', () => {
  const result = run(['--welcome', '5']);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /USDC  needs 30 USDC, holds 0 USDC, send 30 USDC/);
  assert.match(result.stdout, /STRK  needs 12\.5 STRK, holds 0 STRK, send 12\.5 STRK \(sender can spare 21\.43 STRK\)/);
  assert.deepEqual(result.invokes.map((line) => line.split('--arguments ')[1]), [
    '0x5, 30000000_u256', `0x5, ${125n * E18 / 10n}_u256`, `0x5, ${5000n * E18}_u256`,
  ]);
  for (const line of result.invokes) assert.match(line, /^--account funder invoke --dry-run --detailed .*--function transfer/);
  assert.equal(result.balances['0x13:0x5'], undefined);
});

test('send transfers, waits and verifies the new contract balances', () => {
  const result = run(['--welcome', '5', '--send']);
  assert.equal(result.status, 0, result.stderr);
  for (const line of result.invokes) assert.match(line, /^--account funder --wait --wait-timeout 600 invoke --url/);
  assert.equal(result.balances['0x13:0x5'], '30000000');
  assert.match(result.stdout, /Funded: 30 USDC, 12\.5 STRK, 5000 RZBX\./);
});

test('re-running tops up only what is missing, or nothing at all', () => {
  const topUp = run(['--welcome', '5'], { balances: { '0x13:0x5': '6000000', '0x15:0x5': String(9000n * E18) } });
  assert.equal(topUp.status, 0, topUp.stderr);
  assert.deepEqual(topUp.invokes.map((line) => line.split('--arguments ')[1]), [
    '0x5, 24000000_u256', `0x5, ${125n * E18 / 10n}_u256`,
  ]);
  const covered = run(['--welcome', '1'], { balances: {
    '0x13:0x5': '6000000', '0x14:0x5': String(25n * E18 / 10n), '0x15:0x5': String(1000n * E18),
  } });
  assert.equal(covered.status, 0, covered.stderr);
  assert.match(covered.stdout, /already covers this target; nothing to send/);
  assert.deepEqual(covered.invokes, []);
});

test('refuses a short sender, wrong token addresses or a missing target before any transfer', () => {
  const short = run(['--welcome', '9', '--send']);
  assert.equal(short.status, 1);
  assert.match(short.stderr, /sender is short: 1\.07 STRK \(STRK keeps 1 STRK back for gas\)/);
  assert.deepEqual(short.invokes, []);

  const wrongTokens = run(['--welcome', '1', '--send'], { tokens: ['0x13', '0x99', '0x15'] });
  assert.equal(wrongTokens.status, 1);
  assert.match(wrongTokens.stderr, /token addresses differ/);
  assert.deepEqual(wrongTokens.invokes, []);

  const noTarget = run(['--send']);
  assert.equal(noTarget.status, 1);
  assert.match(noTarget.stderr, /Pass --welcome and\/or --week/);
});

test('wrapper requires an explicit mainnet config', () => {
  const result = spawnSync('bash', [wrapper, '--network', 'mainnet', '--welcome', '1'], { encoding: 'utf8' });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /explicit --doppler-config/);
});
