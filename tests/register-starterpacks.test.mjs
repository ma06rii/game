import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { PACKS, cairoString, loadMetadata, parseRaw, quoteMatches, registerArguments,
  registeredIdFromReceipt } from '../scripts/register-starterpacks.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const script = path.join(root, 'scripts/register-starterpacks.mjs');
const wrapper = path.join(root, 'scripts/register-starterpacks.sh');
const REGISTRY = '0x3eb03b8f2be0ec2aafd186d72f6d8f3dd320dbc89f2b6802bca7465f6ccaa43';
const USDC = '0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8';
const [WELCOME, WEEK] = PACKS;

// Shape of a real mainnet StarterpackRegistered event (pack 2, block 4053077).
const registeredEvent = (id, registry = REGISTRY) => ({
  keys: ['0x1c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd',
    '0x562c7a296437394d061d12c6da24a8d8aefaf314290ac9b10c768183390ac5e', registry],
  data: ['0x1', `0x${id.toString(16)}`, '0x5', '0x3763', '0x0', '0x1', '0xdbd8', '0x6933440b'],
});

test('metadata becomes an escaped Cairo string and placeholders block a send', () => {
  const text = readFileSync(path.join(root, 'integrations/starterpacks/welcome.json'), 'utf8');
  assert.throws(() => loadMetadata(text), /YOUR-HOST/);
  const json = loadMetadata(text, { allowPlaceholders: true });
  assert.equal(JSON.parse(json).items.length, 3);
  assert.equal(cairoString('{"a":"b\\\\c"}'), '"{\\"a\\":\\"b\\\\\\\\c\\"}"');
  assert.throws(() => loadMetadata('{"name":"x","description":"y","image_uri":"z","items":[]}'), /items/);
  assert.equal(
    registerArguments(WEEK, { implementation: '0x1', usdc: '0x2', receiver: '0x3', metadata: '{"n":1}' }),
    '0x1, 0_u8, true, 29990000_u256, 0x2, Option::Some(0x3), "{\\"n\\":1}"',
  );
});

test('responses, receipts and quotes are decoded from the real registry formats', () => {
  assert.deepEqual(parseRaw('Success: Call completed\nResponse:     14_u32\nResponse Raw: [0xe]\n'), [14n]);
  assert.equal(registeredIdFromReceipt({ events: [{ keys: ['0x1'], data: [] }, registeredEvent(14)] }, REGISTRY), 14);
  assert.throws(() => registeredIdFromReceipt({ events: [registeredEvent(14, '0x99')] }, REGISTRY), /found 0/);
  const quote = [9_990_000n, 0n, 0n, 0n, 0n, 0n, 9_990_000n, 0n, BigInt(USDC)];
  assert.ok(quoteMatches(quote, WELCOME, USDC));
  assert.ok(!quoteMatches(quote, WEEK, USDC));
  assert.ok(!quoteMatches(quote, WELCOME, '0x1'));
});

function runScript(args, overrides = {}) {
  const directory = mkdtempSync(path.join(os.tmpdir(), 'roz-register-packs-'));
  const bin = path.join(directory, 'bin');
  const metadataDir = path.join(directory, 'metadata');
  mkdirSync(bin);
  mkdirSync(metadataDir);
  for (const key of ['welcome', 'week']) {
    writeFileSync(path.join(metadataDir, `${key}.json`), JSON.stringify({
      name: key, description: 'd', image_uri: 'https://img.example/x.png',
      items: [{ name: 'i', description: 'd', image_uri: 'https://img.example/i.png' }],
      additional_payment_tokens: [], conditions: [],
    }));
  }
  const invokeLog = path.join(directory, 'invoke.log');
  writeFileSync(path.join(bin, 'sncast'), `#!/usr/bin/env bash
fn= args=
prev=
for a in "$@"; do
  [[ "$prev" == --function ]] && fn=$a
  [[ "$prev" == --arguments ]] && args=$a
  prev=$a
done
if [[ "$1" == account ]]; then
  printf -- '- owner_alias:\\n  network: alpha-sepolia\\n  address: 0xa\\n'
elif [[ "$1" == call ]]; then
  case "$fn" in
    get_arcade_registry) raw=${REGISTRY} ;;
    get_token_addresses) raw="${USDC}, 0x2, 0x3" ;;
    are_pack_ids_configured) raw=$TEST_CONFIGURED ;;
    register) raw=0xe ;;
    get_pack_ids) raw="0xe, 0xf" ;;
    quote)
      case "\${args%%,*}" in
        14) raw="0x986f70, 0x0, 0x0, 0x0, 0x0, 0x0, 0x986f70, 0x0, ${USDC}" ;;
        *) raw="0x1c99c70, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1c99c70, 0x0, ${USDC}" ;;
      esac ;;
  esac
  printf 'Success: Call completed\\nResponse Raw: [%s]\\n' "$raw"
else
  printf '%s %s\\n' "$fn" "$*" >> "$TEST_INVOKE_LOG"
  if [[ " $* " == *" --dry-run "* ]]; then printf 'Overall Fee: 1000 Fri (~0.000000000000001 STRK)\\n'
  elif [[ "$fn" == register && "$args" == *", true, "* ]]; then printf 'Transaction Hash: 0xa2\\n'
  elif [[ "$fn" == register ]]; then printf 'Transaction Hash: 0xa1\\n'
  else printf 'Transaction Hash: 0xb1\\n'; fi
fi
`);
  chmodSync(path.join(bin, 'sncast'), 0o755);
  const preload = path.join(directory, 'mock-fetch.cjs');
  writeFileSync(preload, `
const events = ${JSON.stringify({ '0xa1': [registeredEvent(14)], '0xa2': [registeredEvent(15)] })};
global.fetch = async (_url, options) => {
  const { method, params } = JSON.parse(options.body);
  const result = method === 'starknet_chainId' ? '0x534e5f5345504f4c4941' : { events: events[params[0]] ?? [] };
  return { ok: true, json: async () => ({ jsonrpc: '2.0', id: 1, result }) };
};
`);
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
        ARCADE_REGISTRY_ADDRESS: REGISTRY,
        USDC_TOKEN_ADDRESS: USDC,
        STARTERPACK_PAYMENT_RECEIVER: '0x6',
        STARTERPACK_OWNER_ADDRESS: '0xa',
        STARTERPACK_OWNER_SNCAST_ACCOUNT: 'owner_alias',
        STARTERPACK_METADATA_DIR: metadataDir,
        TEST_INVOKE_LOG: invokeLog,
        TEST_CONFIGURED: '0x0',
        ...overrides,
      },
    });
    if (result.error) throw result.error;
    let invokes = [];
    try { invokes = readFileSync(invokeLog, 'utf8').trim().split('\n').filter(Boolean); } catch {}
    return { ...result, invokes };
  } finally {
    rmSync(directory, { recursive: true });
  }
}

test('dry-run previews consecutive IDs and estimates all three transactions', () => {
  const result = runScript([]);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Expected Welcome pack ID: 14/);
  assert.match(result.stdout, /Expected Week pack ID: 15/);
  assert.equal(result.invokes.length, 3);
  for (const line of result.invokes) assert.match(line, / invoke --dry-run --detailed /);
  assert.match(result.invokes[0], /^register .*0x5, 0_u8, false, 9990000_u256, 0x53c9.*Option::Some\(0x6\), "\{\\"name\\":\\"welcome\\"/);
  assert.match(result.invokes[2], /^set_pack_ids .*--arguments 14, 15$/);
});

test('send reads each ID from its receipt, checks the quote and sets the pack IDs', () => {
  const result = runScript(['--send']);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Welcome pack ID: 14\n[\s\S]*Week pack ID: 15/);
  assert.match(result.stdout, /Registered: Welcome 14, Week 15\./);
  assert.equal(result.invokes.length, 3);
  for (const line of result.invokes) assert.match(line, /--account owner_alias --wait --wait-timeout 600 invoke --url/);
});

test('send can reuse a registered pack and refuses wrong or finished setups', () => {
  const reuse = runScript(['--send', '--welcome-id', '14']);
  assert.equal(reuse.status, 0, reuse.stderr);
  assert.match(reuse.stdout, /Reusing existing Arcade pack 14/);
  assert.deepEqual(reuse.invokes.map((line) => line.split(' ')[0]), ['register', 'set_pack_ids']);

  const wrongReuse = runScript(['--send', '--welcome-id', '15']);
  assert.equal(wrongReuse.status, 1);
  assert.match(wrongReuse.stderr, /does not have the Welcome price/);
  assert.equal(wrongReuse.invokes.length, 0);

  const configured = runScript(['--send'], { TEST_CONFIGURED: '0x1' });
  assert.equal(configured.status, 0, configured.stderr);
  assert.match(configured.stdout, /already configured: Welcome 14, Week 15/);
  assert.equal(configured.invokes.length, 0);

  const wrongSigner = runScript(['--send'], { STARTERPACK_OWNER_ADDRESS: '0xb' });
  assert.equal(wrongSigner.status, 1);
  assert.match(wrongSigner.stderr, /not a local sepolia account/);

  const wrongToken = runScript(['--send'], { USDC_TOKEN_ADDRESS: '0x7' });
  assert.equal(wrongToken.status, 1);
  assert.match(wrongToken.stderr, /differs from the starter pack contract USDC/);
});

test('wrapper requires an explicit mainnet config and forwards its flags', () => {
  const directory = mkdtempSync(path.join(os.tmpdir(), 'roz-register-wrapper-'));
  const bin = path.join(directory, 'bin');
  mkdirSync(bin);
  const log = path.join(directory, 'node.log');
  writeFileSync(path.join(bin, 'npm'), `#!/usr/bin/env bash
shift 5
exec "$@"
`);
  writeFileSync(path.join(bin, 'node'), `#!/usr/bin/env bash
[[ "$1" == *sum-fees.mjs ]] && exec "$TEST_REAL_NODE" "$@"
shift
printf '%s\\n' "$*" > "$TEST_LOG"
printf 'Overall Fee: 2000000000000000 Fri (~0.002 STRK)\\n'
`);
  chmodSync(path.join(bin, 'npm'), 0o755);
  chmodSync(path.join(bin, 'node'), 0o755);
  const run = (args, network = 'sepolia') => spawnSync('bash', [wrapper, ...args], {
    encoding: 'utf8',
    env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, TEST_LOG: log,
      TEST_REAL_NODE: process.execPath, STARKNET_NETWORK: network },
  });
  try {
    const implicit = run(['--network', 'mainnet', '--send']);
    assert.equal(implicit.status, 2);
    assert.match(implicit.stderr, /explicit --doppler-config/);

    const mismatch = run(['--network', 'mainnet', '--doppler-config', 'stg']);
    assert.equal(mismatch.status, 2);
    assert.match(mismatch.stderr, /targets sepolia, not mainnet/);

    const sent = run(['--network', 'mainnet', '--doppler-config', 'prd', '--send', '--week-id', '15'], 'mainnet');
    assert.equal(sent.status, 0, sent.stderr);
    assert.equal(readFileSync(log, 'utf8').trim(), '--send --week-id 15');
    assert.match(sent.stdout, /Estimated total fee: 0\.002 STRK/);
  } finally {
    rmSync(directory, { recursive: true });
  }
});
