# Deploy the ROZ reward token to Sepolia and pay it for in-game actions

A proposal for review. Nothing here has been implemented. The defaults in §2 are
recommendations, not decisions.

---

## 1. Context

`src/game_reward_token.cairo` holds an OpenZeppelin ERC20 preset — `ROZToken`,
symbol **`ROZ`**, 18 decimals, fixed supply of 5,000,000,000 minted once at
construction. It is `Ownable` and `Upgradeable`, with `burn` but **no mint after
deployment**.

The goal is to deploy it to Sepolia and pay it to players for in-game actions,
on the schedule in §2.2.

### No USD valuation, by design

The game does **not** price ROZ. There is no oracle, no pool lookup, and no USD
figure anywhere in the reward path. An Ekubo pool will be created separately
later, once the game is live on mainnet, and the market decides what the token is
worth from there.

The contract's only job is to hand out the correct **token amount**. The frontend
shows that amount and nothing more.

This is a change from the current frontend, which prices the reward token through
a mainnet Ekubo pool — see §6 for what has to come out.

### The one thing blocking the token itself

**The file has never been compiled.** `lib.cairo` declares
`mod mock_vrf_provider;` but not `mod game_reward_token;`, so the build has never
seen it. It also imports the OpenZeppelin **v3** split packages
(`openzeppelin_access`, `openzeppelin_token`, …) while `Scarb.toml` pins the
**v2.0.0** umbrella. Every symbol it needs exists in v2.0.0 — only the paths
differ — so this is an import rewrite, not a dependency upgrade.

## 2. Defaults applied

| Decision | Default taken | Reasoning |
|---|---|---|
| Where the supply mints | Your account, then fund the game per tranche | The tranche *is* the emission cap |
| How rewards reach players | **Accrued to a pending balance, claimed separately** | Gameplay never breaks when ROZ runs low — see §4c |
| USD valuation | None, anywhere | Your instruction; market decides |
| Ticker | Deploy as `ROZ`, frontend adopts it | The player's wallet will say ROZ |

## 2.1 Play-to-earn allocation and emission schedule

**45% of supply — 2,250,000,000 ROZ — is earmarked for distribution by the game
contract.** The remaining 55% (2,750,000,000 ROZ) stays in the treasury and is
outside the scope of this document.

| Period | Share of pool | ROZ | Raw (18dp) |
|---|---|---|---|
| Year 1 | 38% | 855,000,000 | `855000000000000000000000000` |
| Year 2 | 28% | 630,000,000 | `630000000000000000000000000` |
| Year 3 | 18% | 405,000,000 | `405000000000000000000000000` |
| Year 4 | 10% | 225,000,000 | `225000000000000000000000000` |
| Year 5+ tail | 6% | 135,000,000 | `135000000000000000000000000` |
| **Total** | **100%** | **2,250,000,000** | `2250000000000000000000000000` |

Year 1 is weighted for launch incentives. The 6% tail releases slowly across
years 5 to 8 or longer, so the schedule does not simply stop at a cliff.

### The tranche is the enforcement mechanism

The game contract can only pay ROZ it holds, and the token has no mint function.
**Transferring one year's tranche at a time enforces the schedule with no
contract code at all** — the balance is the cap.

Funding all 2.25B up front would leave the schedule as documentation only, with
nothing stopping year one draining the whole pool.

ROZ sent to the game contract **is** recoverable — see §4j, where
`withdraw_token_balance` becomes able to sweep any token. It will only release
the surplus above what players are already owed.

## 2.2 Reward actions

**A round is 6 hours** — four per day, 1,460 per year. A round may also end early
once every eligible hidden treasure has been found (see §4k).

### Per-round rewards

| Action | ROZ | Conditions |
|---|---|---|
| Instant hide | **30** | Paid immediately on a successful hide |
| Hide survives a full active round | **50** | Credited at the end of the next round if unfound. Full hide cycle ≈ 80 |
| Find / steal a treasure | **110** + ~$5 USDC | Highest single reward |
| Per hop | **1** | Hard cap at **40 hops** per round; nothing beyond it. Falls to **0.15** below the §2.6 daily spend threshold, or 0.5 for a new wallet. Price rises with daily volume — §2.5 |

### Once per day, not per round

| Action | ROZ | Conditions |
|---|---|---|
| Participation bonus | **18** | Requires **28 hops**, and pays **once per calendar day**. Unavailable below the §2.6 daily spend threshold; 9 for a new wallet |

Participation used to pay per round. At four rounds a day that was the single
biggest contributor to farm yield, so it now pays once — see §2.5.

### Spawning pays nothing

**A spawn earns no ROZ, whether it is free or paid.** A spawn repositions the
rabbit and nothing more. Free and paid spawns are therefore identical in every
respect except the $0.10, which is the same rule free and paid hops follow.

This removes the daily spawn reward and its streak bonus. See §9 — that retention
layer no longer has a trigger, and whether it should move elsewhere is an open
decision rather than something this change settles.

### Allowances and limits at a glance

The four settings that govern free play and cap farming, in one place. Each is
owner-settable — see §4b for the storage table and §4l for the allowance logic.

| Setting | Storage name | Value | Scope | Purpose |
|---|---|---|---|---|
| Daily free hops | `dailyFreeHops` | **22** | Per calendar day, shared across all four rounds | Lets a player try the game at no cost |
| Participation minimum hops | `participationMinimumHops` | **28** | Per calendar day — the bonus pays once daily | Puts the 18-ROZ bonus out of reach of free hops alone |
| Per-round hop cap | `hopRewardCap` | **40** | Per **round** | Stops grinding within a single round |
| Daily free spawns | `dailyFreeSpawns` | **1** | Per calendar day | One free repositioning a day |
| Soft warning threshold | *(none — UI only)* | ~36 hops | Per round | Warns a player they are near the cap. No contract effect |

**Two orderings carry the design, and neither may be broken:**

1. **`dailyFreeHops` (22) < `participationMinimumHops` (28).** The bonus can never
   be reached on free hops alone — see §4l-i-a.
2. **`participationMinimumHops` (28) ≤ `hopRewardCap` (40).** The bonus needs 28
   of a possible 40 — **70% of a round**, so participation is demanding without
   requiring a near-perfect round.

The gap is 6 hops, which cost **$0.045** at the §2.5 tier prices. That gap alone
is no longer the real guard on participation: **the $0.60 daily spend threshold in
§2.6 is**, because the bonus is unavailable below it however many hops are made.
The ordering is now defence in depth rather than the whole defence.

### The intended hierarchy

1. **Find / steal** — clearly the best single action
2. **Successful hide** (instant + survival) — strong and satisfying
3. **Participation** — meaningful but secondary. It needs 28 of a possible 40
   hops, and a wallet that has cleared the §2.6 daily spend threshold
4. **Per hop** — the light drip that rewards exploration itself

There is no longer a retention layer. It sat at position 4 and was triggered by
the daily spawn, which now pays nothing.

**The `+ $5 USDC` on find/steal already works and needs no new code.** A finder
takes the hider's stake through `validate_treasure_coordinates`, and claiming it
pays `5,000,000 − 12,833 = 4,987,167` USDC units. Only the 110 ROZ is new.

### Design targets and what year 1 can sustain

**These bands were revised downward once the §2.6 gate was in place.** The
original bands (80–160, 180–320, 350–550) were written before the gate existed
and no profile could reach them afterwards. The choice was between weakening the
anti-farm parameters and correcting the expectations; **the expectations were
corrected**, and no rate, threshold or limit moved. See §9.

| Player type | Expected ROZ/day | |
|---|---|---|
| Light casual — **below the gate** | 25 – 70 | 1–2 rounds, light hopping |
| Typical casual — **above the gate** | 140 – 280 | 2–3 rounds, one hide, some searching |
| Active | 300 – 500 | Most rounds, consistent hiding and finding |

The Year 1 tranche of 855,000,000 gives a budget of **2,342,466 ROZ per day**:

| Player mix | Daily actives sustained |
|---|---|
| Light casual (25–70) | 33,500 – 93,700 |
| Typical casual (140–280) | 8,400 – 16,700 |
| Active (300–500) | 4,700 – 7,800 |

**Year 1 therefore supports roughly 4,700 to 16,700 daily actives** on a
realistic mix, up from 4,000 to 13,000 under the old bands. That extra headroom
comes entirely from lowering the expectation — **no rate changed**, so the same
tranche now covers about a quarter more players. That is the ceiling the rates
imply. If the game is expected to exceed it, the rates or the tranche need
revisiting **before** launch — running dry mid-year stops all new rewards until
the next tranche is released.

### Two of the three profiles now meet their target

What the rates actually pay under the §2.6 gate, and what a day costs. Spend is
hop fees at the §2.5 tier prices plus spawns beyond the first free one.

**These figures respect the non-retroactivity rule** (§2.6): a player earns
`hopRewardBelowThreshold` on every hop taken *before* their spend crosses $0.60,
and the full rate only from the crossing hop onward. Earlier drafts of this table
credited every hop at the full rate, which contradicted the rule and overstated
all three profiles.

Two modelling conventions, both stated because they change the answer:

- **Spend accrues in the order actions are taken**, and within each round the
  spawn is taken before that round's hops. This is the player-favourable
  ordering — see the ordering note below.
- **The participation bonus fires at the first action where *both* conditions
  hold**, 28 hops and $0.60. See §4f.

| Player | Round pattern | Hops | Daily spend | Crosses at | **Established** | **New wallet** | Target |
|---|---|---|---|---|---|---|---|
| Light casual | 2 rounds × 20 hops | 40 | $0.265 | **never** | **6** | **6** | 25 – 70 |
| Typical casual | 2.5 rounds × 25 hops | 62 | $0.755 | hop **55** | **114.1** | **101.1** | 140 – 280 |
| Active | 4 rounds × 32 hops | 128 | $3.435 | hop **60** | **285.9** | **242.4** | 300 – 500 |

Established figures include one hide cycle for the casual and active players and
one find for the active player. Days to leave new-wallet status at a $3 lifetime
threshold: active **1**, typical casual **4**, light casual **12**.

Worked, for the typical casual: 54 hops before the crossing at 0.15 (**8.1**),
8 hops after it at 1.0 (**8**), participation (**18**), hide cycle (**80**).

**No profile now reaches its band.** The bands were set against the older figures
that assumed a retroactive crossing; correcting that assumption moved every
profile down, and lowering `hopRewardBelowThreshold` to 0.15 moved them a little
further. The two effects are worth separating:

| Player | As previously stated | Non-retroactive at 0.3 | **Non-retroactive at 0.15** |
|---|---|---|---|
| Light casual | 12 | 12 | **6** |
| Typical casual | 160 | 122.2 | **114.1** |
| Active | 336 | 294.7 | **285.9** |

**Most of the drop is the correction, not the rate change.** Non-retroactivity
costs the typical casual 37.8 ROZ and the active player 41.3; the halved rate
costs a further 8.1 and 8.8. Either the bands come down again or a rate has to
rise — see §9.

**`hopRewardBelowThreshold` is not a farmer-only parameter.** Because every day
starts at zero spend, *every* player earns this rate on their opening stretch —
the first 54 hops for a typical casual, 59 for an active player. §4l-i-a treats it
as the lever that sets zero-cost sybil yield, which it is, but it also sets the
opening of every honest day. Tune it with both in view.

**Earnings now depend on the order actions are taken.** A player who spawns at
the start of a round crosses $0.60 sooner, and so earns more, than an identical
player who spawns at the end. Nothing in the contract is wrong here — it follows
directly from non-retroactivity — but it is invisible to the player and worth a
decision. See §9.

Three further causes sit behind the light casual's 6, all deliberate individually:

- **The §2.6 daily spend threshold**, which the light casual never clears. Their
  hop rate falls to 0.15 and participation is withdrawn entirely. An ungated day
  would pay them 58 (40 hops + 18); they get 6, and the threshold accounts for
  the whole 52-ROZ difference.
- **The daily spawn reward is gone**, removing a floor that did not depend on
  effort.
- **Participation now pays once a day, not four times**, which costs the active
  player 54 ROZ on its own.

### The below-gate band cannot be reached by hopping

The light casual band is explicitly a *below the gate* band, so it is worth
checking that it is reachable there. On hops alone it is not:

| | |
|---|---|
| Most a wallet can spend and stay under $0.60 | **$0.595 — 64 hops** |
| ROZ from those hops at the below-threshold rate | 64 × 0.15 = **9.6** |
| Participation | **None** — withdrawn below the threshold |

**9.6 ROZ is the hard ceiling on a below-gate day of hopping**, and the band
starts at 25. Hop 65 costs $0.615 and crosses the gate, at which point the
player is no longer a below-gate player at all.

The band is therefore reachable only through the reward lines that **pay in full
below the threshold** — instant hide 30, full hide cycle 80, find/steal 110. The
modelled light casual plus **one instant hide is 36 ROZ**, inside 25–70; a
surviving hide cycle takes them to 86, above it.

This is what the band now means: **a light casual is expected to hide, not merely
to hop.** That is a coherent design — hiding is the action the gate deliberately
leaves untouched — but it has an edge worth recording. §4l-ii shows that hiding is
untouched because *no anti-farm measure in the plan reaches it*, which makes it
the cheapest farming route in the game in quiet rounds ($0.00016/ROZ). **The only
way into the below-gate band and the plan's largest residual farm exposure are the
same mechanic**, so anything done to bound one will land on the other. See §9.

Two structural points worth stating rather than leaving to be discovered:

**The two gates overlap at the bottom and leave a gap in the middle.** A light
casual is already at the floor from the daily threshold, so new-wallet status
costs them nothing further. New-wallet status therefore only bites players who
*do* spend — the opposite of what its name suggests.

**Raising `hopRewardCap` to 40 still does not help an honest active player**, but
the reason has changed. Non-retroactivity puts their hops-plus-participation at
**95.85**, just under a `dailySoftCapRoz` of 100 — so the soft cap no longer
clips them, and the round cap does not bind either. The 40-hop cap buys them
nothing because they never get near the ceiling it raises. See §2.5.

Meanwhile the active player's hop fees are $3.135 against $1.38 before §2.5:
earning less and paying more. The anti-farm measures work, but they are not free —
they land on honest players too.

**That trade was decided once, and the correction reopens part of it.** The
targets were revised to fit what the gate pays, on the principle that an
expectation is far cheaper to change than a live anti-farm parameter. That
principle still holds. What has changed is the arithmetic under it: with the
non-retroactivity correction applied, the revised bands are themselves too high,
and all three profiles fall short. The choice between lowering the bands again
and raising a rate is open in §9.

## 2.3 Daily free allowances (anti-frustration)

### The revised price list

| Action | Price | Contract value (USDC, 6dp) | Notes |
|---|---|---|---|
| Hide treasure | **Free** | `currentHiderFee` unchanged at `5000000` | Only the $5 stake is locked |
| Single hop | **$0.005 – $0.04** | tiered — see §2.5 | 22 free per day; the price rises with daily volume |
| Spawn new position | **$0.10** | `currentSpawnNewPositionFee` `1000000` → **`100000`** | 1 free per day |

**The hop price is no longer flat.** `currentFinderFee` is replaced by the tier
schedule in §2.5. The comparisons in this section use the $0.01 tier, which is
what a player pays for hops 26 to 45 — the band most ordinary play sits in.

Hop and spawn fees fall roughly **10×** against the old $0.10 and $1.00. Hiding
needs **no contract change** — it already works this way. The $5 is transferred in and returned on a successful claim, so
it was never a fee; the change is one of framing, and the UI should say "stake",
not "fee".

One caveat on "free": the stake is **at risk, not escrowed**. A finder who steals
the treasure takes it. And a surviving hider gets back `4,987,167` rather than the
full `5,000,000`, because the contract retains 12,833 units on every claim — so
hiding costs about **$0.0128** in practice. See §9.

### The problem, quantified

A 6-hour round means a player spawns up to four times a day. At the old prices,
with no allowance:

| Player | Actions/day | Old cost | New cost, before allowance |
|---|---|---|---|
| Light casual | 30 hops + 2 spawns | $5.00 | **$0.50** |
| Typical casual | 60 hops + 3 spawns | $9.00 | **$0.90** |
| Active | 128 hops + 4 spawns | $16.80 | **$1.68** |

The 10× cut does most of the anti-frustration work on its own. A player no longer
has to part with meaningful money before deciding whether they enjoy the game.

### The allowance

**22 free hops and 1 free spawn per day, shared across every round in that day** —
a single daily bucket, not a per-round one.

| Player | Gross | After allowance | Saved |
|---|---|---|---|
| Light casual (30 hops, 2 spawns) | $0.50 | **$0.18** | $0.32 |
| Typical casual (60 hops, 3 spawns) | $0.90 | **$0.58** | $0.32 |
| Active (128 hops, 4 spawns) | $1.68 | **$1.36** | $0.32 |

The saving is a flat **$0.32** for everyone, because the allowance is fixed —
worth 64% to a light casual and 19% to an active player.

### The allowance deliberately falls short of a full round

22 free hops against a 40-hop cap is **55% of a round**, not all of it. That is
the point: the participation minimum is 28 hops, so **the bonus can never be
reached on free hops alone**. A player has to make 6 paid hops to earn it — about
**$0.045** at the §2.5 tier prices.

That relationship — allowance below minimum — used to be the whole guard on
zero-cost farming. It no longer is: the §2.6 daily spend threshold withdraws
participation entirely below $0.60/day, so the 6-hop gap is now the weaker of the
two locks. Zero-cost yield is capped at **3.3 ROZ/day** — see §4l-i-a.

The free tier costs **$0.32 per day** per player who uses it in full, down from
$4.00 at the old prices.

Players may spread the 22 hops across several rounds, but pay $0.10 for each
spawn beyond the first.

**The allowance does far less work than the price cut.** Dropping hops to $0.01
saves an active player $15.12/day; the allowance saves $0.30 on top. Worth
weighing against the complexity in §4l — most of the anti-frustration win is
already banked by the new prices.

### Two interactions worth noting

**Participation costs more than the allowance covers — deliberately.** The bonus
needs 28 hops in the day, against a 22-hop allowance, so 6 hops must be paid for.
Since the bonus now pays once per calendar day rather than once per round, that is
6 paid hops in total — roughly **$0.045**, not the $1.00/day that a per-round
bonus used to demand.

That gap is not an oversight, but it is no longer the binding constraint. The
§2.6 daily spend threshold requires **$0.60** before participation pays at all,
which is more than thirteen times the cost of the 6-hop gap. Closing the gap would
not by itself reopen the hole — removing the spend threshold would.

**Free actions do not endanger anyone's payout.** Hop and spawn fees are pure
house revenue; the USDC claim pool is funded entirely by hide fees, which are
self-funding (each share was created by a hide that paid for it, and the contract
retains 12,833 units on every claim). Waiving hop and spawn fees reduces revenue
only. It cannot starve the treasure-value payouts.

## 2.4 Dynamic map scaling and density control

Because a hide made during one round only becomes active in the **next** one, the
number of active treasures is known before that round starts. The grid is then
sized to fit them, targeting a median of **35–45 hops per successful find**.

```
Target grid cells  ≈  T × 40 × K
```

- `T` — hides from the previous round, which become this round's active treasures
- `40` — target hops per find
- `K` — search inefficiency factor, initial band **1.8 – 2.5**

The grid side therefore grows as **√T**:

| T (active treasures) | K = 1.8 | K = 2.0 | K = 2.5 |
|---|---|---|---|
| 10 | 27×27 | 29×29 | 32×32 |
| 100 | 85×85 | 90×90 | 100×100 |
| 196 | 119×119 | 126×126 | 140×140 |
| 500 | 190×190 | 200×200 | 224×224 |
| 1000 | 269×269 | 283×283 | 317×317 |

### Adjusting K

| Recent median hops per find | Action |
|---|---|
| Below 32 | Increase K — the map is too dense |
| 32 – 48 | Hold |
| Above 48 | Decrease K — the map is too sparse |

Changes are capped at approximately **±0.15 per round**, so the system drifts
toward calibration rather than oscillating.

### Non-negotiables

- A minimum distance is enforced between active treasures.
- Hard safety bounds on minimum and maximum grid size, and on treasures per 1,000
  cells.
- Coordinates stay hidden from every player until found.
- The number of searching players is never artificially restricted.
- Every decision is logged for ongoing calibration.

### This is off-chain, and needs almost no contract work

K is adjusted from medians over recent rounds — history the contract does not
keep and should not compute. It belongs in the keeper that §4k already
establishes is necessary for rollover.

**`start_new_game` already accepts `gameGridSizeX` and `gameGridSizeY` per
round.** Dynamic scaling is a policy feeding an existing parameter, not a new
contract capability. The only contract additions it forces are the
`maxTreasuresPerRound` bound (§4m-i) and the `TreasureFound` event (§4i) that
gives K its feedback signal.

### Tensions worth resolving before launch

**~~The hop reward cap contradicts the hop target.~~ Resolved.** The model aims
for 35–45 hops per find, and `hopRewardCap` was 32 — a player earned nothing on
exactly the hops where a find became likely. **The cap is now 40**, inside the
target band, so the two no longer disagree.

One consequence to carry forward: 40 hops per round over four rounds lifts the
daily hops-plus-participation ceiling to **178 ROZ** — though under §2.6's
non-retroactivity rule that ceiling is only reachable by a wallet that has
*already* cleared $0.60, so in practice it costs extra to reach. Either way it
changes what `dailySoftCapRoz` can and cannot do. See §2.5.

**A search cannot span rounds.** `player_position` is keyed by round, so every 6
hours a player is wiped and must re-spawn at a random cell. A 40-hop search has
to complete inside a single round; progress is never banked. The model implicitly
assumes a search has room to run, so this is worth stating.

## 2.5 Progressive hop pricing and the daily soft cap

Five measures, aimed at making farming uneconomic without punishing ordinary
play. They work against a single large wallet. They do **not** close the
multi-wallet route — see the honest accounting at the end of this section.

### Progressive hop pricing

A hop costs more the more a wallet has hopped **that day**:

| Daily hop number | Price |
|---|---|
| 1 – 22 | **Free** (the §2.3 allowance) |
| 23 – 25 | $0.005 |
| 26 – 45 | $0.010 |
| 46 – 65 | $0.020 |
| 66 and beyond | $0.040 |

**The tiers must reset daily, never per round.** With per-round tiers a farmer
re-enters the cheap tiers four times a day: 32 hops in each of four rounds costs
**$0.34** instead of $3.135 — roughly **nine times cheaper**, which guts the
measure entirely.

### The crossover sits at 47 hops a day

Below it the new schedule is cheaper than the old flat $0.01; above it, dearer:

| Hops/day | Progressive | Old flat | |
|---|---|---|---|
| 30 | $0.065 | $0.08 | cheaper |
| 45 | $0.215 | $0.23 | cheaper |
| 46 | $0.235 | $0.24 | cheaper |
| **47** | **$0.255** | **$0.25** | dearer |
| 60 | $0.515 | $0.38 | dearer |
| 128 | $3.135 | $1.06 | dearer |

That is the shape intended: light play gets cheaper, grinding gets dearer. Note
the typical casual at 60 hops/day now pays **36% more**, while earning near the
bottom of their revised band (§2.2).

### Participation once per calendar day

The 18-ROZ bonus is claimable **once per day**, not once per round. With four
rounds a day this alone cuts the maximum daily hop-and-participation yield from
232 ROZ to **178**.

### The daily soft cap

Beyond `dailySoftCapRoz`, further hop and participation rewards are multiplied
down — 0.2× or zero. Casuals never reach it; grinders do.

**Set it near 100.** With `hopRewardCap` at 40 per round the theoretical maximum
from hops plus participation is `160 + 18 = 178 ROZ`, but non-retroactivity puts
that out of ordinary reach: a wallet that hops its way to the threshold spends
its first 49–64 hops at 0.15, so a 160-hop day yields **136.35** on the natural
route. The full 178 is only reached by a wallet that clears $0.60 *before* it
starts hopping — six paid spawns will do it for $0.60 — which is farm behaviour,
not play. See §2.6.

So a cap of 150 or 160 binds only on that bought-crossing route. A value near 100
does real work across the grinding band, and it is the value the rest of this
plan assumes.

**The soft cap and the round cap pull against each other at the top, and neither
reaches the honest player.** Raising `hopRewardCap` from 32 to 40 was meant to
stop an honest player earning nothing on the hops where a find becomes likely
(§2.4). Under the corrected figures an active player's hops plus participation
comes to **95.85** — below a soft cap of 100 and nowhere near the round cap. The
round cap's benefit is therefore confined to the top of the range, where the soft
cap immediately takes it back. Recorded in §9.

### Free hops stay below the farm point

Measure 4 is satisfied: `dailyFreeHops` (22) sits below
`participationMinimumHops` (28), so the bonus can never be had for nothing. It is
no longer the primary guard, though — §2.6's daily spend threshold withdraws
participation below $0.60/day whatever the hop count. Keep the ordering as defence
in depth; see §4l-i-a.

---

### What these measures actually achieve

**Against one large wallet, they work well:**

| | Before | After |
|---|---|---|
| Cost of a maximum day (160 hops, 4 spawns) | $1.68 | **$4.715** |
| Yield | 232 ROZ | **136.35 ROZ** |
| Break-even | $0.0072/ROZ | **$0.0346/ROZ** |

**4.8× more expensive.** A whale is meaningfully deterred. The yield is 136.35
rather than the theoretical 178 because non-retroactivity charges the first 49
hops of the day at 0.15 — see §2.6.

**Against many small wallets, they make matters slightly worse.** A wallet doing
just 28 hops — enough for participation, using the free spawn — never leaves the
two cheapest tiers, where hops cost **well under** the old flat rate:

| | Before | After |
|---|---|---|
| Cost per wallet | $0.06 | **$0.045** |
| Yield | 46 ROZ | 46 ROZ |
| Break-even | $0.00130 | **$0.00098** |
| Cost to drain Year 1 (~50,923 wallets) | $3,055/day | **$2,292/day** |

Progressive pricing punishes **concentration** and rewards **distribution**, and
wallets cost nothing to create. So the farmer's answer is simply more wallets,
each staying in the cheap tiers.

**What actually constrains the distributed attack is gas.** Twenty-eight hops plus
a spawn is 29 transactions per wallet per day, against $0.045 of game fees. At any
plausible Starknet price the gas bill is many times the fees — so gas, not the
fee schedule, is doing the anti-farm work. That is worth **measuring** rather
than assuming, since it also sets the floor on what honest play costs.

Closing the distribution route needs a different kind of lever — a per-wallet
minimum spend, gating rewards on a funded balance, or proof of humanity. **That
is what §2.6 adds**, and it takes the cost of draining Year 1 from $2,292/day to
$50,371/day.

---

## 2.6 The Lightweight Gate

Four measures aimed at the one thing §2.5 could not reach: many small wallets.
The principle is that **full rewards are earned by players who actually spend**,
while free play stays open to everyone.

### The four measures

1. **A daily spend threshold.** Full hop and participation rewards require a
   wallet to have spent **≥ $0.60** in game fees that day. Below it, rewards are
   reduced.
2. **Free hops and the free spawn stay available to everyone.** Onboarding is
   unchanged — anyone can play immediately, they simply earn at a reduced rate
   until they spend.
3. **New wallets earn reduced rates** until they reach a **lifetime** spend of
   **$3**.
4. **Optional proof-of-humanity boost** — a higher cap or a small bonus for a
   wallet with linked social.

### The rates

Rates are stated as **absolute values**, not as multipliers of the base rate.
That is deliberate — see rule 2 below.

**Measure 1 — below $0.60 spent today:**

| Reward | Below $0.60 | $0.60 or more |
|---|---|---|
| Per-hop ROZ | **0.15** | **1.0** |
| Participation bonus | **Not available** | **18** |
| Instant hide | Full | Full |
| Hide survives | Full | Full |
| Find / steal | Full | Full |

**Measure 3 — a wallet is *new* until $3 of lifetime spend:**

| Reward | New wallet |
|---|---|
| Per-hop ROZ | **0.5** |
| Participation bonus | **9** (half of 18) |
| Soft daily cap on hops + participation | **80 ROZ** |
| Instant hide | Full |
| Hide survives | Full |
| Find / steal | Full |

New-wallet status is left permanently once $3 of lifetime spend is reached. Both
thresholds count **spend**, which §2.6 rule 1 below defines narrowly.

**Rates apply from the moment the threshold is crossed, not retroactively.** A
player who reaches $0.60 on their 65th hop earns 0.15 on hops 1–64 and 1.0 from
hop 65 onward. Recomputing the day would mean either replaying every hop or
storing enough to true up at day end — real complexity for a modest gain, and it
would let a farmer bank cheap hops and upgrade them later. Stated here because it
is the kind of thing an implementer will otherwise decide by accident. See §9 if
the player-facing effect proves confusing.

**This rule carries most of the gate's strength, and it is easy to model wrong.**
Because every calendar day starts at zero spend, *every* wallet — farm or honest —
earns the reduced rate on its opening stretch of hops. A wallet does not get 65
hops at 1.0 for $0.615; it gets 64 at 0.15 and one at 1.0. Every yield figure in
this plan is computed that way. Two consequences follow directly, and both are
stated where they arise: the cheapest farm route is far dearer than a naive
reading suggests (below), and honest players earn less than the older figures
implied (§2.2).

**Two supporting rules the crossing needs.** First, **the participation bonus
fires at the first action where both of its conditions hold** — 28 hops today and
$0.60 spent today — not at the 28th hop regardless. Under the stricter reading a
typical casual passes hop 28 at $0.145 of spend, the bonus is unavailable at that
instant, and because it pays once a day it would never fire at all. Second,
**spend accrues in the order actions are taken**, so a player who spawns early
crosses sooner and earns more than one who spawns late. Both are recorded in §9.

### Measure 1 does the work §2.5 could not

$0.60/day is first reached at **65 hops** ($0.615). No farmer buys a spawn to
clear it: spawns cost $0.10 and earn nothing, while hops in the same price band
cost $0.02 and earn ROZ.

The yield at that point is **28.6 ROZ**, not 65 + 18. Non-retroactivity means the
first 64 hops pay 0.15 and only hop 65 pays 1.0:

`64 × 0.15 + 1.0 + 18 = 9.6 + 1 + 18 = 28.6`

| | Ungated (§2.5) | With the gate |
|---|---|---|
| Cost per farm wallet | $0.045 | **$0.615** |
| Yield | 46 ROZ | **28.6 ROZ** |
| Break-even | $0.00098/ROZ | **$0.0215/ROZ** |
| Wallets to drain Year 1 | 50,923 | **81,904** |
| Cost to drain Year 1 | $2,292/day | **$50,371/day** |
| Market cap at 5B supply | $4.9M | **$107M** |

**22× more expensive**, and it lands precisely where progressive pricing failed.
The gate does not merely raise the farmer's bill — it also cuts what the wallet
earns, and the second effect is the larger of the two.

**Hopping past 65 does not help the farmer.** Each further hop costs $0.04 and
yields 1 ROZ, which is worse than the $0.0215 average, so the cheapest wallet
stops at 65. A farmer who wants the full 178-ROZ ceiling must clear $0.60 before
hopping at all — six paid spawns for $0.60 — which costs $5.015 for 178 ROZ,
$0.0282/ROZ. Still dearer than stopping at 65.

### Measure 3 attacks churn, but $3 is a modest barrier

A lifetime threshold attacks wallet *churn* rather than wallet *activity*, which
is the farmer's actual cost centre:

| Lifetime threshold | Cost to onboard 81,904 farm wallets |
|---|---|
| $1 | $81,904 |
| $2 | $163,808 |
| **$3 (chosen)** | **$245,712** |
| $5 | $409,520 |
| $10 | $819,040 |

At $3 the one-off barrier is **$245,712**, which is **4.9 days** of the gated
running cost. At $5 it would be $409,520, or 8.1 days. The threshold is a direct
lever on how much churn costs, and $3 buys roughly half of what $5 would — worth
setting deliberately rather than by default. Recorded in §9.

The absolute figures rose sharply with the corrected wallet count, but the ratio
did not: the barrier is still about five days of running cost, because both
numbers scale with the same wallet count.

### Resolved — the zero-cost wallet is now the least productive it has been

This section previously recorded a regression: the free allowance rose 20 → 22
and the below-threshold rate was 0.3 against the 0.2 a 0.2× multiplier had given,
so a wallet paying nothing but gas earned **more** than before. Lowering
`hopRewardBelowThreshold` to **0.15** reverses it outright:

| | Pre-gate settings | Previous | **Current** |
|---|---|---|---|
| Zero-cost daily yield | 20 × 0.2 = **4 ROZ** | 22 × 0.3 = 6.6 | **22 × 0.15 = 3.3** |
| Wallets to drain Year 1 on gas alone | 585,617 | 354,919 | **709,838** |

The allowance is still 22, so the rate did all the work. **709,838 wallets is 21%
more than the pre-gate settings ever required**, so this route is not merely back
to where it was — it is the tightest it has been. Measure 1 governs wallets that
spend and this governs wallets that never do; both now point the same way.

### The honest cost: every profile now falls short

| Player | Hops | Daily spend | Crosses at | Established | New wallet | Target |
|---|---|---|---|---|---|---|
| Light casual | 40 | $0.265 | **never** | **6** | **6** | 25 – 70 |
| Typical casual | 62 | $0.755 | hop 55 | 114.1 | 101.1 | 140 – 280 |
| Active | 128 | $3.435 | hop 60 | 285.9 | 242.4 | 300 – 500 |

**A light casual and a small farmer are indistinguishable by spend.** The gate
cannot separate them, so it hits both — 6 against a floor of 25, and raising the
threshold from $0.50 to $0.60 moved them further from clearing it, not closer.

**The other two profiles are no longer safe either.** The revised bands (§2.2)
were set when the model still assumed a retroactive crossing. Correcting that
puts the typical casual 25.9 short of their floor and the active player 14.1
short. Non-retroactivity is the larger cause; the halved rate adds 8.1 and 8.8
respectively. This is the trade the gate asks for, now measured properly.

**Hopping cannot close the light casual's gap, structurally.** The most a wallet
can spend while staying under $0.60 is $0.595 — 64 hops — which pays
64 × 0.15 = **9.6 ROZ** with no participation. That is the ceiling for any
below-gate day of hopping, and it sits well below the 25 floor. The band is only
reachable through the actions that pay full below the threshold: one instant hide
takes this player from 6 to **36 ROZ**. See §2.2 — and note that the hide loop is
also the cheapest farming route in the game (§4l-ii), so this route into the band
is the least protected one.

**The two measures overlap at the bottom and diverge in the middle.** A light
casual is already at the floor from measure 1, so new-wallet status costs them
nothing extra. Measure 3 therefore only reduces players who *do* spend — which is
the opposite of the intuition its name suggests, and worth confirming as intended.

This is the trade the gate asks for, and it should be made deliberately rather
than discovered after launch. See §9.

---

### Two rules that decide whether the gate works at all

**1. The hide stake must not count as spend.**

The $5 hide fee is refundable — a surviving hider claims back `4,987,167` of
`5,000,000`, so its true cost is **$0.0128**.

If the stake counted toward either threshold, a single hide would clear the whole
$3 lifetime gate for $0.0128 instead of $3 — **234× cheaper** — and it would clear
the $0.60 daily gate every day for the same, five times over. Both measures become
free to bypass.

**Only irrecoverable fees may count:** hop fees, spawn fees, and the 12,833 units
the contract retains on each claim.

This is unchanged from the previous parameters and is the single most important
rule in the section. The lower the thresholds go, the cheaper the bypass looks in
absolute terms, but the ratio stays large at any threshold worth setting.

**2. Reductions resolve to the lowest value. They never compound.**

Both statuses can hold at once — a new wallet that has not yet spent $0.60 today —
and their rates disagree: 0.15 against 0.5 per hop, and *not available* against 9
for participation.

> **Resolve each reward line independently to the lowest applicable value.**

| Situation | Per hop | Participation |
|---|---|---|
| Established, cleared $0.60 today | 1.0 | 18 |
| Established, below $0.60 today | 0.15 | none |
| New wallet, cleared $0.60 today | 0.5 | 9 |
| **New wallet, below $0.60 today** | **0.15** | **none** |

Stating rates as absolute values rather than multipliers removes the compounding
hazard by construction. Under the previous multiplier scheme the three reductions
multiplied to `0.2 × 0.2 × 0.5 = 0.02×`, leaving a new light player with **2%** of
rewards on their first day. There is now only one multiplier left in the system —
the soft cap. **Apply it once, after resolution, and never as a product with
anything else.**

Note one arithmetic coincidence, because it will mislead anyone checking the
numbers by eye: the correct bottom-row answer, **0.15**, is also what the old
multiplier scheme produced from `0.5 × 0.3`. A multiplicative implementation of
the *current* rates would give `0.5 × 0.15 = 0.075` instead. Assert the credited
value directly rather than reasoning from the shape of the number — see test 5g.

The new-wallet soft cap of 80 ROZ is close to inert: a new wallet needs about 142
hops in a day before it binds, well beyond any of the player profiles above.

### Measure 4 introduces a trusted party

A `player_verified` flag needs somebody to sign attestations. That is a new
privileged writer and a centralisation point, and it becomes a target the moment
ROZ has value. The flag is only as trustworthy as whoever controls it — worth
weighing against the modest benefit of a bonus tier.

---

## 3. Step 1 — Make the token compile

Rewrite the four imports in `src/game_reward_token.cairo`:

| Current (OZ v3) | OZ v2.0.0 |
|---|---|
| `openzeppelin_access::ownable::OwnableComponent` | `openzeppelin::access::ownable::OwnableComponent` |
| `openzeppelin_token::erc20::{DefaultConfig, ERC20Component, ERC20HooksEmptyImpl}` | `openzeppelin::token::erc20::{…}` |
| `openzeppelin_upgrades::UpgradeableComponent` | `openzeppelin::upgrades::UpgradeableComponent` |
| `openzeppelin_interfaces::upgrades::IUpgradeable` | `openzeppelin::upgrades::interface::IUpgradeable` |

All verified present in the resolved v2.0.0 source, including `ERC20MixinImpl`,
`OwnableMixinImpl`, the internal `mint`/`burn`, and `DefaultConfig` (the source of
the 18 decimals).

Then add `mod game_reward_token;` to `src/lib.cairo` beside
`mod mock_vrf_provider;`. Nothing else in the file changes — the body is a
standard OZ preset.

## 4. Step 2 — Game contract pays ROZ (`src/lib.cairo`)

This is the bulk of the work, and it is **substantially more than the previous
"one rate at claim" design**. Six reward triggers across four entrypoints, and
two of them need per-player state the contract does not currently keep.

### 4a. Configurable reward-token address

New storage `game_reward_token_contract_address`, a third constructor argument,
and owner-gated `update_game_reward_token` / `get_game_reward_token` — following
the `update_vrf_provider` and `update_game_token` convention already in place.

### 4b. Configurable rates, replacing `currentGameTokenReward`

`currentGameTokenReward` holds `11666667`, a 6-decimal USD figure that only the
frontend interprets. It is replaced by six raw 18-decimal ROZ rates plus two
threshold values, each with an owner-gated setter and getter:

| Storage | Year 1 value | Raw (18dp) |
|---|---|---|
| `rewardHide` | 30 | `30000000000000000000` |
| `rewardHideSurvived` | 50 | `50000000000000000000` |
| `rewardFind` | 110 | `110000000000000000000` |
| `rewardParticipation` | 18 | `18000000000000000000` |
| `rewardPerHop` | 1 | `1000000000000000000` |

| Threshold | Value | Type |
|---|---|---|
| `participationMinimumHops` | 28 | plain count, `u256` |
| `hopRewardCap` | 40 | plain count, `u256` — per **round** |
| `dailyFreeHops` | 22 | plain count, `u256` |
| `dailyFreeSpawns` | 1 | plain count, `u256` |
| `dailySoftCapRoz` | 100 (18dp) | see §2.5. The reachable daily total is 136.35 on the natural route (178 only if the gate is cleared before hopping), so 150–160 barely binds |
| `softCapMultiplierNum` / `Den` | 1 / 5 | 0.2× beyond the cap — **the only multiplier left in the system** |
| `dailySpendThreshold` | `600000` ($0.60) | §2.6 measure 1 |
| `lifetimeSpendThreshold` | `3000000` ($3.00) | §2.6 measure 3 |
| `verifiedBonusNum` / `Den` | — | §2.6 measure 4, if adopted |

The reduced rates are **absolute values, not multipliers** (§2.6 rule 2), so they
are stored the same way as the base rates:

| Reduced rate | ROZ | Raw value (18dp) |
|---|---|---|
| `hopRewardBelowThreshold` | 0.15 | `150000000000000000` |
| `participationBelowThreshold` | 0 | `0` — the bonus is withdrawn, not reduced |
| `hopRewardNewWallet` | 0.5 | `500000000000000000` |
| `participationNewWallet` | 9 | `9000000000000000000` |
| `newWalletSoftCapRoz` | 80 | `80000000000000000000` |

**`hopRewardBelowThreshold` is the most load-bearing of these**, and not only
against farmers. Because every calendar day starts at zero spend, it is the rate
*every* wallet earns on its opening stretch of hops — see §2.2. It sets zero-cost
sybil yield and the first 50-odd hops of an honest day at the same time.

0.15 and 0.5 ROZ are exact in 18 decimals, so there is no rounding concern and no
need for numerator/denominator pairs. The old `belowThresholdNum`/`Den` and
`newWalletNum`/`Den` fractions are **removed** — absolute rates replace them, and
that is what eliminates the compounding hazard described in §2.6.

Plus the progressive hop price schedule from §2.5 — four thresholds and four
prices, all owner-settable:

| Tier | Up to daily hop | Price (USDC, 6dp) |
|---|---|---|
| 1 | 25 | `5000` |
| 2 | 45 | `10000` |
| 3 | 65 | `20000` |
| 4 | beyond | `40000` |

Store as `hop_price_tier_limit: LegacyMap<u8, u256>` and
`hop_price_tier_price: LegacyMap<u8, u256>` so the shape can be retuned without a
redeploy — measure 5 in §2.5 exists precisely to drive that retuning.

**There is no `rewardDailySpawn`.** Spawning pays nothing, free or paid, so the
daily reward and its streak formula are gone. `participationMinimumHops` (28) is
deliberately set **above** `dailyFreeHops` (22), though since §2.6 that ordering is
the secondary guard: `dailySpendThreshold` withdraws the bonus below $0.60/day
whatever the hop count.

Setters are not optional. `currentGameTokenReward` today has **only a getter** —
it is written once in the constructor and can never change (`lib.cairo:1016`).
Without setters, retuning any reward, or applying the year 2 to 4 taper, means a
full redeploy: ~41 STRK and a reset to round 0, annually.

### 4b-i. The taper across years 2 to 4

The rates fall with the emission schedule. At constant player numbers each year's
rate is `year1Rate × pct ÷ 38`:

| | Y1 (38%) | Y2 (28%) | Y3 (18%) | Y4 (10%) |
|---|---|---|---|---|
| `rewardHide` | 30 | 22 | 14 | 8 |
| `rewardHideSurvived` | 50 | 37 | 24 | 13 |
| `rewardFind` | 110 | 81 | 52 | 29 |
| `rewardParticipation` | 18 | 13 | 9 | 5 |
| `rewardPerHop` | 1 | 0.74 | 0.47 | 0.26 |

Illustrative only — re-derive from actual daily actives at each boundary, since
the whole point of the taper is to match emission to real demand.

**One wrinkle: `rewardPerHop` drops below a whole token from year 2.** At 18
decimals `0.74` is perfectly representable (`740000000000000000`), but "0.26
tokens per hop" reads poorly in a UI. Either hold it at 1 and taper the others
slightly harder, or accept the fractions deliberately.

### 4c. Accrue, do not transfer per action

**This is the most important design decision here.** Rewards credit a per-player
pending balance; a separate call withdraws it.

```cairo
reward_token_pending: LegacyMap<ContractAddress, u256>,
total_reward_token_pending: u256,
```

with `claim_reward_tokens()` transferring a player's balance and zeroing it.

The alternative — transferring ROZ inside `hide_treasure`, each move and each
spawn — means that **when the contract runs low on ROZ, core gameplay reverts**.
Players could not hide, move or spawn at all. That is a far worse failure than
being unable to claim, and it would happen at exactly the moment the game is most
active.

Accrual also costs less gas: one storage add per action instead of an ERC20
transfer, and one transfer at the end instead of dozens.

### 4c-i. The coverage invariant — accrual stops before the contract overpromises

Accrual must never write an IOU the contract cannot honour. So every credit is
gated on the contract still being able to cover everything it owes:

```
total_reward_token_pending  <=  ROZ balance of the contract
```

All six rewards go through one internal helper that enforces it:

```cairo
// Credits ROZ to a player's pending balance, but ONLY while the contract can
// still cover every pending balance it has already promised. If it cannot, the
// credit is skipped and the game carries on regardless - no revert, and no
// promise the contract is unable to keep.
//
// Returns whether the credit happened, so callers can tell "paid" from
// "skipped". claim_reward uses that to leave the week's ROZ leg open for a
// retry later (see 4h); the gameplay rewards simply ignore it.
fn _accrueRewardToken(
    ref self: ContractState, player: ContractAddress, amount: u256,
) -> bool {
    let rewardTokenDispatcher = ERC20ABIDispatcher {
        contract_address: self.game_reward_token_contract_address.read(),
    };
    let availableBalance: u256 = rewardTokenDispatcher.balance_of(get_contract_address());
    let currentlyPending: u256 = self.total_reward_token_pending.read();

    if (currentlyPending + amount <= availableBalance) {
        self.reward_token_pending.write(player, self.reward_token_pending.read(player) + amount);
        self.total_reward_token_pending.write(currentlyPending + amount);
        return true;
    }

    // Otherwise: no credit. Emit RewardTokenAccrualSkipped so it is visible.
    return false;
}
```

**What this buys.** The invariant is self-maintaining. Three things could break
it, and each is closed:

| Could break it | Why it does not |
|---|---|
| Accruing more than the balance | Refused by the check above |
| Paying out | `claim_reward_tokens` reduces both sides by the same amount |
| The owner sweeping ROZ | `withdraw_token_balance` releases only the surplus above `total_reward_token_pending` — see §4j |

So once it holds, it holds forever — which means **`claim_reward_tokens` can
never fail for insufficient funds.** Nobody is ever shown a balance the contract
cannot pay.

The third row is load-bearing. §4j makes every token sweepable, so the guard
there is what keeps this section true — the two must be implemented together.

The failure mode becomes: an unfunded contract quietly stops issuing new rewards,
while every ROZ already earned stays claimable and all gameplay continues.

**Make it visible, not silent.** A player whose rewards stopped should be able to
tell. Emit `RewardTokenAccrualSkipped { player, amount }` on every skip, and add:

```cairo
fn get_reward_token_coverage(self: @ContractState) -> (u256, u256);  // (balance, pending)
```

so the frontend can show "rewards paused - contract awaiting funding" rather than
appearing to have quietly stopped working.

**Cost.** This reads `balance_of` on the ROZ contract once per rewarded action.
That is a real external call on the hot path. The alternative - tracking a funded
budget in storage - is cheaper but drifts from the true balance the moment anyone
transfers ROZ in directly, which is exactly how funding happens. Reading the
balance is the honest option.

**One hazard.** Calling `update_game_reward_token` while pending balances exist
strands them: `total_reward_token_pending` still counts IOUs denominated in the
old token, while the balance check reads the new one. Treat it as a setup lever
only, like `update_game_token`.

### 4d. Separating survived hides from steals

`claim_share_amounts` is a single count. `validate_treasure_coordinates`
decrements the hider and increments the finder, so **at claim time the contract
cannot tell a survived hide from a steal** — they are the same number in the same
map. Paying 120 for one and 180 for the other is impossible as things stand.

Add two parallel maps, maintained alongside the existing one:

```cairo
hider_share_amounts:  LegacyMap<(u256, ContractAddress), u256>,
finder_share_amounts: LegacyMap<(u256, ContractAddress), u256>,
```

`claim_share_amounts` keeps driving the USDC payout exactly as it does now — no
change to money already in flight. The two new maps drive the ROZ payout only.
`_rewardGamer`, `_removeGamerReward` and `validate_treasure_coordinates` each
need to maintain them.

### 4e. Per-round and per-day counters

None of this state exists today:

```cairo
player_hops:               LegacyMap<(u256, ContractAddress), u256>,  // per ROUND - the 32 cap
player_hops_today:         LegacyMap<(u64,  ContractAddress), u256>,  // per DAY   - the price tiers
player_hop_roz_today:      LegacyMap<(u64,  ContractAddress), u256>,  // per DAY   - the soft cap
player_paid_participation: LegacyMap<(u64,  ContractAddress), bool>,  // per DAY   - once, not per round
player_free_hops_used:     LegacyMap<(u64,  ContractAddress), u256>,
player_free_spawns_used:   LegacyMap<(u64,  ContractAddress), u256>,

// The Lightweight Gate - 2.6
player_spend_today:        LegacyMap<(u64,  ContractAddress), u256>,  // resets daily
player_lifetime_spend:     LegacyMap<ContractAddress, u256>,          // never resets
player_verified:           LegacyMap<ContractAddress, bool>,          // measure 4, if adopted
```

Everything except the last two is keyed by round or by day, so it resets
naturally as time advances — no cleanup pass is needed. `player_lifetime_spend`
is deliberately permanent; that is the whole point of measure 3.

**Both spend counters take irrecoverable fees only.** Hop fees, spawn fees, and
the 12,833 units retained on a claim. **Never the hide stake** — it is refundable,
and counting it would let a farmer clear a $5 lifetime gate for $0.0128. See §2.6.

Cost: two extra `u256` writes on every paid hop and every paid spawn.

**Two hop counters are required, and they cannot be merged.** The 40-hop reward
cap is per **round**; the price tiers and the soft cap are per **day**. Sharing
one counter would either reset the tiers four times a day — which §2.5 shows is
five times cheaper for a farmer — or make the cap a daily limit and quarter the
hops an honest player can earn on.

Note `player_paid_participation` moved from a round key to a day key. That single
change is what makes the bonus pay once a day rather than four times.

**Two entries from earlier drafts are now unnecessary:**

- `player_last_spawn_day` and `player_streak_days` existed only for the daily
  spawn reward. Spawning pays nothing, so both go — along with the streak
  formula that derived the bonus. See §9: whether the retention layer should
  return on a different trigger is an open decision, and that decision would
  bring this state back.
- `player_spawned` tracked whether a player had spawned, for the participation
  test. It is redundant: a player must already hold a position to hop at all, so
  reaching 28 hops proves they spawned.

Participation therefore needs one counter and one flag: count the hops, and
record that the bonus has been paid so it pays once per day rather than on
every hop past the twenty-eighth.

### 4f. Wiring each entrypoint

| Entrypoint | Credits |
|---|---|
| `hide_treasure` | `rewardHide`, and increments `hider_share_amounts` |
| `hide_treasure_bulk` | `rewardHide × treasureCount`, and adds `treasureCount` to `hider_share_amounts` — see §4m |
| `finder_player_generate_position` | **Nothing.** A spawn repositions the rabbit and pays no ROZ, free or paid. It consumes the free spawn allowance first, which affects the USDC charge only |
| `finder_player_move_position` | Charges the §2.5 tier price for the day's hop number; adds it to both spend counters; increments both hop counters; credits the hop reward under the 40-hop round cap; credits the participation bonus at **28** hops, **once per day**. Both rates are **resolved to the lowest applicable absolute value** first (§2.6 rule 2), then the soft cap is applied once — never as a product. The free/paid distinction gates only the USDC transfer — see §4l-i |
| `validate_treasure_coordinates` | moves a share between `hider_share_amounts` and `finder_share_amounts` |
| `claim_reward` | credits `hider_shares × rewardHideSurvived + finder_shares × rewardFind`, and sets `reward_token_claimed` only if that credit succeeded |
| `claim_reward_token_for_week` | retries the above for one week — see §4h |

Every one of these goes through `_accrueRewardToken` — a credit to the pending
map, never a transfer, and skipped rather than reverted when uncovered.

The five gameplay rewards ignore the helper's return value: they come round again
next round, so a skipped hop or hide is not worth tracking. Only the claim leg
records whether it landed.

**One helper resolves the gated rates, and the order matters.** Hop and
participation rewards are the only two the gate touches; hide, survival and
find/steal always pay in full (§2.6). The sequence is:

```
0. Charge the fee first, so today's spend is current before the rate is read
1. Pick the base rate:        rewardPerHop / rewardParticipation
2. If lifetime spend < $3:    take min(rate, newWallet rate)
3. If today's spend < $0.60:  take min(rate, belowThreshold rate)
4. Credit, then apply the soft cap once if the day's total is past it
```

Steps 2 and 3 both **take a minimum**, never a product — which is why a new wallet
that is also below the daily threshold lands on 0.15 and no participation, rather
than compounding down to nothing. Step 4 is the one remaining multiplier and runs
at most once.

**Step 0 is what makes the hop that crosses the threshold pay the full rate.**
The fee is charged, the spend counters are updated, and only then is the rate
read — so the 65th hop in §2.6's worked example earns 1.0, not 0.15. Every figure
in this plan is computed that way.

**Participation is tested against both of its conditions each time, and fires on
the first action where both hold.** It is not credited at the 28th hop and then
forgotten. A player can reach 28 hops while still below $0.60 — the typical
casual in §2.2 does exactly that, at hop 28 with $0.145 spent — and must still
receive the bonus when their spend later crosses. Concretely: on each hop, if
`hops_today >= participationMinimumHops` and `spend_today >= dailySpendThreshold`
and the bonus has not yet paid today, credit it. Getting this wrong costs that
player the whole 18 ROZ and is invisible in any test that spends first.

### 4g. The two claims are separate, and the USDC one is never blocked

`claim_reward_tokens` is an **additional** entrypoint, not a replacement.
`claim_reward` keeps doing exactly what it does today.

| Function | Transfers | Basis | Can a ROZ shortage block it? |
|---|---|---|---|
| `claim_reward(gameWeek)` | **USDC** — the hidden treasure value | Per game week, one-shot | **No** |
| `claim_reward_tokens()` | **ROZ** — the whole pending balance | Running total, callable any time | No — the invariant guarantees coverage |

**The USDC path is untouched.** `_claimReward` still computes
`shares × hiderFee` for the funding week, subtracts the three deduction fees, and
transfers the result from the contract's USDC balance — which the hide fees
themselves fund. A surviving hider gets their ~$4.99 stake back; a finder who
stole it gets it instead.

The only change is the order inside `_claimReward`:

1. assert the week is finished and not already claimed
2. compute the USDC due and assert it is non-zero
3. **transfer the USDC** — always happens, regardless of ROZ
4. `_accrueRewardToken(...)` for the survived-hide or steal reward — credited if
   covered, skipped if not
5. set `claimed_rewards` for the USDC leg, and `reward_token_claimed` **only if
   step 4 actually credited**

So an empty ROZ balance costs a player nothing in USDC. The treasure value still
returns to the hider, or goes to the finder, exactly as before.

### 4h. The claim-time ROZ leg is retryable

Step 4 is the only accrual that cannot be earned again — hide, hop and spawn
rewards come round next round, but a week's claim is one-shot. It is also the
largest reward in the table. So it gets its own flag and its own retry path, and
nothing is lost when the contract is temporarily unfunded.

```cairo
//Reward_token_claimed: LegacyMap::<(gameWeek, gamerWalletAddress), rewardTokenCredited>
//Separate from claimed_rewards, which gates the USDC leg. The two legs are
//independent: the USDC always pays, while the ROZ leg stays open until the
//contract can actually cover it.
reward_token_claimed: LegacyMap<(u256, ContractAddress), bool>,
```

**`_accrueRewardToken` returns whether it credited**, so the caller can tell the
difference between "paid" and "skipped":

```cairo
fn _accrueRewardToken(ref self: ContractState, player: ContractAddress, amount: u256) -> bool
```

**New entrypoint `claim_reward_token_for_week(gameWeek)`** — retries just the ROZ
leg for one finished week:

```cairo
fn claim_reward_token_for_week(ref self: ContractState, gameWeek: u256) -> bool {
    let player = get_caller_address();

    assert(gameWeek < self.currentGameWeek.read(), 'Game week not finished yet');
    assert(
        self.reward_token_claimed.read((gameWeek, player)) == false,
        'Reward token already claimed',
    );

    let amountDue = self._playerRewardTokenDue(player, gameWeek);
    assert(amountDue != 0, 'No reward available');

    // Unlike the automatic attempt inside claim_reward, the player asked for this
    // explicitly - so tell them plainly when the contract still cannot cover it,
    // rather than charging them gas for a silent no-op.
    assert(self._accrueRewardToken(player, amountDue), 'Reward token not funded yet');

    self.reward_token_claimed.write((gameWeek, player), true);
    return true;
}
```

Note the two flags are **fully independent** — a player may claim either leg
first, and neither gates the other. `hider_share_amounts` and
`finder_share_amounts` are not cleared by claiming, so the amount stays
computable for the retry.

Getting the ROZ after a refund is therefore two calls: `claim_reward_token_for_week`
to credit the pending balance, then `claim_reward_tokens` to withdraw it. The
frontend can send both in one multicall.

**Supporting view** so the UI can surface an outstanding leg:

```cairo
fn get_reward_token_claimed(self: @ContractState, gameWeek: u256, gamerWalletAddress: ContractAddress) -> bool;
```

Paired with the existing `get_player_reward_token_due`, that is enough to show
"120 ROZ still owed for week 3 — claim now" once funding returns.

### 4i. Making claim state observable — the getter and the events

**The problem this fixes is pre-existing, not caused by ROZ.** `claimed_rewards`
appears in exactly three places in `lib.cairo`: its declaration (`:290`), one
assert (`:744`) and one write (`:757`). There is **no getter and no event**, so
the claim state is completely invisible from outside the contract.

That bites because `_claimReward` never clears `claim_share_amounts`. The shares
survive the claim, so `get_player_reward_due` keeps returning `4,987,167`
**forever after the money has been paid**. The frontend cannot tell "you are owed
$4.99" from "you were already paid $4.99", and shows a claim button that reverts
with `'Reward already claimed'`.

The two-leg design sharpens it. With `claimed_rewards` and `reward_token_claimed`
both in play, a week has four states — and exposing only the ROZ one leaves the
UI unable to identify the §4h retry case, which is the exact situation
`claim_reward_token_for_week` exists to serve:

| USDC claimed | ROZ claimed | Meaning |
|---|---|---|
| no | no | nothing collected yet |
| no | yes | ROZ taken, treasure value outstanding |
| **yes** | **no** | **the §4h retry state — awaiting a refund** |
| yes | yes | fully settled |

**The getter**, mirroring `get_reward_token_claimed`:

```cairo
fn get_claimed_reward(
    self: @ContractState, gameWeek: u256, gamerWalletAddress: ContractAddress,
) -> bool;
```

**Four events.** The getter answers "is it claimed now"; the events give claim
*history*, and let an indexer reconstruct state without polling per week per
player. All follow the existing house style — `#[key]` on `user` and `gameWeek`,
camelCase value fields — as in `TreasureHidden` (`lib.cairo:186`):

| Event | Emitted from | Records |
|---|---|---|
| `RewardClaimed` | `_claimReward`, after the USDC transfer | The missing half of the claim record |
| `RewardTokenClaimed` | `claim_reward_token_for_week`, and `claim_reward` when its accrual lands | Which week's ROZ leg was credited |
| `RewardTokensWithdrawn` | `claim_reward_tokens` | ROZ actually leaving the contract |
| `RewardTokenAccrualSkipped` | `_accrueRewardToken` on refusal (§4c-i) | A reward the contract could not cover |
| `TreasureFound` | `validate_treasure_coordinates` | The find itself, **and the hop count that produced it** |

**`TreasureFound` is not optional if §2.4 ships.** `validate_treasure_coordinates`
emits nothing today — a find leaves no trace beyond a silent share movement. So
"recent median hops per find", the input that drives every K adjustment, **cannot
be computed from the chain at all**. Without this event the scaling model has no
feedback signal and K can only be guessed.

```cairo
#[derive(Drop, starknet::Event)]
struct TreasureFound {
    #[key]
    finder: ContractAddress,
    hider: ContractAddress,
    hopsTaken: u256,
    #[key]
    gameWeek: u256,
}
```

`hopsTaken` comes straight from the `player_hops` counter §4e already adds, so it
costs nothing extra to include — and it turns the whole calibration loop into a
single event stream to read.

```cairo
#[derive(Drop, starknet::Event)]
struct RewardClaimed {
    #[key]
    user: ContractAddress,
    rewardAmount: u256,
    #[key]
    gameWeek: u256,
}
```

`RewardTokenClaimed` takes the same shape with `rewardTokenAmount`.
`RewardTokensWithdrawn` and `RewardTokenAccrualSkipped` carry `user` and an
amount but no week — neither is week-scoped.

Emitting for the USDC leg but not the ROZ legs would recreate exactly the
asymmetry this section removes, so all four go in together.

**There is already a consumer.** The frontend runs a `WebSocketChannel` filtered
on an event selector (`Middle.vue:1258-1291`) alongside its Pusher channel, so
events are an established mechanism here rather than a new one. `RewardClaimed`
gives the rewards panel a live update path instead of polling.

### 4j. `withdraw_token_balance` sweeps any token

The signature gains a token argument, and stays owner-gated:

```cairo
fn withdraw_token_balance(
    ref self: ContractState, tokenAddress: ContractAddress, receiver: ContractAddress,
);
```

Today it sweeps only the configured game token, which is why ROZ sent to the
contract used to be unrecoverable. Any token can now be recovered — useful for
tokens sent to the contract by mistake as well as for reclaiming an over-funded
tranche.

**This breaks the coverage invariant unless guarded.** §4c-i argues that
`total_reward_token_pending <= balance` holds forever *because there is no ROZ
withdrawal path*. There now is one. An owner sweeping ROZ while players hold
pending balances would leave `claim_reward_tokens` unable to pay — the exact
failure the invariant exists to prevent.

**The guard: when the token being swept is the configured reward token, release
only the surplus.**

```cairo
// Players' accrued ROZ is not the owner's to take. Sweeping the reward token
// releases only what is left after every pending balance is covered, which is
// what keeps the 4c-i invariant true and claim_reward_tokens unable to fail.
let mut sweepableAmount = tokenDispatcher.balance_of(get_contract_address());

if (tokenAddress == self.game_reward_token_contract_address.read()) {
    sweepableAmount = sweepableAmount - self.total_reward_token_pending.read();
}
```

Cheap, and it preserves the invariant by construction while leaving every other
token fully sweepable.

**The equivalent USDC hazard is pre-existing and not fixed here.** Sweeping the
game token strands every outstanding claim, because USDC owed is computed from
shares on demand and never totalled. There is no `total_usdc_pending` to subtract.
Worth knowing while the function is open: sweeping USDC mid-round takes money
players are entitled to.

### 4k. Round cadence — an operational problem, not a contract one

**A 6-hour round means `start_new_game` must be called 1,460 times a year.**

It takes eight positional `u256`/`u128` arguments with no validation, and a slip
corrupts that round's economics — this is exactly how `4500000000000000` ended up
in the old contract's hider-count slot, where a treasure value was passed as a
hider count. Doing that by hand four times a day is not viable, and 1,460 annual
chances to mistype are worse.

Two ways out, both outside this document's scope but needed before launch:

- **An off-chain keeper** that calls `start_new_game` on a schedule with fixed
  arguments. No contract change; the rollover depends on the keeper staying up.
- **An on-chain `advance_round()`** that carries the current root, fees and grid
  forward and takes no arguments. Removes the footgun entirely, and could be
  permissionless with a time check so anyone can roll a stale round.

**Rounds ending early.** "A round may end once all eligible treasures are found"
is already detectable — `total_reward_shares_for_hiders[round]` decrements on
every successful `validate_treasure_coordinates`, so zero means all found. Acting
on it is new behaviour and should be designed deliberately rather than bolted on.

**A naming note.** `gameWeek` now means a 6-hour round throughout the contract,
the ABI and the frontend. Renaming is cosmetic but touches everything, including
a deployed ABI other tooling reads. Recommend documenting the meaning rather than
churning the interface.

### 4k-i. The keeper's per-round procedure

Dynamic scaling (§2.4) makes the keeper more than a cron job — it has a decision
to make each round. Four steps:

1. **Read `T`** — `get_total_number_of_hiders(nextRound)`. These are the hides
   made during the round now ending, which become the next round's active
   treasures.
2. **Size the grid** — `cells = T × 40 × K`, `side = ceil(sqrt(cells))`, clamped
   to the min/max grid bounds.
3. **Adjust K** from the recent median of `hopsTaken` in `TreasureFound` events:
   below 32 raise it, 32–48 hold, above 48 lower it, never by more than ±0.15.
4. **Call `start_new_game`** with the new root, the fees, `side` for both grid
   dimensions, and **`T` for `totalNumberOfHidersFromThePreviousWeek`**.

**This defuses the argument footgun.** `start_new_game` *overwrites*
`total_reward_shares_for_hiders[newRound]` with whatever is passed — the exact
mistake that put `4500000000000000` in the old contract's hider slot, where a
treasure value was supplied as a hider count. The keeper has to read the true `T`
anyway for step 2, so passing that same value back in step 4 is the natural thing
to do rather than a separate step to remember.

Log every decision — `T`, `K`, the median that moved it, and the resulting grid —
so the calibration can be reviewed rather than guessed at.

### 4l. Daily free hop and spawn allowances

Implements §2.3. Four pieces.

**1. Two configurable allowances**, owner-settable like every other rate:

```cairo
dailyFreeHops:   u256,   // 22 - 55% of a round against the 40 hop cap, and
                         //      deliberately BELOW participationMinimumHops
                         //      (28). Since 2.6 the daily spend threshold is
                         //      the primary guard; this ordering is defence in
                         //      depth. Zero-cost yield is 3.3 ROZ - see 4l-i-a.
dailyFreeSpawns: u256,   // 1  - one free round a day
```

**2. Usage counters keyed by day, so they self-reset:**

```cairo
//Player_free_hops_used: LegacyMap::<(dayIndex, gamerWalletAddress), hopsUsedToday>
player_free_hops_used:   LegacyMap<(u64, ContractAddress), u256>,
player_free_spawns_used: LegacyMap<(u64, ContractAddress), u256>,
```

Keyed by `dayIndex = get_block_timestamp() / 86400`. A new day is a new key, so
the allowance resets with no cleanup pass —
matching how the per-round counters in §4e reset when the round advances. The
daily bucket is deliberately **not** keyed by round, so it is shared across all
four rounds in the day exactly as specified.

**3. Skip the charge, not the action.** In `finder_player_move_position` and
`finder_player_generate_position`, the fee transfer becomes conditional:

```cairo
// A player's first hops each day are on the house. ONLY the fee is waived - the
// hop is identical in every other respect, so nothing after this block needs to
// know whether it was paid for. The hop counter, the 40-hop cap, the 28-hop
// participation test and the ROZ accrual all run exactly as they would for a
// paid hop. A free hop adds nothing to the spend counters, though, because it
// costs nothing - so free hops alone never clear the 2.6 gate. See 4l-i.
let freeHopsUsed = self.player_free_hops_used.read((today, gamerWalletAddress));
let hopIsFree = freeHopsUsed < self.dailyFreeHops.read();

if (hopIsFree) {
    self.player_free_hops_used.write((today, gamerWalletAddress), freeHopsUsed + 1);
} else {
    let transferResult = self
        ._transfer_token_from(gamerWalletAddress, myContract, finderCost);
    assert(transferResult == true, 'game token not transferred');
}
```

**4. The blocker — `minimumAllowance` must not gate a free spawn.**

This is the part that makes or breaks the feature.
`finder_player_generate_position` currently opens with:

```cairo
assert(allowanceAmount >= self.minimumAllowance.read(), 'token spend approval req');
```

That check runs **before anything else**, so a new player with no USDC approval
cannot spawn at all — even if their spawn would be free. Left as is, the free
allowance is unreachable for exactly the players it exists to help, and the
anti-frustration goal fails completely.

The assert must move inside the paid branch: **a free spawn requires no approval
and no USDC balance.** That is what lets someone play immediately, decide they
like it, and only then approve a spend limit.

**5. Views, so the allowance is visible:**

```cairo
fn get_free_hops_remaining(self: @ContractState, gamerWalletAddress: ContractAddress) -> u256;
fn get_free_spawns_remaining(self: @ContractState, gamerWalletAddress: ContractAddress) -> u256;
fn get_next_hop_price(self: @ContractState, gamerWalletAddress: ContractAddress) -> u256;
```

`get_next_hop_price` matters more than it looks: with tiered pricing a player has
no way to know what their next hop costs. Showing "your next 20 hops cost $0.01,
then the price doubles" is the difference between a schedule that feels fair and
one that feels like a trap.

**Monitoring — measure 5 of §2.5.** Retuning the tiers needs cost-per-ROZ per
wallet. Two views supply it, and **no extra storage is needed**: ROZ earned comes
straight from the soft-cap counter, and USDC spent is derivable off-chain from
the hop count plus the published tier schedule.

```cairo
fn get_player_hops_today(self: @ContractState, gamerWalletAddress: ContractAddress) -> u256;
fn get_player_hop_roz_today(self: @ContractState, gamerWalletAddress: ContractAddress) -> u256;
```

Sample these across active wallets. A cluster with an unusually low cost-per-ROZ
is a farm; the tier prices are owner-settable so the schedule can be tightened
without a redeploy.

An invisible allowance reduces no frustration. The UI needs to show what is left
and warn **before** the first charge — the same reasoning as the ~28-hop soft
warning in §2.2, and arguably more important, since this one is about money.

### 4l-i. Free and paid differ only in cost

**Decided rule: a free action behaves identically to a paid one in every respect
except the USDC charge.** This now holds for hops *and* spawns, with no
exceptions.

| Behaviour | Free hop | Free spawn |
|---|---|---|
| Performs the action | Yes | Yes — repositions the rabbit |
| Awards ROZ | Yes, at whatever rate §2.6 resolves to | **No — and neither does a paid spawn** |
| Counts toward the 28-hop participation minimum | Yes | n/a |
| Counts toward the 40-hop reward cap | Yes | n/a |
| Charges USDC | **No** | **No** |
| Counts toward the §2.6 spend thresholds | **No — it costs nothing** | **No** |

Spawning is consistent because **neither version pays**, rather than because both
do. Hops are consistent because both pay.

Implementation is therefore *simpler* than any alternative: the `hopIsFree` flag
from §4l gates only the transfer. Everything downstream — the hop counter, the
cap check, the participation test, the accrual — runs unchanged and never needs
to know whether the action was paid for. The same is true of the spawn path,
which now has no reward branch at all.

**This removes the perverse incentive for good.** An earlier rule made free hops
earn nothing, which meant the allowance *cost* an earning player money and the
rational move was to avoid it. A later rule left spawns asymmetric. Neither
problem survives: there is nothing for a player to route around, and nothing to
explain.

### 4l-i-a. The allowance sits below the participation minimum, by design

Free hops earn ROZ, so a zero-cost wallet earns *something*. Three settings cap
how much: **`dailyFreeHops` is 22, `participationMinimumHops` is 28, and
`dailySpendThreshold` is $0.60.**

A wallet that never pays cannot clear the spend threshold — free hops add nothing
to the spend counters — so its hops pay `hopRewardBelowThreshold`, not
`rewardPerHop`:

| | ROZ |
|---|---|
| 22 free hops × **0.15** (below the $0.60 threshold) | 3.3 |
| Participation — withdrawn below the threshold, and 22 < 28 in any case | **0** |
| Spawn — pays nothing, free or paid | 0 |
| **Total, at zero USDC cost** | **3.3/day** |

**Participation is now locked twice over.** The §2.6 spend threshold withdraws it
outright, and the hop ordering would deny it anyway. Either lock alone is
sufficient; keeping both costs nothing.

The ordering rule still stands — **keep `dailyFreeHops` strictly below
`participationMinimumHops`** — but it is no longer the whole defence. If the
allowance were raised above 28, a zero-cost wallet would still earn only
`28 × 0.15 = 4.2` rather than gaining the bonus, because the spend threshold holds.

Against the Year 1 budget of 2,342,466 ROZ/day, roughly **709,838 throwaway
wallets** would be needed to drain the tranche, paying Starknet gas throughout.

**This was a regression, and lowering the rate has reversed it.** The route has
been through three settings:

| Settings | Zero-cost yield | Wallets to drain Year 1 |
|---|---|---|
| 20 free hops, 0.2× multiplier | 4 ROZ | 585,617 |
| 22 free hops, 0.3 absolute | 6.6 ROZ | 354,919 |
| **22 free hops, 0.15 absolute** | **3.3 ROZ** | **709,838** |

The allowance never moved back — the rate did all of it. 709,838 is **21% more
wallets than the original settings ever required**, so this is now the tightest
the zero-cost route has been, not merely a return to par.

**One caveat on the lever, because it is easy to over-pull.**
`hopRewardBelowThreshold` is not confined to this attack. Every calendar day
starts at zero spend, so it is also the rate honest players earn on their opening
stretch — the first 54 hops of a typical casual's day, 59 of an active player's
(§2.2). Halving it took 8.1 and 8.8 ROZ off those two profiles. It remains the
dominant term for zero-cost wallets, but it is not free to lower.

Remaining levers if it still looks too generous:

- **Lower `hopRewardBelowThreshold` further** — still the dominant term, subject
  to the caveat above.
- **Lower `dailyFreeHops`** — linear in the same figure, and it touches only
  wallets inside the allowance, so it does not hit honest players who hop past
  22. But it is also the onboarding budget, so it trades against measure 2.
- **Accept it on testnet**, and gate on a funded balance before mainnet.

### 4l-ii. The residual farming route is the hide loop

Gating free actions removes zero-cost farming, but it leaves paid routes whose
ROZ yield may exceed their USDC cost. **The 10× price cut moved every one of
these 10× cheaper:**

| Route | ROZ | Real cost | Break-even |
|---|---|---|---|
| Per-hop, mid-tier | 1 | $0.01 | $0.01000 |
| 65 paid hops — the cheapest route through the §2.6 gate | 28.6 | $0.615 | $0.0215 |
| Hide cycle, if unfound | 80 | $0.0128 | **$0.00016** |

There is no spawn row — a spawn pays nothing.

The 65-hop row replaces the old 28-hop one: below $0.60 of daily spend the
participation bonus is withdrawn entirely, so a farmer must reach the threshold
before the hop route is worth running at all. Its yield is 28.6 rather than 83
because non-retroactivity pays only hop 65 at the full rate — see §2.6.

The hide loop is the cheapest, because the $5 hide fee is *staked* rather than
spent — survive the round and the player claims back $4.99, keeping 80 ROZ for
the 12,833 units the contract retains.

**But that $0.00016 is a floor, not a typical cost.** The row assumes the
treasure is never found. The rest of this section works out what the route
actually costs, because the answer decides whether it is the plan's largest
exposure or merely its cheapest corner.

#### No anti-farm measure in the plan touches hiding

This is the structural point, and it is easy to miss because it is a property of
what the measures *omit*. Both §2.6 rate tables read the same way on the hide
lines, above and below the threshold:

| Reward | Below $0.60 | $0.60 or more | New wallet |
|---|---|---|---|
| Per hop | 0.15 | 1.0 | 0.5 |
| Participation | none | 18 | 9 |
| **Instant hide** | **Full** | **Full** | **Full** |
| **Hide survives** | **Full** | **Full** | **Full** |
| **Find / steal** | **Full** | **Full** | **Full** |

And §2.6 rule 1 requires the hide stake **not** to count as spend — correctly,
since it is refundable. So hiding neither clears the gate nor is reduced by it.
Progressive pricing (§2.5), the daily spend threshold, the lifetime threshold,
the soft caps and the free allowance all act on hops and participation. **None of
them reaches a hide.**

#### What the route actually costs depends on `P(found)`

A hide pays **30 ROZ unconditionally** and 50 more only if it survives. If found,
the finder takes the $5 stake. So the expected figures per hide are:

```
cost = P(found) × $5  +  (1 − P(found)) × $0.0128
ROZ  = 30             +  (1 − P(found)) × 50
```

To drain the 2,342,466 ROZ/day budget a farmer needs about **29,281 hides a day**
— roughly **7,320 per round**. `P(found)` is then the honest players' finds per
round divided by that pool. It does not fall as the farmer scales: §2.4 sizes the
grid at `T × 40 × K`, holding density constant, so flooding the board grows it
proportionally and finds per honest hop stay put.

| Honest finds per round | P(found) | Break-even | Cost to drain Year 1 | Profitable above |
|---|---|---|---|---|
| ~1,875 — a healthy game, ≈5,000 daily actives | 25.6% | **$0.0192/ROZ** | $45,000/day | **$96M** |
| ~500 | 6.8% | $0.00461 | $10,800/day | $23M |
| ~100 — a quiet round | 1.4% | $0.00102 | $2,390/day | $5.1M |
| 0 — a dead round | 0% | **$0.00016** | $375/day | **$0.8M** |

**Read the top row first.** At $96M against the gated hop route's $107M, the hide
loop in a busy game is *comparable to hopping*, not 134× cheaper. The 134× figure
compares the bottom row against the hop route, and it is the honest comparison
only for a round nobody is playing.

**The exposure is timing, not scale.** A farmer does not need the game to be dead
on average — only to be quiet sometimes, and to hide then. With 6-hour rounds
there will be quiet ones, and nothing in the design discourages concentrating
hides into them. That is the real shape of this attack: not a cheaper farm, but
a farm that costs 120× less on some rounds than others, chosen by the farmer.

#### Gas does not constrain this route either

The plan leans on Starknet gas as the real anti-farm cost (§2.5, §9). Bulk hiding
removes that lever — `hide_treasure_bulk` places 200 treasures in one transaction
for almost the gas of one:

| | Gated hop route | Hide route |
|---|---|---|
| Transactions to drain Year 1 | ~5.3M/day | **~147/day** |
| Cost | $50,371/day | $375 – $45,000/day |
| Capital required | none | $146,405, **refundable** |

**About 36,000× fewer transactions**, and that ratio holds at every `P(found)`.
Where the hop route is bounded by transaction count, this one is bounded only by
locked capital that comes back.

#### Two things bound it, and both are unshipped

- **The per-treasure claim deduction (§4m-ii).** Without it the 12,833 units are
  charged once per *claim*, not per treasure, so a bulk-claiming farmer pays
  about **$1.88/day** rather than $375. That is exactly the quiet-round case
  where the deduction is the *only* remaining cost.
- **`maxTreasuresPerRound` (§4m-i).** The cap that would stop a farmer putting
  7,320 treasures into one round exists in the code, but §9 records that its
  value cannot be chosen until the grid bounds are. **The one lever aimed at this
  route currently has no number in it.**

Both are recorded in §9. Note also the collision with §2.2: the hide loop is the
only route by which a below-gate light casual reaches their band, so the cheapest
farm route and the intended casual path are the same mechanic.

### What a maximising farm wallet now costs

**A farmer optimises for cost per ROZ, not for ROZ per wallet**, so the worst case
is the cheapest gate-clearing wallet, not the biggest one:

| | Cheapest gated wallet | Maximising wallet |
|---|---|---|
| Daily cost | **$0.615** — 65 paid hops | $4.715 — 160 paid hops + 3 paid spawns |
| Daily yield | **28.6 ROZ** — 9.6 pre-crossing, 1 at full rate, 18 participation | 136.35 ROZ |
| Break-even | **$0.0215/ROZ** → a **$107M** market cap at 5B supply | $0.0346/ROZ → $173M |
| To drain the Year 1 tranche | ~81,904 wallets/day at **~$50,371/day** | ~17,180 wallets at ~$81,004/day |

The left column is still the one that matters, and it is now far less alarming
than it was: **$107M is a strong valuation for a game token, not an ordinary
one.** The corrected figures move this from a live risk to a distant one — the
attack only becomes profitable well after the token has succeeded.

The maximising wallet reaches 136.35 rather than 178 because it too pays 0.15 on
its first 49 hops. The full 178 requires clearing $0.60 on spawns before hopping
($5.015 for 178 ROZ, $0.0282/ROZ) — cheaper per ROZ than the 160-hop route above,
and still dearer than simply stopping at 65 hops.

Note what the free allowance does and does not do: it holds a **zero-cost** wallet
to 3.3 ROZ/day, but a farmer willing to spend $0.615 is only slowed by the gate,
not by the allowance. The allowance defends against throwaway wallets; §2.6
defends against funded ones. Neither addresses a farmer who simply pays. The fix
for that is a tokenomics choice, not an engineering one; see §9.

### 4l-ii-a. Resolved — the free allowance no longer penalises the player

This section previously recorded a real problem: because free hops earned no ROZ
and the allowance was consumed automatically, taking it forfeited per-hop ROZ plus
a blocked participation bonus for a saving of only $0.30. The allowance became a
**net loss** to the player once ROZ passed $0.00625, and the rational move was to
avoid the feature entirely.

**§4l-i now makes free hops identical to paid hops apart from the charge**, so
the trade disappears: a free hop saves the tier price and earns exactly what a
paid hop earns at the player's resolved rate. There is nothing left to route
around.

The cost of that fix is the sybil surface in §4l-i-a — **3.3 ROZ/day** for a
wallet that spends nothing. Kept here as a record of why the rule changed.

One residual wrinkle, worth knowing rather than fixing: because free hops do not
count toward the §2.6 spend thresholds, a player sitting just under $0.60 gains
nothing from further free hops but would cross the threshold by paying. That is
the gate working as designed, not a perverse incentive — the player is choosing
whether to buy the higher rate, and both options are visible.

### 4l-iii. "Free" still costs gas

Waiving the in-game fee does not make a transaction free — the player still pays
Starknet gas, and their wallet still prompts. Unless the Cartridge paymaster is
working, calling these hops "free" in the UI will mislead. Word it as **"no game
fee"** until gas is genuinely sponsored.

### 4m. Bulk hiding

A hider pays a single amount that is an exact multiple of the hider fee, and the
contract records that many individual hidden treasures. $1,000 at a $5 fee
becomes 200 treasures in one transaction.

**No loop is needed.** Shares are a counter, so the whole thing is O(1) regardless
of size — two storage writes and one transfer, not 200 of each:

```cairo
fn hide_treasure_bulk(ref self: ContractState, bulkAmount: u256) -> bool {
    let caller = get_caller_address();
    let hiderCost: u256 = self.currentHiderFee.read();
    let gameWeek = self.currentGameWeek.read() + 1_u256;

    // The bulk amount buys whole treasures only - a remainder would be money the
    // contract took without hiding anything for it.
    assert(bulkAmount % hiderCost == 0, 'not a multiple of hider fee');

    let treasureCount: u256 = bulkAmount / hiderCost;
    assert(treasureCount > 0, 'bulk amount too small');

    // A hard safety bound, NOT a grid check - the grid for this round does not
    // exist yet. See 4m-i.
    let alreadyHidden: u256 = self.total_reward_shares_for_hiders.read(gameWeek);

    assert(
        alreadyHidden + treasureCount <= self.maxTreasuresPerRound.read(),
        'round treasure cap',
    );

    // ... single transfer of bulkAmount, then shares and totals += treasureCount
}
```

Refactor `_hideTreasure(caller)` into `_hideTreasure(caller, treasureCount)` and
have the existing `hide_treasure()` call it with `1`. One code path, no
duplication.

**Events.** Coordinates are assigned off-chain — `hide_treasure` never takes them,
and the merkle root arrives later via `start_new_game`. So the backend that
places treasures only needs to know *how many*. Add
`TreasureHiddenBulk { user, hiderFee, treasureCount, gameWeek }` and leave
`TreasureHidden` untouched, so the existing consumer keeps working and the backend
gains one handler. Emitting 200 individual events would cost gas for no benefit.

### 4m-i. Why the bound is a cap, not a grid check

The obvious guard — "do not hide more treasures than there are cells" — **cannot
be written**, and would break bulk hiding completely if attempted.

`main_game_grid_size` is written only in `_createNewGame` (`lib.cairo:507`), when
a round is *created*. Hides target `currentGameWeek + 1` (`:543`, `:1058`) — a
round that does not exist yet. So at hide time the target round's grid reads
**(0,0)**, a capacity of zero, and every bulk hide would revert.

Dynamic scaling (§2.4) also reverses the causality such a check assumed: **the
grid is sized from the hide count**, so it cannot bound the hide count. With
`T × 40 × K`, the $1,000 / 200-treasure case is no longer a problem at all — it
simply produces a ~126×126 board.

**What the check was protecting still matters.** Two treasures on one cell share
a leaf, and `found_coordinates[(leaf, gameWeek)]` lets a leaf be found only once —
so the second is unfindable, and its hider is guaranteed the survival reward for a
treasure nobody could ever have taken. That is now prevented by the off-chain
minimum-distance and density rules in §2.4, which have the coordinates to enforce
it. The contract never sees coordinates and could not have enforced it properly
anyway.

**On-chain, one blunt safety bound remains:**

```cairo
maxTreasuresPerRound: u256,   // owner-settable; the on-chain half of the
                              // "hard safety bounds" in 2.4
```

Derive it from the off-chain limits — `maxGridCells × maxTreasuresPer1000Cells ÷ 1000`.
At a 250×250 maximum grid and 20 treasures per 1,000 cells that is roughly
**1,250 per round**. Its job is to stop a single whale, or a bug in the keeper,
from committing the game to a round it cannot physically lay out. It is a
backstop, not the density mechanism.

### 4m-ii. The claim deduction must scale, or bulk hiding is 200× cheaper

`_calculateRewardDue` subtracts the three fees **once per claim**, not per share:

```cairo
let eligibleReward = claimShareCount * gameHiderFee;
let rewardDue = ((eligibleReward - gasFee) - gameFee) - gameLandownerFee;
```

So a 200-share bulk claim pays 12,833 units in total — the same as a single hide.

| | Real cost | Break-even |
|---|---|---|
| 200 hides, one at a time | $2.5666 | $0.00016/ROZ |
| 200 hides, in bulk | **$0.0128** | **$0.0000008/ROZ** |

Bulk hiding would make the cheapest farming route in the game **200× cheaper
still**, because the only real cost of a survived hide is that deduction.

**Where this bites is the quiet round.** §4l-ii shows the hide loop's cost is
`P(found) × $5` plus the deduction. When the game is busy the lost stakes dominate
and the deduction barely registers. When a round is quiet almost nothing is
found, the stakes come back, and **the deduction is the entire remaining cost** —
so removing it takes the cost of draining Year 1 by hiding from $375/day to about
**$1.88/day**. The fix matters least in the case that was never dangerous and
most in the one that is.

**The fix is one line, and it is backward compatible:**

```cairo
let rewardDue = claimShareCount * (gameHiderFee - gasFee - gameFee - gameLandownerFee);
```

For a single share this is `5,000,000 − 12,833 = 4,987,167` — **identical to
today**. It only changes bulk claims, charging per treasure hidden rather than per
claim submitted, which is what the deduction was always meant to represent.

Ship this **with** bulk hiding, not after.

### Session policies

`claim_reward` needs **no new policy entry** — it is already registered at
`controllerPolicies.js:46`. **`claim_reward_tokens` and
`claim_reward_token_for_week` are both new entrypoints and need one each**,
otherwise the keychain prompts on every claim.

## 5. Step 3 — Deploy to Sepolia

Use an explicit `--url` on a spec-0.10 endpoint throughout; `--network sepolia`
fails with `-32603`.

The two phases are **independent** — phase 1 needs nothing from phase 2, and is
much the smaller piece. Ship it on its own to get the token on-chain while the
reward mechanics are still being settled.

### Phase 1 — the token, standalone

1. Fix the four imports (§3) and add `mod game_reward_token;`.
2. `scarb build` — confirm a `ROZToken` class is emitted alongside the other two.
3. **Declare and deploy `ROZToken`** with
   `--constructor-calldata <your account> <your account>` (recipient, owner).
4. Verify `symbol()`, `decimals()` and `total_supply()` per §7.

At this point the token exists and the full supply is in your account. Nothing
else in the system knows or cares about it yet.

### Phase 2 — the game contract

5. **Redeploy the game contract** with three constructor arguments: mock VRF,
   USDC, then the ROZ address from phase 1. This also carries the reward-repricing
   fix already in the working tree, and the claim visibility work in §4i.

   §4i is **not a dependency of the ROZ feature** — it is a pre-existing gap that
   the two-leg claim design makes worse. It is bundled here purely because a
   declare costs ~41 STRK and resets the contract to round 0, so adding four
   lines during a redeploy that is happening anyway is free, and adding them
   afterwards is not.
6. **Fund the game contract.** For Sepolia, send a token amount — say
   1,000,000 ROZ. Deliberately under-funding is also how you test §7.7.
7. Verify `get_game_reward_token()` returns the ROZ address.

Sweep the old contract at `0x0407390e…` first — and note that after §4j the sweep
takes a token address, so USDC must be named explicitly.

### Annual operation

At each year boundary, two things: transfer that year's tranche, then apply the
taper by calling the rate setters with the year's values from §4b-i.

| | Tranche | Raw (18dp) |
|---|---|---|
| Year 1 | 855,000,000 | `855000000000000000000000000` |
| Year 2 | 630,000,000 | `630000000000000000000000000` |
| Year 3 | 405,000,000 | `405000000000000000000000000` |
| Year 4 | 225,000,000 | `225000000000000000000000000` |
| Year 5+ | 135,000,000 | released gradually across years 5–8 |

Transfer the tranche **before** lowering the rates, so claimants at the boundary
are not paid a reduced rate out of the old balance.

Unspent ROZ carries forward in the contract — the schedule caps what is
*released*, not what must be spent. §4j lets you pull any surplus back.

## 6. Step 4 — Frontend (to be documented, not applied here)

The frontend checkouts are read-only from this repo, so this becomes a separate
document.

**Remove the reward token's mainnet dependency entirely.** Three things go:

1. `Middle.vue:1225` builds the reward token against
   `starknet-mainnet.g.alchemy.com`. Point it at `READ_PROVIDER_URL` and the new
   Sepolia address.
2. `counter.js:45` `getPoolRewardTokenPrice` — the mainnet Ekubo USDC/ROZ lookup.
   Delete it.
3. `counter.js:87` `convertRewardTokenToUsd`, and the `gamerRewardTokenDueUSD` /
   `gamerRewardTokenDueUSDNextRound` fields it feeds. Delete them, and remove the
   USD pills from the GTR columns at `Middle.vue:2366` and `:2398`.

The reward panel then shows a ROZ amount and nothing else, which is the intent.

Also:

4. **The failing `getClassAt` aborts bootstrap.** It runs before `setAccount` and
   `startGameSetup()` with no `try`. Wrap it, so a reward-token problem degrades
   the balance display rather than killing the game.
5. **Read amounts from the contract**, not from local arithmetic: replace
   `rewardLegs`' reward leg with the pending balance and drop
   `VITE_REWARD_TOKEN_MULTIPLIER` — it exists only to convert USD to tokens, and
   there is no USD any more.
6. **Add a claim button for `claim_reward_tokens`**, and a policy entry for it.
7. **Ticker and labels.** Introduce a `REWARD_TOKEN_TICKER` constant mirroring
   `GAME_TOKEN_TICKER` rather than editing 8 hardcoded `GTR` literals, and fix
   `Middle.vue:1899` where GTR is captioned "(Game Token)" — which is what USDC
   is called two panels away.

---

## 7. Verification

1. `scarb build` and `scarb fmt --check` clean; three classes emitted.
2. On the token: `symbol()` → `ROZ`, `decimals()` → `18`, `total_supply()` →
   `5000000000000000000000000000`.
3. `get_game_reward_token()` returns the ROZ address.
4. **Hide.** Call `hide_treasure`; pending balance rises by exactly
   `30000000000000000000` and no ROZ moves yet.
5. **Hop, cap and participation.** With a wallet that has cleared both thresholds,
   move once — pending rises by `1e18`. At the **28th** hop, participation credits
   `18e18` **exactly once**, not per hop. Hop 40 still credits; hop 41 credits
   nothing and the move itself still succeeds.
5a. **Participation is daily, not per round (§2.5).** After earning it in round 1,
   reach 28 hops again in round 2 — it must **not** credit a second time. Cross
   midnight UTC and it credits again.
5b. **Progressive pricing (§2.5).** Hop 23 charges `5000`, hop 26 charges
   `10000`, hop 46 charges `20000`, hop 66 charges `40000`. Hops 1–22 charge
   nothing. **The tiers must not reset at a round boundary** — hop 41, the first
   of round 2, still charges the tier its daily number falls in, not `5000`. This
   is the single most important assertion in the anti-farm work.
5c. **The soft cap.** Drive `player_hop_roz_today` past `dailySoftCapRoz`, then
   hop again — the credit is multiplied down, not full. Confirm it resets at
   midnight UTC.
5d. **The daily spend gate (§2.6).** At `player_spend_today` of `599999` a hop
   credits `0.15e18` and the 28th hop credits **no** participation at all; at
   `600000` a hop credits the full `1e18` and participation credits `18e18`.
   Assert the participation case explicitly — it is withdrawn below the threshold,
   not reduced.
5d-i. **The crossing hop pays the full rate, and earlier hops are not upgraded.**
   Hop a fresh wallet all the way to hop 65 with no spawns. Hops 1–64 must credit
   `0.15e18` each and hop 65 `1e18`, for a pending total of `28.6e18` including
   participation. Re-read the pending balance after hop 65 and confirm the first
   64 credits were **not** revised upward — non-retroactivity is what most of the
   gate's strength rests on, and a retroactive implementation would nearly treble
   this wallet's yield.
5d-ii. **Participation survives a late crossing.** Reach 28 hops while still below
   $0.60, confirm no bonus, then keep hopping until the spend crosses. The `18e18`
   must credit at the crossing hop. A wallet that never crosses never gets it.
   Getting this wrong silently costs every honest player 18 ROZ a day, and a test
   that funds the wallet before hopping will not catch it.
5e. **The hide stake gives no spend credit — the highest-value assertion here.**
   A wallet that only calls `hide_treasure` or `hide_treasure_bulk`, however
   much it stakes, must leave `player_spend_today` and `player_lifetime_spend`
   at **zero**. If the stake counts, the $3 lifetime gate is clearable for
   $0.0128 — 234× cheaper — and both §2.6 measures are void.
5e-i. **A free hop gives no spend credit either.** Twenty-two free hops must
   leave both spend counters at zero, so free play alone can never clear the gate.
5f. **New-wallet rates.** A wallet below `lifetimeSpendThreshold` that *has*
   cleared the daily threshold credits `0.5e18` per hop and `9e18` participation.
   Cross **$3** lifetime and the same actions credit `1e18` and `18e18`.
5g. **Rates resolve to the lowest value; they do not compound.** With a new wallet
   that is also below the daily spend threshold, a hop credits **`0.15e18`** — the
   lower of the new-wallet rate (`0.5e18`) and the below-threshold rate — and
   participation credits **nothing**. Assert the credited amount directly. Two
   wrong answers to rule out: `0.5e18`, from applying new-wallet status and
   ignoring the daily gate, and **`0.075e18`**, from multiplying the two rates
   together. Only one multiplier, the soft cap, may ever be applied, and only
   after the rate is resolved.

   **Do not sanity-check this one by eye.** `0.15` is what the *old* multiplier
   scheme produced from `0.5 × 0.3`, so the correct answer here looks exactly like
   the bug the absolute-rate design was introduced to prevent. Compare against the
   stored `hopRewardBelowThreshold`, not against a remembered figure.
6. **Spawning pays nothing.** A spawn credits `0` — free or paid, first of the
   day or fifth. Confirm no daily or streak reward exists on any path.
7. **Unfunded — the important one.** With the contract holding **no ROZ**:
   - `hide_treasure`, moves and spawns all still **succeed**, and pending stays
     at zero. A `RewardTokenAccrualSkipped` event fires each time.
   - **`claim_reward` still pays USDC in full.** Check the player's USDC balance
     rises by `4,987,167` with an empty ROZ balance. This is the behaviour the
     whole design exists for.
   - `claim_reward_tokens` with a zero pending balance is a no-op, not a revert.
8. **Partially funded.** Fund the contract with less than one hide reward
   (say `50e18` against a 70 ROZ reward) and confirm the credit is refused
   outright rather than partially applied — pending stays at zero.
9. **Claim.** With the contract funded: a surviving hider's pending rises by
   `50e18`, a finder's by `110e18`. `claim_reward_tokens` then transfers the lot
   and zeroes the balance.
10. **The retry path — the point of §4h.** In order:
    - With **zero** ROZ in the contract, call `claim_reward(K)`. USDC pays in
      full; `get_reward_token_claimed(K, player)` is still `false`.
    - Call `claim_reward(K)` again — it must revert with `'Reward already claimed'`,
      proving the USDC leg is not repeatable.
    - Call `claim_reward_token_for_week(K)` while still unfunded — it must revert
      with `'Reward token not funded yet'`, and the flag must stay `false`.
    - Fund the contract, call it again — it succeeds, the flag flips to `true`,
      and pending rises by the right amount.
    - Call it a third time — it must revert with `'Reward token already claimed'`.
    - `claim_reward_tokens` then withdraws the balance.
11. **The invariant.** After any sequence of actions,
    `get_reward_token_coverage()` must always return `pending <= balance`. Try to
    break it: fund, accrue to exactly the balance, then act again — the next
    credit must be refused.
12. **Claim state is observable (§4i).** `get_claimed_reward(K, player)` is
    `false` before `claim_reward(K)` and `true` after. Walk all four combinations
    of the two flags and confirm the getter pair reports each one correctly — in
    particular the `(true, false)` retry state.
13. **Events fire with the right payloads.** `RewardClaimed` on the USDC claim;
    `RewardTokenAccrualSkipped` on every credit refused while unfunded;
    `RewardTokenClaimed` when the §4h retry finally lands;
    `RewardTokensWithdrawn` on withdrawal. Check `user`, `gameWeek` and the
    amounts, and that a full round can be reconstructed from the event log alone
    without reading storage.
14. **The sweep guard (§4j).** With players holding pending ROZ, call
    `withdraw_token_balance(<ROZ>, owner)` — it must move only the surplus and
    leave `total_reward_token_pending` fully covered. Then confirm
    `claim_reward_tokens` still pays every player in full. Sweeping an unrelated
    token must move its entire balance, since the guard applies only to the
    configured reward token.
15. **The taper.** Call the rate setters with the year 2 column from §4b-i and
    confirm each getter reflects it, and that a subsequent hide credits `22e18`
    rather than `30e18`.
15a. **The new prices (§2.3).** `get_finder_player_fee()` returns `10000` and
    `get_generate_position_fee()` returns `100000`. `get_hider_player_fee()` is
    **unchanged** at `5000000` — it is a stake, not a fee. A claim still pays
    `4987167`, proving the 10× cut touched only hops and spawns.
16. **Free allowances (§4l) — the onboarding test.** From a wallet holding **no
    USDC and with no approval granted**:
    - `finder_player_generate_position` **succeeds** on the first spawn of the
      day. If it reverts with `'token spend approval req'`, the assert was not
      moved into the paid branch and the whole feature is unreachable.
    - The second spawn that day **does** revert for lack of approval, proving the
      allowance is 1.
    - Hops succeed and move the player, with no USDC leaving the wallet.
    - `get_free_hops_remaining` counts down from 22; at zero the next hop reverts
      for lack of approval rather than silently doing nothing.
    - Fund and approve the same wallet, then confirm the next hop charges exactly
      `10000` units ($0.01) and the next spawn `100000` ($0.10).
17. **Free and paid differ only in cost (§4l-i).** From the zero-balance wallet:
    - After 22 free hops in one round, pending ROZ is exactly **`3.3e18`** —
      `hopRewardBelowThreshold` on every free hop, because free hops add nothing
      to the spend counters and the wallet is below $0.60. A free hop earns
      exactly what a *paid* hop by the same wallet would earn — the rate is set by
      the gate, never by whether the hop was charged for.
    - **Participation does not fire**, for two independent reasons: the wallet is
      below the daily spend threshold, and 22 hops is below the 28-hop minimum.
      This is the cap on zero-cost farming and the most important assertion here.
    - Fund the wallet and hop up to 65. Once `player_spend_today` reaches
      `600000`, subsequent hops credit `1e18` and participation credits `18e18`
      once. Earlier hops are **not** retroactively upgraded — assert that too, so
      the implementation is not tempted to recompute the day.
    - The 40-hop cap counts free hops: hop 41 earns nothing. Free hops must not
      buy extra capped hops.
    - The free **spawn** credits nothing, and neither does a paid one.
17a. **Bulk hiding (§4m).**
    - `hide_treasure_bulk(5000000)` behaves exactly like `hide_treasure` — one
      share, `30e18` accrued.
    - `hide_treasure_bulk(50000000)` gives 10 shares and `300e18`, in one
      transaction, with exactly one transfer of `50000000`.
    - `hide_treasure_bulk(7000000)` reverts with `'not a multiple of hider fee'`.
    - **`hide_treasure_bulk(1000000000)` — the $1,000 case — succeeds**, giving
      200 shares. It must *not* consult `main_game_grid_size`: the target round
      has none yet, so any grid read would return zero and revert. See §4m-i.
    - Exceeding `maxTreasuresPerRound` reverts with `'round treasure cap'`.
    - Gas for a 200-treasure bulk is within a few percent of a single hide,
      proving there is no hidden loop.
17a-i. **Dynamic scaling (§2.4).** After 200 hides in a round, the keeper sizes
    the next round at ~126×126 for K=2.0. Confirm `get_game_grid_size(nextRound)`
    reports it, that a spawn lands inside it, and that a move to `127` reverts
    with `'out of game board range'`. Then confirm `TreasureFound` fires on a
    validated find carrying a plausible `hopsTaken` — without it K has no input.
17b. **The deduction scales (§4m-ii).** A 1-share claim still pays exactly
    `4987167`. A 10-share claim pays `49871670`, **not** `49987167` — per
    treasure, not per claim.
18. **The daily reset.** Spend the full hop allowance, advance past midnight UTC,
    and confirm it is restored — and that spending it in round 1 leaves nothing
    for rounds 2 to 4 that same day, proving the bucket is daily and not
    per-round.

## 8. Out of scope

Making ROZ mintable (fixed supply by design), any USD valuation or price oracle,
the Ekubo pool, and staking or in-game spending of ROZ.

## 9. Open questions

### Settled

- ~~Hop cap and participation minimum~~ — **40 and 28**. All four allowance and
  limit settings are summarised in one table in §2.2.
- ~~The hop cap contradicts the 35–45 hops-per-find target~~ — **resolved by the
  cap of 40**, which sits inside the band. See §2.4.
- ~~Should reductions be multipliers?~~ — **no, absolute rates** (§2.6 rule 2).
  0.15 and 0.5 ROZ per hop, 9 or nothing for participation. The soft cap is the
  only multiplier left.
- ~~Do the targets or the rates need revisiting?~~ — **the targets** (§2.2), on
  the principle that an expectation is cheaper to change than a live anti-farm
  parameter. The bands became **25–70 / 140–280 / 300–500** and Year 1 headroom
  rose to 4,700–16,700 daily actives. The principle stands; the arithmetic under
  it has since changed — see the reopened question below.
- ~~Zero-cost wallets earn more than they used to~~ — **resolved** (§4l-i-a).
  `hopRewardBelowThreshold` at **0.15** puts zero-cost yield at **3.3 ROZ/day**
  and the wallets needed to drain Year 1 at **709,838** — 21% more than the
  original pre-gate settings required, so this route is now the tightest it has
  been. The free allowance stayed at 22; the rate did all the work.
- ~~Is the claim-time ROZ lost or retryable?~~ — **retryable**, §4h.
- ~~Does the daily reward outweigh the core loop?~~ — **no.** At a maximum of 22
  it now sits below a find (110) and a completed hide cycle (80).
- ~~Do the rates taper across years 2 to 4?~~ — **yes**, §4b-i.
- ~~What happens after year 4?~~ — a **6% tail**, released across years 5 to 8.
- ~~Is a round a week?~~ — **no, 6 hours.** Capacity figures rebuilt in §2.2.
- ~~Deploy the token on its own first?~~ — **yes**, phase 1 of §5.

### Still open

- **Rollover automation (§4k) is the biggest one.** 1,460 `start_new_game` calls
  a year, each with eight unvalidated positional arguments, cannot be done by
  hand. A keeper or an `advance_round()` is needed before launch.
- **Ending a round early** once all treasures are found — detectable today via
  `total_reward_shares_for_hiders`, but acting on it is new behaviour.
- **Does `rewardPerHop` stay at 1 through the taper**, or drop to fractional
  values from year 2? See the wrinkle in §4b-i.
- **Is 4,700–16,700 daily actives the right year 1 ceiling?** That is what the
  rates and the 855M tranche imply together under the revised bands (§2.2) — the
  old bands implied 4,000–13,000. Exceeding it exhausts the tranche early and
  stops all new rewards until the next release.
- **Sweeping USDC still strands outstanding claims** (§4j). Pre-existing, not
  fixed here, and worth a decision since the function is being changed anyway.
- **Farming break-evens, corrected for non-retroactivity** (§4l-ii). The cheapest
  gate-clearing wallet costs **$0.615/day** and yields **28.6 ROZ** — break-even
  at **$0.0215/ROZ**, a **$107M** market cap at 5B supply. ~81,904 wallets would
  drain the Year 1 tranche for ~$50,371/day. At $107M this is a distant risk
  rather than a live one; the earlier $37M figure came from crediting all 65 hops
  at the full rate, which §2.6 forbids.
- **The hide loop is the exposure the gate never addressed** (§4l-ii). No measure
  in §2.5 or §2.6 touches a hide: all three hide and find rewards pay in full
  above and below the threshold, and the stake is excluded from spend by rule 1.
  Its cost is `P(found) × $5` plus the claim deduction, so it ranges from
  **$0.0192/ROZ in a healthy game** — a $96M cap, comparable to the hop route —
  down to **$0.00016 in a dead round**, a $0.8M cap. **The risk is a farmer
  choosing quiet rounds, not a permanently cheap route.** Gas does not constrain
  it either: bulk hiding drains Year 1 in ~147 transactions a day against ~5.3M
  for the hop route. Two things bound it and neither is settled — the §4m-ii
  per-treasure deduction, and `maxTreasuresPerRound`, below.
- ~~The free allowance costs an earning player money~~ **Resolved** — free hops
  are now identical to paid hops apart from the charge (§4l-i).
- **`hopRewardBelowThreshold` is not a farmer-only lever** (§2.2, §4l-i-a). It was
  lowered to 0.15 to close the zero-cost route, which it did. But because every
  calendar day starts at zero spend, it is also the rate *every* wallet earns on
  its opening stretch — 54 hops for a typical casual, 59 for an active player.
  Halving it took 8.1 and 8.8 ROZ off those two profiles. Any further move down
  should be weighed against that, or paired with a lower `dailyFreeHops`, which
  touches only wallets inside the allowance.
- ~~Should a free spawn earn the daily reward?~~ **Settled: spawning pays
  nothing**, free or paid. Free and paid now differ only in cost, everywhere.
- **The daily and streak retention layer no longer has a trigger.** It was
  attached to the spawn. Removing the spawn reward removed it, along with
  `player_last_spawn_day` and `player_streak_days`. Either accept that the game
  has no retention reward, or move the trigger to the player's **first hop of the
  day** — which needs the same day-index state and keeps spawns reward-free as
  decided. The nine-row streak table is preserved in git history if it returns.
- **No player type meets its target — reopened** (§2.2). The bands were lowered to
  25–70 / 140–280 / 300–500 against figures that credited every hop at the full
  rate. Correcting for non-retroactivity puts the light casual at **6**, the
  typical casual at **114.1** and the active player at **285.9** — all three below
  their floors again. Non-retroactivity is the larger cause (−37.8 and −41.3);
  the halved below-threshold rate adds −8.1 and −8.8. The options are the same as
  before, but the choice has to be made again: lower the bands a second time,
  raise `hopRewardBelowThreshold` back up, or lower `dailySpendThreshold` so
  players cross sooner. Lowering the threshold is the only one of the three that
  helps the light casual, and it is also the one that weakens the gate.
- ~~Progressive pricing makes distributed farming cheaper~~ **Addressed by §2.6.**
  The daily spend threshold takes the cost of draining Year 1 from $2,292/day to
  **$50,371/day**, and the $3 lifetime threshold adds a **$245,712** one-off
  onboarding barrier.
- **Earnings depend on the order a player takes their actions** (§2.6). Spend
  accrues in action order, so a player who spawns at the start of a round crosses
  $0.60 sooner — and earns more — than one who takes identical actions in a
  different order. All the figures in this plan assume spawns first. The effect
  is small and invisible to the player, but it is real, and a UI that recommends
  "spawn first" would be giving genuine mechanical advice. Either accept it, or
  settle the day's rate once at a fixed point rather than per action.
- **Participation must be tested on both conditions, every hop** (§4f). Crediting
  it at the 28th hop and no later would deny it outright to any player who reaches
  28 hops before $0.60 of spend — which the modelled typical casual does, at
  $0.145. That is 18 ROZ, silently. Recorded as a rule rather than an open
  question, but it is the kind of thing that gets implemented the other way.
- **The light casual is the furthest below band** (§2.6). At 40 hops and $0.265
  daily spend they never clear the $0.60 threshold and earn **6 ROZ** against a
  target of 25–70. A light casual and a small farmer are indistinguishable by
  spend, so the gate cannot separate them — and raising the threshold from $0.50
  to $0.60 moved this player further from clearing it. Options: accept it on the
  basis that one instant hide reaches 36 ROZ (below), lower the threshold, raise
  `hopRewardBelowThreshold` back above 0.15, restore a reduced participation bonus
  below the threshold rather than withdrawing it, or exempt a wallet's first N
  days.
- **The below-gate band is only reachable by hiding** (§2.2, §2.6). Hopping caps a
  below-gate wallet at **9.6 ROZ** — 64 hops for $0.595, the most that can be
  spent without crossing $0.60 — so the 25–70 band cannot be reached on hops at
  all, and lowering the rate to 0.15 put it further out of reach. It needs an
  instant hide (30), which pays full below the threshold and takes the modelled
  light casual to **36 ROZ**. That makes the band coherent, but it routes the
  lightest players onto the hide loop — the one route no anti-farm measure reaches
  (§4l-ii), and the cheapest farming route in the game in quiet rounds at
  **$0.00016/ROZ**. Either confirm that "expect a light casual to hide" is the
  intended shape of the band, or raise the below-threshold hop rate so hops alone
  can reach 25. **Whatever bounds the hide loop will also land on this player.**
- **Is $3 lifetime too low?** It buys a **$245,712** onboarding barrier where $5
  would buy $409,520. Halving the threshold roughly halves the strongest anti-churn
  lever in the plan, so this should be a deliberate choice rather than a default.
  Both figures rose with the corrected wallet count, but the ratio did not: the
  barrier is still about 4.9 days of running cost. The daily threshold sets where
  the casual cliff falls; the lifetime one sets the farm's onboarding cost.
- **The round cap and the soft cap fight at the top, and neither reaches the
  honest player** (§2.5). `hopRewardCap` at 40 implies a 178-ROZ ceiling, but
  non-retroactivity puts the reachable total at 136.35 on the natural route, and
  an honest active player only reaches **95.85** — under a soft cap of 100 and
  nowhere near the round cap. So the 40-hop cap buys the player §2.4 was worried
  about nothing at all. Either accept that both caps are aimed at the top of the
  range only, or revisit §2.4's fix.
- **Should crossing a threshold mid-day upgrade earlier actions?** The plan says
  **no** (§2.6): rates apply from the crossing onward. Retroactive upgrade would
  be friendlier to a player who ends the day just over $0.60, but it needs a day
  replay or an end-of-day true-up, and it would let a farmer bank cheap hops and
  upgrade them.

  **This is no longer a minor decision.** It is worth ~55 ROZ/day to the cheapest
  farm wallet — the difference between 28.6 and 83 — and 37.8 to a typical casual.
  It is the single largest lever in the gate, larger than the $0.60 threshold
  itself, and every figure in the plan now depends on it. Reversing it would put
  the farming break-even back to $0.00741/ROZ, a $37M market cap, and would also
  lift all three player profiles back into their bands. Both effects are large and
  they pull in opposite directions.
- **Measure 3 only reduces players who spend** (§2.6). A light casual is already
  at the measure-1 floor, so new-wallet status costs them nothing extra — the
  reduction lands on the mid-range player instead. Confirm that is intended.
- **Is measure 4 worth its centralisation?** A `player_verified` flag needs an
  attestor — a new privileged writer, and a target once ROZ has value.
- **The gate costs gas on every paid action** — two extra `u256` writes per hop
  and per spawn, on a path players take dozens of times a day.
- **How much anti-farm work is gas already doing?** 65 transactions per wallet per
  day against $0.615 of game fees on the cheapest gated route. The gate has closed
  much of the gap the ungated case had, but gas may still be the binding
  constraint. Worth measuring before tuning the tiers further.
- **What should `dailySoftCapRoz` be?** The reachable daily hops-plus-participation
  total is **136.35** on the natural route, and 178 only for a wallet that clears
  $0.60 before hopping, so 150–160 barely binds. Near 100 still does the most
  work — though as noted above, an honest active player at 95.85 now sits just
  under it, so a cap of 100 catches almost nobody it was aimed at.
- **Is the typical casual paying 36% more acceptable?** At 60 hops/day the tiered
  schedule costs $0.515 against $0.38 flat, and that player now earns **below**
  their band (114.1 against 140–280) rather than near the bottom of it.
- ~~Is a 14×14 grid big enough for bulk hiding?~~ **Resolved by §2.4** — the grid
  is now sized from the hide count (`T × 40 × K`), so it grows to fit. The $1,000
  case produces a ~126×126 board.
- **What are the hard grid bounds, and therefore `maxTreasuresPerRound`?** (§2.4,
  §4m-i) The minimum and maximum grid size and the treasures-per-1,000-cells cap
  are stated as principles but not as numbers. `maxTreasuresPerRound` is derived
  from them, so it cannot be set until they are. **This is now the binding
  question for the hide loop, not just a grid-sizing detail** — §4l-ii shows a
  farmer needs ~7,320 hides in a round to drain Year 1, and this cap is the only
  thing in the design that could refuse them.
- ~~The hop reward cap contradicts the hop target~~ **Resolved** (§2.4). The cap
  is now **40**, inside the 35–45 hops-per-find band. But see the soft-cap
  conflict above — the daily cap can still clip those hops.
- **What is K's starting value?** The band is 1.8–2.5 and moves ±0.15 a round, so
  a bad opening value takes several rounds to correct — during which the map is
  visibly too dense or too sparse.
- **Should hiding be genuinely free?** The plan calls it free, but a surviving
  hider gets back `4,987,167` of their `5,000,000` stake — the contract retains
  12,833 units (~$0.0128) on every claim. With hop and spawn revenue down 92%,
  those retentions are now a much larger share of income, so removing them is not
  free either.
- **Should the allowance cover full participation?** It deliberately does not:
  28 hops are needed against a 22-hop allowance, so 6 hops (~$0.045) must be paid
  for. Since the bonus now pays once per calendar day, that is the whole cost —
  not the $1.00/day a per-round bonus demanded. The gap is no longer the binding
  constraint either, since §2.6's $0.60 threshold withdraws the bonus outright
  below it. Closing the gap alone would not reopen the hole.
