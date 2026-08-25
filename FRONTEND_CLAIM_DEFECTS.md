# Two claim defects in the frontend: diagnosis and fix plan

The two defects `CLAIM_REWARDS_ASSESSMENT.md` found while assessing the USDC
claim flow, traced to their source and specified for implementation.

Both are **live in the frontend today** and independent of the USDC claim feature
that assessment proposes — they are wrong now, on the panel as shipped.

- **Frontend:** `/home/ii/development/personal/game_frontend-worktrees/bug-fixapp-game_frontend`, branch `bug/fixapp`
- **Contract source:** `/home/ii/development/personal/game-worktrees/bug-vrf-game/src/lib.cairo`

Line numbers drift. Grep the identifier.

## The contract this targets — READ THIS FIRST

A **new game contract is deployed** carrying `get_reward_claimed` and
`get_claimable_weeks`. Neither defect is blocked any more, but the frontend must
be repointed before either fix can work.

| | Address | Verified on chain |
|---|---|---|
| **Game (new)** | `0x0771fdfb9c6f81b19a08b6f883878f52f6264b00b92d55516dfaa8a913cd834c` | `get_reward_claimed` → `false`, `get_claimable_weeks` → `array![]` |
| Game (old, superseded) | `0x0783f2409b051a0ec8db4f93c4ce0cf370617956ff31880d0c35a61bb1d350a9` | neither view exists |
| ROZ token | `0x03a5c8760ed42b8d916f2a37e55335c38979e9ec91c963d0be351e2c285d445b` | unchanged — the new game points at it |
| USDC | `0x0512feac6339ff7889822cb5aa2a86c848e9d392bb0e3e237c008674feed8343` | unchanged |

**Step zero: repoint the game address.** There are exactly **two** live sites,
and they must stay in step — when they drift, every gameplay call falls outside
the session policy and the keychain prompts on each one:

| File | Line | Constant |
|---|---|---|
| `src/components/utils/controllerPolicies.js` | 14 | `SEPOLIA_GAME_CONTRACT_ADDRESS` |
| `src/components/Middle.vue` | 41 | `SEPOLIA_GAME_CONTRACT_ADDRESS` |

`controllerPolicies.js:5`, `:7` and `:9` hold three **commented-out** historical
addresses. Leave them alone; they are not live.

**Do not touch the ROZ address in `Middle.vue:46`** — it is already correct and
did not change.

Both bounds guards were confirmed live: a reversed range reverts with
`bad week range`, and a 256-week span with `week range too wide`.

**The new contract is empty.** `get_game_week()` is `0`, and it holds no USDC and
no ROZ. The 3 shares and the $15.60 referenced below are on the **old** contract
and did not migrate — of that, **$15.00 is still owed to players** and only $0.60
is sweepable. Nothing on the new contract is claimable until a round is opened
and played.

---

## Defect 1 — the USDC figure is overstated

### Where

`src/stores/counter.js:516` — `gameTokenClaimShare()`

```js
function gameTokenClaimShare(share) {
  return fromTokenUnits(
    new BigNumber(String(this.hiderGamerFee)).multipliedBy(share),
    gameTokenDecimalsOrDefault.call(this)
  );
}
```

Reached from `setClaimShareAmountsDueThisRound` (`counter.js:523`) and
`setClaimShareAmountsDueNextRound` (`counter.js:530`), fed by the two
`get_claim_share_amounts` reads in `Middle.vue:658` and `Middle.vue:663`.

### What is wrong

The contract does **not** pay `hiderFee × shares`. `_calculateRewardDue`
(`src/lib.cairo`, grep `fn _calculateRewardDue`) pays:

```cairo
claimShareCount * (gameHiderFee - gasFee - gameFee - gameLandownerFee)
```

| | Value | Source |
|---|---:|---|
| `gasFeeReservation` | 3,333 | constructor |
| `gameMasterFee` | 8,333 | constructor |
| `gameLandownerFee` | 1,167 | constructor |
| **deductions per treasure** | **12,833** | |
| `hiderFee` | 5,000,000 | |
| **paid per share** | **4,987,167** | |

For the 3 shares currently on chain:

- frontend shows `3 × 5,000,000` = **$15.00**
- contract pays `3 × 4,987,167` = **$14.96**

### Two things that make it worse than a flat rounding error

**The deduction is per treasure, not per claim.** That was corrected in the
contract (see the long comment in `_calculateRewardDue` about the old
`eligibleReward - gasFee - gameFee - landowner` form). So the gap grows linearly:
$0.0128 per share, not $0.0128 per claim. At 100 shares the panel is $1.28 out.

**`hiderGamerFee` is the wrong fee anyway.** `counter.js:151` holds the **live**
hider fee. The contract pays from the **funding week's** fee —
`main_game[gameWeek - 1]`, the round *before* the one being claimed. The two are
equal only while fees never change. This is the same error the contract itself
already had and fixed (commit `ea49d57`, "fix the claim reward functionality to
use the correct hider fee amount"); the frontend still carries it.

### Fix

**Do not reproduce the arithmetic. Read the answer.** The contract already
exposes it:

```
get_player_reward_due(gameWeek, gamerWalletAddress) -> u256
```

Note the argument order — **week first**, the opposite of
`get_reward_token_due(addr, week)`.

1. Replace the two `get_claim_share_amounts` calls in `Middle.vue:658` and
   `:663` with `get_player_reward_due`, and delete `gameTokenClaimShare`
   (`counter.js:516`) along with its two call sites' arithmetic.
2. Keep the share counts if the panel wants to show "3 treasures" — but the
   money must come from the contract.

**`get_player_reward_due` can revert.** It deliberately mirrors the claim
including its assertions, so it throws `'Reward is less than fees'` on a round
funded below its own deductions. Wrap each call and treat a revert as "nothing
to collect from that round" rather than letting it break the panel. The existing
try/catch at `Middle.vue:675` is the right shape; it must not swallow the error
into a misleading `0`.

---

## Defect 2 — "Claim this round's ROZ" cannot succeed

### Where

- Gate: `src/stores/counter.js:683` — `canClaimRoundRewardTokenValue`
- Button: `src/components/Middle.vue:2624`
- Handler: `src/components/Middle.vue:488` — `claimRewardTokenForWeek()`
- Data: `src/components/Middle.vue:400` — `getRewardTokenPending()`

### What the assessment found

```js
const canClaimRoundRewardTokenValue = computed(() => {
  if (!hasRoundRewardTokenValue.value) return false
  if (isRoundRewardTokenClaimedValue.value) return false
  const held = rewardTokenContractBalance.value
  if (held === undefined) return false
  return held >= (rewardTokenDue.value?.[2] ?? 0n)
})
```

Three conditions: ROZ is owed, the ROZ leg is unclaimed, the contract can cover
it. **Missing: the USDC leg has been claimed.** `claim_reward_token_for_week`
opens with

```cairo
assert(
    self.claimed_rewards.read((gameWeek, gamerWalletAddress)),
    'USDC leg not claimed yet',
);
```

so the button reverts.

### The deeper cause the assessment did not reach

**The week is wrong, and no added condition can fix that.**

`getRewardTokenPending` (`Middle.vue:406`) reads `useCounter.currentGameWeek`,
which is the live `get_game_week()` (`counter.js:554`). `claimRewardTokenForWeek`
(`Middle.vue:493`) then submits that same current week.

But `_claimReward` asserts `gameWeek < currentGameWeek` — **the current week can
never have been claimed**, because it has not finished. So
`claimed_rewards[(currentWeek, addr)]` is *structurally* false, and the assert
above is guaranteed to fail. The retry only ever makes sense for a **finished**
round.

**The same off-by-one corrupts the display.** `_hideTreasure` records
`hider_survival_roz` against `currentGameWeek + 1` ("hide treasure for the week
upcoming"). So `get_reward_token_due(addr, currentWeek)` at `Middle.vue:415`
shows ROZ from hides made during the *previous* round — not "this round's" at
all. The label and the data disagree in opposite directions.

### Fix

The button's job is: *find a finished round whose USDC was collected but whose
ROZ was skipped, and re-run its ROZ leg.* Build it from that sentence.

1. **Target a finished round**, never `currentGameWeek`. Candidates are weeks
   `< currentGameWeek`.
2. **Add the missing condition** to `canClaimRoundRewardTokenValue`: the USDC
   leg for that week must be claimed. **`get_reward_claimed` exists for exactly
   this and is now deployed**, so this can be built today. The full gate is:

   | Condition | Read |
   |---|---|
   | round finished | `week < get_game_week()` |
   | USDC collected | `get_reward_claimed(addr, week) === true` |
   | ROZ still owed | `get_reward_token_claimed(addr, week) === false` |
   | ROZ recorded | `get_reward_token_due(addr, week)[2] > 0` |
   | contract can pay | `balance >= due` |

3. **Read the week's data at that week**, not the current one — fix
   `Middle.vue:415` and `:416` to take the target week rather than
   `currentGameWeek`.
4. **Correct the label.** It is not "this round's ROZ"; it is ROZ owed from a
   finished round whose payout was skipped. Something like *"Collect ROZ from a
   past round"*.

### Ordering note

Because `_claimReward` credits ROZ into `pending` as its final step
(`_creditClaimRoz`), this button is **only** for rounds claimed while the
contract held no ROZ. In the normal path the ROZ arrives with the USDC claim and
this button never appears. That makes it an exception handler — but with the
contract holding 0 ROZ, it is the path every player hits today.

---

## Dependency

**Nothing is blocked.** Both fixes can be built in full against the new address.

| | Needs | Status |
|---|---|---|
| Repoint the game address | — | **Do this first.** Every read below hits the wrong contract until it is done |
| Defect 1 | `get_player_reward_due` | Existed all along, on both contracts |
| Defect 2, steps 1/3/4 | nothing | Pure frontend logic |
| Defect 2, step 2 | `get_reward_claimed` | **Deployed and verified** |

The earlier advice to hide the ROZ retry button as an interim **no longer
applies** — build the real gate.

One order-of-work note: with the frontend repointed at a contract at week `0`
and no shares, both defects will *look* fixed simply because every figure is
zero and the retry button never appears. That proves the wiring, not the fix.
The verification below needs a round opened and played.

---

## Verification

0. The frontend is talking to `0x0771fdfb…cd834c`. Confirm before anything else:
   a call to `get_claimable_weeks` succeeding at all proves it, since the old
   contract has no such entrypoint.
1. Hide 3 treasures, then open two rounds so they become claimable. The panel
   must read **$14.96**, not $15.00 — `3 × (5,000,000 − 12,833)`. Confirm against
   `get_player_reward_due(<week>, <player>)` directly.
2. Change the hider fee between rounds via `start_new_game`, then confirm the
   panel still matches the contract — this is what catches the live-vs-funding
   week error, and the current display passes test 1 while failing this one.
3. The ROZ retry button does not appear for the current round.
4. On a round with USDC claimed and ROZ skipped, the button appears and its
   transaction succeeds.
5. A round funded below its fees makes `get_player_reward_due` revert; the panel
   shows "nothing to collect from that round" and the rest still renders.
