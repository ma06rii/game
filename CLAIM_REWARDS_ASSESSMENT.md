# Claiming USDC rewards: assessment and design

Assessment of a proposed approach for claiming USDC rewards, written against the
deployed contract at `0x007030fb8aec5eb20ed893bb2147fefe0dd07b204d55be12fedf9ce4579f7a4f`
and the contract source at `/home/ii/development/personal/game-worktrees/bug-vrf-game/src/lib.cairo`.

Line references drift — grep the identifier rather than trusting the number.

**Status.** The contract recommendation in this document is **built, tested and
deployed**. `get_reward_claimed` and `get_claimable_weeks` are in `src/lib.cairo`,
covered by seven of the suite's 43 passing tests, and both are live and verified
on chain.

The game contract has no upgrade path, so every change ships as a **redeploy at a
new address**. This document's views went out in one; a later redeploy added the
missed-ROZ ledger:

| | Address |
|---|---|
| **Game (current)** | `0x007030fb8aec5eb20ed893bb2147fefe0dd07b204d55be12fedf9ce4579f7a4f` |
| Game (superseded, has these views) | `0x0771fdfb9c6f81b19a08b6f883878f52f6264b00b92d55516dfaa8a913cd834c` |
| ROZ token | `0x03a5c8760ed42b8d916f2a37e55335c38979e9ec91c963d0be351e2c285d445b` |
| USDC | `0x0512feac6339ff7889822cb5aa2a86c848e9d392bb0e3e237c008674feed8343` |

Two further deployments precede these — see `ROZ_DEPLOYMENT_AND_FUNDING.md` §1.

**The frontend points at `0x0771fdfb…`, not the current contract**, so it has the
views this document asked for but not the missed-ROZ ledger. See
`FRONTEND_CLAIM_DEFECTS.md`, step zero. Everything from "Design" onward is still
a proposal, and no frontend code has changed.

Two carry-overs: the current contract is **empty** (`get_game_week` is `0`, no
USDC, no ROZ), and **state never migrates**. `0x0771fdfb…` is at week 5 holding
$22.13 USDC, of which **$20.08 is owed to players** and only $2.05 is sweepable —
claimable only while the frontend still points there.

## The problem

The sidebar has two ROZ claim buttons and **no way to claim USDC at all**.
`claim_reward` is present in `src/components/utils/controllerPolicies.js` as a
session policy but has no call site anywhere in `src/components/Middle.vue`; the
only other mention is a commented-out line. The original "Claim Rewards" button
was hard-disabled with a "coming soon" label, and the ROZ buttons replaced it —
which made the gap visible rather than creating it.

## The proposal being assessed

> A serverless backend function retrieves how much USDC is due for a player and
> the list of claimable game weeks. If more than one week is outstanding, the
> frontend sends a multicall in batches of at most 8 calls. USDC must be claimed
> before ROZ, so immediately after the USDC calls succeed, claim the ROZ.

Three parts are right, one does not work, and one is dangerous.

---

## ✅ Right: USDC must precede ROZ

`claim_reward_token_for_week` asserts `claimed_rewards[week]` with
`'USDC leg not claimed yet'`. The ordering instinct is correct and enforced
on-chain.

## ✅ Right: batching in a multicall

Starknet multicall is native, and the existing `executeAndConfirm` helper already
accepts an array of calls — `spawnNewPosition` passes two today. 8 is a sensible
cap. The real constraint is the transaction step limit rather than a call count,
so treat 8 as a starting figure to tune, not a contract rule.

## ⚠️ Refine: one ROZ sweep, not one per round

`_claimReward` calls `_creditClaimRoz(addr, week)` as its final step. So
`claim_reward(week)` pays the USDC **and** credits that round's ROZ into
`pending` in the same transaction. The real sequence is:

1. `claim_reward(week)` × N — USDC paid, ROZ credited to `pending`
2. `claim_reward_tokens()` × **1** — sweeps all accumulated `pending` to the wallet
3. `claim_reward_token_for_week(week)` — **only** for rounds whose credit was
   skipped because the contract was unfunded at the time

One sweep at the end, not a per-round ROZ call.

## 🚨 Dangerous: never put `claim_reward_tokens()` in the same multicall

`claim_reward_tokens` asserts its ERC20 transfer succeeded, and the token panics
on insufficient balance. **The contract currently holds 0 ROZ.** Bundled into the
same transaction as the USDC claims, a ROZ shortage reverts the entire multicall
and the USDC never lands.

That destroys the exact guarantee the contract is built around, stated in its own
source:

> THE USDC HAS ALREADY BEEN PAID AND THE FLAG ALREADY SET. That ordering is the
> whole point: a ROZ shortage must never be able to block a USDC claim. This is
> the behaviour the entire accrual design exists to protect.

The ROZ sweep must be a **separate transaction**, sent only after the USDC
transaction confirms. "Immediately afterwards" is fine; "in the same call" is not.

## ✅ Resolved: the backend cannot get the data it needs

**This was the finding that changed the architecture. The contract has since
been changed, and it no longer applies** — see "Recommendation" below, which is
now built and tested. The reasoning is kept because it is why the two views
exist, and why removing them would put the whole problem back.

To list claimable rounds you need, per round, "was this already claimed". That
information *was* not reachable from outside the contract:

- `claimed_rewards` was **storage-only**, with no view exposing it. This is the
  one item the change fixes; `get_reward_claimed` now reads it, on the current
  contract. It remains true of the superseded one.
- There is **no USDC claim event**. The complete event enum is `TreasureHidden`,
  `TreasureHiddenBulk`, `TreasureFound`, `PlayerPosition`, `CheckForTreasure`,
  `RewardTokenAccrued`, `RewardTokenAccrualSkipped`, `RewardTokenClaimed`.
  `_transfer_token` is a raw `call_contract_syscall` and emits nothing.
  **An indexer has nothing to index.**
- A read-only `starknet_call` probe does not work: `get_caller_address()` is `0`
  in a call, so it reports address zero's state. Verified — probing week 0
  returned `'No reward available'` for zero, not for the player. Both new views
  take the wallet as an **argument** for exactly this reason.
- `get_reward_token_claimed` is not a usable proxy. It stays `false` when the ROZ
  leg is skipped, which is *always* while the contract is unfunded.

The only workarounds were `simulateTransactions` with `skipValidate` (one INVOKE
simulation per round, requires a nonce) or an indexer parsing historical
transaction calldata for `claim_reward` calls. Both are heavy and brittle, and a
backend is no better placed to do either than the frontend is.

### Recommendation: add a view to the contract — **BUILT**

Both views are implemented in `src/lib.cairo` and covered by seven tests in
`tests/test_contract.cairo`. Grep `get_claimable_weeks` rather than trusting a
line number.

```cairo
// Has the USDC leg of this round already been collected?
fn get_reward_claimed(
    gamerWalletAddress: ContractAddress, gameWeek: u256,
) -> bool;

// Which rounds can this wallet collect? Bounds are INCLUSIVE.
fn get_claimable_weeks(
    gamerWalletAddress: ContractAddress, fromWeek: u256, toWeek: u256,
) -> Array<u256>;
```

`get_reward_claimed` mirrors the existing `get_reward_token_claimed` in four
lines. `get_claimable_weeks` applies **all three** of `_claimReward`'s
conditions, so every week it returns is one `claim_reward` will accept and the
frontend can batch them into a multicall without checking again.

With these the frontend needs **no backend at all** for correctness, and a
backend becomes a pure scale optimisation — worth adding only when the round
count makes a single scan impractical. `currentGameWeek` is `0` on the new
contract — it is freshly deployed and no round has been opened yet.

**One caveat that shapes the frontend code.** `get_claimable_weeks` never
reverts, but `get_player_reward_due` still does — it deliberately mirrors the
claim including its assertions. Reading amounts for the weeks the scan returns
is safe by construction; reading them for an arbitrary week is not. A round
funded below its own fees is the case that trips it.

Two bounds are enforced: `fromWeek <= toWeek` (`'bad week range'`) and a span
under 256 rounds (`'week range too wide'`, guarding the step limit for a call).
Both were confirmed firing on the deployed contract with those exact strings.

**Both views are live at `0x007030fb…9f7a4f`**, verified by call:
`get_reward_claimed` returns `false` and `get_claimable_weeks` returns
`array![]` for a wallet that has not played. Neither entrypoint exists on the
superseded contract, which makes a successful `get_claimable_weeks` call the
simplest proof that a client is pointed at the right one.

The superseded contract still holds **$15.00 owed to players** in hider stakes —
`get_sweepable_balance` frees only $0.60 — so those stakes need claiming or
writing off before that address is abandoned. They did not migrate.

---

## Two related defects found while assessing

**The displayed USDC is overstated.** The panel computes `$5 stake × 3 shares` =
`$15.00` locally. The contract's `get_player_reward_due(1, addr)` returns
**$14.96** — the local arithmetic misses the fee deduction. It should read the
contract.

**The "Claim this round's ROZ" button is wrong as shipped.** It gates on
`survivalRoz > 0 && !rewardTokenClaimed` but not on the USDC leg being claimed, so
today it would revert with `'USDC leg not claimed yet'`.

---

## Design

Grounded in the existing system: `.dp-panel-container`, `.dp-pill`, `.dp-divider`,
`.dp-btn-claim`, the `--dp-*` custom properties, `data-media-type="banani-button"`
on every button, and the `.dp-gate-track` meter built for the spend gate.
Desktop-only, `rem`-sized, no new breakpoints.

**Principle: one action, and never expose the machinery.** A player should not
meet the words multicall, batch, week index, or leg. Batching is an implementation
detail; rounds are "rounds".

### Resting state, something to claim

One primary action with the breakdown beneath, so the total reads first and the
composition second:

```
COLLECT REWARDS                 <- .dp-btn-claim, primary
$14.96 USDC + 40 ROZ            <- breakdown line
from 1 finished round           <- .dp-pill, muted
```

With several rounds owed the third line becomes `from 5 finished rounds`. The
count is the only hint that batching exists, and it reads as information rather
than mechanism.

### Working state, inline rather than a modal

The flow is not an interruption, so it does not warrant a modal. Reuse
`.dp-gate-track` as a two-segment progress rail in place of the button:

```
Collecting your USDC...    [########....]   round 2 of 5
Collecting your ROZ...     [############]
```

Two labelled steps make the dependency legible without ever explaining it.

### Partial success, the state that matters most

If the USDC transaction confirms and the ROZ sweep reverts because the game is
unfunded, that is **a success with a footnote** and must never read as a failure.
Reuse the existing `.dp-notice-warning`:

> **Your USDC has arrived.** Your 40 ROZ is saved and will be paid once the game
> is topped up. Nothing is lost.

with a quiet secondary retry. This is the state players will actually hit today,
so it deserves the most care.

### Empty state, today's reality

`_claimReward` asserts `gameWeek < currentGameWeek`, so only finished rounds are
claimable. A player whose shares sit in the current round has nothing to collect
yet. A disabled button with no explanation is what prompted this whole thread:

> Rewards unlock when the round ends. Yours are building up in this one.

### Copy rules

`round` not `week`. `collect` not `claim_reward`. Never surface a raw revert
string; map the three knowable ones:

| Revert | Player-facing |
|---|---|
| `Game week not finished yet` | Rewards unlock when the round ends |
| `Reward already claimed` | Already collected |
| `No reward available` | Nothing to collect from that round |

---

## Implementation sketch

| File | Change |
|---|---|
| `src/components/Middle.vue` | `claimAllRewards()` sequencing USDC batches then one ROZ sweep as separate transactions; claimable-round discovery; revert-message mapping |
| `src/stores/counter.js` | `claimableRounds` state (`week`, `usdcDue`, `rozDue`), totals, and the claim-phase flag driving the progress rail |
| `src/assets/game/game_index.css` | breakdown line and the two-step reuse of `.dp-gate-track`; no new tokens |

Reuse rather than rebuild. `executeAndConfirm` already handles multicall arrays
and separates submit failures from confirm failures; `showTxError` already
surfaces errors; `.dp-gate-track` and `.dp-notice-warning` already exist.

**Discovery** is now a single call — `get_claimable_weeks(addr, 0, currentWeek)`
— then one `get_player_reward_due(week, addr)` per returned week for the amounts.
No bounded window, no probing, no `'Reward already claimed'` revert to
disambiguate, and nothing to guess.

The superseded approach, for contrast: read `get_player_reward_due` across the
most recent 8 rounds, treat non-zero as a candidate, and let a revert settle the
ambiguity. It is worth knowing this is what the alternative looks like, because
it is what the frontend falls back to if it points at a contract without the
views.

## Verification

1. The panel shows the empty state with its reason, not a silent disabled button.
2. With a claimable round on a test wallet, the button reads
   `Collect rewards / $X USDC + Y ROZ / from N finished rounds`.
3. With the contract unfunded, the USDC transaction confirms and the
   partial-success notice appears. **Confirm on-chain that the USDC balance rose** —
   this is the regression that bundling would cause.
4. With more than 8 claimable rounds: multiple transactions, progress counts up,
   one ROZ sweep at the end.
5. Re-run the headless driver and diff every figure against the chain:
   ```
   node .claude/skills/run-game-frontend/driver.mjs --simulate-account \
     --address <player> --shot .side-panel --out /tmp/shots
   ```

## Open items

- ~~**`get_reward_claimed` is the highest-value change here, and it is a contract
  change rather than a frontend one.**~~ **Done and deployed** at
  `0x007030fb…9f7a4f`. What remains is a **frontend repoint** — the app still
  talks to the superseded address — and settling that contract's $15.00 of
  player stakes.
- The contract holds **0 ROZ**, so the ROZ leg fails for every player until it is
  funded. The partial-success state is not an edge case today; it is the default
  path.
- The `/impeccable` design skill's full flow requires a `PRODUCT.md`, which this
  repo does not have. `/impeccable document` would generate a `DESIGN.md` from the
  existing CSS and is worth running before further visual work.
