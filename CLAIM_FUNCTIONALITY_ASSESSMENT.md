# Claim functionality - assessment and proposal

What is needed to get claiming working, why it does not work today, and the
decisions still open. Nothing here is speculative: every contract statement was
read from `src/lib.cairo`, and every state value was queried live against
`0x0407390e9074fab2526d2cca38ed6922bcde406ccc0993809bc0e0b327c1e2e0`.

**Summary in one line:** the contract's claim path is sound and needs no changes
to function - claiming is blocked by the game week never having advanced, and by
a frontend that has no claim code in it at all.

---

## 1. Current state (verified on-chain)

The USDC contract is deployed and correctly wired. This part is done:

| Check | Value |
|---|---|
| Game contract | `0x0407390e9074fab2526d2cca38ed6922bcde406ccc0993809bc0e0b327c1e2e0` |
| Class hash | `0x20ff5873f91cdcd05e0ebc7f5a10a0b3aa22a742e0a905b1eb023c1f03aae16` |
| `get_game_token()` | USDC `0x0512feac...` ✓ |
| `get_vrf_provider()` | mock `0x1baad38b...` ✓ |
| `get_hider_player_fee()` | `5000000` ($5) ✓ |
| `get_generate_position_fee()` | `1000000` ($1) ✓ |
| `get_minimum_allowance_fee()` | `7000000` ($7) ✓ |
| Contract USDC balance | `11800000` ($11.80) |
| **`get_game_week()`** | **0** |

Per-week state:

| Week | `total_reward_shares_for_hiders` | `main_game (root, finderFee, hiderFee)` |
|---|---|---|
| 0 | 3 (constructor seed) | `(0xbc19a3..., 100000, 5000000)` |
| 1 | **2** - two real hides | empty, week not created |
| 2 | 0 | empty |

The $11.80 is consistent with 2 hides ($10) + 1 spawn ($1) + 8 moves ($0.80).
There is real play data on this contract.

---

## 2. Why claim does not work - two independent blockers

### Blocker 1 - the week never advanced

`_claimReward` (`src/lib.cairo:728`) opens with:

```cairo
assert(gameWeek < self.currentGameWeek.read(), 'Game week not finished yet');
```

`currentGameWeek` is `0` and `u256` is unsigned, so no week satisfies this.
Meanwhile `hide_treasure` credits shares to `currentWeek + 1`, so the two
existing shares sit at **week 1** and need `currentGameWeek >= 2` before they
become claimable.

This has never been reachable on any deployment. The previous contract sat at
week 1 with 33 hides credited to week 2 - equally unclaimable.

### Blocker 2 - the frontend has no claim implementation

Not broken, absent. `claim_reward` is never invoked anywhere in `src/`; every
occurrence is a session-policy declaration or a comment. The button
(`Middle.vue:2405`) is hardcoded:

```html
<button class="dp-btn-claim" data-media-type="banani-button" :disabled="true">
  Claim Rewards
  <div class="game-coming-soon-label">coming soon</div>
</button>
```

No `@click`. `:disabled` is a literal, not a computed. The CSS additionally sets
`pointer-events: none`. Even the week to claim for does not exist in the store -
there is `gameWeek` and `nextGameWeek` but no `previousGameWeek`, and
`get_claim_share_amounts` is only ever read for current and next week, never for
a claimable past one.

---

## 3. How rewards actually accrue

Worth stating plainly, because the timing is unintuitive:

- **`hide_treasure` at week W** credits `claim_share_amounts[(W+1, hider)] += 1`
  and pays the hider fee into the contract. You are buying into **next** week.
- **`validate_treasure_coordinates`** (owner-only, merkle proof) credits the
  finder and debits the hider for that week. No backend appears to run it, so in
  practice **only hiders accrue shares today**.
- **`claim_reward(W)`** pays out once `W < currentGameWeek`.

Payout, from `_calculateRewardDue` (`src/lib.cairo:749`):

```
eligibleReward = shares x currentHiderFee
rewardDue      = eligibleReward - gasFeeReservation - gameMasterFee - gameLandownerFee
```

The three fees are subtracted **once per claim, not per share**:

- two players with 1 share each -> `4,987,167` each, `9,974,334` total
- one player with 2 shares -> `10,000,000 - 12,833` = `9,987,167`

Either way the contract's `11,800,000` covers it.

---

## 4. Week rollover mechanics

`start_new_game` writes exactly six things:

| Writes | Value | Note |
|---|---|---|
| `currentGameWeek` | previous + 1 | the only way it moves |
| `currentFinderFee` / `currentHiderFee` / `currentSpawnNewPositionFee` | your args | **global, not per-week** |
| `main_game[newWeek]` | `(root, finderFee, hiderFee)` | |
| `main_game_grid_size[newWeek]` | `(gridX, gridY)` | |
| `total_reward_shares_for_hiders[newWeek]` | your arg | **overwrites, does not add** |
| `game_totals[newWeek]` | your arg | |

It does **not** touch `claim_share_amounts`, which is what claim actually pays
on - so a rollover cannot destroy anyone's entitlement.

### Two traps

1. **`total_reward_shares_for_hiders[newWeek]` is clobbered.** Week 1 holds `2`
   right now, accrued from the hides. Rolling 0→1 must pass `2` back in.
   Passing the wrong argument here is exactly what left `4500000000000000` in the
   old contract's week-1 hider slot.
2. **The fee arguments are global**, and `_calculateRewardDue` reads the global.
   Pass anything but `5000000` for `hiderFee` and every unclaimed reward across
   all weeks reprices.

### The calls needed to unblock the existing shares

Two rollovers. Re-read `get_total_number_of_hiders` immediately before each and
pass the value straight back:

- **0→1** with `totalNumberOfHidersFromThePreviousWeek = 2`
- **1→2** with whatever week 2 reads at that moment (0 now, +1 per hide while
  sitting at week 1)

`u256` arguments are two felts, `(low, high)`. The week-0 merkle root splits as:

```
low  = 0x92fe3fb625937ab468940c4c58966849
high = 0xbc19a39ffdeb3ff487a290fd65626b95
```

Then `claim_reward(1)` pays out. Side effect: positions are keyed per week, so
every player must re-spawn after each rollover. That is by design.

Use an explicit `--url` on a spec-0.10 endpoint for all of these; `--network
sepolia` fails with `-32603`.

---

## 5. Contract issues - none of which block claim

| Issue | Blocks claim? | Effect |
|---|---|---|
| No `claimed_rewards` getter | No | UI cannot tell claimed from unclaimed; keeps showing the amount, claim reverts `'Reward already claimed'` |
| Fee repricing (`currentHiderFee`, not per-week) | No | Live risk, since manual rollover passes fees each time. `main_game[week]` already stores the per-week fee, so the fix needs no new storage |
| `validate_treasure_coordinates` reads the root from `currentGameWeek`, not its own `gameWeek` argument (`lib.cairo:1049`) | No | Only bites when validating a past week |
| GTR never transferred | No | `currentGameTokenReward` appears only in its declaration, the constructor and a getter. `claim_reward` makes one transfer, of the game token. `0x0788929e...` returns "Contract not found" on Sepolia |
| `_calculateRewardDue` underflow (assert omits the landowner fee) | No | Unreachable at current fee values |

**Cost of acting on any of these:** a fresh declare (~41 STRK) plus deploy, and
the new contract restarts at week 0 with no balance, no shares and no positions.
You would lose the $11.80 and the two live test shares.

---

## 6. Frontend gaps

Everything needed to build claim exists except claim itself.

**Ready to reuse:**
- `executeAndConfirm` (`Middle.vue:181`) and `showTxError` (`Middle.vue:163`)
  already separate submit failures from on-chain reverts properly. The
  `hideTreasure` call site is the template to copy.
- The session policy already grants `claim_reward`
  (`controllerPolicies.js:47`) - no re-approval prompt for existing sessions.

**Missing:**
- A `claimReward(week)` function.
- A `previousGameWeek` notion, and share reads for past weeks.
- An enabled button with a handler.
- Any already-claimed signal (blocked on the contract getter, see §5).

**Staleness problems that will bite once claim ships:**
- `get_game_week` is read once at mount and never polled.
- The Pusher `start-new-game` event only opens a modal. It does not refresh the
  week, shares, grid or TVL, so everything week-dependent goes stale mid-session.
- The position WebSocket binds `currentGameWeek` at subscribe time.
- `getGamerClaimableShares` swallows errors with `console.log`, so a failed share
  read silently displays `0`.

---

## 7. Open decisions

### A. Sequencing

No contract change is required for claim to work.

- **Ship claim against the current contract.** Roll the week twice, build the
  frontend, prove it end to end with real money moving, keep the $11.80 and the
  live shares. Batch contract fixes into a later redeploy. The frontend build is
  the long pole either way.
- **Redeploy with fixes first.** Build the UI against the final ABI and skip the
  already-claimed workaround, at the cost of ~41 STRK and resetting to week 0
  with nothing to claim until the hides are re-done.

### B. Which fixes to include in the eventual redeploy

`get_claimed_reward(week, addr)` and the fee snapshot are the two that matter.
The root fix and the underflow guard are cheap to add alongside.

### C. GTR

Is the reward token meant to be paid on-chain, or is the figure a projection
settled elsewhere? Today the UI promises something `claim_reward` does not
deliver, and the token is not deployed on Sepolia.

### D. Finder rewards

They require an operator running `validate_treasure_coordinates` with merkle
proofs. Is that backend planned? Without it, only hiders ever earn.

---

## 8. Recommended path

1. Roll the week forward twice, passing the re-read hider counts (§4). Costs
   nothing, breaks nothing, and makes the two existing shares claimable
   immediately.
2. Confirm the claim path works by calling `claim_reward(1)` directly from the
   holder's account before writing any UI. If it pays `4,987,167` USDC units,
   the contract is proven and the remaining work is entirely frontend.
3. Build the frontend claim flow against the current contract, using the
   `hideTreasure` pattern. Accept that already-claimed state cannot be detected
   until the getter exists - surface `'Reward already claimed'` as a friendly
   message in the meantime.
4. Batch the contract fixes (§5) into the next redeploy, once the frontend work
   has surfaced whatever else it needs.

The reason for this order is that step 2 costs one transaction and definitively
separates "the contract is wrong" from "the UI is missing" - and everything
after it is frontend work that does not depend on a redeploy.
