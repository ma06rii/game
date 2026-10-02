#!/usr/bin/env node

// Register the Welcome and Week packs with Cartridge Arcade's starter pack
// registry, then point TreasureGameStarterpack at the returned IDs with
// set_pack_ids. Run through scripts/register-starterpacks.sh, which loads the
// Doppler values with Varlock and totals the fees.
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { readSncastAccount } from './check-contract-env.mjs';

const CHAIN_IDS = { sepolia: '0x534e5f5345504f4c4941', mainnet: '0x534e5f4d41494e' };
const ADDRESS = /^0x[0-9a-fA-F]{1,64}$/;
const ALIAS = /^[A-Za-z][A-Za-z0-9_-]*$/;
// Arcade emits registrations through its Dojo world as EventEmitted with keys
// [EventEmitted, ARCADE-StarterpackRegistered, registry] and data
// [keys_len, starterpack_id, ...]; see manifest_mainnet.json in cartridge-gg/arcade.
const EVENT_EMITTED = 0x1c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcdn;
const STARTERPACK_REGISTERED = 0x562c7a296437394d061d12c6da24a8d8aefaf314290ac9b10c768183390ac5en;
const PLACEHOLDER = 'YOUR-HOST';

// Prices are in USDC base units (6 decimals); docs/PACKS.md is the source.
export const PACKS = [
  { key: 'welcome', label: 'Welcome', price: 9_990_000n, reissuable: false, referral: 0 },
  { key: 'week', label: 'Week', price: 29_990_000n, reissuable: true, referral: 0 },
];

/** A Cairo string literal for sncast --arguments (ByteArray parameter). */
export function cairoString(text) {
  return `"${text.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

/** Compact the metadata JSON and check the fields Arcade rejects when empty. */
export function loadMetadata(text, { allowPlaceholders = false } = {}) {
  const metadata = JSON.parse(text);
  for (const field of ['name', 'description', 'image_uri']) {
    if (typeof metadata[field] !== 'string' || !metadata[field]) throw new Error(`metadata ${field} is required`);
  }
  if (!Array.isArray(metadata.items) || metadata.items.length === 0) throw new Error('metadata items are required');
  const json = JSON.stringify(metadata);
  if (!allowPlaceholders && json.includes(PLACEHOLDER)) {
    throw new Error(`metadata still contains ${PLACEHOLDER} image placeholders`);
  }
  return json;
}

export function registerArguments(pack, { implementation, usdc, receiver, metadata }) {
  return [implementation, `${pack.referral}_u8`, String(pack.reissuable), `${pack.price}_u256`,
    usdc, `Option::Some(${receiver})`, cairoString(metadata)].join(', ');
}

/** Felts from sncast's "Response Raw: [0x.., ..]" line. */
export function parseRaw(output) {
  const match = output.match(/Response Raw:\s*\[([^\]]*)\]/);
  if (!match) throw new Error('sncast printed no raw response');
  return match[1].split(',').map((felt) => felt.trim()).filter(Boolean).map(BigInt);
}

export function registeredIdFromReceipt(receipt, registry) {
  const ids = (receipt.events ?? [])
    .filter(({ keys }) => keys?.length >= 3 && BigInt(keys[0]) === EVENT_EMITTED &&
      BigInt(keys[1]) === STARTERPACK_REGISTERED && BigInt(keys[2]) === BigInt(registry))
    .map(({ data }) => {
      if (!data || BigInt(data[0]) < 1n) throw new Error('malformed StarterpackRegistered event');
      return Number(BigInt(data[1]));
    });
  if (ids.length !== 1) throw new Error(`expected one StarterpackRegistered event, found ${ids.length}`);
  return ids[0];
}

/** quote() returns (base_price, referral_fee, protocol_fee, total_cost) as u256s, then the token. */
export function quoteMatches(raw, pack, usdc) {
  return raw.length === 9 && raw[0] + (raw[1] << 128n) === pack.price && raw[8] === BigInt(usdc);
}

export function validateEnvironment(env) {
  const errors = [];
  if (!Object.hasOwn(CHAIN_IDS, env.STARKNET_NETWORK ?? '')) errors.push('STARKNET_NETWORK must be sepolia or mainnet');
  if (!env.STARKNET_RPC_URL?.startsWith('https:')) errors.push('STARKNET_RPC_URL must be an HTTPS URL');
  for (const name of ['STARTERPACK_ADDRESS', 'ARCADE_REGISTRY_ADDRESS', 'USDC_TOKEN_ADDRESS',
    'STARTERPACK_PAYMENT_RECEIVER', 'STARTERPACK_OWNER_ADDRESS']) {
    if (!ADDRESS.test(env[name] ?? '') || BigInt(env[name]) === 0n) errors.push(`${name} must be a nonzero address`);
  }
  if (!ALIAS.test(env.STARTERPACK_OWNER_SNCAST_ACCOUNT ?? '')) {
    errors.push('STARTERPACK_OWNER_SNCAST_ACCOUNT must be a valid sncast account alias');
  }
  return errors;
}

function parseArguments(argv) {
  const options = { send: false, ids: {} };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--send') options.send = true;
    else if (arg === '--dry-run') options.send = false;
    else if (arg === '--welcome-id' || arg === '--week-id') {
      const value = argv[++i];
      if (!/^\d+$/.test(value ?? '')) throw new Error(`${arg} needs a numeric pack ID`);
      options.ids[arg === '--welcome-id' ? 'welcome' : 'week'] = Number(value);
    } else {
      throw new Error('Usage: node scripts/register-starterpacks.mjs [--dry-run|--send] [--welcome-id N] [--week-id N]');
    }
  }
  return options;
}

async function rpc(url, method, params) {
  const response = await fetch(url, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }),
    signal: AbortSignal.timeout(20_000),
  });
  const body = await response.json();
  if (!response.ok || body.error) throw new Error(`${method}: ${body.error?.message ?? response.status}`);
  return body.result;
}

function sncast(args) {
  return execFileSync('sncast', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'] });
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const env = process.env;
  const errors = validateEnvironment(env);
  if (errors.length) throw new Error(`environment is not ready:\n- ${errors.join('\n- ')}`);
  const url = env.STARKNET_RPC_URL;
  const network = env.STARKNET_NETWORK;
  const registry = env.ARCADE_REGISTRY_ADDRESS;
  const pack = env.STARTERPACK_ADDRESS;
  const usdc = env.USDC_TOKEN_ADDRESS;
  const signer = env.STARTERPACK_OWNER_SNCAST_ACCOUNT;

  const call = (contract, fn, args) => parseRaw(sncast(['call', '--url', url,
    '--contract-address', contract, '--function', fn, ...(args ? ['--arguments', args] : [])]));
  const invoke = (contract, fn, args) => {
    const output = sncast(['--account', signer, ...(options.send ? ['--wait', '--wait-timeout', '600'] : []),
      'invoke', ...(options.send ? [] : ['--dry-run', '--detailed']), '--url', url,
      '--contract-address', contract, '--function', fn, '--arguments', args]);
    console.log(output.trim());
    return output;
  };

  if (BigInt(await rpc(url, 'starknet_chainId', [])) !== BigInt(CHAIN_IDS[network])) {
    throw new Error(`RPC is not Starknet ${network}`);
  }
  const account = readSncastAccount(sncast(['account', 'list']), signer);
  if (!account?.network?.toLowerCase().includes(network) || !ADDRESS.test(account.address ?? '') ||
      BigInt(account.address) !== BigInt(env.STARTERPACK_OWNER_ADDRESS)) {
    throw new Error(`${signer} is not a local ${network} account for STARTERPACK_OWNER_ADDRESS`);
  }

  // The pack contract must trust this registry and pay out the token buyers pay in.
  if (call(pack, 'get_arcade_registry')[0] !== BigInt(registry)) {
    throw new Error('the starter pack contract is configured for a different Arcade registry');
  }
  if (call(pack, 'get_token_addresses')[0] !== BigInt(usdc)) {
    throw new Error('USDC_TOKEN_ADDRESS differs from the starter pack contract USDC token');
  }
  if (call(pack, 'are_pack_ids_configured')[0] === 1n) {
    const [welcome, week] = call(pack, 'get_pack_ids');
    console.log(`Pack IDs are already configured: Welcome ${welcome}, Week ${week}. Nothing to register.`);
    return;
  }

  const ids = {};
  for (const config of PACKS) {
    console.log(`\n== ${config.label} pack`);
    const reused = options.ids[config.key];
    if (reused !== undefined) {
      if (!quoteMatches(call(registry, 'quote', `${reused}, 1, false`), config, usdc)) {
        throw new Error(`Arcade pack ${reused} does not have the ${config.label} price and USDC token`);
      }
      console.log(`Reusing existing Arcade pack ${reused}.`);
      ids[config.key] = reused;
      continue;
    }
    // STARTERPACK_METADATA_DIR can point at per-network copies of these files.
    const file = join(env.STARTERPACK_METADATA_DIR || 'integrations/starterpacks', `${config.key}.json`);
    const metadata = loadMetadata(readFileSync(file, 'utf8'), { allowPlaceholders: !options.send });
    if (metadata.includes(PLACEHOLDER)) console.log(`Warning: ${file} still has ${PLACEHOLDER} image placeholders.`);
    const args = registerArguments(config, {
      implementation: pack, usdc, receiver: env.STARTERPACK_PAYMENT_RECEIVER, metadata,
    });
    const preview = Number(call(registry, 'register', args)[0]);
    const output = invoke(registry, 'register', args);
    if (!options.send) {
      // Nothing is registered yet, so both previews return the same next ID.
      ids[config.key] = preview + Object.keys(ids).length;
      console.log(`Expected ${config.label} pack ID: ${ids[config.key]}`);
      continue;
    }
    const hash = output.match(/Transaction Hash:\s*(0x[0-9a-fA-F]+)/)?.[1];
    if (!hash) throw new Error(`no transaction hash for the ${config.label} registration`);
    const id = registeredIdFromReceipt(await rpc(url, 'starknet_getTransactionReceipt', [hash]), registry);
    if (!quoteMatches(call(registry, 'quote', `${id}, 1, false`), config, usdc)) {
      throw new Error(`Arcade pack ${id} quote does not match the ${config.label} price and USDC token`);
    }
    console.log(`${config.label} pack ID: ${id}`);
    ids[config.key] = id;
  }

  console.log('\n== set_pack_ids');
  invoke(pack, 'set_pack_ids', `${ids.welcome}, ${ids.week}`);
  if (!options.send) {
    console.log('\nDry run only. Re-run with --send to register both packs and set the IDs.');
    return;
  }
  const [welcome, week] = call(pack, 'get_pack_ids');
  if (Number(welcome) !== ids.welcome || Number(week) !== ids.week) throw new Error('get_pack_ids readback failed');
  console.log(`\nRegistered: Welcome ${ids.welcome}, Week ${ids.week}.`);
  console.log('Next: fund the pack contract inventory, then make a test purchase per docs/PACKS.md.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch((error) => {
    console.error(error.message);
    console.error('If a pack was already registered, re-run with --welcome-id/--week-id to reuse it.');
    process.exitCode = 1;
  });
}
