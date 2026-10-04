#!/usr/bin/env node

// Read-only health check for a deployed TreasureGameStarterpack and its two
// Arcade listings. Run through scripts/check-starterpack.sh, which loads the
// Doppler values with Varlock. Exits 1 when any check fails.
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { PACKS, parseRaw } from './register-starterpacks.mjs';

const CHAIN_IDS = { sepolia: '0x534e5f5345504f4c4941', mainnet: '0x534e5f4d41494e' };
const ADDRESS = /^0x[0-9a-fA-F]{1,64}$/;
const DECIMALS = { USDC: 6, STRK: 18, RZBX: 18 };
const TOKENS = ['USDC', 'STRK', 'RZBX'];

// Issued per pack (docs/PACKS.md); index order matches pack_amounts and TOKENS.
export const EXPECTED_AMOUNTS = {
  welcome: [6_000_000n, 2_500_000_000_000_000_000n, 1_000_000_000_000_000_000_000n],
  week: [18_000_000n, 6_000_000_000_000_000_000n, 3_000_000_000_000_000_000_000n],
};
export const EXPECTED_MIN_HIDE_STAKE = 5_000_000n;
const REQUIRED_ENV = ['STARTERPACK_ADDRESS', 'ARCADE_REGISTRY_ADDRESS', 'USDC_TOKEN_ADDRESS',
  'STRK_TOKEN_ADDRESS', 'ROZ_TOKEN_ADDRESS'];

export function u256s(raw) {
  if (raw.length % 2) throw new Error('malformed u256 response');
  const values = [];
  for (let i = 0; i < raw.length; i += 2) values.push(raw[i] + (raw[i + 1] << 128n));
  return values;
}

export function formatUnits(value, decimals) {
  const scale = 10n ** BigInt(decimals);
  const fraction = (value % scale).toString().padStart(decimals, '0').replace(/0+$/, '');
  return `${value / scale}${fraction ? `.${fraction}` : ''}`;
}

const hex = (value) => `0x${value.toString(16)}`;

/** Turn the on-chain state into PASS/WARN/FAIL results. Pure, for testing. */
export function evaluate(state, env) {
  const results = [];
  const add = (status, name, detail) => results.push({ status, name, detail });
  const tokens = [env.USDC_TOKEN_ADDRESS, env.STRK_TOKEN_ADDRESS, env.ROZ_TOKEN_ADDRESS].map(BigInt);

  if (!state.configured) {
    add('FAIL', 'pack IDs', 'not configured; run scripts/register-starterpacks.sh --send');
  } else if (state.ids.welcome === state.ids.week) {
    add('FAIL', 'pack IDs', `Welcome and Week share ID ${state.ids.welcome}`);
  } else {
    add('PASS', 'pack IDs', `Welcome ${state.ids.welcome}, Week ${state.ids.week}`);
  }

  for (const pack of PACKS) {
    const amounts = state.amounts[pack.key];
    if (!amounts) continue;
    const expected = EXPECTED_AMOUNTS[pack.key];
    const shown = amounts.map((value, i) => `${formatUnits(value, DECIMALS[TOKENS[i]])} ${TOKENS[i]}`).join(', ');
    const ok = amounts.every((value, i) => value === expected[i]);
    add(ok ? 'PASS' : 'FAIL', `${pack.label} amounts`, ok ? shown
      : `${shown}; expected ${expected.map((v, i) => `${formatUnits(v, DECIMALS[TOKENS[i]])} ${TOKENS[i]}`).join(', ')}`);
  }

  const tokensOk = state.tokens.length === 3 && state.tokens.every((value, i) => value === tokens[i]);
  add(tokensOk ? 'PASS' : 'FAIL', 'token addresses', tokensOk ? 'match Doppler USDC, STRK and RZBX'
    : `contract has ${state.tokens.map(hex).join(', ')}`);

  add(state.minHideStake === EXPECTED_MIN_HIDE_STAKE ? 'PASS' : 'WARN', 'minimum hide stake',
    `${formatUnits(state.minHideStake, 6)} USDC${state.minHideStake === EXPECTED_MIN_HIDE_STAKE
      ? '' : `; expected 5 USDC unless the game hide stake changed`}`);

  const registryOk = state.registry === BigInt(env.ARCADE_REGISTRY_ADDRESS);
  add(registryOk ? 'PASS' : 'FAIL', 'Arcade registry', registryOk ? hex(state.registry)
    : `contract has ${hex(state.registry)}, Doppler has ${env.ARCADE_REGISTRY_ADDRESS}`);

  for (const pack of PACKS) {
    const quote = state.quotes[pack.key];
    if (!quote) continue;
    const [base, referral, protocol, total] = u256s(quote.slice(0, 8));
    const token = quote[8];
    if (base !== pack.price || token !== tokens[0]) {
      add('FAIL', `${pack.label} Arcade listing`,
        `price ${formatUnits(base, 6)} in ${hex(token)}; expected ${formatUnits(pack.price, 6)} USDC`);
    } else if (referral || protocol) {
      add('WARN', `${pack.label} Arcade listing`,
        `buyers pay ${formatUnits(total, 6)} USDC (referral ${formatUnits(referral, 6)}, protocol ${formatUnits(protocol, 6)})`);
    } else {
      add('PASS', `${pack.label} Arcade listing`, `${formatUnits(total, 6)} USDC`);
    }
  }

  const balances = state.balances;
  const shown = balances.map((value, i) => `${formatUnits(value, DECIMALS[TOKENS[i]])} ${TOKENS[i]}`).join(', ');
  const covers = (key) => balances.reduce((min, value, i) => {
    const sales = value / EXPECTED_AMOUNTS[key][i];
    return min === null || sales < min ? sales : min;
  }, null);
  const welcomeSales = covers('welcome');
  add(welcomeSales === 0n ? 'FAIL' : 'PASS', 'inventory',
    `${shown}; covers ${welcomeSales} Welcome or ${covers('week')} Week sales` +
    (welcomeSales === 0n ? '; top up with scripts/fund-starterpack.sh' : ''));
  return results;
}

function sncast(args) {
  return execFileSync('sncast', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

async function main() {
  const env = process.env;
  const missing = REQUIRED_ENV.filter((name) => !ADDRESS.test(env[name] ?? '') || BigInt(env[name]) === 0n);
  if (!Object.hasOwn(CHAIN_IDS, env.STARKNET_NETWORK ?? '') || !env.STARKNET_RPC_URL?.startsWith('https:')) {
    missing.push('STARKNET_NETWORK/STARKNET_RPC_URL');
  }
  if (missing.length) throw new Error(`missing or invalid: ${missing.join(', ')}`);

  const response = await fetch(env.STARKNET_RPC_URL, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'starknet_chainId', params: [] }),
    signal: AbortSignal.timeout(20_000),
  });
  const chain = (await response.json()).result;
  if (!chain || BigInt(chain) !== BigInt(CHAIN_IDS[env.STARKNET_NETWORK])) {
    throw new Error(`RPC is not Starknet ${env.STARKNET_NETWORK}`);
  }

  const call = (contract, fn, args) => parseRaw(sncast(['call', '--url', env.STARKNET_RPC_URL,
    '--contract-address', contract, '--function', fn, ...(args ? ['--arguments', args] : [])]));
  const pack = env.STARTERPACK_ADDRESS;
  const configured = call(pack, 'are_pack_ids_configured')[0] === 1n;
  const [welcome, week] = call(pack, 'get_pack_ids').map(Number);
  const state = {
    configured,
    ids: { welcome, week },
    amounts: {},
    quotes: {},
    tokens: call(pack, 'get_token_addresses'),
    minHideStake: u256s(call(pack, 'get_min_hide_stake_usdc'))[0],
    registry: call(pack, 'get_arcade_registry')[0],
    balances: [env.USDC_TOKEN_ADDRESS, env.STRK_TOKEN_ADDRESS, env.ROZ_TOKEN_ADDRESS]
      .map((token) => u256s(call(token, 'balance_of', pack))[0]),
  };
  if (configured) {
    for (const [key, id] of Object.entries(state.ids)) {
      state.amounts[key] = u256s(call(pack, 'pack_amounts', String(id)));
      state.quotes[key] = call(env.ARCADE_REGISTRY_ADDRESS, 'quote', `${id}, 1, false`);
    }
  }

  const results = evaluate(state, env);
  for (const { status, name, detail } of results) console.log(`${status.padEnd(4)}  ${name}: ${detail}`);
  const failed = results.filter(({ status }) => status === 'FAIL').length;
  const warned = results.filter(({ status }) => status === 'WARN').length;
  console.log(`\n${failed ? `${failed} check(s) failed` : 'All checks passed'}${warned ? `, ${warned} warning(s)` : ''}.`);
  if (failed) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1; });
}
