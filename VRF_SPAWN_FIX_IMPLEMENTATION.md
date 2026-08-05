# VRF spawn fix - implementation record

What was actually built, what it does, and what still needs doing.

Companion documents:
- `VRF_SPAWN_FIX_CONTEXT.md` / `VRF_SPAWN_FIX_PLAN.md` - the original handoff
  notes. **Several of their assumptions turned out to be wrong**; see
  "Corrections to the handoff docs" below before trusting them.
- `FRONTEND_ADDRESS_UPDATE.md` - the frontend changes required after deploy.

---

## The problem

Spawning reverted on Sepolia with:

```
argent/multicall-failed, 0x1, 'VrfProvider: not fulfilled', ENTRYPOINT_FAILED
```

Index `0x1` is the game contract, and the inner failure is `consume_random` on
Cartridge's VRF provider.

Cartridge's provider does not generate randomness - it hands back a number their
**paymaster** proved and submitted earlier in the same transaction via
`submit_random`. Cartridge confirmed their Sepolia paymaster is down, so:

- **Cartridge Controller path** - paymaster down, nothing works at all.
- **Standard-wallet fallback** - no paymaster in the path, so `submit_random`
  never runs and `consume_random` reverts.

That is why `hide_treasure` (no randomness) worked while spawn could not, and
why every move was blocked behind spawn.

## The fix

A testnet-only mock VRF provider that generates randomness **inline**, so nothing
ever needs to call `submit_random`. The game contract's VRF address becomes a
constructor argument plus an owner-gated setter, so it can be repointed at either
provider without a redeploy.

The decisive property: **no frontend logic changes.** The mock keeps
`request_random`'s signature identical to Cartridge's, so the existing
`[request_random, finder_player_generate_position]` multicall works untouched.
Only address constants change.

---

## What changed

### `src/mock_vrf_provider.cairo` (new)

`MockVrfProvider`, implementing the same `IVrfProvider` trait from `lib.cairo`
that the game contract's dispatcher already calls through - which is what makes
the mock and the real provider interchangeable by address alone.

- **`consume_random`** builds a Poseidon hash from a per-key counter, the
  randomness key, the caller, the transaction hash and the block timestamp, and
  **never reverts**. That single difference is what unblocks spawn.
- **`request_random`** is a no-op, kept only so the frontend's multicall stays
  valid. Its signature `(caller: ContractAddress, source: Source)` is held
  byte-identical because the frontend hand-assembles that calldata as
  `[gameContractAddress, "0", myAccountAddress]` with no ABI to catch a mistake -
  a reordering would fail silently, not loudly.
- **The constructor asserts the chain id is not `SN_MAIN`**, so the class refuses
  to deploy on mainnet.

  This differs from the plan, which put the mainnet guard in a deploy script. This
  repo has no deploy scripts for it to live in, and a script can be skipped or
  edited by hand, whereas the assertion travels with the class itself.

> The mock's randomness is predictable and steerable by a determined player.
> That is acceptable on testnet and unacceptable anywhere real value is at stake.

### `src/lib.cairo` (93 insertions, 18 deletions vs `cartridge_vrf_2`)

- `constructor` now takes `vrfProviderAddress: ContractAddress`; the hardcoded
  `contract_address_const::<0x051fea...>()` is gone.
- New **`update_vrf_provider`** (owner-gated, following the existing `update_*`
  convention exactly) and **`get_vrf_provider`**.
- Renamed `pragma_vrf_contract_address` -> `vrf_provider_contract_address` and
  `_request_randomness_from_pragma` -> `_request_randomness_from_vrf_provider`.
  Both names described a Pragma integration that no longer exists and directly
  contradicted the code around them.
- `mod mock_vrf_provider;` declared at the crate root, and `IVrfProvider` made
  `pub` so the mock can implement it.
- Heavy comments throughout: why the paymaster dependency broke spawn, what the
  two providers do differently, and the one-call route back to real VRF.

**Not touched:** `_spawnNewPosition`, `_receive_random_words_2`,
`finder_player_generate_position`.

### `Scarb.toml`

`allowed-libfuncs-list.name` changed from `"experimental"` to `"audited"`.
See caveat 2 below - this was a pre-existing break, not a change of preference.

### `tests/test_contract.cairo`

`deploy_contract` now serialises a VRF address into the constructor calldata
(previously `@ArrayTrait::new()`). See caveat 3 - this edit could not be
compile-checked.

---

## Verification performed

| Check | Result |
|---|---|
| `scarb build` from a clean `target/` | Passes |
| Both classes produced | `project_name_HelloStarknet` + `project_name_MockVrfProvider` |
| `scarb fmt --check` | Clean |
| Diff confined to intended changes | Confirmed - `scarb fmt` reformatted nothing incidental |
| Mock ABI shape | `request_random(caller, source)` view, `consume_random(source)` external, constructor with no args - matches the frontend's hand-rolled calldata |
| Game ABI shape | `update_vrf_provider(vrfProviderAddress)` external, `get_vrf_provider()` view, constructor takes `vrfProviderAddress` |

**Nothing has been deployed or tested on-chain.**

---

## Three caveats

### 1. The git merge was NOT made

The git metadata directory
(`/home/ii/development/personal/game/.git/worktrees/bug-vrf-game`) is mounted
read-only in the environment this work was done in, so `git merge cartridge_vrf_2`
fails on writing refs - even with the sandbox disabled:

```
fatal: update_ref failed for ref 'ORIG_HEAD': cannot lock ref 'ORIG_HEAD':
Unable to create '.../ORIG_HEAD.lock': Read-only file system
```

The `cartridge_vrf_2` file contents were materialised into the working tree
instead (`git show cartridge_vrf_2:<path> > <path>` for `src/lib.cairo`,
`Scarb.toml`, `Scarb.lock`, `tests/test_contract.cairo`). The code is correct,
but `bug/vrf` still points at `bd0139e` and there is no merge commit.

**Action required:** redo the merge properly, otherwise the history will show the
entire Cartridge VRF migration as an unattributed bulk edit inside this change.

### 2. `Scarb.toml` had a pre-existing build break

`allowed-libfuncs-list.name = "experimental"` is not a list name Scarb 2.20
recognises, so `cartridge_vrf_2` **did not build at all** with the local
toolchain before this work:

```
error: failed to check allowed libfuncs for contract: HelloStarknet
Caused by: No libfunc list named 'experimental' is known.
```

Changed to `"audited"`, which is also the list Starknet requires when declaring a
class on a public network. The Cairo itself compiled fine either way; only the
final libfunc check failed.

### 3. The test target cannot compile, and that predates these changes

`snforge_std` v0.24.0 fails internally against this toolchain:

```
error[E2200]: Plugin diagnostic: Unknown derive `Display` - a plugin might be missing.
 --> .../snforge_std/src/cheatcodes.cairo:14:54
```

Confirmed pre-existing by restoring the unmodified `cartridge_vrf_2` test file -
it fails identically. The suite is also ~95% commented out.

`deploy_contract` was still updated to pass the new constructor calldata so it is
correct once the `snforge_std` pin is upgraded, but **that edit could not be
compile-checked**. It uses the same `ArrayTrait::new()` + `.append(x.into())`
idiom as `_createRandomnessCalldata` in `lib.cairo` to minimise the risk.

---

## What still needs doing

### Deploy to Sepolia

Not done - it needs an account that was not available. Check what is configured
with `sncast account list`. No `snfoundry.toml` exists in this repo, so pass
network and account flags explicitly.

1. Declare and deploy **`MockVrfProvider`** (no constructor arguments - it
   self-checks the chain id). Record the address.
2. **Sanity-check the mock in isolation before wiring anything to it.** Invoke
   `consume_random` with `Source::Nonce(<your address>)` - calldata
   `0 <your address>`. It must not revert. Call it twice and confirm the returned
   felt changes.
3. Declare and deploy **`HelloStarknet`** with
   `--constructor-calldata <mock address>`. Record the address.
4. Confirm the wiring: `get_vrf_provider()` must return the mock address.

### Check the game week before testing spawn

The constructor calls `_createNewGame(..., gameWeek: 0)`, so **a fresh deploy
starts at week 0**, while the old contract was on week `0x1`. Grid size for week 0
is set (14x14) so week 0 is playable, but if the frontend or any off-chain tooling
assumes week 1, the owner must call `start_new_game(...)` once to advance it.

Confirm with `get_game_week()` and decide before testing.

### Frontend

See `FRONTEND_ADDRESS_UPDATE.md`. Two address constants, one or two files
depending on which branch is targeted, plus a stale ABI worth regenerating.

---

## Corrections to the handoff docs

`VRF_SPAWN_FIX_PLAN.md` and `VRF_SPAWN_FIX_CONTEXT.md` were written without
access to the Cairo source. Four assumptions were wrong:

| Doc says | Reality |
|---|---|
| The Cairo source lives in a separate repo | It is **this** repo. The frontend is `/home/ii/development/personal/game_frontend` |
| The VRF address is a hardcoded `const` | It was already storage (`pragma_vrf_contract_address`), written from a literal in the constructor. No setter, no constructor arg |
| Add `cartridge_vrf` as a Scarb dependency | Unnecessary - `IVrfProvider` and `Source` were already declared locally in `lib.cairo` |
| The mock needs `submit_random` | The local `IVrfProvider` trait declares only `request_random` and `consume_random`. Nothing calls `submit_random`, so it was omitted rather than editing a trait the game contract depends on |

Also worth recording: the branch holding the Cartridge VRF code was
`cartridge_vrf_2`, **not** `bug/vrf`. `bug/vrf` still held the older Pragma VRF
implementation, which is not what is deployed and not what was failing.

---

## Path back to production

- **Mainnet** deploys the game contract with Cartridge's real provider
  (`0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f`, the same
  address on Sepolia and mainnet) as the constructor argument. The mock is never
  deployed there - its constructor rejects the deployment outright.
- **When Cartridge's Sepolia service recovers**, no redeploy is needed. As the
  owner (`0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833`),
  call `update_vrf_provider(0x051fea...)` and the game is back on real,
  verifiable randomness immediately.
- At that point the standard-wallet fallback, its z-index CSS and the
  `?wallet=standard` flag can all be removed together.
