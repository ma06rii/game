import assert from 'node:assert/strict';
import test from 'node:test';
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
