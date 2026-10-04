import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { EXPECTED_AMOUNTS, evaluate, formatUnits, u256s } from '../scripts/check-starterpack.mjs';

const wrapper = path.join(path.dirname(fileURLToPath(import.meta.url)), '../scripts/check-starterpack.sh');
const env = {
  USDC_TOKEN_ADDRESS: '0x13', STRK_TOKEN_ADDRESS: '0x14', ROZ_TOKEN_ADDRESS: '0x15',
  ARCADE_REGISTRY_ADDRESS: '0x3eb03b8f2be0ec2aafd186d72f6d8f3dd320dbc89f2b6802bca7465f6ccaa43',
};
const quote = (price, protocol = 0n) => [price, 0n, 0n, 0n, protocol, 0n, price + protocol, 0n, 0x13n];

function healthy(overrides = {}) {
  return {
    configured: true,
    ids: { welcome: 14, week: 15 },
    amounts: { welcome: [...EXPECTED_AMOUNTS.welcome], week: [...EXPECTED_AMOUNTS.week] },
    quotes: { welcome: quote(9_990_000n), week: quote(29_990_000n) },
    tokens: [0x13n, 0x14n, 0x15n],
    minHideStake: 5_000_000n,
    registry: BigInt(env.ARCADE_REGISTRY_ADDRESS),
    // Enough for ten Welcome sales, limited by STRK.
    balances: [100_000_000n, 25_000_000_000_000_000_000n, 50_000_000_000_000_000_000_000n],
    ...overrides,
  };
}
const byName = (results) => Object.fromEntries(results.map((r) => [r.name, r]));

test('a correctly configured contract passes every check', () => {
  const results = evaluate(healthy(), env);
  assert.equal(results.length, 9);
  assert.deepEqual(results.filter((r) => r.status !== 'PASS'), []);
  const named = byName(results);
  assert.equal(named['Welcome amounts'].detail, '6 USDC, 2.5 STRK, 1000 RZBX');
  assert.equal(named['Week Arcade listing'].detail, '29.99 USDC');
  assert.match(named.inventory.detail, /covers 10 Welcome or 4 Week sales/);
});

test('wrong configuration fails with the values that differ', () => {
  const named = byName(evaluate(healthy({
    amounts: { welcome: [5_000_000n, ...EXPECTED_AMOUNTS.welcome.slice(1)], week: EXPECTED_AMOUNTS.week },
    tokens: [0x99n, 0x14n, 0x15n],
    registry: 0x1n,
    quotes: { welcome: quote(9_990_000n), week: [...quote(29_990_000n).slice(0, 8), 0x99n] },
    balances: [0n, 0n, 0n],
  }), env));
  assert.equal(named['Welcome amounts'].status, 'FAIL');
  assert.match(named['Welcome amounts'].detail, /^5 USDC.*expected 6 USDC/);
  assert.equal(named['Week amounts'].status, 'PASS');
  assert.equal(named['token addresses'].status, 'FAIL');
  assert.equal(named['Arcade registry'].status, 'FAIL');
  assert.equal(named['Week Arcade listing'].status, 'FAIL');
  assert.equal(named.inventory.status, 'FAIL');
});

test('fees and a changed hide stake warn; unconfigured IDs fail', () => {
  const named = byName(evaluate(healthy({
    minHideStake: 6_000_000n,
    quotes: { welcome: quote(9_990_000n, 500_000n), week: quote(29_990_000n) },
  }), env));
  assert.equal(named['minimum hide stake'].status, 'WARN');
  assert.equal(named['Welcome Arcade listing'].status, 'WARN');
  assert.match(named['Welcome Arcade listing'].detail, /buyers pay 10\.49 USDC/);

  const unconfigured = evaluate(healthy({ configured: false, amounts: {}, quotes: {} }), env);
  assert.equal(byName(unconfigured)['pack IDs'].status, 'FAIL');
  assert.equal(unconfigured.length, 5);
});

test('u256 and unit helpers', () => {
  assert.deepEqual(u256s([1n, 1n, 5n, 0n]), [(1n << 128n) + 1n, 5n]);
  assert.throws(() => u256s([1n]), /malformed/);
  assert.equal(formatUnits(9_990_000n, 6), '9.99');
  assert.equal(formatUnits(3_000_000_000_000_000_000_000n, 18), '3000');
});

test('wrapper requires an explicit mainnet config', () => {
  const result = spawnSync('bash', [wrapper, '--network', 'mainnet'], { encoding: 'utf8' });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /explicit --doppler-config/);
});
