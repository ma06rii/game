# Unblock `spawn` on Sepolia with a self-fulfilling mock VRF provider

## Context

`finder_player_generate_position` (spawn) reverts with:

```
argent/multicall-failed, 0x1, 'VrfProvider: not fulfilled', ENTRYPOINT_FAILED
```

Index `0x1` is the second call in the multicall — the game contract — and the
inner failure comes from `consume_random` on Cartridge's VRF provider.

**Why it can never work on the current setup.** Per Cartridge's VRF README, step 4
of the flow is:

> The Cartridge **Paymaster** wraps the players multicall with a `submit_random`
> and `assert_consumed` call.

The randomness proof is injected *by the paymaster* — the component Cartridge
support confirmed is down on Sepolia. So:

- **Cartridge Controller path:** paymaster down → nothing works at all.
- **Standard-wallet fallback:** no paymaster in the path → `submit_random` never
  runs → `consume_random` reverts.

The standard-wallet fallback was therefore always capped at non-VRF calls. That's
why `hide_treasure` works and spawn doesn't. This was a gap in the earlier
recommendation — the VRF dependency was flagged when we discussed Katana but not
carried across to the standard-wallet plan.

**Verified on-chain (Sepolia):**

| Check | Result |
|---|---|
| Argent account deployed | Yes — class `0x036078...` (not the problem) |
| Current game week | `0x1` |
| Player position | `(0x0, 0x0)` — none, so moves are blocked behind spawn too |
| Game contract VRF setter | **None** — provider address is fixed at deploy |
| `submit_random` gating | Verifies against `get_vrf_public_key`; only Cartridge holds that key |

## Approach

Deploy a **testnet-only mock VRF provider** whose `consume_random` generates
randomness inline, so nothing needs to call `submit_random` at all. Make the game
contract's VRF address configurable, redeploy it on Sepolia pointing at the mock,
and repoint the frontend.

The decisive advantage: **zero frontend logic changes**. The existing
`[request_random, finder_player_generate_position]` multicall works untouched,
because the mock keeps `request_random` as a no-op view exactly like the real
provider. Only address constants change.

This is deliberately not the full self-hosted VRF (real provider + `vrf-server` +
client-side Poseidon seed derivation + per-spawn proof fetch). That path needs a
nonce getter, a running server, and a rewrite of `spawnNewPosition`; the mock
gives the same unblock for testnet at a fraction of the work.

⚠️ **The mock produces predictable randomness. It must never reach mainnet.**

---

## 1. Mock VRF provider (contracts repo)

Add `cartridge_vrf` as a Scarb dependency and implement its `IVrfProvider` trait
directly — that guarantees the signatures stay identical to the real provider, so
swapping between them is purely an address change.

Signatures confirmed from the deployed Sepolia class:

```
request_random(caller: ContractAddress, source: Source)   [view]
submit_random(seed: felt252, proof: Proof)                [external]
consume_random(source: Source) -> felt252                 [external]

Source  = enum { Nonce: ContractAddress, Salt: felt252 }
Proof   = struct { gamma: Point, c: felt252, s: felt252, sqrt_ratio_hint: felt252 }
```

```cairo
#[starknet::contract]
mod MockVrfProvider {
    // TESTNET ONLY. Randomness here is predictable and trivially manipulable.
    // Exists solely because Cartridge's Sepolia paymaster (which injects
    // submit_random) is down. Never deploy to mainnet.
    use cartridge_vrf::types::Source;
    use core::poseidon::poseidon_hash_span;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_tx_info};

    #[storage]
    struct Storage {
        nonces: Map<ContractAddress, felt252>,
    }

    #[abi(embed_v0)]
    impl MockVrfProviderImpl of IVrfProvider<ContractState> {
        // No-op, kept so the existing frontend multicall stays valid.
        fn request_random(self: @ContractState, caller: ContractAddress, source: Source) {}

        // No-op: randomness is produced inline by consume_random, so there is
        // no proof to submit. Kept for interface parity with the real provider.
        fn submit_random(ref self: ContractState, seed: felt252, proof: Proof) {}

        fn consume_random(ref self: ContractState, source: Source) -> felt252 {
            let caller = get_caller_address();
            let tx_info = get_tx_info().unbox();
            let key = match source {
                Source::Nonce(addr) => addr,
                Source::Salt(_) => caller,
            };
            // Nonce increments so repeated consumes in one tx differ.
            let nonce = self.nonces.read(key);
            self.nonces.write(key, nonce + 1);
            poseidon_hash_span(
                array![
                    nonce, key.into(), caller.into(),
                    tx_info.transaction_hash, get_block_timestamp().into(),
                ].span()
            )
        }
    }
}
```

The real provider's `consume_random` reverts when unfulfilled; the mock simply
never reverts, which is exactly the behaviour difference we want.

## 2. Make the game contract's VRF address configurable

Currently a hardcoded `const VRF_PROVIDER_ADDRESS`. Change to:

- a `vrf_provider: ContractAddress` storage field, set from a **constructor argument**
- an owner-gated **`update_vrf_provider(new_address)`** setter, matching the
  contract's existing `update_*` convention (`update_gamemaster_fee`,
  `update_callback_fee_limit`, …)

Build the dispatcher from storage rather than the const:

```cairo
let vrf_provider = IVrfProviderDispatcher {
    contract_address: self.vrf_provider.read()
};
```

The setter is the part worth insisting on. It means this exact outage never
forces a redeploy again: when Cartridge's Sepolia VRF recovers, you call
`update_vrf_provider(0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f)`
and you're back on real VRF instantly. That address is **identical on Sepolia and
mainnet**, so mainnet just passes it at construction.

## 3. Deploy (Sepolia)

1. Declare + deploy `MockVrfProvider`. Note its address.
2. Declare + deploy the game contract, passing the mock address as the VRF
   constructor arg.
3. Add a guard in the deploy script that **refuses to deploy the mock if the
   target chain id is `SN_MAIN`**.
4. Sanity-check the mock in isolation before wiring the game to it — invoke
   `consume_random(Source::Nonce(<your address>))` and confirm it returns
   non-zero and does not revert.

## 4. Frontend (this repo) — address constants only

| File | Change |
|---|---|
| `src/components/Middle.vue:35` | `SEPOLIA_GAME_CONTRACT_ADDRESS` → new game address |
| `src/components/Middle.vue:40` | `VRF_PROVIDER_ADDRESS` → mock address |
| `src/components/utils/controllerPolicies.js:4,7` | same two addresses (session policies) |
| `src/contracts/game/sepolia_game_abi_1.json` | regenerate — `update_vrf_provider` is a new entrypoint |

**No change to `spawnNewPosition`.** It already sends
`[request_random(gameContract, Source::Nonce(player)), finder_player_generate_position()]`
(`Middle.vue:614-640`), and the mock accepts `request_random` as a no-op view. The
same frontend code therefore works against both the mock and Cartridge's real VRF
— which is the point.

Leave `standardWallet.js` and the `executeAndConfirm` helper untouched.

## Verification

1. Deploy both contracts to Sepolia; record addresses.
2. Update the four frontend references; `pnpm build`.
3. `pnpm dev`, open `http://localhost:5173/?wallet=standard`, connect Argent/Braavos.
4. Approve spend, then **Spawn**. Expected: no `VrfProvider: not fulfilled`, and a
   receipt with `execution_status: SUCCEEDED`.
5. Confirm a position actually exists on-chain — the UI flag alone isn't proof:
   ```
   curl -s -X POST -H 'Content-Type: application/json' \
     -d '{"jsonrpc":"2.0","id":1,"method":"starknet_call","params":[{
       "contract_address":"<NEW_GAME_ADDRESS>",
       "entry_point_selector":"0x2bec261ebb4513cb00755a1d6dd8b3b33ab4ed93074f498fe56f799e6753a3",
       "calldata":["<player>","0x1","0x0"]},"latest"]}' \
     https://api.cartridge.gg/x/starknet/sepolia/rpc/v0_9
   ```
   Must return a non-`(0x0, 0x0)` pair.
6. Spawn twice with different accounts and confirm the positions differ — that
   the mock isn't returning a constant.
7. Then exercise moves and `hide_treasure`, which were blocked behind spawn.
8. Remove the `//for test purposes only` block at `Middle.vue:1172-1176` before
   any real assessment — it force-sets `isETHUsageApproved` and `isValidBalance`
   to `true` and will mask genuine failures.

## Path back to production

Mainnet deploys the game contract with Cartridge's real VRF address
(`0x051fea...`) at construction — the mock is simply never deployed there. When
Cartridge's Sepolia service recovers, `update_vrf_provider` switches testnet back
to real VRF with no redeploy, and the `?wallet=standard` fallback plus its
z-index CSS can be removed together.
