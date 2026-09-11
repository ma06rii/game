# Frontend changes for the ROZ reward token

**This brief is self-contained.** It is written for someone — human or AI — with
the frontend repo open and no prior knowledge of the contract work. Read §1 and
§2 before writing code: the game's *economics* changed, not just its ABI, and a
purely mechanical port will ship a UI that misreports what players earn.

| | |
|---|---|
| **Frontend repo** | `/home/ii/development/personal/game_frontend-worktrees/bug-fixapp-game_frontend` |
| **Contract repo** | `/home/ii/development/personal/game-worktrees/bug-vrf-game` |
| **Contract source** | `src/lib.cairo` — 3,359 lines, 78 entrypoints |
| **Background** | `ROZ_REWARD_TOKEN_PLAN.md` (full rationale), `ROZ_IMPLEMENTATION_NOTES.md` (what was built) |
| **Contract status** | Implemented, 29 tests passing, **deployed to Sepolia** |

### Live addresses, verified on-chain

| | Address |
|---|---|
| Game contract | `0x007030fb8aec5eb20ed893bb2147fefe0dd07b204d55be12fedf9ce4579f7a4f` |
| ROZ reward token | `0x03a5c8760ed42b8d916f2a37e55335c38979e9ec91c963d0be351e2c285d445b` |
| USDC (game token) | `0x0512feAc6339Ff7889822cb5aA2a86C848e9D392bB0E3E237C008674feeD8343` |
| VRF provider (mock) | `0x01baad38bde8d3d60eebab5b96f72a297d52e6d1386bc3d4ec5344d9a30388bd` |

The game contract answers `get_reward_token_pending`, so it is running the new
code. `get_game_reward_token()` returns the ROZ address above, so the two are
wired to each other. **The frontend already points at the correct ROZ token; it
is the game contract address that is stale.**

---

## 1. What the contract now does

A treasure-hunt game on Starknet. Players pay fees in **USDC (6 decimals)** and
earn a reward token, **ROZ (18 decimals)**. Three things are new.

### 1.1 ROZ is accrued, not transferred

Gameplay credits an internal pending balance. The player withdraws it later with
a separate call.

This is deliberate. If every action transferred ROZ, the game would stop working
the moment the contract ran out — hiding, moving and spawning would all revert
because a *reward* was exhausted. Accruing means an unfunded contract still
plays perfectly and only the reward pauses.

**Consequence for the UI: a player can have earned ROZ that is not in their
wallet. Those are two different numbers and both must be shown.**

### 1.2 A daily spend gate sets the reward rate

A wallet that has spent **≥ $0.60 in fees today** earns full rates. Below it,
rates collapse:

| Reward | Below $0.60 today | $0.60 or more | New wallet (< $3 lifetime) |
|---|---|---|---|
| Per hop | 0.15 | **1.0** | 0.5 |
| Participation bonus | **none** | 18 | 9 |
| Instant hide | 4.5 | **30** | 15 |
| Hide survives the round | 7.5 | **50** | 25 |
| Find / steal | 110 | 110 | 110 |

Two rules that shape the UI:

- **Not retroactive.** Crossing $0.60 pays better *from that moment on*. Earlier
  actions keep the rate they were made at. There is no back-payment.
- **Lowest applicable value wins.** A new wallet below the threshold earns
  0.15/hop — not 0.5, and not the two multiplied together.

Only **irrecoverable** money counts toward the gate: hop fees, spawn fees, the
hide *fee*. **The $5 hide stake never counts** — it is refundable.

### 1.3 Hiding is priced, capped, and has diminishing returns

Hiding used to be free (a refundable $5 stake). Now:

| | Value |
|---|---|
| Fee, treasures 1–3 of the day | **$0.20** each, non-refundable |
| Fee, treasure 4 onward | **$0.25** each, non-refundable |
| Stake (refundable, unchanged) | $5.00 |
| Daily cap | **10 treasures** per wallet |

And rewards fall away with volume — the **Daily Volume Multiplier**, keyed to how
many treasures the wallet has already created *that day*:

| Already created today | 0–2 | 3–4 | 5–6 | 7–8 | 9–10 |
|---|---|---|---|---|---|
| Multiplier | **1.00×** | 0.70× | 0.40× | 0.20× | 0.08× |

Three hides at $0.20 is exactly $0.60. **Hiding three times is the cheapest route
across the gate, and it is designed that way** — cheap fee, full multiplier, and
it lands the wallet precisely on the threshold.

### 1.4 Other economics that moved

| | Was | Now |
|---|---|---|
| Hops | flat $0.10 | **20 USDC-free/day**, then $0.005 → $0.04 tiered by daily volume |
| Spawns | $1.00 | **1 free/day**, then $0.10 |
| Hop reward cap | 32/round | 40/round |
| Participation bonus | per round | **once per calendar day**, needs 28 hops **and** $0.60 |

---

## 2. The two traps — the highest-value UI work

Neither is visible on-chain. If the UI does not surface them, players will lose
rewards and not know why.

### 2.1 Hide order is worth 68 ROZ

A hide placed *before* the wallet crosses $0.60 is worth **12 ROZ**. The same
hide after is worth **80**. The rate is locked in at hide time and never
revisited — see §3.4.

For the modelled typical player that is a **68 ROZ swing on nothing but the order
they clicked in**.

> **UI requirement:** before a hide while below the gate, say plainly that hiding
> now is worth 12 and after $0.60 is worth 80, and offer the cheapest way across.

### 2.2 One hide is worse than none or two

For a light player:

| Their day | ROZ |
|---|---|
| No hide, stays under the gate | ~6 |
| **One hide** | **18** |
| Two hides + 42 hops, deliberately under the gate | ~30 |
| Two hides, crossing the gate | ~54 |

**One hide is the worst position available to them** — past the point of paying,
short of the point of benefiting. Nothing tells them.

---

## 3. Contract API

### 3.1 Changed signatures

```
constructor(vrfProvider, gameToken, rewardToken)     // was 2 args
withdraw_token_balance(tokenAddress, receiver)       // was (receiver)
```

The constructor change **forces a redeploy**, so the game contract address will
be new.

### 3.2 New entrypoints

| Call | Returns | Purpose |
|---|---|---|
| `get_reward_token_pending(addr)` | `u256` | ROZ accrued, not withdrawn |
| `claim_reward_tokens()` | — | Withdraw it. No-op at zero; cannot fail for lack of funds |
| `claim_reward_token_for_week(week)` | — | Retry a ROZ leg skipped while the contract was unfunded |
| `get_reward_token_claimed(addr, week)` | `bool` | **False = a retry is owed** |
| `get_reward_token_due(addr, week)` | `(hiderShares, finderShares, survivalRoz)` | Breakdown for a week |
| `get_total_reward_token_pending()` | `u256` | All IOUs. Compare to the contract's ROZ balance |
| `get_player_daily_state(addr)` | `(hops, roz, hides, spend, freeHopsUsed)` | Everything resetting at 00:00 UTC |
| `get_player_lifetime_spend(addr)` | `u256` | New-wallet status, against $3 |
| `get_free_hops_remaining(addr)` | `u256` | "N hops with no USDC fee left today" |
| `get_hide_settings()` | `(feeBase, feeHigh, tierBoundary, dailyCap, perRound)` | |
| `get_gate_thresholds()` | `(daily, lifetime)` | The $0.60 and $3 lines |
| `get_hop_limits()` | `(participationMin, roundCap, freeHops, freeSpawns)` | |
| `get_volume_band(i)` | `(limit, num, den)` | Bands 0–5 |
| `get_hop_price_band(i)` | `(limit, price)` | Bands 0–3 |
| `get_sweepable_balance(token)` | `u256` | Admin |
| `hide_treasure_bulk(bulkAmount, merkleProof, leafIndex)` | `bool` | Multi-hide |

**Read every threshold from the contract. Do not hardcode.** All are
owner-settable and will be retuned as the game is balanced.

### 3.3 `hide_treasure_bulk`

`bulkAmount` is the total **stake** and must be an exact multiple of the $5 hider
fee. Per-treasure fees are charged on top. Ordinary players pass an **empty
proof and index 0** — verification fails, which is the normal path, and the
10/day cap applies.

A bulk of N is arithmetically identical to N single hides. There is no advantage
to either shape.

### 3.4 Why the survival rate is snapshotted

`claim_reward` credits the survival ROZ **stored when the hide was placed**, not
a freshly resolved rate. A claim can land days later on a fresh day with that
day's spend back at zero; re-resolving would pay an honest player 7.5 instead of
50 for claiming on a Monday morning.

### 3.5 New events

`TreasureHiddenBulk`, `TreasureFound` (carries `hopsTaken`; feeds the off-chain
map-scaling controller), `RewardTokenAccrued`, `RewardTokenAccrualSkipped`,
`RewardTokenClaimed`.

---

## 4. Frontend as it stands

Vue 3 + Vite, `starknet.js` ^9.2.1, `@cartridge/controller` ^0.13.16.

| Path | Role |
|---|---|
| `src/components/Middle.vue` | **2,501 lines — the live game component** |
| `src/components/utils/controllerPolicies.js` | Session policies + all contract addresses |
| `src/contracts/game/sepolia_game_abi_1.json` | The live ABI |
| `src/stores/counter.js` | Pinia store — balances, game state, USD conversion |
| `src/components/Middle1/2/3/4.vue` | Variants — see §7 |
| `src/contracts2/` | Duplicate of `src/contracts/` — see §7 |

### 4.1 Exact call sites

**`src/components/Middle.vue`**

| Line | What is there | Action |
|---|---|---|
| `46` | `GAME_REWARD_CONTRACT_ADDRESS = "0x03a5c876…5d445b"` | **Already correct — leave it.** Verified on-chain: this is the live ROZ token, and the game contract's `get_game_reward_token()` returns the same address |
| `315` | `get_hider_player_fee()` → `setHiderGamerFee` | Keep — still the $5 stake |
| `318` | `get_game_token_reward()` → `setGameTokenReward` | **Remove.** Returns a superseded USD figure |
| `323` | `get_minimum_allowance_fee()` | Keep, but re-check the value covers fees (§5.2) |
| `415` | `approveGameContractToSpend(tokenUnitAmount)` | **Budget must now include hide fees** |
| `492` | `getGameRewardTokenBalance()` | Keep — but it is only the *wallet* half (§5.3) |
| `685` | `entrypoint: 'finder_player_generate_position'` | Works; 1 free/day then $0.10 |
| `758`, `813`, `874`, `932` | `entrypoint: 'finder_player_move_position'` | Works; 20 USDC-free/day then tiered |
| `960`, `994` | `hideTreasure()` / `entrypoint: 'hide_treasure'` | Works, but now costs a fee and is capped at 10/day |
| `1225–1241` | Reward-token contract + decimals setup | Repoint at ROZ (18 decimals) |
| `2362`, `2394` | `gamerRewardTokenDue` display | Feed from the contract, not the old formula |

**`src/stores/counter.js`**

| Line | What is there | Action |
|---|---|---|
| `451–465` | `rewardLegs(share)` | **Replace — see below** |
| `42–46` | `getPoolRewardTokenPrice` | Repoint at the ROZ pool, or drop USD conversion |
| `87` | `convertRewardTokenToUsd` | As above |
| `125`, `473`, `565` | `gamerRewardTokenDue` ref/setter/export | Keep the name, change the source |

**`rewardLegs()` is the old model and cannot be adapted.** It computes:

```js
rewardUsd      = gameTokenReward × share        // a USD figure from the contract
rewardTokenDue = rewardUsd × VITE_REWARD_TOKEN_MULTIPLIER
```

ROZ is now accrued **on-chain, per action**, at rates that depend on the player's
daily spend. It cannot be derived from a share count and an env multiplier. Read
`get_reward_token_pending()` instead and retire `VITE_REWARD_TOKEN_MULTIPLIER`.

---

## 5. Work required

### 5.1 Rewire — do this first

1. **New game contract address** — `controllerPolicies.js:18-19` **and**
   `Middle.vue:47`. Both hold `SEPOLIA_GAME_CONTRACT_ADDRESS` and must stay in
   step, or every call falls outside the session policy and the keychain prompts
   each time. Every superseded address sits commented out directly above the live
   one in both files — history, not live.
2. **Regenerate the ABI** into `src/contracts/game/sepolia_game_abi_1.json`.
   78 entrypoints, up from ~40. Do not hand-edit.
3. **Add the ROZ token address** — `Middle.vue:52` and a session-policy entry.
4. **Remove `get_game_token_reward()`** at `Middle.vue:318` and its store setter.
5. **`withdraw_token_balance` now takes the token first** — fix if exposed.

### 5.2 Approvals — fails silently if missed

`approveGameContractToSpend` (`Middle.vue:415`) sizes the budget from the $5
stake and `minimumAllowance`. **A hide now costs the stake plus a $0.20–$0.25
fee.** A budget sized for stakes alone leaves `transfer_from` reverting partway
through a hide, after the stake has already moved.

Recompute as `(stake + fee) × intendedHides`, taking fees from
`get_hide_settings()`. Re-check that `minimumAllowance` ($7.00) clears a
realistic session.

### 5.3 UI to build, in priority order

**1 — The gate meter.** Progress toward $0.60 today, from
`get_player_daily_state`. This one element decides whether a hop pays 1.0 or
0.15, and nothing else in the UI communicates it. *Highest value in this
document.*

**2 — Hide-order guidance.** §2.1. Warn before a below-gate hide; offer the
three-hide route across.

**3 — Two balances.** "Earned (pending)" from `get_reward_token_pending` and "In
wallet" from the token's `balance_of`. A claim button when pending > 0, calling
`claim_reward_tokens()`.

**4 — Daily allowances.** USDC-free hops remaining (of 20), hides used (of 10), free
spawn used. All reset 00:00 UTC.

"Free" waives the game fee only: gas is still paid in STRK. If a later
paymaster campaign sponsors fewer than 20 hops (for example 15), show the two
limits separately. The fully sponsored count is `min(20, campaignCap)`; hops
above the campaign cap but not above 20 still have no USDC fee.

**5 — Diminishing returns.** The multiplier for the *next* treasure. A player at
8 hides today should see their next is worth 0.20×.

**6 — Accrual-paused banner.** `RewardTokenAccrualSkipped` fires when the
contract cannot cover a reward: **the action succeeds and the ROZ silently does
not accrue.** Without a banner players will believe they are earning when they
are not. Detect proactively by comparing `get_total_reward_token_pending()`
against the contract's ROZ `balance_of`.

**7 — Unclaimed ROZ legs.** Where `get_reward_token_claimed(addr, week)` is
false, offer `claim_reward_token_for_week(week)`.

### 5.4 Session policies

Add to `controllerPolicies.js`: `hide_treasure_bulk`, `claim_reward_tokens`,
`claim_reward_token_for_week`. Without these the keychain prompts on every call.

---

## 6. Verification

1. Approve, hide three times → gate meter reads $0.60, and hop rewards visibly
   change afterwards.
2. Hop 20 times with no USDC fee → counter reaches zero; hop 21 charges $0.005.
3. Pending ROZ non-zero → claim → wallet balance rises, pending returns to zero.
4. Hide 8 times → next-treasure multiplier shows 0.20×; the 11th hide is refused.
5. Point at a contract holding no ROZ → gameplay still works, accrual-paused
   banner appears.
6. Every threshold shown in the UI came from a contract call, not a constant.

---

## 7. Flag rather than guess

- **Which of `Middle1/2/3/4.vue` are live.** Only `Middle.vue` was confirmed as
  the active component. Do not edit all five in parallel.
- **Whether `src/contracts2/` is dead.** It duplicates `src/contracts/`; the
  imports found all point at `src/contracts/`.
- **The existing reward-token plumbing** (`Middle.vue:52`, `:492`,
  `:1225–1241`) already points at the correct ROZ token, so the *address* work is
  done. What is superseded is how the **amount** is derived — `rewardLegs()` in
  the store, see §4.1. Keep the contract wiring, replace the maths.
- **The store's pool-price USD conversion** (`counter.js:42–46`, `:87`) uses a
  token pair that may predate ROZ. Confirm the pool exists for the live ROZ token
  before relying on the USD figures, or drop the conversion.
- **A non-deployed reward-token address bricks rewarded actions.** The contract
  handles the address being *unset* (zero) gracefully, but an address pointing at
  nothing makes `balance_of` revert and takes the whole hop or hide with it. Do
  not configure a placeholder.
