#!/usr/bin/env node

// Top up TreasureGameStarterpack inventory so it can cover a target number of
// Welcome and Week sales. Amounts per sale come from the contract's live
// pack_amounts; only each token's shortfall is sent, so re-running tops up
// instead of double-funding. Run through scripts/fund-starterpack.sh.
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { readSncastAccount } from './check-contract-env.mjs';
import { formatUnits, u256s } from './check-starterpack.mjs';
import { parseRaw } from './register-starterpacks.mjs';

const CHAIN_IDS = { sepolia: '0x534e5f5345504f4c4941', mainnet: '0x534e5f4d41494e' };
const ADDRESS = /^0x[0-9a-fA-F]{1,64}$/;
const ALIAS = /^[A-Za-z][A-Za-z0-9_-]*$/;
export const TOKENS = [
  { symbol: 'USDC', decimals: 6, env: 'USDC_TOKEN_ADDRESS' },
  { symbol: 'STRK', decimals: 18, env: 'STRK_TOKEN_ADDRESS' },
  { symbol: 'RZBX', decimals: 18, env: 'ROZ_TOKEN_ADDRESS' },
];
// Left in the sender's STRK balance to pay for these transfers and later gas.
export const STRK_GAS_RESERVE = 1_000_000_000_000_000_000n;

const fmt = (value, i) => `${formatUnits(value, TOKENS[i].decimals)} ${TOKENS[i].symbol}`;

/**
 * Per token: target = welcome * welcomeAmount + week * weekAmount, and the
 * transfer is whatever the contract is missing. Pure, for testing.
 */
export function planFunding({ welcome, week, welcomeAmounts, weekAmounts, contractBalances,
  senderBalances, senderPaysGasInStrk }) {
  return TOKENS.map((token, i) => {
    const target = BigInt(welcome) * welcomeAmounts[i] + BigInt(week) * weekAmounts[i];
    const send = target > contractBalances[i] ? target - contractBalances[i] : 0n;
    const reserve = token.symbol === 'STRK' && senderPaysGasInStrk ? STRK_GAS_RESERVE : 0n;
    const available = senderBalances[i] > reserve ? senderBalances[i] - reserve : 0n;
    return { ...token, index: i, target, have: contractBalances[i], send, available,
      shortBy: send > available ? send - available : 0n };
  });
}

function parseArguments(argv) {
  const options = { send: false, welcome: 0, week: 0, account: undefined };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--send') options.send = true;
    else if (arg === '--dry-run') options.send = false;
    else if (arg === '--welcome' || arg === '--week') {
      const value = argv[++i];
      if (!/^\d+$/.test(value ?? '')) throw new Error(`${arg} needs a whole number of sales`);
      options[arg.slice(2)] = Number(value);
    } else if (arg === '--account') {
      options.account = argv[++i];
    } else {
      throw new Error('Usage: node scripts/fund-starterpack.mjs --welcome N [--week N] [--account ALIAS] [--dry-run|--send]');
    }
  }
  if (options.welcome + options.week === 0) throw new Error('Pass --welcome and/or --week with the number of sales to cover');
  return options;
}

function sncast(args) {
  return execFileSync('sncast', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'] });
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const env = process.env;
  const signer = options.account ?? env.STARTERPACK_OWNER_SNCAST_ACCOUNT;
  const bad = ['STARTERPACK_ADDRESS', ...TOKENS.map((t) => t.env)]
    .filter((name) => !ADDRESS.test(env[name] ?? '') || BigInt(env[name]) === 0n);
  if (!Object.hasOwn(CHAIN_IDS, env.STARKNET_NETWORK ?? '') || !env.STARKNET_RPC_URL?.startsWith('https:')) {
    bad.push('STARKNET_NETWORK/STARKNET_RPC_URL');
  }
  if (!ALIAS.test(signer ?? '')) bad.push('--account or STARTERPACK_OWNER_SNCAST_ACCOUNT');
  if (bad.length) throw new Error(`missing or invalid: ${bad.join(', ')}`);

  const url = env.STARKNET_RPC_URL;
  const network = env.STARKNET_NETWORK;
  const pack = env.STARTERPACK_ADDRESS;
  const response = await fetch(url, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'starknet_chainId', params: [] }),
    signal: AbortSignal.timeout(20_000),
  });
  const chain = (await response.json()).result;
  if (!chain || BigInt(chain) !== BigInt(CHAIN_IDS[network])) throw new Error(`RPC is not Starknet ${network}`);

  const account = readSncastAccount(sncast(['account', 'list']), signer);
  if (!account?.network?.toLowerCase().includes(network) || !ADDRESS.test(account.address ?? '')) {
    throw new Error(`${signer} is not a local ${network} sncast account`);
  }
  const sender = account.address;

  const call = (contract, fn, args) => parseRaw(sncast(['call', '--url', url,
    '--contract-address', contract, '--function', fn, ...(args ? ['--arguments', args] : [])]));
  const tokenAddresses = TOKENS.map((t) => env[t.env]);
  const onContract = call(pack, 'get_token_addresses');
  if (onContract.length !== 3 || onContract.some((value, i) => value !== BigInt(tokenAddresses[i]))) {
    throw new Error('Doppler token addresses differ from the starter pack contract; run check-starterpack.sh');
  }
  if (call(pack, 'are_pack_ids_configured')[0] !== 1n) {
    throw new Error('pack IDs are not configured; run register-starterpacks.sh first');
  }
  const [welcomeId, weekId] = call(pack, 'get_pack_ids');
  const balances = (holder) => tokenAddresses.map((token) => u256s(call(token, 'balance_of', holder))[0]);
  const plan = planFunding({
    welcome: options.welcome,
    week: options.week,
    welcomeAmounts: u256s(call(pack, 'pack_amounts', String(welcomeId))),
    weekAmounts: u256s(call(pack, 'pack_amounts', String(weekId))),
    contractBalances: balances(pack),
    senderBalances: balances(sender),
    senderPaysGasInStrk: true,
  });

  console.log(`Target: ${options.welcome} Welcome + ${options.week} Week sales. Sender ${sender} (${signer}).`);
  for (const row of plan) {
    const i = row.index;
    console.log(`  ${row.symbol.padEnd(4)}  needs ${fmt(row.target, i)}, holds ${fmt(row.have, i)}, ` +
      `send ${fmt(row.send, i)} (sender can spare ${fmt(row.available, i)})`);
  }
  const short = plan.filter((row) => row.shortBy > 0n);
  if (short.length) {
    throw new Error(`sender is short: ${short.map((row) => fmt(row.shortBy, row.index)).join(', ')}` +
      ` (STRK keeps ${formatUnits(STRK_GAS_RESERVE, 18)} STRK back for gas)`);
  }
  const transfers = plan.filter((row) => row.send > 0n);
  if (!transfers.length) {
    console.log('\nThe contract already covers this target; nothing to send.');
    return;
  }

  for (const row of transfers) {
    const output = sncast(['--account', signer, ...(options.send ? ['--wait', '--wait-timeout', '600'] : []),
      'invoke', ...(options.send ? [] : ['--dry-run', '--detailed']), '--url', url,
      '--contract-address', env[row.env], '--function', 'transfer', '--arguments', `${pack}, ${row.send}_u256`]);
    console.log(`\n== transfer ${fmt(row.send, row.index)}\n${output.trim()}`);
  }
  if (!options.send) {
    console.log('\nDry run only. Re-run with --send to transfer.');
    return;
  }

  const after = balances(pack);
  const missing = plan.filter((row) => after[row.index] < row.target);
  if (missing.length) throw new Error(`balances after funding are still below target for ${missing.map((r) => r.symbol).join(', ')}`);
  console.log(`\nFunded: ${after.map(fmt).join(', ')}. Run scripts/check-starterpack.sh to confirm.`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1; });
}
