#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { readSncastAccount } from './check-contract-env.mjs';

export const GAME = '0x07088478d5e2464e947186bca33dec61bfd3a84bdf82f76b78f2528bd19b3c86';
export const GAME_CLASS_HASH = '0x05c62564e2163b40ed87e846bfb06fd79b11c1fd9a0719a2d4ea91e4022644df';
export const FACET_HASHES = [
  '0x007babbfe571caf1a047b808d2c7bf3e01e3084c7ebc67a491bb3699052c6534',
  '0x024232d93f567ee49ed7e7f186b060877012f4caff1cd69bf84b8c3186254f91',
  '0x0716b9541dfeb1cf20952062ada1d417f8d41375e980e573e7873692525adb1d',
  '0x03cc8a2a12d584d79dce60ae24b545ff84cc11ed1609f623aee6887000cf489e',
  '0x06f5777735e21219846dab8d822a24971e193ed39bdd233ba4ca0be1824701df',
  '0x017e6b72aa8cb9d311001cca0952371378ad7ed1a6f4f5cb15bfe201511929b4',
  '0x061a3f4ec8f6402fba2f90673a886ae60489dbbe8b9f009280cb697f22718405',
  '0x01ecac72c39ccb7583d066efd4eefa45ba0fca0d79a22c615bc6c162eb26bf29',
  '0x05d52ab6c6d8054a40e5bad19a0d97747bf0867ea757a4b223c7d63d73a47e0a',
  '0x016e04a316028511c6c37f8a1ea738e55dbff1b817fe7e6d6bf215a1530422df',
  '0x00d287a5c994d04d14e450066c0e7a0eead70deb80de3832d5ec681b5035d38f',
  '0x00060888e5f10ad35c719a9c9ab6d32f7937568f678f824f7d641fad246ea152',
  '0x036f4b18dc52af7edec3f8187513ca1475af4b5845ce8496946d572f2f4f222d',
  '0x0609086696cddca40e66aad9752c106addbeb45c3f6843ab9010a877f1e68af7',
];
const SEPOLIA_CHAIN_ID = '0x534e5f5345504f4c4941';
const MAX_U128 = (1n << 128n) - 1n;
const ADDRESS = /^0x[0-9a-fA-F]{1,64}$/;

// This is the canonical, ordered first batch from RZBX_DEPLOYMENT_AND_FUNDING.md.
export const SETTINGS = [
  ['rewardHide', 30000000000000000000n],
  ['rewardHideSurvived', 50000000000000000000n],
  ['rewardFind', 110000000000000000000n],
  ['rewardParticipation', 18000000000000000000n],
  ['rewardPerHop', 1000000000000000000n],
  ['hopRewardBelowThreshold', 150000000000000000n],
  ['participationBelowThreshold', 0n],
  ['rewardHideBelowThreshold', 4500000000000000000n],
  ['hideSurvivedBelowThreshold', 7500000000000000000n],
  ['hopRewardNewWallet', 500000000000000000n],
  ['participationNewWallet', 9000000000000000000n],
  ['rewardHideNewWallet', 15000000000000000000n],
  ['rewardHideSurvivedNewWallet', 25000000000000000000n],
  ['participationMinimumHops', 28n],
  ['hopRewardCap', 40n],
  ['dailyFreeHops', 20n],
  ['dailyFreeSpawns', 1n],
  ['dailySoftCapRoz', 136000000000000000000n],
  ['newWalletSoftCapRoz', 80000000000000000000n],
  ['softCapMultiplierNum', 1n],
  ['softCapMultiplierDen', 5n],
  ['dailySpendThreshold', 600000n],
  ['lifetimeSpendThreshold', 3000000n],
  ['hideFeeBase', 200000n],
  ['hideFeeHigh', 250000n],
  ['hideFeeTierBoundary', 3n],
  ['dailyHideCap', 10n],
  ['maxTreasuresPerRound', 2840n],
  ['whitelistRoundCap', 250n],
  ['whitelistCollectiveCap', 1200n],
  ['whitelistHourlyCap', 80n],
  ['gasFeeReservation', 3333n],
  ['gameMasterFee', 8333n],
  ['gameLandownerFee', 1167n],
  ['minimumAllowance', 7000000n],
];

export const BANDS = [
  [0n, 0n, 25n, 5000n, 0n],
  [0n, 1n, 45n, 10000n, 0n],
  [0n, 2n, 65n, 20000n, 0n],
  [0n, 3n, MAX_U128, 40000n, 0n],
  [1n, 0n, 2n, 1n, 1n],
  [1n, 1n, 4n, 7n, 10n],
  [1n, 2n, 6n, 2n, 5n],
  [1n, 3n, 8n, 1n, 5n],
  [1n, 4n, 10n, 2n, 25n],
  [1n, 5n, MAX_U128, 3n, 100n],
];

export function u256(value) {
  const big = BigInt(value);
  if (big < 0n || big >= (1n << 256n)) throw new Error('u256 out of range');
  return [big & MAX_U128, big >> 128n];
}

export function feltString(value) {
  const bytes = Buffer.from(value, 'ascii');
  if (bytes.length > 31 || /[^\x20-\x7e]/.test(value)) throw new Error('invalid short string');
  return BigInt(`0x${bytes.toString('hex')}`);
}

export function settingsCalldata() {
  return [BigInt(SETTINGS.length), ...SETTINGS.map(([key]) => feltString(key)),
    BigInt(SETTINGS.length), ...SETTINGS.flatMap(([, value]) => u256(value))];
}

export function bandCalldata(band) {
  const [kind, index, upTo, num, den] = band;
  return [kind, index, ...u256(upTo), ...u256(num), ...u256(den)];
}

export function routedCalldata(facet, selector, calldata) {
  return [BigInt(facet), BigInt(selector), BigInt(calldata.length), ...calldata].map(String);
}

const READBACKS = [
  [10, 'get_reward_rates', SETTINGS.slice(0, 5)],
  [10, 'get_below_threshold_rates', SETTINGS.slice(5, 9)],
  [10, 'get_new_wallet_rates', SETTINGS.slice(9, 13)],
  [10, 'get_hop_limits', SETTINGS.slice(13, 17)],
  [10, 'get_soft_caps', SETTINGS.slice(17, 21)],
  [10, 'get_gate_thresholds', SETTINGS.slice(21, 23)],
  [3, 'get_hide_settings', SETTINGS.slice(23, 28)],
  [3, 'get_whitelist_caps', SETTINGS.slice(28, 31)],
  [6, 'get_minimum_allowance_fee', SETTINGS.slice(34, 35)],
];

function selector(name) {
  const output = execFileSync('sncast', ['utils', 'selector', name], { encoding: 'utf8' });
  const value = output.match(/Selector:\s*(0x[0-9a-fA-F]+)/)?.[1];
  if (!value) throw new Error(`could not calculate selector ${name}`);
  return value;
}

async function rpc(url, method, params) {
  const response = await fetch(url, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', method, params, id: 1 }),
    signal: AbortSignal.timeout(20_000),
  });
  const body = await response.json();
  if (!response.ok || body.error) throw new Error(`${method}: ${body.error?.message ?? response.status}`);
  return body.result;
}

async function routeCall(url, facet, name, calldata = []) {
  const result = await rpc(url, 'starknet_call', [{
    contract_address: GAME,
    entry_point_selector: selector('route'),
    calldata: routedCalldata(facet, selector(name), calldata).map((felt) => `0x${BigInt(felt).toString(16)}`),
  }, 'latest']);
  const count = Number(BigInt(result[0]));
  if (count !== result.length - 1) throw new Error(`${name}: malformed routed response`);
  return result.slice(1).map(BigInt);
}

function decodeU256(values) {
  if (values.length % 2) throw new Error('malformed u256 response');
  const decoded = [];
  for (let i = 0; i < values.length; i += 2) decoded.push(values[i] + (values[i + 1] << 128n));
  return decoded;
}

async function inspect(url) {
  const actual = await rpc(url, 'starknet_getClassHashAt', ['latest', GAME]);
  if (BigInt(actual) !== BigInt(GAME_CLASS_HASH)) throw new Error('game class hash mismatch');
  for (let i = 0; i < FACET_HASHES.length; i++) {
    const result = await rpc(url, 'starknet_call', [{
      contract_address: GAME, entry_point_selector: selector('get_facet_hash'),
      calldata: [`0x${i.toString(16)}`],
    }, 'latest']);
    if (result.length !== 1 || BigInt(result[0]) !== BigInt(FACET_HASHES[i])) {
      throw new Error(`facet ${i} class hash mismatch`);
    }
  }
  const paused = (await routeCall(url, 12, 'is_paused'))[0] === 1n;
  const wrongSettings = [];
  for (const [facet, name, settings] of READBACKS) {
    const actualValues = decodeU256(await routeCall(url, facet, name));
    if (actualValues.length !== settings.length) throw new Error(`${name}: wrong response length`);
    for (let i = 0; i < settings.length; i++) {
      if (actualValues[i] !== settings[i][1]) wrongSettings.push(settings[i][0]);
    }
  }
  const wrongBands = [];
  for (const band of BANDS) {
    const actualValues = decodeU256(await routeCall(url, 10, 'get_price_band', band.slice(0, 2)));
    if (actualValues.length !== 3 || actualValues.some((value, i) => value !== band[i + 2])) {
      wrongBands.push(`${band[0]}:${band[1]}`);
    }
  }
  return { paused, wrongSettings, wrongBands };
}

function verifyAccount(alias, expected) {
  const output = execFileSync('sncast', ['account', 'list'], { encoding: 'utf8' });
  const account = readSncastAccount(output, alias);
  if (!account || !account.network?.toLowerCase().includes('sepolia') ||
      BigInt(account.address) !== BigInt(expected)) {
    throw new Error(`${alias}: local account does not match the expected Sepolia address`);
  }
}

function invoke(alias, url, facet, name, calldata, dryRun) {
  const args = ['--account', alias, '--json', ...(dryRun ? [] : ['--wait', '--wait-timeout', '600']),
    'invoke', '--contract-address', GAME, '--function', 'route', '--url', url,
    '--calldata', ...routedCalldata(facet, selector(name), calldata),
    ...(dryRun ? ['--dry-run'] : [])];
  const output = execFileSync('sncast', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'] });
  console.log(`${dryRun ? 'Estimated' : 'Accepted'} ${name}: ${output.trim()}`);
}

async function main() {
  const mode = process.argv[2] ?? '--check';
  if (!['--check', '--estimate', '--send', '--unpause'].includes(mode) || process.argv.length > 3) {
    throw new Error('Usage: DOPPLER_CONFIG=dev varlock run -- node scripts/initialize-routed-game.mjs [--check|--estimate|--send|--unpause]');
  }
  const env = process.env;
  if (env.DOPPLER_CONFIG !== 'dev' || env.STARKNET_NETWORK !== 'sepolia' ||
      !env.STARKNET_RPC_URL?.startsWith('https:')) throw new Error('Sepolia roz-contract/dev Varlock context required');
  if (!ADDRESS.test(env.ADMIN_ADDRESS ?? '') || !ADDRESS.test(env.PAUSER_ADDRESS ?? '')) {
    throw new Error('admin and pauser addresses are required');
  }
  const chain = await rpc(env.STARKNET_RPC_URL, 'starknet_chainId', []);
  if (BigInt(chain) !== BigInt(SEPOLIA_CHAIN_ID)) throw new Error('RPC is not Starknet Sepolia');
  const onchainAdmin = (await routeCall(env.STARKNET_RPC_URL, 13, 'get_admin'))[0];
  if (onchainAdmin !== BigInt(env.ADMIN_ADDRESS)) throw new Error('on-chain admin does not match Doppler');
  const state = await inspect(env.STARKNET_RPC_URL);
  console.log(JSON.stringify({ game: GAME, paused: state.paused,
    incorrectSettings: state.wrongSettings, incorrectBands: state.wrongBands }));
  if (mode === '--check') return;
  if (!state.paused) throw new Error('game is already unpaused; refusing initialization action');
  if (mode === '--estimate') {
    verifyAccount(env.SNCAST_ACCOUNT, env.ADMIN_ADDRESS);
    if (state.wrongSettings.length) {
      invoke(env.SNCAST_ACCOUNT, env.STARKNET_RPC_URL, 9, 'set_params', settingsCalldata(), true);
    } else if (state.wrongBands.length) {
      const [kind, index] = state.wrongBands[0].split(':').map(BigInt);
      const band = BANDS.find(([k, i]) => k === kind && i === index);
      invoke(env.SNCAST_ACCOUNT, env.STARKNET_RPC_URL, 9, 'update_price_band', bandCalldata(band), true);
    } else {
      console.log('All settings and bands already match.');
    }
    return;
  }
  if (mode === '--send') {
    verifyAccount(env.SNCAST_ACCOUNT, env.ADMIN_ADDRESS);
    if (state.wrongSettings.length) {
      invoke(env.SNCAST_ACCOUNT, env.STARKNET_RPC_URL, 9, 'set_params', settingsCalldata(), true);
      invoke(env.SNCAST_ACCOUNT, env.STARKNET_RPC_URL, 9, 'set_params', settingsCalldata(), false);
      const after = await inspect(env.STARKNET_RPC_URL);
      if (after.wrongSettings.length) throw new Error(`settings readback failed: ${after.wrongSettings.join(', ')}`);
    }
    for (const band of BANDS) {
      const current = decodeU256(await routeCall(env.STARKNET_RPC_URL, 10, 'get_price_band', band.slice(0, 2)));
      if (current.length === 3 && current.every((value, i) => value === band[i + 2])) continue;
      invoke(env.SNCAST_ACCOUNT, env.STARKNET_RPC_URL, 9, 'update_price_band', bandCalldata(band), true);
      invoke(env.SNCAST_ACCOUNT, env.STARKNET_RPC_URL, 9, 'update_price_band', bandCalldata(band), false);
      const updated = decodeU256(await routeCall(env.STARKNET_RPC_URL, 10, 'get_price_band', band.slice(0, 2)));
      if (updated.length !== 3 || updated.some((value, i) => value !== band[i + 2])) {
        throw new Error(`band ${band[0]}:${band[1]} readback failed`);
      }
    }
    console.log('Settings and bands verified; game remains paused.');
    return;
  }
  if (state.wrongSettings.length || state.wrongBands.length) throw new Error('settings or bands are incomplete');
  verifyAccount(env.PAUSER_SNCAST_ACCOUNT, env.PAUSER_ADDRESS);
  const pauseRole = selector('PAUSE_ROLE');
  const roleResult = await rpc(env.STARKNET_RPC_URL, 'starknet_call', [{
    contract_address: GAME, entry_point_selector: selector('has_role'),
    calldata: [pauseRole, env.PAUSER_ADDRESS],
  }, 'latest']);
  if (BigInt(roleResult[0]) !== 1n) throw new Error('pauser lacks effective PAUSE_ROLE');
  invoke(env.PAUSER_SNCAST_ACCOUNT, env.STARKNET_RPC_URL, 12, 'unpause', [], true);
  invoke(env.PAUSER_SNCAST_ACCOUNT, env.STARKNET_RPC_URL, 12, 'unpause', [], false);
  if ((await routeCall(env.STARKNET_RPC_URL, 12, 'is_paused'))[0] !== 0n) throw new Error('unpause not reflected on-chain');
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1; });
}
