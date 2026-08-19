# ROZ reward token — implementation notes

Status of the Cairo work against `ROZ_REWARD_TOKEN_PLAN.md` and its STE mirror.

**Everything builds; 29 of 29 tests pass.** Nine of the ten planned slices are
implemented. Nothing has been declared or deployed.

---

## 1. Running it

`scarb` and `snforge` both need writable cache directories, which the default
locations are not in every environment:

```bash
export SCARB_CACHE="$SOME_WRITABLE_DIR/scarb-cache"
export CARGO_HOME="$SOME_WRITABLE_DIR/cargo-home"   # snforge_std pulls Rust proc-macros

scarb build      # 0 errors, 4 contract classes
snforge test     # 29 passed, 0 failed
```

Warnings are all pre-existing — deprecated `LegacyMap`, unused imports left over
from the Pragma VRF flow.

### `snforge_std` was bumped

`Scarb.toml` pinned **v0.24.0** against an **0.62.1** binary. That combination
cannot build at all: v0.24's cheatcodes derive `Display`, which Cairo 2.20.0 does
not provide. Now pinned to **v0.62.1**.

Two API changes came with it, both already applied in `tests/test_contract.cairo`:

- `declare()` returns `DeclareResult`, so `.contract_class()` is needed before
  `.deploy()`.
- That method lives on `DeclareResultTrait`, which must be imported.

---

## 2. What was built

| Slice | Plan | State |
|---|---|---|
| 1 | §3 — token compiles | **Done** |
| 2 | §4a, §4b, §4e — storage foundation | **Done** |
| 3 | §4c, §4c-i, §4d — accrual core | **Done** |
| 4 | §4f, §2.6 r2 — rate resolution | **Done** |
| 5 | §2.5, §4l — hop path | **Done** |
| 6 | §2.3 — hide path | **Done** |
| 7 | §4m, §4m-iii — bulk hiding and whitelist | **Done** |
| 8 | §4g, §4h, §4i — claims | **Done** |
| 9 | §4j — sweep guards | **Done** |
| 10 | §7 — tests | **Done**, with two gaps in §5 below |

`src/lib.cairo` went 1,328 → 3,359 lines; 78 entrypoints. New file
`src/mock_erc20.cairo` (75 lines, test-only). Token imports fixed in
`src/game_reward_token.cairo`.

### Import paths, verified against the resolved source

The plan's §3 mapping table is correct, and worth restating because the wrong
half looks plausible: **there is no `openzeppelin_interfaces` package in
v2.0.0**. The umbrella `openzeppelin` crate re-exports each sub-package under a
nested path, and `IUpgradeable` lives beside its component:

```cairo
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::token::erc20::{DefaultConfig, ERC20Component, ERC20HooksEmptyImpl};
use openzeppelin::upgrades::UpgradeableComponent;
use openzeppelin::upgrades::interface::IUpgradeable;
```

---

## 3. Breaking changes

Two signatures changed. Any existing script calling them will fail.

**The constructor takes a third argument.**

```cairo
constructor(vrfProviderAddress, gameTokenAddress, rewardTokenAddress)
```

§5 phase 2 already documents three, so the plan and the code agree — but a
two-argument deploy script does not.

**`withdraw_token_balance` takes the token first.**

```cairo
withdraw_token_balance(tokenAddress, receiver)   // was (receiver)
```

---

## 4. Decisions taken while implementing

These went beyond a literal reading of the plans. All are commented at the
relevant code.

**Defaults live in `_initialiseRewardSettings()`, not inline in the
constructor.** An upgrade does not re-run a constructor, so a setting added in a
later version would read back as zero — and a zero `dailyHideCap` or
`maxTreasuresPerRound` silently stops all hiding. Keeping them in one callable
shape lets a future version re-apply them deliberately.

**Single and bulk hides share one code path.** `hide_treasure` calls
`_hideTreasure(caller, 1, …)`; `hide_treasure_bulk` passes the real count. The
fee tier and volume multiplier are read from `player_hides_today` as it advances
*inside the loop*, so a bulk of N **is** N singles arithmetically rather than
being separately coded to match. Verified by
`test_bulk_hide_equals_the_same_number_of_single_hides`.

**`total_usdc_claimable` is maintained, not just declared.** The plans specify
the counter for the §4j sweep guard but never say where it is written. It is
incremented by the stake on every hide and decremented on claim; without that
the USDC guard has nothing to subtract.

**§4m-ii was fixed in passing.** `_calculateRewardDue` subtracted the three fees
once per *claim*; it now subtracts them per *treasure*. A single-share claim
still pays exactly `4,987,167`, so the live path is unchanged.

**Two guards the plans imply but never state**, both asserted in setters:

```
dailyFreeHops < participationMinimumHops
whitelistCollectiveCap <= maxTreasuresPerRound
```

---

## 5. Test coverage

29 tests in `tests/test_contract.cairo`. The harness deploys `MockVrfProvider`
and two `MockERC20`s — one standing in for USDC, one for ROZ — funds the player,
approves the game contract, and funds the contract with ROZ so the coverage rule
lets rewards accrue.

### The assertions that carry the anti-farm reasoning

| Test | What it pins down |
|---|---|
| `test_hide_fee_is_spend_but_stake_is_not` | Three hides move $15.60; spend reads exactly **600000**. `15600000` would mean the stake is counting, which makes the $3 gate 14× cheaper |
| `test_three_hides_land_exactly_on_the_gate` | The `tierBoundary × feeBase == dailyThreshold` calibration, end to end |
| `test_rates_resolve_to_lowest_and_never_multiply` | **4.5e18** — and explicitly not `15e18` (new-wallet only) or `2.25e18` (multiplied) |
| `test_bulk_hide_equals_the_same_number_of_single_hides` | Identical ROZ and spend, so there is nothing to gain by splitting or batching |
| `test_volume_multiplier_reduces_later_treasures` | Marginals 15 → 10.5 → 1.2, day total **64.2 ROZ** |
| `test_free_hops_earn_but_never_count_as_spend` | 22 free hops → **3.3 ROZ**, spend 0. The §4l-i-a zero-cost figure |
| `test_participation_waits_for_both_conditions` | Bonus withheld at 28 hops, fires once spend crosses |
| `test_whitelist_group_cap_leaves_room_for_ordinary_players` | Group cap refuses a whitelisted address whose own cap would allow it — **and an ordinary player still hides** |
| `test_sweep_leaves_what_players_are_owed` | Only the fee is sweepable; the stake is not |

### On the volume-multiplier test

The first version of it asserted that ten hides earn less than ten first-hides.
**It failed, and the assertion was wrong, not the contract.** The first two
treasures pay 4.5 because the wallet is below the *gate*, not because of the
curve; once hide 3 crosses $0.60 the wallet sits on the flat new-wallet rate of
15. Ten treasures total 64.2, which is more than 45.

Comparing treasure 10 against treasure 1 measures the gate. The test now walks
marginals at constant gate status, which is what the curve actually governs.

### On the whitelist proofs

The Merkle tree is built **in Cairo, in the test**, using the same
`PoseidonTrait` calls `_verifyWhitelist` uses. That makes the proofs correct by
construction, and a four-leaf tree is small enough to write the proofs out by
hand — which is what checks the index convention.

The tests are **self-validating**: `test_whitelisted_address_exceeds_the_daily_cap`
places 15 treasures, and an unverified caller is capped at 10, so 15 landing is
itself the proof that verification succeeded.

### Two gaps

**Cross-language Merkle compatibility is unverified.** The verifier is
self-consistent, but nothing here proves the `starknet-merkle-tree` JS tooling in
§4m-iii produces trees it accepts. Three things must agree — Poseidon as the
hash, the raw address as the leaf, and the index convention — and a mismatch
**fails silently**, dropping whitelisted addresses back to 10/day. Check this
before the whitelist is used for real.

**Production whitelist caps are only checked arithmetically.** The group-cap
mechanism is tested with scaled values (20/30/20) so the bound is reachable in a
few calls; reaching it at 250/1,200/80 needs three hours of block-time warping
past the hourly cap. The production values and the 1,640-slot floor are asserted
in `test_whitelist_caps_leave_a_floor`. The mechanism is identical at any scale.

---

## 6. Known risk

**A non-deployed reward-token address bricks every rewarded action.**
`_accrueRewardToken` handles the *unset* case — `is_zero()` skips the credit and
emits `RewardTokenAccrualSkipped` — but an address pointing at nothing makes
`balance_of` revert and take the whole hop or hide with it.

That contradicts the plan's principle that gameplay must never depend on reward
plumbing. It is loud and immediate rather than silent, so a bad
`update_game_reward_token` surfaces on the first transaction after it. Tolerating
it would need a safe-dispatcher call; **not done**, because whether a config typo
should fail loudly or degrade quietly is a judgement call, not an oversight.

---

## 7. Outstanding

**Upgradeability — undecided, not built.** The game contract has
`OwnableComponent` but no `UpgradeableComponent`; the ROZ token has both. Two
questions block it:

- *Who may call `upgrade()`?* The contract holds USDC stakes, unclaimed USDC and
  pending ROZ, so whoever can upgrade can replace it with a class that drains
  all of it. Options are owner-only with a multisig owner, an on-chain timelock,
  or owner-only with the current single EOA.
- *Should the owner become a constructor argument?* It is currently hardcoded as
  `0x052a2b…`, which with upgradeability becomes the upgrade key baked into the
  class. The VRF provider was already moved from hardcoded to a constructor
  argument for the same reason.

**§6 frontend** — the plans mark it "to be documented, not applied here".

**§5 deployment** — build and test only; nothing declared or deployed.

---

## 8. Files

| File | Change |
|---|---|
| `src/lib.cairo` | 1,328 → 3,359 lines. Storage, rate resolution, hop and hide paths, whitelist, claims, sweep |
| `src/game_reward_token.cairo` | Four OZ v2.0.0 import paths corrected |
| `src/mock_erc20.cairo` | **New.** Test-only ERC-20 with an unrestricted mint — never deploy to mainnet |
| `tests/test_contract.cairo` | 29 tests, wired harness |
| `Scarb.toml` / `Scarb.lock` | `snforge_std` v0.24.0 → v0.62.1 |
