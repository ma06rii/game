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
| Instant hide | **30** | Paid immediately on a successful hide. Falls to **4.5** below the §2.6 daily spend threshold, or 15 for a new wallet, and is then scaled by the **Daily Volume Multiplier** — §2.3 |
| Hide survives a full active round | **50** | Credited at the end of the next round if unfound. Full hide cycle ≈ 80. Falls to **7.5** below the threshold, or 25 for a new wallet, **fixed at the rate in force when the hide was placed** — §4f |
| Find / steal a treasure | **110** + ~$5 USDC | Highest single reward, and **the only one that pays in full to everyone**. Never reduced by either §2.6 measure — see below |
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
| Daily free hops | `dailyFreeHops` | **20** | Per calendar day, shared across all four rounds | Waives the USDC fee for a player's first 20 hops |
| Participation minimum hops | `participationMinimumHops` | **28** | Per calendar day — the bonus pays once daily | Puts the 18-ROZ bonus out of reach of free hops alone |
| Per-round hop cap | `hopRewardCap` | **40** | Per **round** | Stops grinding within a single round |
| Daily free spawns | `dailyFreeSpawns` | **1** | Per calendar day | One free repositioning a day |
| Soft warning threshold | *(none — UI only)* | ~36 hops | Per round | Warns a player they are near the cap. No contract effect |

**Two orderings carry the design, and neither may be broken:**

1. **`dailyFreeHops` (20) < `participationMinimumHops` (28).** The bonus can never
   be reached on free hops alone — see §4l-i-a.
2. **`participationMinimumHops` (28) ≤ `hopRewardCap` (40).** The bonus needs 28
   of a possible 40 — **70% of a round**, so participation is demanding without
   requiring a near-perfect round.

The gap is 8 hops, which cost **$0.055** at the §2.5 tier prices. That gap alone
is no longer the real guard on participation: **the $0.60 daily spend threshold in
§2.6 is**, because the bonus is unavailable below it however many hops are made.
The ordering is now defence in depth rather than the whole defence.

### The intended hierarchy

1. **Find / steal** — clearly the best single action
2. **Successful hide** (instant + survival) — strong and satisfying, and now
   gated: 80 for a wallet that has cleared the daily spend threshold, 12 for one
   that has not. **The first three hides of a day pay in full; the fourth onward
   is scaled down steeply** (§2.3), so this position holds for a player and not
   for a farm
3. **Participation** — meaningful but secondary. It needs 28 of a possible 40
   hops, and a wallet that has cleared the §2.6 daily spend threshold
4. **Per hop** — the light drip that rewards exploration itself

There is no longer a retention layer. It sat at position 4 and was triggered by
the daily spawn, which now pays nothing.

**Find/steal is deliberately the one reward the gate never touches.** Both §2.6
measures leave it at 110 for everyone. Finding is the only action a player cannot
perform against themselves — it needs somebody else's hidden treasure, and it
takes that hider's stake — so it cannot be farmed in a closed loop the way hopping
and hiding can. Keeping it whole also keeps the incentive to *clear* the board,
which is what limits the hide loop (§4l-ii). Reducing it would weaken the one
mechanic working against the plan's largest farm exposure.

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

Three modelling conventions, all stated because they change the answer:

- **Spend accrues in the order actions are taken**, and within each round the
  spawn is taken before that round's hops. This is the player-favourable
  ordering — see the ordering note below.
- **The participation bonus fires at the first action where *both* conditions
  hold**, 28 hops and $0.60. See §4f.
- **A hide is placed after the wallet has crossed the threshold.** Since §2.3 the
  hide rewards are gated too, so this convention is worth 68 ROZ to a typical
  casual — see the ordering note.

| Player | Round pattern | Hops | Daily spend | Crosses at | **Established** | **New wallet** | Target |
|---|---|---|---|---|---|---|---|
| Light casual | 2 rounds × 20 hops, no hide | 40 | $0.275 | **never** | **6** | **6** | 25 – 70 |
| Light casual **+ 2 hides** | 2 rounds × 20 hops | 40 | $0.775 | hop **33** | **≈55** | ≈55 | 25 – 70 |
| Typical casual | 2.5 rounds × 25 hops | 62 | $0.965 | the **round-3 hide** | **117.5** | **62.5** | 140 – 280 |
| Active | 4 rounds × 32 hops | 128 | $3.645 | hop **59** | **286.7** | **202.7** | 300 – 500 |

Established figures include one hide cycle for the casual and active players and
one find for the active player. Days to leave new-wallet status at a $3 lifetime
threshold: active **1**, typical casual **4**, light casual **12** — or **5** for
a wallet that only hides, at $0.20 a hide and 3 a day.

Worked, for the typical casual: 50 hops before the crossing at 0.15 (**7.5**), 12
after it at 1.0 (**12**), participation (**18**), a full-rate hide cycle (**80**).

**Established players are barely affected by the §2.3 hide changes.** The typical
casual *gains* 3.4 ROZ, because the $0.20 hide fee counts as spend and brings
their crossing forward; the active player is unchanged and pays $0.20 more. The
new-wallet column falls, which is what new-wallet status is for.

**Two of the three profiles still miss their band**, and that predates these
changes. The bands were set against older figures that assumed a retroactive
crossing:

| Player | As first stated | Non-retroactive at 0.3 | At 0.15 | **With gated hides** |
|---|---|---|---|---|
| Light casual | 12 | 12 | 6 | **6** (≈55 with 2 hides) |
| Typical casual | 160 | 122.2 | 114.1 | **117.5** |
| Active | 336 | 294.7 | 285.9 | **286.7** |

**Most of the drop was the non-retroactivity correction, not any rate change.** It
cost the typical casual 37.8 ROZ and the active player 41.3; the halved hop rate
added 8.1 and 8.8; gating the hides gave 3.4 back to the typical casual. Either
the bands come down again or a rate has to rise — see §9.

**A light casual who hides twice now lands inside their band**, at roughly 55 ROZ.
That is new: two hides cost $0.40 in fees, which combined with their hop and spawn
spend carries them over $0.60 at hop 33, after which everything pays full. The
route into the band changed shape — it used to be one instant hide at the full 30,
and it is now two hides that clear the gate. One hide alone leaves them at 18,
still short.

**`hopRewardBelowThreshold` is not a farmer-only parameter.** Because every day
starts at zero spend, *every* player earns this rate on their opening stretch —
the first 50 hops for a typical casual, 58 for an active player. §4l-i-a treats it
as the lever that sets zero-cost sybil yield, which it is, but it also sets the
opening of every honest day. Tune it with both in view.

**Earnings depend on the order actions are taken, and hiding made that much
sharper.** A player who spawns at the start of a round crosses $0.60 sooner, and
so earns more, than an identical player who spawns at the end. That was worth a
few ROZ. Now that hide rewards are gated too, **the same typical casual earns
117.5 hiding in round 3 and 50.35 hiding in round 2** — a 67-ROZ swing on nothing
but ordering, because a hide placed before the crossing is worth 12 instead of 80
and the snapshot rule (§4f) makes that permanent. Nothing in the contract is wrong
here; it follows directly from non-retroactivity. But it is invisible to the
player, it is now the largest single ordering effect in the game, and a UI that
says "hide once you have spent $0.60" would be giving real mechanical advice. See
§9.

Three further causes sit behind the light casual's 6, all deliberate individually:

- **The §2.6 daily spend threshold**, which the light casual never clears. Their
  hop rate falls to 0.15 and participation is withdrawn entirely. An ungated day
  would pay them 58 (40 hops + 18); they get 6, and the threshold accounts for
  the whole 52-ROZ difference.
- **The daily spawn reward is gone**, removing a floor that did not depend on
  effort.
- **Participation now pays once a day, not four times**, which costs the active
  player 54 ROZ on its own.

### The below-gate band is now reachable, but not by hopping

The light casual band is explicitly a *below the gate* band, so it is worth
checking that it is reachable there. On hops alone it is not:

| | |
|---|---|
| Most a wallet can spend and stay under $0.60 | **$0.585 — 63 hops** |
| ROZ from those hops at the below-threshold rate | 63 × 0.15 = **9.45** |
| Participation | **None** — withdrawn below the threshold |

**9.45 ROZ is the ceiling on a below-gate day of hopping**, and the band starts at
25. Hop 64 costs $0.605 and crosses the gate, at which point the player is no
longer a below-gate player at all.

**Mixing in hides raises that ceiling to 30.3, which clears the floor.** Two hides
cost $0.40 in fees, leaving room for 42 hops before $0.60:

| | ROZ | Spend |
|---|---|---|
| 2 hide cycles at the below-gate rate (4.5 + 7.5 each) | 24 | $0.40 |
| 42 hops × 0.15 | 6.3 | $0.185 |
| Participation — still withdrawn | 0 | — |
| **Total, staying under the gate** | **30.3** | **$0.585** |

So a below-gate player can reach the bottom of the band, at 30.3 against a floor
of 25. This is a change from the previous position, which recorded the band as
structurally unreachable below the gate — gating the hide rewards *reduced* the
per-hide payout but the $0.20 fee also made hiding a way to spend, and on balance
the ceiling rose from 9.6 to 30.3.

The alternative, and the better outcome for the player, is simply to cross:
**two hides carry the modelled light casual over $0.60 and to roughly 55 ROZ**,
comfortably inside the band, because everything then pays full. One hide leaves
them at 18 — below the floor, and below the 30.3 a deliberate below-gate day
would give them. **The worst place to be is halfway.**

This is what the band now means: **a light casual is expected to hide, not merely
to hop.** The collision that used to sit here is much smaller than it was. Hiding
was previously the one action no anti-farm measure reached, which made the route
into the band and the plan's cheapest farm route the same *ungoverned* mechanic.
§2.3 and §2.6 now gate hiding as well, so the two share a mechanic but no longer
share an exposure — §4l-ii puts the hide loop's floor at $23.1M rather than
$0.8M. Anything further done to bound the hide loop will still land on this
player, so keep the two in view together. See §9.

Two structural points worth stating rather than leaving to be discovered:

**The two gates overlap at the bottom and leave a gap in the middle.** A light
casual is already at the floor from the daily threshold, so new-wallet status
costs them nothing further. New-wallet status therefore only bites players who
*do* spend — the opposite of what its name suggests.

**Raising `hopRewardCap` to 40 still does not help an honest active player**, but
the reason has changed. Non-retroactivity puts their hops-plus-participation at
**96.7**, just under a `dailySoftCapRoz` of 100 — so the soft cap no longer
clips them, and the round cap does not bind either. The 40-hop cap buys them
nothing because they never get near the ceiling it raises. See §2.5.

Meanwhile the active player's hop fees are $3.145 against $1.38 before §2.5:
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
| Hide treasure | **$0.20 / $0.25** + a $5 stake | `hideFeeBase` **`200000`**, `hideFeeHigh` **`250000`**, `currentHiderFee` unchanged at `5000000` | **Max 10 a day.** The fee is never returned; the $5 is staked |
| Single hop | **$0.005 – $0.04** | tiered — see §2.5 | 20 free per day; the price rises with daily volume |
| Spawn new position | **$0.10** | `currentSpawnNewPositionFee` `1000000` → **`100000`** | 1 free per day |

**The hop price is no longer flat.** `currentFinderFee` is replaced by the tier
schedule in §2.5. The comparisons in this section use the $0.01 tier, which is
what a player pays for hops 26 to 45 — the band most ordinary play sits in.

Hop and spawn fees fall roughly **10×** against the old $0.10 and $1.00.

### Hiding is no longer free, and volume is priced

Three mechanisms, all aimed at §4l-ii's hide loop — the route no other measure
reached. Together they let an ordinary player hide freely while making volume
uneconomic:

| Setting | Value | Storage |
|---|---|---|
| Hide fee, treasures **1–3** of the day | **$0.20** | `hideFeeBase` `200000` |
| Hide fee, treasure **4 onward** | **$0.25** | `hideFeeHigh` `250000` |
| Fee tier boundary | **3** | `hideFeeTierBoundary` |
| Daily treasure cap | **10 per wallet per calendar day** | `dailyHideCap` |

**All limits count treasures, not transactions.** A bulk call of four counts four
against the daily cap and pays four fees — see §4m.

**The fee counts toward the §2.6 spend thresholds; the $5 stake does not.** The
fee is irrecoverable, so by §2.6 rule 1 it is spend. The stake is refundable, so
it is not. That distinction is what stops the gate being bought for nothing.

### The Daily Volume Multiplier

Hide rewards are scaled by how many treasures the wallet has **already created
today**, before the current one:

| Already created today | Multiplier | So it applies to treasure # |
|---|---|---|
| 0 – 2 | **1.00×** | 1, 2, 3 |
| 3 – 4 | 0.70× | 4, 5 |
| 5 – 6 | 0.40× | 6, 7 |
| 7 – 8 | 0.20× | 8, 9 |
| 9 – 10 | 0.08× | 10, 11 |
| 11+ | 0.03× | 12+ — whitelisted addresses only |

**It is keyed to the daily count, not the transaction size.** That distinction is
the whole point: an earlier draft scaled by how many treasures were in the call,
which a farmer sidestepped by sending ten single hides instead of one bulk call
of ten. Keying it to the day makes single and bulk hiding identical in yield, so
there is nothing to route around. §4l-ii shows what it is worth.

**Three settings deliberately meet at 3:**

```
hideFeeTierBoundary (3)  ×  hideFeeBase ($0.20)  =  dailySpendThreshold ($0.60)
                         ↑
        also the top band of the Daily Volume Multiplier
```

A player's first three hides therefore cost the cheap fee, pay the full
multiplier, and land them exactly on the spend threshold. **Three hides is the
designed shape of an ordinary hiding day**; everything past it is priced as
volume. §2.6 rule 1 states the invariant the setters must protect.

The stake is **at risk, not escrowed**. A finder who steals the treasure takes
it. And a surviving hider gets back `4,987,167` rather than the full `5,000,000`,
because the contract retains 12,833 units on every claim. So one of the first
three hides costs **$0.2128** all in if it survives, and $5.20 if it is found.

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

**20 free hops and 1 free spawn per day, shared across every round in that day** —
a single daily bucket, not a per-round one.

| Player | Gross | After allowance | Saved |
|---|---|---|---|
| Light casual (30 hops, 2 spawns) | $0.50 | **$0.20** | $0.30 |
| Typical casual (60 hops, 3 spawns) | $0.90 | **$0.60** | $0.30 |
| Active (128 hops, 4 spawns) | $1.68 | **$1.38** | $0.30 |

The saving is a flat **$0.30** for everyone, because the allowance is fixed —
worth 60% to a light casual and 18% to an active player.

### The allowance deliberately falls short of a full round

20 free hops against a 40-hop cap is **50% of a round**, not all of it. That is
the point: the participation minimum is 28 hops, so **the bonus can never be
reached on free hops alone**. A player has to make 8 paid hops to earn it — about
**$0.055** at the §2.5 tier prices.

That relationship — allowance below minimum — used to be the whole guard on
zero-cost farming. It no longer is: the §2.6 daily spend threshold withdraws
participation entirely below $0.60/day, so the 8-hop gap is now the weaker of the
two locks. Zero-USDC-fee yield is capped at **3 ROZ/day** — see §4l-i-a.

The free tier waives **$0.30 per day** per player who uses it in full, down from
$3.00 at the old prices.

Players may spread the 20 hops across several rounds, but pay $0.10 for each
spawn beyond the first.

**The allowance does far less work than the price cut.** Dropping hops to $0.01
saves an active player $15.12/day; the allowance saves $0.30 on top. Worth
weighing against the complexity in §4l — most of the anti-frustration win is
already banked by the new prices.

Here and throughout this plan, **free means no USDC game fee**. The player still
pays Starknet gas in STRK today. A future paymaster may sponsor at most these 20
hops, or a lower campaign cap: the effective fully sponsored allowance is
`min(20, campaignCap)`. For example, with a campaign cap of 15, hops 1–15 are
USDC-free and gas-sponsored, hops 16–20 remain USDC-free but the player pays
STRK gas, and hop 21 onward pays the tiered USDC fee plus gas unless separately
sponsored.

### Two interactions worth noting

**Participation costs more than the allowance covers — deliberately.** The bonus
needs 28 hops in the day, against a 20-hop allowance, so 8 hops must be paid for.
Since the bonus now pays once per calendar day rather than once per round, that is
8 paid hops in total — roughly **$0.055**, not the $1.00/day that a per-round
bonus used to demand.

That gap is not an oversight, but it is no longer the binding constraint. The
§2.6 daily spend threshold requires **$0.60** before participation pays at all,
which is more than ten times the cost of the 8-hop gap. Closing the gap would
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
- `K` — search inefficiency factor, band **1.8 – 2.5**, **starting at 2.2**

**K starts at 2.2**, mid-band and slightly toward the sparse side, on the
principle that a map which is too generous is harder to correct than one which is
too hard. It should be revisited once the first round's real `T` is known, which
will not be until close to launch.

The grid side therefore grows as **√T**:

| T (active treasures) | K = 1.8 | **K = 2.2** | K = 2.5 |
|---|---|---|---|
| 10 | 27×27 | **30×30** | 32×32 |
| 100 | 85×85 | **94×94** | 100×100 |
| 196 | 119×119 | **131×131** | 140×140 |
| 500 | 190×190 | **210×210** | 224×224 |
| 1000 | 269×269 | **297×297** | 317×317 |
| **2,840** — `maxTreasuresPerRound` | 452×452 | **500×500** | 533×533 |

**The last row sets the hard maximum grid size.** `maxTreasuresPerRound` is
**2,840** (§4m-i), so at the starting K the largest board the game can ever be
asked to lay out is `2,840 × 40 × 2.2 = 249,920` cells — **500×500**. That is
11.4 treasures per 1,000 cells, comfortably inside the density bound. Any
increase to `maxTreasuresPerRound` must be checked against the maximum grid the
front end and the merkle tooling can handle.

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

**`T` is now bounded at both ends, which is what makes K tractable.** No wallet
can place more than 10 treasures a day (250 a round if whitelisted), and no round
can hold more than **2,840** in total. So `T` moves within a known range instead
of following whatever any single participant chooses to spend, and the controller
never faces a step change it cannot absorb at ±0.15 a round. The formula does not
change; the inputs it has to cope with do. See §4m.

## 2.5 Progressive hop pricing and the daily soft cap

Five measures, aimed at making farming uneconomic without punishing ordinary
play. They work against a single large wallet. They do **not** close the
multi-wallet route — see the honest accounting at the end of this section.

### Progressive hop pricing

A hop costs more the more a wallet has hopped **that day**:

| Daily hop number | Price |
|---|---|
| 1 – 20 | **Free** (the §2.3 allowance) |
| 21 – 25 | $0.005 |
| 26 – 45 | $0.010 |
| 46 – 65 | $0.020 |
| 66 and beyond | $0.040 |

**The tiers must reset daily, never per round.** With per-round tiers a farmer
re-enters the cheap tiers four times a day: 32 hops in each of four rounds costs
**$0.35** instead of $3.145 — roughly **nine times cheaper**, which guts the
measure entirely.

### The crossover sits at 48 hops a day

Below it the new schedule is cheaper than the old flat $0.01; above it, dearer:

| Hops/day | Progressive | Old flat | |
|---|---|---|---|
| 30 | $0.075 | $0.10 | cheaper |
| 45 | $0.225 | $0.25 | cheaper |
| 46 | $0.245 | $0.26 | cheaper |
| 47 | $0.265 | $0.27 | cheaper |
| **48** | **$0.285** | **$0.28** | dearer |
| 60 | $0.525 | $0.40 | dearer |
| 128 | $3.145 | $1.08 | dearer |

That is the shape intended: light play gets cheaper, grinding gets dearer. Note
the typical casual at 60 hops/day now pays **31% more**, while earning near the
bottom of their revised band (§2.2).

### Participation once per calendar day

The 18-ROZ bonus is claimable **once per day**, not once per round. With four
rounds a day this alone cuts the maximum daily hop-and-participation yield from
232 ROZ to **178**.

### The daily soft cap

Beyond `dailySoftCapRoz`, further hop and participation rewards are multiplied
down — 0.2× or zero. Casuals never reach it; grinders do.

**Set to 136.** With `hopRewardCap` at 40 per round the theoretical maximum from
hops plus participation is `160 + 18 = 178 ROZ`, but non-retroactivity puts that
out of ordinary reach: depending on spawn timing, a wallet that hops its way to
the threshold spends its first 48–63 hops at 0.15. Taking four spawns first gives
the largest raw 160-hop result, **137.2 ROZ**, which the soft cap reduces to
**136.24 ROZ**.
The full 178 is only reached by a wallet that clears $0.60 *before* it starts
hopping — six paid spawns will do it for $0.60 — which is farm behaviour, not
play. See §2.6.

**136 is set just under that natural ceiling, and it is close to inert by
design.** Be honest about what it catches:

| Who | Hops + participation | Against a cap of 136 |
|---|---|---|
| Honest active player | 96.7 | never binds |
| Cheapest farm wallet (§4l-ii) | 46 | never binds |
| 160-hop maximising wallet | 137.2 raw | clips to **136.24** |
| Six-spawns-first route | 178 | clips to **144.4** |

So it exists to bound the bought-crossing route and nothing else. That is a
defensible thing for a backstop to do, but it should not be described as doing
work across the grinding band — the §2.3 hide limits and the §2.6 gate do that.

**At 136 the two caps no longer fight.** Raising `hopRewardCap` from 32 to 40 was
meant to stop an honest player earning nothing on the hops where a find becomes
likely (§2.4). A soft cap near 100 would have clipped that back at the daily
level; 136 sits close to the natural 137.2 ceiling, so the round cap's benefit
largely survives. Neither cap reaches the honest active player at 96.7 — which is the
point, not a defect.

### Free hops stay below the farm point

`dailyFreeHops` (20) sits below `participationMinimumHops` (28), so the bonus can
never be had for nothing. It is no longer the primary guard, though — §2.6's
daily spend threshold withdraws participation below $0.60/day whatever the hop
count. Keep the ordering as defence in depth; see §4l-i-a.

---

### What these measures actually achieve

**Against one large wallet, they work well:**

| | Before | After |
|---|---|---|
| Cost of a maximum day (160 hops, 4 spawns) | $1.68 | **$4.725** |
| Yield | 232 ROZ | **136.24 ROZ** |
| Break-even | $0.0072/ROZ | **$0.0347/ROZ** |

**About 4.8× more expensive.** A whale is meaningfully deterred. With four
spawns taken first, non-retroactivity charges the first 48 hops of the day at
0.15 and the soft cap reduces the raw 137.2 ROZ — see §2.6.

**Against many small wallets, they make matters slightly worse.** A wallet doing
just 28 hops — enough for participation, using the free spawn — never leaves the
two cheapest tiers, where hops cost **well under** the old flat rate:

| | Before | After |
|---|---|---|
| Cost per wallet | $0.06 | **$0.055** |
| Yield | 46 ROZ | 46 ROZ |
| Break-even | $0.00130 | **$0.00120** |
| Cost to drain Year 1 (~50,923 wallets) | $3,055/day | **$2,801/day** |

Progressive pricing punishes **concentration** and rewards **distribution**, and
wallets cost nothing to create. So the farmer's answer is simply more wallets,
each staying in the cheap tiers.

**What actually constrains the distributed attack is gas.** Twenty-eight hops plus
a spawn is 29 transactions per wallet per day, against $0.055 of game fees. At any
plausible Starknet price the gas bill is many times the fees — so gas, not the
fee schedule, is doing the anti-farm work. That is worth **measuring** rather
than assuming, since it also sets the floor on what honest play costs.

Closing the distribution route needs a different kind of lever — a per-wallet
minimum spend, gating rewards on a funded balance, or proof of humanity. **That
is what §2.6 adds**, and it takes the cost of draining Year 1 from $2,801/day to
$49,813/day.

---

## 2.6 The Lightweight Gate

Three measures aimed at the one thing §2.5 could not reach: many small wallets.
The principle is that **full rewards are earned by players who actually spend**,
while free play stays open to everyone.

### The three measures

1. **A daily spend threshold.** Full hop and participation rewards require a
   wallet to have spent **≥ $0.60** in game fees that day. Below it, rewards are
   reduced.
2. **Free hops and the free spawn stay available to everyone.** Onboarding is
   unchanged — anyone can play immediately, they simply earn at a reduced rate
   until they spend.
3. **New wallets earn reduced rates** until they reach a **lifetime** spend of
   **$3**.

**A fourth measure — a proof-of-humanity bonus for a wallet with linked social —
was considered and rejected.** It needed somebody to sign attestations, which is
a new privileged writer and a target once ROZ has value, and it bought little
that the three spend-based measures do not already deliver. The `player_verified`
flag and `verifiedBonusNum`/`Den` are **not** in the design.

One related privilege does exist: the owner-controlled **bulk-hide whitelist**
(§4m-iii). It is a different kind of thing — it grants no ROZ bonus, only higher
hide limits, and the owner is already privileged for every setter in §4b — but
the reversal is worth seeing rather than inferring.

### The rates

Rates are stated as **absolute values**, not as multipliers of the base rate.
That is deliberate — see rule 2 below.

**Measure 1 — below $0.60 spent today:**

| Reward | Below $0.60 | $0.60 or more |
|---|---|---|
| Per-hop ROZ | **0.15** | **1.0** |
| Participation bonus | **Not available** | **18** |
| Instant hide | **4.5** | 30 |
| Hide survives | **7.5** | 50 |
| Find / steal | **110 — full** | **110 — full** |

**Measure 3 — a wallet is *new* until $3 of lifetime spend:**

| Reward | New wallet |
|---|---|
| Per-hop ROZ | **0.5** |
| Participation bonus | **9** (half of 18) |
| Soft daily cap on hops + participation | **80 ROZ** |
| Instant hide | **15** |
| Hide survives | **25** |
| Find / steal | **110 — full** |

**Find/steal is the one line neither measure reduces.** A find needs somebody
else's hidden treasure and takes that hider's stake, so unlike hopping and hiding
it cannot be run as a closed loop against yourself. It is also the mechanic that
bounds the hide loop — every find is a farm hide that did not survive (§4l-ii) —
so reducing it would weaken the plan's own defence. See §2.2.

**Hiding joined this table in §2.3**, along with a tiered fee and a 10-a-day cap.
Before that change no measure in the plan touched a hide at all. The hide rows
above are the **wallet rate**; the §2.3 Daily Volume Multiplier is then applied to
whichever of them resolves — see rule 2.

New-wallet status is left permanently once $3 of lifetime spend is reached. Both
thresholds count **spend**, which §2.6 rule 1 below defines narrowly.

**Rates apply from the moment the threshold is crossed, not retroactively.**
**Settled** — §9. A player who reaches $0.60 on their 64th hop earns 0.15 on hops
1–63 and 1.0 from hop 64 onward. Recomputing the day would mean either replaying
every hop or storing enough to true up at day end — real complexity for a modest
gain, and it would let a farmer bank cheap hops and upgrade them later. The
alternative was weighed explicitly: reversing it would return the farm break-even
to $0.00741/ROZ and lift the typical casual and active profiles back into their
bands, and it was rejected because the farm effect is the larger of the two.

**This rule carries most of the gate's strength, and it is easy to model wrong.**
Because every calendar day starts at zero spend, *every* wallet — farm or honest —
earns the reduced rate on its opening stretch of hops. A wallet does not get 64
hops at 1.0 for $0.605; it gets 63 at 0.15 and one at 1.0. Every yield figure in
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

$0.60/day is first reached at **64 hops** ($0.605). No farmer buys a spawn to
clear it: spawns cost $0.10 and earn nothing, while hops in the same price band
cost $0.02 and earn ROZ.

The yield at that point is **28.45 ROZ**, not 64 + 18. Non-retroactivity means the
first 63 hops pay 0.15 and only hop 64 pays 1.0:

`63 × 0.15 + 1.0 + 18 = 9.45 + 1 + 18 = 28.45`

| | Ungated (§2.5) | With the gate |
|---|---|---|
| Cost per farm wallet | $0.055 | **$0.605** |
| Yield | 46 ROZ | **28.45 ROZ** |
| Break-even | $0.00120/ROZ | **$0.0213/ROZ** |
| Wallets to drain Year 1 | 50,923 | **82,336** |
| Cost to drain Year 1 | $2,801/day | **$49,813/day** |
| Market cap at 5B supply | $6.0M | **$106M** |

**About 18× more expensive**, and it lands precisely where progressive pricing failed.
The gate does not merely raise the farmer's bill — it also cuts what the wallet
earns, and the second effect is the larger of the two.

**Hopping past 64 does not help the farmer.** Each further hop costs $0.04 and
yields 1 ROZ, which is worse than the $0.0213 average, so the cheapest wallet
stops at 64. A farmer who wants the full 178-ROZ ceiling must clear $0.60 before
hopping at all — six paid spawns for $0.60 — which costs $5.015 for 178 ROZ,
$0.0282/ROZ. Still dearer than stopping at 64.

### Measure 3 attacks churn, but $3 is a modest barrier

A lifetime threshold attacks wallet *churn* rather than wallet *activity*, which
is the farmer's actual cost centre:

| Lifetime threshold | Cost to onboard 82,336 farm wallets |
|---|---|
| $1 | $82,336 |
| $2 | $164,672 |
| **$3 (chosen)** | **$247,008** |
| $5 | $411,680 |
| $10 | $823,360 |

At $3 the one-off barrier is **$247,008**, which is **5.0 days** of the gated
running cost. At $5 it would be $411,680, or 8.3 days. The threshold is a direct
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
| Zero-USDC-fee daily yield | 20 × 0.2 = **4 ROZ** | 22 × 0.3 = 6.6 | **20 × 0.15 = 3** |
| Wallets to drain Year 1 on gas alone | 585,617 | 354,919 | **780,822** |

The current allowance is 20, so both the lower rate and the restored allowance
tighten the route. **780,822 wallets is 33% more than the pre-gate settings ever
required**, so this is the tightest version yet. Measure 1 governs wallets that
spend and this governs wallets that never pay a game fee; both now point the same
way.

### The honest cost: every profile now falls short

| Player | Hops | Daily spend | Crosses at | Established | New wallet | Target |
|---|---|---|---|---|---|---|
| Light casual, no hide | 40 | $0.275 | **never** | **6** | **6** | 25 – 70 |
| Light casual, 2 hides | 40 | $0.775 | hop 33 | **≈55** | ≈55 | 25 – 70 |
| Typical casual | 62 | $0.965 | round-3 hide | 117.5 | 62.5 | 140 – 280 |
| Active | 128 | $3.645 | hop 59 | 286.7 | 202.7 | 300 – 500 |

**A light casual and a small farmer are indistinguishable by spend.** The gate
cannot separate them, so it hits both — 6 against a floor of 25, and raising the
threshold from $0.50 to $0.60 moved them further from clearing it, not closer.

**The other two profiles are no longer safe either.** The revised bands (§2.2)
were set when the model still assumed a retroactive crossing. Correcting that
puts the typical casual 22.5 short of their floor and the active player 14.1
short. Non-retroactivity is the larger cause; the halved hop rate adds 8.1 and
8.8. This is the trade the gate asks for, now measured properly.

**Hopping cannot close the light casual's gap, structurally.** The most a wallet
can spend while staying under $0.60 is $0.585 — 63 hops — which pays
63 × 0.15 = **9.45 ROZ** with no participation. That is the ceiling for any
below-gate day of hopping, and it sits well below the 25 floor.

**Hiding can close it, in either direction.** Two hides plus 42 hops reaches
**30.3 ROZ** while staying under the gate, or the same two hides carry the player
*over* $0.60 and to roughly **54 ROZ**. Both clear the floor. What does not work
is one hide — 18 ROZ, short of the floor and short of the deliberate below-gate
day. See §2.2.

**The two measures overlap at the bottom and diverge in the middle.** A light
casual is already at the floor from measure 1, so new-wallet status costs them
nothing extra. Measure 3 therefore only reduces players who *do* spend — which is
the opposite of the intuition its name suggests, and worth confirming as intended.

This is the trade the gate asks for, and it should be made deliberately rather
than discovered after launch. See §9.

---

### Two rules that decide whether the gate works at all

**1. A hide payment is two things, and only one of them is spend.**

Since §2.3 a hide costs **$5.20**: a `$0.20` fee plus a `$5.00` stake. They must be
treated differently, and getting this wrong voids both measures.

| Part of the payment | Recoverable? | Counts as spend? |
|---|---|---|
| `hideFeeBase` / `hideFeeHigh` — $0.20 / $0.25 | **No, never** | **Yes** |
| `currentHiderFee` — the $5 stake | **Yes**, less 12,833 units on claim | **No** |
| The 12,833 units retained on claim | No | **Yes** |

**Only irrecoverable value may count:** hop fees, spawn fees, the hide fee at
whichever tier applies, and the 12,833 units the contract retains on each claim.
Never the stake.

If the stake counted toward either threshold, a single hide would clear the whole
$3 lifetime gate for the $0.2128 a surviving hide actually costs — **14× cheaper**
— and would clear the $0.60 daily gate every day on top. The $0.20 fee has already
shrunk that bypass considerably: before the fee existed a hide cost $0.0128 and
the bypass was **234×**. It is smaller, not gone, and the rule still stands.

**The gate is calibrated against the fee tier, not the daily cap.**

```
hideFeeTierBoundary (3)  ×  hideFeeBase ($0.20)  =  dailySpendThreshold ($0.60)
```

The first three hides of a day cost the cheap fee and land a wallet exactly on the
threshold — no shortfall, no overshoot. That gives a light player a clean route
across (§2.2) and gives a farmer no cheaper way over than anyone else has.

**This is the assertion the setters must carry**, and it is easy to write the
wrong one. The relationship is *not* `dailyHideCap × hideFeeBase`: the cap is 10,
and 10 × $0.20 is $2.00. Three settings move independently and each breaks the
calibration differently:

| Change | Effect |
|---|---|
| `hideFeeBase` → $0.25 | two hides clear the gate; the third overshoots |
| `hideFeeTierBoundary` → 2 | hiding alone can no longer reach $0.60 at the cheap fee |
| `dailySpendThreshold` → $0.50 | two hides clear it; the tier boundary means nothing |

`dailyHideCap` (10) is deliberately **not** in this relationship. It bounds
volume; it has no part in clearing the gate. See §4b for the setter assertion.

**2. Reductions resolve to the lowest value. They never compound.**

Both statuses can hold at once — a new wallet that has not yet spent $0.60 today —
and their rates disagree: 0.15 against 0.5 per hop, *not available* against 9 for
participation, and 4.5 against 15 for an instant hide.

> **Resolve each reward line independently to the lowest applicable value.**

| Situation | Per hop | Participation | Instant hide | Hide survives | Find |
|---|---|---|---|---|---|
| Established, cleared $0.60 today | 1.0 | 18 | 30 | 50 | 110 |
| Established, below $0.60 today | 0.15 | none | 4.5 | 7.5 | 110 |
| New wallet, cleared $0.60 today | 0.5 | 9 | 15 | 25 | 110 |
| **New wallet, below $0.60 today** | **0.15** | **none** | **4.5** | **7.5** | **110** |

The find column is constant by design — see above.

Stating rates as absolute values rather than multipliers removes the compounding
hazard by construction. Under the previous multiplier scheme the three reductions
multiplied to `0.2 × 0.2 × 0.5 = 0.02×`, leaving a new light player with **2%** of
rewards on their first day.

**The §2.3 Daily Volume Multiplier does not reopen that hazard, because no reward
line ever takes two multipliers:**

| Reward line | Resolved from | Then scaled by | Multipliers applied |
|---|---|---|---|
| Per hop | absolute rate | the soft cap, if past it | **at most 1** |
| Participation | absolute rate | the soft cap, if past it | **at most 1** |
| Instant hide | absolute rate | the Daily Volume Multiplier | **exactly 1** |
| Hide survives | absolute rate | the Daily Volume Multiplier | **exactly 1** |
| Find / steal | 110, always | nothing | **0** |

The soft cap covers hops and participation only; the volume multiplier covers
hides only. They never meet. **Resolve the wallet rate to its absolute value
first, apply the one multiplier that line is entitled to, and stop.**

Worth noting that the wallet rates *could* be written as multipliers — 0.15× and
0.5× against a 30 base give exactly the stored 4.5 and 15, and against a 50 base
exactly 7.5 and 25. They are stored as absolutes anyway, because that is what
makes "at most one multiplier per line" checkable by reading the code rather than
by doing arithmetic.

Note one arithmetic coincidence, because it will mislead anyone checking the
numbers by eye: the correct bottom-row answer, **0.15**, is also what the old
multiplier scheme produced from `0.5 × 0.3`. A multiplicative implementation of
the *current* rates would give `0.5 × 0.15 = 0.075` instead. Assert the credited
value directly rather than reasoning from the shape of the number — see test 5g.

The new-wallet soft cap of 80 ROZ is close to inert: a new wallet needs about 142
hops in a day before it binds, well beyond any of the player profiles above.

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
| `dailyFreeHops` | 20 | plain count, `u256` |
| `dailyFreeSpawns` | 1 | plain count, `u256` |
| `dailySoftCapRoz` | **136** (18dp) | see §2.5. Sits just under the 137.2 raw maximum with four early spawns, so it binds only the bought-crossing route |
| `softCapMultiplierNum` / `Den` | 1 / 5 | 0.2× beyond the cap — applies to **hops and participation only** |
| `dailySpendThreshold` | `600000` ($0.60) | §2.6 measure 1 |
| `lifetimeSpendThreshold` | `3000000` ($3.00) | §2.6 measure 3 |
| `hideFeeBase` | `200000` ($0.20) | §2.3 — treasures 1–3 of the day. A **fee**, not the stake |
| `hideFeeHigh` | `250000` ($0.25) | §2.3 — treasure 4 onward |
| `hideFeeTierBoundary` | 3 | plain count — where the fee steps up |
| `dailyHideCap` | **10** | plain count — per calendar day, counting **treasures**, non-whitelisted |
| `maxTreasuresPerRound` | **2,840** | plain count — the round total, everyone. §4m-i |

There is no `verifiedBonusNum`/`Den` and no `player_verified` — the
proof-of-humanity measure was rejected, see §2.6.

**The Daily Volume Multiplier curve** (§2.3), six owner-settable bands. Stored as
numerator/denominator pairs so the values are exact:

| Treasures already created today | Multiplier | Num / Den |
|---|---|---|
| 0 – 2 | 1.00× | 1 / 1 |
| 3 – 4 | 0.70× | 7 / 10 |
| 5 – 6 | 0.40× | 2 / 5 |
| 7 – 8 | 0.20× | 1 / 5 |
| 9 – 10 | 0.08× | 2 / 25 |
| 11+ | 0.03× | 3 / 100 |

**The setter assertion — write this one carefully:**

```cairo
// 2.6 rule 1. The gate is calibrated against the FEE TIER, not the daily cap:
// the first hideFeeTierBoundary hides of a day must land a wallet exactly on
// dailySpendThreshold. Any setter that moves one of these three re-checks it.
assert(
    self.hideFeeTierBoundary.read() * self.hideFeeBase.read()
        == self.dailySpendThreshold.read(),
    'hide fee gate mismatch',
);
```

It is **not** `dailyHideCap × hideFeeBase` — that was the relationship when the
cap was 3, and 10 × `200000` is `2000000`. `dailyHideCap` bounds volume and has no
part in clearing the gate.

The reduced rates are **absolute values, not multipliers** (§2.6 rule 2), so they
are stored the same way as the base rates:

| Reduced rate | ROZ | Raw value (18dp) |
|---|---|---|
| `hopRewardBelowThreshold` | 0.15 | `150000000000000000` |
| `participationBelowThreshold` | 0 | `0` — the bonus is withdrawn, not reduced |
| `rewardHideBelowThreshold` | **4.5** | **`4500000000000000000`** |
| `rewardHideSurvivedBelowThreshold` | **7.5** | **`7500000000000000000`** |
| `hopRewardNewWallet` | 0.5 | `500000000000000000` |
| `participationNewWallet` | 9 | `9000000000000000000` |
| `rewardHideNewWallet` | **15** | **`15000000000000000000`** |
| `rewardHideSurvivedNewWallet` | **25** | **`25000000000000000000`** |
| `newWalletSoftCapRoz` | 80 | `80000000000000000000` |

**There is no reduced `rewardFind`.** Find/steal pays 110 to every wallet in every
state — see §2.6.

**`hopRewardBelowThreshold` is the most load-bearing of these**, and not only
against farmers. Because every calendar day starts at zero spend, it is the rate
*every* wallet earns on its opening stretch of hops — see §2.2. It sets zero-cost
sybil yield and the first 50-odd hops of an honest day at the same time.

0.15, 0.5, 4.5, 7.5, 15 and 25 ROZ are all exact in 18 decimals, so there is no
rounding concern and no need for numerator/denominator pairs. The old
`belowThresholdNum`/`Den` and `newWalletNum`/`Den` fractions are **removed** —
absolute rates replace them, and that is what eliminates the compounding hazard
described in §2.6.

Two new per-player maps, both following conventions already in the contract:

```cairo
// Day-keyed, so it self-resets - same pattern as player_free_hops_used (4l).
// Drives BOTH the 2.3 fee tier and the Daily Volume Multiplier, so it must be
// read BEFORE the current treasure is counted and written after.
player_hides_today:  LegacyMap<(u64, ContractAddress), u256>,

// Round-keyed alongside hider_share_amounts. Accumulates the survival reward
// RESOLVED AT HIDE TIME, so a later gate crossing cannot revalue an old hide.
hider_survival_roz:  LegacyMap<(u256, ContractAddress), u256>,
```

**The bulk-hide whitelist** (§4m-iii). One root plus four counters — the counters
exist only because whitelisted addresses are exempt from `dailyHideCap` and need
their own bounds:

```cairo
// Only the owner may write this. A leaf is the address as felt252, hashed
// with Poseidon. See 4m-iii for the off-chain tree and the proof format.
whitelist_merkle_root: felt252,

// 250 treasures per ROUND for a whitelisted address, so one of them cannot
// take the whole 2,840 round allowance. Round-keyed, so it self-resets.
whitelist_round_count: LegacyMap<(ContractAddress, u64), u32>,

// 1,200 treasures per ROUND across ALL whitelisted addresses together. The
// per-address cap above bounds one of them; this bounds the group, because
// 250 each does not compose - eleven such addresses would otherwise fill a
// round. Incremented by every treasure a whitelisted caller creates, single
// or bulk. A non-whitelisted hide never touches it.
whitelist_round_total: LegacyMap<u64, u32>,

// 80 treasures per rolling HOUR, so a whitelisted address cannot dump its
// round allowance in the first minutes and shut ordinary hiders out.
whitelist_hour_start: LegacyMap<ContractAddress, u64>,
whitelist_hour_count: LegacyMap<ContractAddress, u32>,
```

| Setting | Value | Applies to | Resets |
|---|---|---|---|
| `whitelistRoundCap` | **250** | one whitelisted address | each round |
| `whitelistCollectiveCap` | **1,200** | **all whitelisted addresses together** | each round |
| `whitelistHourlyCap` | **80** | one whitelisted address | every 3,600s |
| `dailyHideCap` | **10** | non-whitelisted only | each calendar day |
| `maxTreasuresPerRound` | **2,840** | **everyone** | each round |

`maxTreasuresPerRound − whitelistCollectiveCap` = **1,640** is therefore the
number of slots a round always keeps for ordinary players. See §4m-iii.

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
deliberately set **above** `dailyFreeHops` (20), though since §2.6 that ordering is
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
```

There is no `player_verified` — the proof-of-humanity measure was rejected (§2.6).

Everything except `player_lifetime_spend` is keyed by round or by day, so it
resets naturally as time advances — no cleanup pass is needed. The lifetime
counter is deliberately permanent; that is the whole point of measure 3.

**Both spend counters take irrecoverable fees only.** Hop fees, spawn fees, **the
hide fee at whichever tier applies**, and the 12,833 units retained on a claim.
**Never the hide stake** — it is refundable, and counting it would let a farmer
clear the $3 lifetime gate for $0.2128. See §2.6 rule 1.

Cost: two extra `u256` writes on every paid hop and every paid spawn, and on
every hide two more for `player_hides_today` and `hider_survival_roz`.

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
| `hide_treasure` | Reverts with `'daily hide cap'` if `player_hides_today` is already **10** and the caller is not whitelisted. Otherwise transfers the tiered **fee plus** the `$5` stake, adds **only the fee** to both spend counters (§2.6 rule 1), increments `player_hides_today` and `hider_share_amounts`, credits `rewardHide` resolved **and then scaled by the Daily Volume Multiplier**, and adds the equally-resolved `rewardHideSurvived` to `hider_survival_roz` for later |
| `hide_treasure_bulk` | The same, once **per treasure** — the fee tier and the volume multiplier are both read from `player_hides_today` as it advances *within* the call, so a bulk of four pays exactly what four single hides would. Limits per §4m-iii: 10/day non-whitelisted, or 250/round and 80/hour whitelisted |
| `finder_player_generate_position` | **Nothing.** A spawn repositions the rabbit and pays no ROZ, free or paid. It consumes the free spawn allowance first, which affects the USDC charge only |
| `finder_player_move_position` | Charges the §2.5 tier price for the day's hop number; adds it to both spend counters; increments both hop counters; credits the hop reward under the 40-hop round cap; credits the participation bonus at **28** hops, **once per day**. Both rates are **resolved to the lowest applicable absolute value** first (§2.6 rule 2), then the soft cap is applied once — never as a product. The free/paid distinction gates only the USDC transfer — see §4l-i |
| `validate_treasure_coordinates` | moves a share between `hider_share_amounts` and `finder_share_amounts`, and deducts that share's pro-rata part of `hider_survival_roz` |
| `claim_reward` | credits **`hider_survival_roz` as stored** + `finder_shares × rewardFind`, and sets `reward_token_claimed` only if that credit succeeded. The survival rate is **not** re-resolved here — see below |
| `claim_reward_token_for_week` | retries the above for one week — see §4h |

Every one of these goes through `_accrueRewardToken` — a credit to the pending
map, never a transfer, and skipped rather than reverted when uncovered.

The five gameplay rewards ignore the helper's return value: they come round again
next round, so a skipped hop or hide is not worth tracking. Only the claim leg
records whether it landed.

**One helper resolves the gated rates, and the order matters.** Four rewards now
pass through it — per hop, participation, instant hide and hide survival. Only
find/steal bypasses it, paying 110 in every state (§2.6). The sequence is:

```
0. Charge the fee first, so today's spend is current before the rate is read
1. Pick the base rate:        rewardPerHop / rewardParticipation /
                              rewardHide / rewardHideSurvived
2. If lifetime spend < $3:    take min(rate, newWallet rate)
3. If today's spend < $0.60:  take min(rate, belowThreshold rate)
4. Apply the ONE multiplier that line is entitled to:
     - hop / participation -> the soft cap, if the day's total is past it
     - hide / hide-survives -> the Daily Volume Multiplier for the treasure
                               index being created (2.3)
     - find / steal        -> none, ever
```

Steps 2 and 3 both **take a minimum**, never a product — which is why a new wallet
that is also below the daily threshold lands on 0.15 and no participation, rather
than compounding down to nothing. Step 4 applies **at most one** multiplier, and
the two available multipliers never apply to the same line — see §2.6 rule 2.

**The volume multiplier is read from the count *before* the current treasure.**
Treasure 1 of the day sees `player_hides_today == 0` and takes the 1.00× band;
treasure 4 sees 3 and takes 0.70×. Inside a bulk call the count advances per
treasure, so `hide_treasure_bulk(4)` pays 1.00×, 1.00×, 1.00×, 0.70× — identical
to four separate single hides. **That equivalence is the whole design**: it is
what stops a farmer splitting a bulk call to escape the curve.

**Step 0 is what makes the hop that crosses the threshold pay the full rate.**
The fee is charged, the spend counters are updated, and only then is the rate
read — so the 64th hop in §2.6's worked example earns 1.0, not 0.15. Every figure
in this plan is computed that way.

**Participation is tested against both of its conditions each time, and fires on
the first action where both hold.** It is not credited at the 28th hop and then
forgotten. A player can reach 28 hops while still below $0.60 — the typical
casual in §2.2 does exactly that, at hop 28 with $0.145 spent — and must still
receive the bonus when their spend later crosses. Concretely: on each hop, if
`hops_today >= participationMinimumHops` and `spend_today >= dailySpendThreshold`
and the bonus has not yet paid today, credit it. Getting this wrong costs that
player the whole 18 ROZ and is invisible in any test that spends first.

**The survival reward is resolved when the hide is placed, not when it is
claimed.** This one needs stating because the obvious implementation is wrong.
`claim_reward` credits `hider_shares × rewardHideSurvived`, and a player may call
it days after hiding — on a fresh calendar day, with that day's spend back at
zero. Resolving the rate at claim time would therefore hand an honest player 7.5
instead of 50 for claiming on a Monday morning, and would let a farmer do the
reverse by claiming only on days they had already cleared $0.60. Both directions
are wrong.

So `hide_treasure` resolves the survival rate through the sequence above and adds
it to `hider_survival_roz[round][wallet]`; `claim_reward` credits **that stored
amount**, never a freshly resolved rate:

```cairo
// At hide time - the gate status now is the one that counts, permanently.
let survivalRate = _resolveGatedRate(rewardHideSurvived, caller);
hider_survival_roz.write((round, caller), stored + survivalRate);
```

**When a finder steals a share, deduct pro rata** — `stored ÷ share_count` — since
the shares themselves are a fungible counter. With at most 3 hides a day the
approximation is bounded and small. A tiered map keyed by rate would be exact; it
is not obviously worth the storage. Recorded in §9.

The instant hide reward has no such problem: it is credited inside
`hide_treasure`, so the current gate status is the right one by construction. Note
the ordering that follows from step 0 — **the $0.20 fee is charged before the
instant reward is resolved**, so the third hide of a day is itself the action that
crosses $0.60 and it pays the full 30.

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

**The same guard is required for USDC — decided, and it needs new state.**
Sweeping the game token currently strands every outstanding claim, because USDC
owed is computed from shares on demand and never totalled. There is no
`total_usdc_pending` to subtract, so unlike the ROZ case the guard cannot be
written as a one-line subtraction.

The cheapest correct form is to total the outstanding stake as it accrues:

```cairo
// Mirrors total_reward_token_pending. Incremented by currentHiderFee on every
// treasure hidden, decremented when a claim pays out or a finder takes a
// stake. The sweep then releases only the surplus, exactly as it does for ROZ.
total_usdc_claimable: u256,
```

Both branches then read the same way, which is the point — one rule, two tokens:

```cairo
if (tokenAddress == self.game_reward_token_contract_address.read()) {
    sweepableAmount -= self.total_reward_token_pending.read();
} else if (tokenAddress == self.game_token_contract_address.read()) {
    sweepableAmount -= self.total_usdc_claimable.read();
}
```

This is a real addition rather than a guard on existing state, so it carries a
write on the hide path and on the claim path. Worth it: without it the sweep can
take money players are entitled to, and the failure is silent.

### 4k. Round cadence — an operational problem, not a contract one

**A 6-hour round means `start_new_game` must be called 1,460 times a year.**

It takes eight positional `u256`/`u128` arguments with no validation, and a slip
corrupts that round's economics — this is exactly how `4500000000000000` ended up
in the old contract's hider-count slot, where a treasure value was passed as a
hider count. Doing that by hand four times a day is not viable, and 1,460 annual
chances to mistype are worse.

**Decided: an off-chain keeper on AWS.** An **EventBridge** schedule fires every
6 hours and invokes a **Lambda** that calls `start_new_game` with the arguments
computed in §4k-i. No contract change is needed.

What that choice carries, and should be designed for rather than discovered:

- **The rollover depends on the keeper staying up.** A missed invocation means a
  round never starts. EventBridge retries, but the Lambda must be idempotent —
  calling `start_new_game` twice for the same round would overwrite that round's
  parameters, which is the footgun §4k-i exists to defuse. Guard on the current
  round index before writing.
- **The keeper holds a privileged key.** It is the only account that can start a
  round, so its compromise stops or corrupts the game. It needs the same care as
  the owner key.
- **The eight positional arguments are still unvalidated.** Computing them in one
  reviewed Lambda is a large improvement on doing it by hand 1,460 times a year,
  but the contract will still accept a wrong value silently.

An on-chain `advance_round()` remains the stronger long-term answer — it removes
the argument footgun entirely and could be permissionless with a time check, so a
stale round can be rolled by anyone if the keeper is down. Not required for
launch, but worth keeping on the roadmap as the way to retire the keeper's
privilege.

**Decided: a round may end early once every eligible treasure is found.** This is
already detectable — `total_reward_shares_for_hiders[round]` decrements on every
successful `validate_treasure_coordinates`, so zero means all found. Two points
the implementation has to settle:

- **Who ends it.** The natural trigger is the finder whose validation takes the
  count to zero, but that makes one player pay the gas for everyone. The
  alternative is to let the keeper notice and roll early, which costs nothing
  extra since it is already scheduled — at the price of up to 6 hours of dead
  round. Recommend the keeper, with the count exposed so the front end can show
  "all treasures found".
- **Hides already placed for the next round are unaffected.** They target
  `currentGameWeek + 1`, so an early roll simply brings their round forward. No
  refund logic is needed.

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
dailyFreeHops:   u256,   // 20 - 50% of a round against the 40 hop cap, and
                         //      deliberately BELOW participationMinimumHops
                         //      (28). Since 2.6 the daily spend threshold is
                         //      the primary guard; this ordering is defence in
                         //      depth. Zero-USDC-fee yield is 3 ROZ - see 4l-i-a.
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

**There is no free hide.** Since §2.3 every hide costs the $0.20 fee, there is no
allowance against it, and the 3-a-day cap is a hard stop rather than the point at
which a charge begins. That fee *does* count toward the spend thresholds — it is
the one irrecoverable part of a hide payment (§2.6 rule 1) — which is what makes
hiding the only action that both earns ROZ and moves a wallet toward the gate
without hopping.

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
how much: **`dailyFreeHops` is 20, `participationMinimumHops` is 28, and
`dailySpendThreshold` is $0.60.**

A wallet that never pays cannot clear the spend threshold — free hops add nothing
to the spend counters — so its hops pay `hopRewardBelowThreshold`, not
`rewardPerHop`:

| | ROZ |
|---|---|
| 20 USDC-free hops × **0.15** (below the $0.60 threshold) | 3 |
| Participation — withdrawn below the threshold, and 20 < 28 in any case | **0** |
| Spawn — pays nothing, free or paid | 0 |
| **Total, at zero USDC fee** | **3/day** |

**Participation is now locked twice over.** The §2.6 spend threshold withdraws it
outright, and the hop ordering would deny it anyway. Either lock alone is
sufficient; keeping both costs nothing.

The ordering rule still stands — **keep `dailyFreeHops` strictly below
`participationMinimumHops`** — but it is no longer the whole defence. If the
allowance were raised above 28, a zero-cost wallet would still earn only
`28 × 0.15 = 4.2` rather than gaining the bonus, because the spend threshold holds.

Against the Year 1 budget of 2,342,466 ROZ/day, roughly **780,822 throwaway
wallets** would be needed to drain the tranche, paying Starknet gas throughout.

**This was a regression, and lowering the rate has reversed it.** The route has
been through three settings:

| Settings | Zero-cost yield | Wallets to drain Year 1 |
|---|---|---|
| 20 free hops, 0.2× multiplier | 4 ROZ | 585,617 |
| 22 free hops, 0.3 absolute | 6.6 ROZ | 354,919 |
| **20 free hops, 0.15 absolute** | **3 ROZ** | **780,822** |

The allowance is back at 20 and the rate is lower. 780,822 is **33% more wallets
than the original settings required**, so this is now the tightest the
zero-USDC-fee route has been, not merely a return to par.

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
  20. But it is also the onboarding budget, so it trades against measure 2.
- **Accept it on testnet**, and gate on a funded balance before mainnet.

### 4l-ii. The hide loop, and how §2.3 bounded it

Gating free actions removes zero-cost farming, but it leaves paid routes whose
ROZ yield may exceed their USDC cost. The hide loop used to be the worst of them
by a wide margin. §2.3 and §2.6 changed that:

| Route | ROZ | Real cost | Break-even |
|---|---|---|---|
| Per-hop, mid-tier | 1 | $0.01 | $0.01000 |
| 64 paid hops — the cheapest route through the §2.6 gate | 28.45 | $0.605 | $0.0213 |
| ~~Hide cycle, ungated and unfound~~ *(superseded)* | ~~80~~ | ~~$0.0128~~ | ~~$0.00016~~ |
| **3 hides + 28 hops — the cheapest wallet now** | **150** | **$0.6935** | **$0.00462** |

There is no spawn row — a spawn pays nothing.

The 64-hop row: below $0.60 of daily spend the participation bonus is withdrawn
entirely, so a farmer must reach the threshold before the hop route is worth
running at all. Its yield is 28.45 rather than 82 because non-retroactivity pays
only hop 64 at the full rate — see §2.6.

#### What used to make hiding uniquely cheap

Worth keeping, because it explains what the three changes were aimed at. Before
§2.3, hiding was the one action **no measure in the plan reached**: both §2.6
tables paid it in full above and below the threshold, the $5 stake was excluded
from spend as refundable, and `hide_treasure_bulk` placed 200 treasures in a
single transaction. Progressive pricing, both thresholds, the soft caps and the
free allowance all acted on hops and participation and none of them on a hide. A
surviving hide returned 80 ROZ for the 12,833 units retained on claim —
**$0.00016/ROZ**, profitable above a $0.8M market cap, and reachable in **147
transactions a day**.

#### The three changes, and what each one did

| Change | Effect on the route |
|---|---|
| Gate the hide rewards (§2.6) | A below-gate hide cycle pays **12**, not 80 |
| Tiered fee (§2.3) | A real irrecoverable cost per hide, and it **counts as spend** |
| **Daily Volume Multiplier** (§2.3) | The 4th treasure of a day pays 0.70×, the 10th 0.08× |
| Per-wallet and per-round caps (§2.3, §4m-i) | 10 a day per wallet, 2,840 a round in total |

**The volume multiplier is what makes the daily cap safe to raise.** The cap is 10
rather than 3, which on its own would have made farming *cheaper* — each extra
surviving hide adds 80 ROZ for $0.25. The curve removes that: past the third
treasure the marginal yield falls faster than the marginal fee.

#### The cheapest wallet is still 3 hides plus 28 hops

The hide fees clear the gate exactly — 3 × $0.20 = $0.60 — after which the 20 free
hops pay the full 1.0 rather than 0.15. All three hides sit in the 1.00× band:

| Step | Spend after | Volume | ROZ |
|---|---|---|---|
| Hide 1 | $0.20 — below | 1.00× | 4.5 + 7.5 |
| Hide 2 | $0.40 — below | 1.00× | 4.5 + 7.5 |
| Hide 3 | **$0.60 — crosses** | 1.00× | 30 + 50 |
| 20 USDC-free hops | $0.60 | — | 20 |
| Hops 21–28 (+$0.055) | $0.655 | — | 8 |
| Participation | — | — | 18 |
| **Total** | **$0.6935 all in** | | **150 ROZ** |

$0.6935 is $0.60 of hide fees, $0.055 of hop fees and 3 × $0.0128 retained on
claim.

**Hiding past three is worse, which is the point.** The farmer's whole curve:

| Hides | ROZ | Cost | $/ROZ | Cap at 5B |
|---|---|---|---|---|
| 1 | 38.95 | $0.618 | 0.01586 | $79.3M |
| 2 | 49.3 | $0.631 | 0.01279 | $64.0M |
| **3** | **150.0** | **$0.693** | **0.00462** | **$23.1M** |
| 4 | 206.0 | $0.956 | 0.00464 | $23.2M |
| 5 | 262.0 | $1.219 | 0.00465 | $23.3M |
| 7 | 326.0 | $1.745 | 0.00535 | $26.8M |
| 10 | 364.4 | $2.533 | 0.00695 | $34.8M |

**Raising the cap from 3 to 10 cost nothing.** The floor stays near $23.1M, exactly
where the 3-a-day design had it. One and two hides are far worse, not better: a
wallet without three hides has to *hop* to $0.60, spending 44–55 hops at 0.15 to
get there.

| | Before §2.3 | **Now** |
|---|---|---|
| Break-even, all hides survive | $0.00016/ROZ → **$0.8M** cap | **$0.00462/ROZ → $23.1M** |
| Break-even, busy game (`P(found)` 16%) | $0.0192 → $96M | **$0.0221 → $110M** |
| Cost to drain Year 1, quiet | $375/day | **$10,831/day** |
| Wallets needed | ~1 | **15,616/day** |
| **Transactions** | **~147/day** | **~500,000/day** |
| Capital locked, refundable | $146,405 | $234,240 |

**The floor rises about 29× and the transaction count 3,400×.** Against the gated hop
route's $106M the hide loop is now 4.6× cheaper rather than 134×, and the gas
argument the rest of the plan leans on applies to it again.

#### What the route actually costs depends on `P(found)`

The wallet above assumes every hide survives. If found, the finder takes the $5
stake, and only the instant reward is kept. Per wallet of 3 hides:

```
cost = 3 × P(found) × $5   +  $0.6935
ROZ  = 39                  +  (1 − P(found)) × 65   +  46 from the hops
```

The instant rewards (4.5 + 4.5 + 30 = 39) and the hop leg (28 + 18) are
unconditional; only the 65 of survival value is at risk. To drain the 2,342,466
ROZ/day budget a farmer needs **15,616 wallets**, so **46,848 hides a day** or
about **11,712 per round**. `P(found)` is the honest players' finds divided by
that pool, and it does not fall as the farmer scales: §2.4 sizes the grid at
`T × 40 × K`, holding density constant, so flooding the board grows it
proportionally and finds per honest hop stay put.

| Honest finds per round | P(found) | Break-even | Cost to drain Year 1 | Profitable above |
|---|---|---|---|---|
| ~1,875 — a healthy game, ≈5,000 daily actives | 16.0% | **$0.0222/ROZ** | $51,900/day | **$111M** |
| ~500 | 4.3% | $0.00909 | $21,299/day | $45.5M |
| ~100 — a quiet round | 0.9% | $0.00554 | $12,989/day | $27.7M |
| 0 — a dead round | 0% | **$0.00462** | $10,831/day | **$23.1M** |

**Read the bottom row first now.** It is the farmer's best case, and at $23.1M it
is no longer the runaway it was — the same row read $0.8M before §2.3. The top row
at $111M is *dearer* than the gated hop route's $106M.

**The timing exposure is much smaller.** A farmer still prefers quiet rounds, but
the swing between the top and bottom rows is now **4.8×**, against 120× before.
The $0.20 fee is charged whether or not the treasure survives, so it sets a floor
the farmer cannot time their way under.

#### Gas constrains this route again — and gas is now measured

The plan leans on Starknet gas as the real anti-farm cost (§2.5, §9). Bulk hiding
used to remove that lever — 200 treasures per transaction. Counting treasures
rather than transactions restores it:

| | Gated hop route | Hide route, before §2.3 | **Hide route now** |
|---|---|---|---|
| Transactions to drain Year 1 | ~5.3M/day | ~147/day | **~500,000/day** |
| Fees | $49,813/day | $375 – $45,000/day | **$10,831 – $51,900/day** |
| Capital required | none | $146,405, refundable | $234,240, refundable |

15,616 wallets × 32 transactions each — 3 hides, 28 hops and a claim. **About
3,400× more transactions than before.**

**At the measured rate of $0.025 – $0.04 per transaction (§9), gas now exceeds
game fees on every route**, and the figures above understate the farmer's cost
substantially:

| Route | Fees | Gas | Total | Break-even | Cap at 5B |
|---|---|---|---|---|---|
| 3 hides + 28 hops (32 tx) | $0.693 | $0.80 – $1.28 | $1.49 – $1.97 | $0.0100 – $0.0132 | **$50M – $66M** |
| **5 hides + 28 hops (34 tx)** | $1.219 | $0.85 – $1.36 | $2.07 – $2.58 | **$0.0079 – $0.0098** | **$39M – $49M** |
| 64 hops only (65 tx) | $0.605 | $1.63 – $2.60 | $2.23 – $3.21 | $0.078 – $0.113 | $392M – $563M |

**Gas changes which wallet is optimal.** On fees alone the farmer stops at three
hides; once gas is counted the best shape is **five**, because more treasures per
wallet amortises the fixed 29-transaction hop-and-claim leg. The floor rises from
$23.1M to **$39M – $49M**.

**The pure hop route is effectively dead** at $392M+. It costs 65 transactions for
28.45 ROZ — 2.3 transactions per ROZ, against 0.13 for the hide route. Everything
that matters now runs through hiding.

#### The round cap puts a hard ceiling on volume

Break-even measures price. `maxTreasuresPerRound` measures **how much can be taken
at any price**, and it is the binding constraint:

```
2,840 per round  ×  4 rounds  =  11,360 treasures/day
11,360  ÷  5 per wallet       =   2,272 farm wallets
2,272   ×  262 ROZ            = 595,264 ROZ/day
```

Against the Year 1 budget of 2,342,466 ROZ/day that is **25.4%**. **Hide-farming
cannot drain the tranche** — not at any price, and not with any number of wallets.
Beyond a quarter of the daily issuance the farmer must fall back on the hop route
at $396M+, which nobody will do.

This is a different kind of protection from the break-even figures, and a more
robust one: it does not depend on the ROZ price, on gas, or on `P(found)`. It also
crowds honest hiders onto the same 2,840 slots, which is recorded in §9.

#### One thing still unshipped

**The per-treasure claim deduction (§4m-ii).** Without it the 12,833 units are
charged once per *claim*, not per treasure. With the cap at 10 the under-charge is
at most 10× rather than 200×, and it moves the cheapest wallet by about 4% — so
this is no longer urgent. It is one line, the calculation is simply wrong without
it, and it should ship with bulk hiding.

Note the collision with §2.2: hiding is also how a below-gate light casual reaches
their band, so the two share a mechanic — though since §2.3 they no longer share
an exposure.

### What a maximising farm wallet now costs

**A farmer optimises for cost per ROZ, not for ROZ per wallet**, so the worst case
is the cheapest gate-clearing wallet, not the biggest one. With gas counted that
wallet is five hides:

| | **5 hides + 28 hops** | 3 hides + 28 hops | Hops only | Maximising hop wallet |
|---|---|---|---|---|
| Daily fees | $1.219 | $0.6935 | $0.605 | $4.725 |
| Daily yield | **262 ROZ** | 150 ROZ | 28.45 ROZ | 136.24 ROZ |
| Break-even, fees only | $0.00465 → $23.3M | **$0.00462 → $23.1M** | $0.0213 → $106M | $0.0347 → $173M |
| **Break-even, with gas** | **$0.0079–$0.0098 → $39M–$49M** | $0.0100–$0.0132 → $50M–$66M | $0.078–$0.113 → $392M+ | — |
| Volume ceiling | **25.4% of the tranche** | 25.4% | unbounded | unbounded |

**$39M–$49M is the live number**, and it is bounded at a quarter of daily issuance
by `maxTreasuresPerRound`. Before §2.3 the same column read **$0.8M** and had no
volume ceiling at all.

The maximising hop wallet receives 136.24 rather than 178 because it pays 0.15
on its first 48 hops and then meets the soft cap. The full raw 178 requires clearing $0.60 on spawns before
hopping ($5.015 for 178 ROZ, $0.0282/ROZ) — and `dailySoftCapRoz` at 136 clips
that route back to 144.4, which is the only thing that cap does (§2.5).

Note what the free allowance does and does not do: it holds a **zero-cost** wallet
to 3 ROZ/day, but a farmer willing to spend $0.605 is only slowed by the gate,
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

The cost of that fix is the sybil surface in §4l-i-a — **3 ROZ/day** for a
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

### 4m. Bulk hiding — open to everyone, bounded five ways

A hider pays a single amount that is an exact multiple of the hider fee, and the
contract records that many individual hidden treasures. **Anyone may call it**;
what differs is how many treasures they are allowed to create.

| Caller | Per transaction | Per day | Per round | Per hour |
|---|---|---|---|---|
| Non-whitelisted | remaining daily allowance | **10** | — | — |
| Whitelisted (§4m-iii) | unlimited | unlimited | **250** | **80** |
| **All whitelisted together** | — | — | **1,200** | — |
| **Everyone** | — | — | **2,840 in total** | — |

The fourth row is what stops the third from composing: 250 each is a limit on one
address, not on a group of them.

**Every limit counts treasures, not transactions.** So does the §2.3 fee tier, and
so does the Daily Volume Multiplier. That is the single rule that makes bulk
hiding safe to offer at all: **a bulk call of N is exactly equivalent to N single
hides** — same fees, same multipliers, same yield. There is no advantage to
splitting a call and none to combining one, so there is nothing to arbitrage.

**No loop is needed for the shares.** They are a counter, so the transfer and the
share write stay O(1). The fee and the reward *do* vary per treasure, since both
depend on how many the wallet has already created — but both are computed from a
running index rather than a loop over storage:

```cairo
fn hide_treasure_bulk(
    ref self: ContractState,
    bulkAmount: u256,
    merkleProof: Span<felt252>,   // empty if the caller is not whitelisted
    leafIndex: u32,
) -> bool {
    let caller = get_caller_address();
    let hiderCost: u256 = self.currentHiderFee.read();
    let gameWeek = self.currentGameWeek.read() + 1_u256;
    let dayIndex: u64 = get_block_timestamp() / 86400;

    // The bulk amount buys whole treasures only - a remainder would be money the
    // contract took without hiding anything for it.
    assert(bulkAmount % hiderCost == 0, 'not a multiple of hider fee');

    let treasureCount: u256 = bulkAmount / hiderCost;
    assert(treasureCount > 0, 'bulk amount too small');

    // 4m-iii. A whitelisted caller escapes the DAILY cap only. It is still
    // bound by 250 a round, 80 an hour, and the global round cap below.
    let isWhitelisted = self._verifyWhitelist(caller, merkleProof, leafIndex);

    let hidesToday: u256 = self.player_hides_today.read((dayIndex, caller));

    if (isWhitelisted) {
        self._enforceWhitelistRoundCap(caller, gameWeek, treasureCount);
        self._enforceWhitelistRateLimit(caller, treasureCount);
    } else {
        // 2.3 - counts TREASURES, so a bulk call is bounded exactly as the same
        // number of single hides would be. This equivalence is what stops a
        // farmer splitting calls to escape the Daily Volume Multiplier.
        assert(
            hidesToday + treasureCount <= self.dailyHideCap.read(),
            'daily hide cap',
        );
    }

    // A hard safety bound on the ROUND, NOT a grid check - the grid for this
    // round does not exist yet. This is the only limit that binds the aggregate
    // across all wallets, whitelisted or not. See 4m-i.
    let alreadyHidden: u256 = self.total_reward_shares_for_hiders.read(gameWeek);

    assert(
        alreadyHidden + treasureCount <= self.maxTreasuresPerRound.read(),
        'round treasure cap',
    );

    // The fee and the reward are per-treasure, because both read the running
    // count. Charge hideFeeBase below hideFeeTierBoundary and hideFeeHigh at or
    // above it; scale each treasure's reward by the 2.3 band its index falls in.
    // Only the FEE part reaches the spend counters - never the stake (2.6 rule 1).
    // ... then shares, totals and player_hides_today += treasureCount
}
```

Refactor `_hideTreasure(caller)` into `_hideTreasure(caller, treasureCount)` and
have the existing `hide_treasure()` call it with `1`. One code path, no
duplication — and it is what guarantees the single/bulk equivalence rather than
merely intending it.

**Events.** Coordinates are assigned off-chain — `hide_treasure` never takes them,
and the merkle root arrives later via `start_new_game`. So the backend that
places treasures only needs to know *how many*. Add
`TreasureHiddenBulk { user, hiderFee, treasureCount, gameWeek }` and leave
`TreasureHidden` untouched, so the existing consumer keeps working and the backend
gains one handler. Emitting one event per treasure would cost gas for no benefit.

### 4m-i. Why the bound is a cap, not a grid check

The obvious guard — "do not hide more treasures than there are cells" — **cannot
be written**, and would break bulk hiding completely if attempted.

`main_game_grid_size` is written only in `_createNewGame` (`lib.cairo:507`), when
a round is *created*. Hides target `currentGameWeek + 1` (`:543`, `:1058`) — a
round that does not exist yet. So at hide time the target round's grid reads
**(0,0)**, a capacity of zero, and every bulk hide would revert.

Dynamic scaling (§2.4) also reverses the causality such a check assumed: **the
grid is sized from the hide count**, so it cannot bound the hide count. With
`T × 40 × K`, a large single hide was never a problem in itself.

**This bound now does the one job the per-wallet caps cannot.** The daily cap of
10 stops any single farmer; `maxTreasuresPerRound` bounds the *aggregate*, which
is invisible to a per-wallet rule — 15,616 wallets hiding 5 each would otherwise
put 78,080 treasures into a day. §4l-ii shows this is what holds hide-farming to
**25.4% of the daily tranche**, and unlike every break-even figure in the plan it
does not depend on the ROZ price, on gas, or on how many treasures get found.

**What the check was protecting still matters.** Two treasures on one cell share
a leaf, and `found_coordinates[(leaf, gameWeek)]` lets a leaf be found only once —
so the second is unfindable, and its hider is guaranteed the survival reward for a
treasure nobody could ever have taken. That is now prevented by the off-chain
minimum-distance and density rules in §2.4, which have the coordinates to enforce
it. The contract never sees coordinates and could not have enforced it properly
anyway.

**On-chain, one blunt safety bound remains — and its value is now settled:**

```cairo
maxTreasuresPerRound: u256,   // 2,840. Owner-settable; the on-chain half of the
                              // "hard safety bounds" in 2.4. Changing it changes
                              // the maximum grid the game can be asked to lay
                              // out - see below before raising it.
```

**`maxTreasuresPerRound` = 2,840**, with a setter so it can be retuned without a
redeploy. What that value implies, at the starting K of 2.2:

| | |
|---|---|
| Grid cells at capacity | `2,840 × 40 × 2.2` = **249,920** |
| Maximum grid side | **500 × 500** |
| Density at capacity | **11.4** treasures per 1,000 cells |
| Treasures per day | 2,840 × 4 rounds = **11,360** |

The density sits comfortably inside the 20-per-1,000 bound from §2.4, so the
constraint that actually binds is the **grid size**: 500×500 is the largest board
the front end, the merkle tooling and the keeper must ever handle. **Raising
`maxTreasuresPerRound` raises that ceiling as √T** — 5,000 treasures would need
663×663 — so any increase has to be checked against what the off-chain stack can
render, not just against the density rule.

Its job is now twofold: stop a bug in the keeper committing the game to a round it
cannot physically lay out, and cap aggregate farm volume (§4l-ii).

### 4m-ii. The claim deduction should still scale

`_calculateRewardDue` subtracts the three fees **once per claim**, not per share:

```cairo
let eligibleReward = claimShareCount * gameHiderFee;
let rewardDue = ((eligibleReward - gasFee) - gameFee) - gameLandownerFee;
```

So a multi-share claim pays 12,833 units in total, the same as a single hide.

**§2.3's caps have absorbed most of this.** The section previously recorded a
**200×** under-charge, because a bulk claim could cover 200 shares. A
non-whitelisted wallet is now limited to 10 treasures a day, so the worst case is
**10×** — and on the cheapest farm route, which uses five, it is 5×:

| | Real cost | Effect |
|---|---|---|
| 5 hides, claimed one at a time | $0.0640 | correct |
| 5 hides, claimed together | **$0.0128** | 5× under-charged |

In cash terms that moves the cheapest farm wallet from $1.219 to $1.168 a day —
about 4%, against the 200× it would have been. **The urgency is gone; the
correctness argument is not.** The deduction represents per-treasure costs, so
charging it per claim is simply wrong, and the fix is one line.

A whitelisted address claiming 250 shares at once would still be under-charged
250× without the fix, which is the case that keeps it worth shipping.

**The fix is one line, and it is backward compatible:**

```cairo
let rewardDue = claimShareCount * (gameHiderFee - gasFee - gameFee - gameLandownerFee);
```

For a single share this is `5,000,000 − 12,833 = 4,987,167` — **identical to
today**. It only changes bulk claims, charging per treasure hidden rather than per
claim submitted, which is what the deduction was always meant to represent.

Ship this **with** bulk hiding, not after.

### 4m-iii. The bulk-hide whitelist

Some addresses need to place more than 10 treasures a day — seeding a map for an
event, or a partner running a promotion. The whitelist grants that, and **nothing
else**: no ROZ bonus, no rate change, no exemption from the fee tiers or the Daily
Volume Multiplier. It lifts one limit and replaces it with two tighter ones.

| | Non-whitelisted | Whitelisted |
|---|---|---|
| Daily treasure cap | **10** | none |
| Per round, one address | — | **250** |
| Per round, **all whitelisted together** | — | **1,200** |
| Per rolling hour | — | **80** |
| Round total, shared | 2,840 | 2,840 |
| Fee tiers, volume multiplier, wallet rate | apply | **apply identically** |

**Why a Merkle root rather than a mapping.** Storing addresses on-chain costs a
write per address and a transaction per change. A root is one `felt252`; the list
lives off-chain and the caller supplies a proof. Adding fifty addresses costs one
setter call.

```cairo
// Only the owner writes this. Publishing a new root replaces the whole list -
// there is no incremental add or remove, which is deliberate: the list is
// always exactly what the published tree says it is.
whitelist_merkle_root: felt252,

fn set_whitelist_merkle_root(ref self: ContractState, new_root: felt252) {
    self.ownable.assert_only_owner();
    self.whitelist_merkle_root.write(new_root);
}
```

**Verification — Poseidon, proof plus index.** The index tells the verifier
whether each step hashes left or right, which is what lets the proof be a flat
list of siblings rather than a list of (sibling, side) pairs:

```cairo
use core::poseidon::PoseidonTrait;
use core::hash::{HashStateTrait, HashStateExTrait};

fn verify_merkle_proof(
    leaf: felt252, proof: Span<felt252>, root: felt252, mut index: u32,
) -> bool {
    let mut computed_hash = leaf;
    let mut i: u32 = 0;

    while i < proof.len() {
        let sibling = *proof.at(i);

        // The low bit of the index says which side this node sits on. Getting
        // it backwards produces a valid-looking hash that never matches, so a
        // whitelisted caller would silently fall back to the 10-a-day cap.
        computed_hash = if index % 2 == 0 {
            PoseidonTrait::new().update(computed_hash).update(sibling).finalize()
        } else {
            PoseidonTrait::new().update(sibling).update(computed_hash).finalize()
        };

        index = index / 2;
        i += 1;
    };

    computed_hash == root
}
```

**The leaf is the caller's address as `felt252`, nothing more.** Not the address
plus a limit, not a hash of the address — the tooling below builds it that way and
the two must agree exactly or every proof fails.

**Order of checks, and it matters:**

```
1. Verify the proof            -> is this caller whitelisted at all?
2. Whitelist round cap         -> 250 for THIS address in this round?
3. Whitelist hourly rate limit -> 80 for THIS address in the last 3,600s?
4. Whitelist collective cap    -> 1,200 across ALL whitelisted this round?
5. Global round capacity       -> 2,840 across everyone?
6. Fees, volume multiplier, wallet rate
7. Create treasures, update every counter
```

**The order runs personal, then collective, then global**, and that is what makes
the three errors mean different things:

| Revert | What it tells the caller |
|---|---|
| `'whitelist round cap'` | *you* have used your 250 |
| `'whitelist group cap'` | the whitelist as a whole has used its 1,200 |
| `'round treasure cap'` | the round is genuinely full, for everyone |

A whitelisted address that has spent its own allowance should not be told the
round is full, and one blocked by the group cap should not think it was its own
limit. Ordinary hiders can only ever see the third.

**The hourly limit is a simple resetting bucket**, not a true rolling window —
cheaper, and adequate for what it defends against:

```cairo
fn enforce_whitelist_rate_limit(
    ref self: ContractState, caller: ContractAddress, treasures: u32,
) {
    let now = get_block_timestamp();
    let mut window_start = self.whitelist_hour_start.read(caller);
    let mut count = self.whitelist_hour_count.read(caller);

    // A plain bucket: once an hour has elapsed the window restarts. Two full
    // batches CAN land 1 second apart across a boundary - acceptable, because
    // the 250 round cap still holds and that is what protects the round.
    if now >= window_start + 3600 {
        window_start = now;
        count = 0;
    }

    assert(count + treasures <= self.whitelistHourlyCap.read(), 'whitelist hourly limit');

    self.whitelist_hour_start.write(caller, window_start);
    self.whitelist_hour_count.write(caller, count + treasures);
}
```

**The collective cap is checked against a round-keyed running total:**

```cairo
// 1,200 across ALL whitelisted addresses in this round. The 250 above bounds
// one address; this bounds the group, because per-address limits do not
// compose - eleven addresses at 250 each would otherwise take 2,750 of 2,840
// and leave 90 for everybody else.
let groupSoFar: u32 = self.whitelist_round_total.read(gameWeek);

assert(
    groupSoFar + treasures <= self.whitelistCollectiveCap.read(),
    'whitelist group cap',
);

self.whitelist_round_total.write(gameWeek, groupSoFar + treasures);
```

**What the three limits buy.**

| Limit | Effect |
|---|---|
| **250** a round, per address | one address takes at most **8.8%** of the round |
| **1,200** a round, all together | the whitelist takes at most **42.3%**, whatever the list length |
| **80** an hour, per address | placing 250 takes **3.1 hours** of a 6-hour round |

The first stops one address monopolising a round; the second stops a *group* of
them doing it; the third stops any of them front-running the opening minutes.

**1,640 slots — 57.7% — are therefore always available to ordinary players**,
regardless of how many addresses are whitelisted. Before the collective cap that
figure was **90**, because eleven addresses at 250 each take 2,750 of 2,840.

**The cap first binds at five whitelisted addresses.** Four can each use their
full 250 (1,000 in total, under the cap); a fifth would push the group to 1,250
and is trimmed to 200. Below five it never fires, so it costs a short list
nothing.

**1,640 is a floor, not a ceiling.** Ordinary players are bounded only by the
global 2,840 — if the whitelist places nothing, they may take the entire round.
The 1,200 caps the whitelist group; it is not held in reserve for them.

And the economics stay hostile: at 250/round × 4 rounds the volume multiplier's
0.03× tail dominates, so **1,000 treasures yield 2,834 ROZ for $263** — a
break-even of **$0.0928/ROZ**, or a **$464M** market cap. **Whitelisting an
address does not make farming viable for it**, and the collective cap now bounds
what a group of compromised whitelist keys could take as well.

#### Off-chain: generating the tree

`starknet-merkle-tree`, Poseidon, leaves of one element:

```js
import * as Merkle from "starknet-merkle-tree";
import fs from "fs";

const whitelistedAddresses = ["0x123...", "0x456..."];

// One element per leaf, and that element is the raw address. This must match
// `let leaf: felt252 = caller.into();` in the contract exactly.
const tree = Merkle.StarknetMerkleTree.create(
  whitelistedAddresses.map(addr => [addr]),
  Merkle.HashType.Poseidon,
);

const proofs = {};
whitelistedAddresses.forEach((address, index) => {
  // The index is part of the proof - the contract needs it to know which side
  // each sibling sits on. Store it alongside, never regenerate it separately.
  proofs[address] = { index, proof: tree.getProof(index) };
});

fs.writeFileSync("whitelist-root.json", JSON.stringify({ root: tree.root }, null, 2));
fs.writeFileSync("whitelist-proofs.json", JSON.stringify(proofs, null, 2));
```

**Flow:** the owner generates the tree and calls `set_whitelist_merkle_root`; the
backend serves proofs from `whitelist-proofs.json`; the front end fetches the
caller's proof and index and passes both to `hide_treasure_bulk`.

**Regenerate the proofs whenever the list changes.** Every index shifts when the
tree is rebuilt, so a stale proof file silently drops addresses back to the
10-a-day cap. Publish the root and the proof file together.

A non-whitelisted caller passes an empty proof and any index; verification simply
fails and the daily cap applies. **Failing the proof is not an error** — it is the
normal path for almost every caller.

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
5b. **Progressive pricing (§2.5).** Hop 21 charges `5000`, hop 26 charges
   `10000`, hop 46 charges `20000`, hop 66 charges `40000`. Hops 1–20 charge
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
   Hop a fresh wallet all the way to hop 64 with no spawns. Hops 1–63 must credit
   `0.15e18` each and hop 64 `1e18`, for a pending total of `28.45e18` including
   participation. Re-read the pending balance after hop 64 and confirm the first
   63 credits were **not** revised upward — non-retroactivity is what most of the
   gate's strength rests on, and a retroactive implementation would nearly treble
   this wallet's yield.
5d-ii. **Participation survives a late crossing.** Reach 28 hops while still below
   $0.60, confirm no bonus, then keep hopping until the spend crosses. The `18e18`
   must credit at the crossing hop. A wallet that never crosses never gets it.
   Getting this wrong silently costs every honest player 18 ROZ a day, and a test
   that funds the wallet before hopping will not catch it.
5e. **A hide credits the fee as spend and the stake as nothing — the highest-value
   assertion here.** A wallet that only hides, three times, must end with
   `player_spend_today` and `player_lifetime_spend` at **exactly `600000`** — the
   three `$0.20` fees, and not one unit of the `$15` staked. Assert the number,
   not merely that it is non-zero: `15600000` would mean the stake is counting,
   and the $3 lifetime gate then falls to the $0.2128 a surviving hide really
   costs — **14× cheaper** — with both §2.6 measures void. See §2.6 rule 1.
5e-i. **A free hop gives no spend credit either.** Twenty USDC-free hops must
   leave both spend counters at zero, so free play alone can never clear the gate.
5e-ii. **Three hides clear the daily gate exactly, and the third pays full.**
   Following on from 5e: hides 1 and 2 credit `4.5e18` each, and hide 3 — the one
   that takes spend to `600000` — credits **`30e18`**, because the fee is charged
   before the rate is resolved (§4f step 0). All three sit in the 1.00× volume
   band, so no multiplier is involved.
5e-iii. **The fee tier steps at treasure 4.** Hides 1–3 each transfer `200000` of
   `hideFeeBase`; hide 4 transfers `250000`. After ten hides `player_spend_today`
   is exactly `600000 + 7 × 250000 = 2350000`, and not one unit of the `$50`
   staked appears in either counter.
5e-iv. **The Daily Volume Multiplier, band by band.** With a wallet that cleared
   the gate on hide 3, the instant-hide credits across ten hides must read:

   | Treasure | 1–3 | 4–5 | 6–7 | 8–9 | 10 |
   |---|---|---|---|---|---|
   | Band | 1.00× | 0.70× | 0.40× | 0.20× | 0.08× |
   | Credit | `30e18` | `21e18` | `12e18` | `6e18` | `2.4e18` |

   Assert the **10th** credit specifically — `2.4e18`. It is the band a farmer
   would reach and the one an off-by-one in the index would get wrong.
5e-v. **A bulk call equals the same number of single hides — the assertion that
   closes §4l-ii.** Run one wallet through `hide_treasure` ten times and another
   through `hide_treasure_bulk(50000000)`. **Both must end with identical pending
   ROZ and identical `player_spend_today`.** If bulk is cheaper or more generous
   by any amount, a farmer splits or combines calls to exploit the difference.
5e-vi. **The daily hide cap.** The 11th `hide_treasure` in a calendar day reverts
   with `'daily hide cap'`. Advance past midnight UTC and it succeeds. Separately,
   `hide_treasure_bulk(55000000)` — eleven treasures — reverts from a wallet that
   has not hidden today, because **the cap counts treasures, not calls** (§4m).
   `hide_treasure_bulk(50000000)` succeeds and leaves the counter at 10.
5e-vii. **Hide rates across all three wallet states.** Below the threshold a hide
   credits `4.5e18`; a new wallet that has cleared it credits `15e18`; an
   established wallet that has cleared it credits `30e18`. All at the 1.00× band,
   so the volume multiplier is not confounding the result.
5e-viii. **The survival rate is fixed at hide time.** Hide once while below $0.60 —
   `hider_survival_roz` must hold `7.5e18`. Then clear the gate, let the round
   pass unfound, and claim: the credit is **`7.5e18`, not `50e18`**. Repeat in the
   other direction — hide after clearing, then claim on a later day with that
   day's spend at zero, and the credit must still be `50e18`. Both directions
   matter: the first is the farmer's exploit, the second is an honest player
   losing 42.5 ROZ for claiming on a Monday morning (§4f).
5e-ix. **Find/steal is never reduced.** A wallet below the daily threshold, on a
   new wallet, with zero lifetime spend, credits the full **`110e18`** on a
   validated find. No state reduces it (§2.6).
5e-x. **The setter assertion (§4b).** `set_hide_fee_base(250000)` must revert with
   `'hide fee gate mismatch'` while `hideFeeTierBoundary` is 3 and
   `dailySpendThreshold` is `600000`, because 3 × `250000` is `750000`. Setting
   base and threshold together so the product holds must succeed. Assert that
   changing `dailyHideCap` alone — to 5, or 50 — **never** trips it: the cap is
   not part of the relationship.
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
    - `get_free_hops_remaining` counts down from 20; at zero the next hop reverts
      for lack of approval rather than silently doing nothing.
    - Fund and approve the same wallet, then confirm the next hop charges exactly
      `10000` units ($0.01) and the next spawn `100000` ($0.10).
17. **Free and paid differ only in cost (§4l-i).** From the zero-balance wallet:
    - After 20 USDC-free hops in one round, pending ROZ is exactly **`3e18`** —
      `hopRewardBelowThreshold` on every free hop, because free hops add nothing
      to the spend counters and the wallet is below $0.60. A free hop earns
      exactly what a *paid* hop by the same wallet would earn — the rate is set by
      the gate, never by whether the hop was charged for.
    - **Participation does not fire**, for two independent reasons: the wallet is
      below the daily spend threshold, and 20 hops is below the 28-hop minimum.
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
      share, `30e18` accrued if the wallet has cleared the gate.
    - `hide_treasure_bulk(50000000)` — ten treasures, the largest call the §2.3
      cap permits a normal wallet — gives 10 shares, one transfer of `50000000`
      **plus** `2350000` of fees, and pending ROZ matching test 5e-v exactly. It
      must *not* consult `main_game_grid_size`: the target round has none yet, so
      any grid read would return zero and revert. See §4m-i.
    - `hide_treasure_bulk(7000000)` reverts with `'not a multiple of hider fee'`.
    - **`hide_treasure_bulk(1000000000)` — the old $1,000 case — reverts** with
      `'daily hide cap'` from a non-whitelisted wallet, and **succeeds** from a
      whitelisted one only if 200 fits inside its 250-a-round and 80-an-hour
      budgets. See 17a-ii.
    - Exceeding `maxTreasuresPerRound` across *many* wallets reverts with
      `'round treasure cap'` — the per-wallet caps cannot see the aggregate, and
      this is the only limit that binds a whitelisted address in company.
17a-ii. **The whitelist (§4m-iii).**
    - A wallet in the published tree, passing its correct proof and index, may
      exceed 10 treasures in a day. The **same wallet with an empty proof falls
      back to the 10-a-day cap** — failing verification is the normal path, not
      an error.
    - A wallet with a valid proof but the **wrong index** must fail verification
      and fall back to 10. This is the likeliest tooling mistake, and it fails
      silently rather than reverting.
    - The 251st treasure in one round reverts with `'whitelist round cap'`, even
      though the daily cap does not apply. Advance the round and it succeeds.
    - The 81st treasure inside one hour reverts with `'whitelist hourly limit'`.
      Advance 3,600 seconds and it succeeds, and confirm the bucket **resets**
      rather than sliding — that is the documented behaviour, not a defect.
    - Only the owner may call `set_whitelist_merkle_root`; anyone else reverts.
    - Republishing a root with an address **removed** drops that address to the
      10-a-day cap on its next call, with no other state change.
17a-iii. **The collective whitelist cap (§4m-iii).**
    - Five whitelisted addresses each attempt 250 treasures in one round. The
      first four succeed (1,000 in total). The fifth places **200 and then
      reverts** with `'whitelist group cap'`, leaving the group total at exactly
      **1,200** — not 1,250.
    - **A non-whitelisted wallet can still hide after that.** This is the
      assertion the whole cap exists for: with the whitelist exhausted, 1,640
      slots remain and an ordinary player must not see `'round treasure cap'`.
    - Assert the three errors are distinguishable. An address that has used its
      own 250 gets `'whitelist round cap'`, *not* `'whitelist group cap'`; a fresh
      whitelisted address once the group is full gets `'whitelist group cap'`,
      *not* `'round treasure cap'`.
    - `whitelist_round_total` resets on the next round — five addresses may take
      1,200 again.
    - With four or fewer whitelisted addresses the cap never fires, and a
      non-whitelisted hide never increments the counter.
17a-i. **Dynamic scaling (§2.4).** After 200 hides in a round — now necessarily
    from at least 20 different wallets — the keeper sizes the next round at
    ~131×131 for the starting K of **2.2**. Confirm `get_game_grid_size(nextRound)`
    reports it, that a spawn lands inside it, and that a move to `132` reverts
    with `'out of game board range'`. Then confirm `TreasureFound` fires on a
    validated find carrying a plausible `hopsTaken` — without it K has no input.
    Separately, confirm the **capacity** case: `maxTreasuresPerRound` of 2,840 at
    K = 2.2 sizes a **500×500** board, which is the largest the stack must handle.
17b. **The deduction scales (§4m-ii).** A 1-share claim still pays exactly
    `4987167`. A 10-share claim pays `49871670`, **not** `49987167` — per treasure,
    not per claim. Ten is the largest a normal wallet can reach; a whitelisted
    address can reach 250, where the error would be 250×.
18. **The daily reset.** Spend the full hop allowance, advance past midnight UTC,
    and confirm it is restored — and that spending it in round 1 leaves nothing
    for rounds 2 to 4 that same day, proving the bucket is daily and not
    per-round. Confirm the same for `player_hides_today`: ten hides then midnight
    then an eleventh must succeed, with the **fee tier and volume band both back
    at their first-treasure values**.
19. **The sweep protects both tokens (§4j).** With pending ROZ and outstanding
    USDC claims, `withdraw_token_balance` must release only the surplus in each
    case. Sweep ROZ and confirm `claim_reward_tokens` still pays in full; sweep
    USDC and confirm `claim_reward` still pays `4987167`. Sweeping a third,
    unrelated token releases its whole balance.
20. **The keeper is idempotent (§4k).** Calling `start_new_game` twice for the
    same round index must not overwrite the round's parameters — EventBridge
    retries, so this will happen in production.

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
- ~~Is the hide loop reachable by any anti-farm measure?~~ — **it is now**
  (§2.3, §2.6, §4m). Hide rewards are gated (4.5 / 7.5 below the threshold, 15 /
  25 for a new wallet), a **tiered fee** applies, and a **Daily Volume Multiplier**
  scales rewards down past the third treasure of a day. Find/steal stays at 110
  for everyone, deliberately. The route's floor moves from **$0.8M to $23.1M** on
  fees, **$39M–$49M** with measured gas, and its transaction cost from ~147/day to
  ~500,000/day.
- ~~Does raising the hide cap to 10 weaken the gate?~~ — **no** (§4l-ii). It would
  have, on its own: each extra surviving hide adds 80 ROZ for $0.25. The Daily
  Volume Multiplier cancels it exactly — the farmer's optimum stays at three hides
  and **$0.00462/ROZ**, effectively the same floor the 3-a-day design produced.
- ~~Should the volume multiplier key to transaction size or daily count?~~ —
  **daily count** (§2.3). Keyed to transaction size it was bypassable by sending
  ten single hides instead of one bulk call of ten, which would have made the farm
  route roughly twice as cheap as the design it replaced.
- ~~Is measure 4 worth its centralisation?~~ — **no, it is removed** (§2.6). The
  `player_verified` flag needed an attestor, which is a new privileged writer and
  a target once ROZ has value. §2.6 now has three measures. An owner-controlled
  bulk-hide whitelist does exist (§4m-iii), but it grants no ROZ bonus — only
  higher hide limits — and the owner is already privileged for every setter.
- ~~What is `maxTreasuresPerRound`?~~ — **2,840**, owner-settable (§4m-i). At the
  starting K it implies a **500×500** maximum grid at 11.4 treasures per 1,000
  cells, and it caps hide-farming at **25.4%** of the daily tranche — the one
  protection that does not depend on price, gas or `P(found)`.
- ~~What is K's starting value?~~ — **2.2** (§2.4), mid-band and slightly toward
  the sparse side, to be revisited once the first round's real `T` is known.
- ~~How should rounds be started?~~ — **AWS EventBridge every 6 hours invoking a
  Lambda** that calls `start_new_game` (§4k). The Lambda must be idempotent, since
  EventBridge retries, and its key is as privileged as the owner's.
- ~~Should a round end early once all treasures are found?~~ — **yes** (§4k).
  Recommended trigger is the keeper rather than the finder, so no single player
  pays the gas for everyone.
- ~~Must the sweep protect claimable USDC?~~ — **yes** (§4j). Unlike the ROZ case
  this needs new state — a `total_usdc_claimable` running total — because USDC owed
  is computed from shares on demand and never totalled.
- ~~Should crossing a threshold mid-day upgrade earlier actions?~~ — **no**
  (§2.6). Reversing it would return the farm break-even to $0.00741/ROZ and lift
  the typical casual and active profiles back into their bands; the farm effect is
  the larger of the two, so the rule stands.
- ~~What should `dailySoftCapRoz` be?~~ — **136** (§2.5). It sits just under the
  137.2 raw ceiling, so it binds only the bought-crossing route. Near-inert
  by design, and no longer in conflict with `hopRewardCap`.
- ~~Does the per-hop reward stay at 1 in year 2?~~ — **no, it tapers with the
  tranche** (§4b-i). 630M ÷ 855M = **0.7368**, which is where the 0.74 figure came
  from. The same proportional rule applies to every later year.
- ~~How much does Starknet gas cost?~~ — **$0.025 – $0.04 per transaction**,
  measured. It now exceeds game fees on every route (§4l-ii), which is why the
  cheapest farm wallet moved from three hides to five.
- ~~Do we still want bulk hiding?~~ — **yes, respecified** (§4m, §4m-iii). Open to
  everyone, bounded by treasures rather than calls, with an owner-controlled
  Merkle whitelist for addresses that need to seed a map.
- ~~Zero-cost wallets earn more than they used to~~ — **resolved** (§4l-i-a).
  `hopRewardBelowThreshold` at **0.15** and 20 free hops put zero-USDC-fee yield
  at **3 ROZ/day** and the wallets needed to drain Year 1 at **780,822** — 33% more than the
  original pre-gate settings required, so this route is now the tightest it has
  been. Both the rate and restored 20-hop allowance do the work.
- ~~Is the claim-time ROZ lost or retryable?~~ — **retryable**, §4h.
- ~~Does the daily reward outweigh the core loop?~~ — **no.** At a maximum of 22
  it now sits below a find (110) and a completed hide cycle (80).
- ~~Do the rates taper across years 2 to 4?~~ — **yes**, §4b-i.
- ~~What happens after year 4?~~ — a **6% tail**, released across years 5 to 8.
- ~~Is a round a week?~~ — **no, 6 hours.** Capacity figures rebuilt in §2.2.
- ~~Deploy the token on its own first?~~ — **yes**, phase 1 of §5.

### Still open

- **Is 4,700–16,700 daily actives the right year 1 ceiling?** That is what the
  rates and the 855M tranche imply together under the revised bands (§2.2).
  **Unknowable before launch** — it depends entirely on public response — so treat
  it as something to measure in week one rather than settle now. Exceeding it
  exhausts the tranche early and stops all new rewards until the next release.
- **The live farm number is $39M–$49M, and it is bounded at a quarter of the
  tranche** (§4l-ii). The cheapest wallet is **5 hides + 28 hops — 262 ROZ for
  $1.219 in fees plus $0.85–$1.36 of gas**. On fees alone it is $23.1M at three
  hides; gas is what moves both the optimum and the floor. Above 25.4% of daily
  issuance `maxTreasuresPerRound` stops the route entirely, and the fallback hop
  route costs $392M+. Worth re-deriving whenever gas moves materially.
- **The keeper is a single point of failure** (§4k). EventBridge plus Lambda is
  decided, but the Lambda's key can start or corrupt any round, and a missed
  invocation means a round never begins. An on-chain permissionless
  `advance_round()` with a time check would retire that privilege — worth keeping
  on the roadmap rather than treating the keeper as final.
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
- **No player type meets its target — accepted as it stands** (§2.2). The bands
  are 25–70 / 140–280 / 300–500; the light casual earns **6** (≈55 with two
  hides), the typical casual **117.5** and the active player **286.7**. The
  options were weighed — lower the bands again, raise `hopRewardBelowThreshold`,
  or lower `dailySpendThreshold` — and **none was taken**, on the grounds that
  only the last helps the light casual and it is also the one that weakens the
  gate. Recorded as an accepted cost rather than an open question, but it should
  be the first thing re-examined if real players churn early.
- ~~Progressive pricing makes distributed farming cheaper~~ **Addressed by §2.6.**
  The daily spend threshold takes the cost of draining Year 1 from $2,801/day to
  **$49,813/day**, and the $3 lifetime threshold adds a **$247,008** one-off
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
- **The below-gate band needs hides, and the middle of the range is a trap**
  (§2.2, §2.6). Hopping caps a below-gate wallet at **9.6 ROZ**, so the 25–70 band
  is out of reach on hops alone. Two hides plus 42 hops reaches **30.3** while
  staying under the gate, or the same two hides carry the player *over* it to
  roughly **54**. Both clear the floor. **One hide leaves them at 18** — worse than
  either. A player who hides once and stops is in the worst place available to
  them, and nothing tells them so. Either accept that and put it in the UI, or
  raise `hopRewardBelowThreshold` so hops alone can reach 25.
- ~~The whitelist is protected per address, not as a class~~ — **resolved by a
  collective cap** (§4m-iii). The per-address 250 did not compose: eleven such
  addresses would have taken 2,750 of 2,840, leaving **90** for everyone else.
  `whitelistCollectiveCap` = **1,200** now bounds all whitelisted addresses
  together, so **1,640 slots — 57.7% — are always available to ordinary players**,
  whatever the list length. It first binds at **five** addresses, so a short list
  is unaffected, and it costs one round-keyed counter. Farming was never the risk
  here (a whitelisted address breaks even at **$464M**); crowding out was.
- **The 1,640 floor covers one hide per player, not two** (§4m-iii). Against the
  honest demand below:

  | 5,000 daily actives, each hiding… | Per round | vs floor 1,640 | vs cap 2,840 |
  |---|---|---|---|
  | once | 1,250 | **fits** | fits |
  | twice — what §2.2 asks of a light casual | 2,500 | **does not fit** | fits |

  At two hides each, ordinary players need the whitelist to be using less than 340
  of its 1,200. They are not blocked — the floor is a guarantee, not a limit, and
  the full 2,840 stays reachable — but **the guarantee alone does not cover the
  behaviour the design encourages.** Serving both in full needs **3,700 a round**,
  which at K = 2.2 is a **571×571** grid, above the 500×500 §4m-i sets as the
  maximum the off-chain stack must handle. So this cannot be fixed by raising
  2,840 without revisiting the grid bound first. Watch it alongside the ~70%
  utilisation trigger below.
- **Is 25.4% of the tranche the right hide-farm ceiling?** (§4l-ii). Every round
  has **2,840 treasure slots**, shared by everyone. If a farmer took every slot in
  every round they would earn **595,264 ROZ a day — a quarter of the day's
  issuance**. That is the worst case the cap permits, and the question is simply
  whether a quarter is too much to concede.

  Lowering the cap cuts it proportionally — 1,420 would halve the farmer to 12.7%.
  But **the contract cannot tell whose treasure is whose.** A slot is a slot, taken
  first-come, with nothing on it to say who filled it. So halving the pool halves
  honest hiding by exactly the same amount. It is one dial and it moves both sides
  together.

  **A farmer's slot is worth less than a player's, which argues for leaving it
  alone.** The volume multiplier dilutes them:

  | Who | ROZ per slot used |
  |---|---|
  | Honest player, 1 hide | **80** |
  | Farm wallet, 5 hides (216 ÷ 5) | **43.2** |

  A farmer's 4th and 5th treasures pay 0.70×, so they extract **1.9× less per
  slot** than someone hiding once. Tightening the cap therefore costs honest
  players almost twice what it costs a farm.
- **The slot pool is tighter at launch than it looks** (§4m-i). Capacity is 2,840
  a round, 11,360 a day. Honest demand at 5,000 daily actives:

  | Each player hides… | Per round | Capacity used |
  |---|---|---|
  | once | 1,250 | **44%** |
  | twice — what §2.2 asks of a light casual | 2,500 | **88%** |

  **Plan against two.** §2.2 tells a light casual to hide twice, because that is
  how they reach their 25–70 band, so high participation is what the design asks
  for rather than an upper bound on it. At the top of the Year 1 range — 16,700
  daily actives — two hides each is **8,350 a round, roughly 3× over capacity**.

  **When it fills, it fills first-come, and one side is automated.** A bot can hide
  the instant a round opens; a person cannot. So the pool does not fill evenly —
  it fills with whoever is watching for the block, and honest players get
  `'round treasure cap'`. Time in the game buys no priority: a wallet created this
  morning has the same claim as one that has played all year.

  Still worth watching rather than pre-solving, but with a trigger rather than a
  vibe: **track slot utilisation per round, and act if it passes ~70%.** Options
  then are a per-wallet round cap for everyone (not just whitelisted addresses),
  or raising 2,840 — which raises the grid as √T and needs the 500×500 check in
  §4m-i first.
- **Hiding at the wrong moment costs a player up to 68 ROZ** (§2.2, §4f). A
  typical casual who hides in round 3 earns 117.5; the same player hiding in round
  2, before their spend crosses $0.60, earns 50.35 — and the §4f snapshot makes it
  permanent. This is the action-ordering effect below, but an order of magnitude
  larger than the spawn case that first raised it. A UI hint ("hide after you have
  spent $0.60") fixes it for anyone who reads it and nobody who does not.
- **Is $3 lifetime too low? — accepted as it stands.** It buys a **$247,008**
  onboarding barrier where $5 would buy $411,680, so $3 gives roughly half the
  anti-churn effect. Accepted deliberately: the ratio is unchanged at about 4.9
  days of running cost either way, and the daily threshold does the work of
  deciding where the casual cliff falls.
- **Measure 3 only reduces players who spend — confirmed intended** (§2.6). A
  light casual is already at the measure-1 floor, so new-wallet status costs them
  nothing extra and the reduction lands on the mid-range player instead. Counter-
  intuitive given the name, and correct: the measure exists to price wallet churn,
  and a wallet that never spends is not worth churning.
- **The gate costs gas on every paid action** — two extra `u256` writes per hop
  and per spawn, a third on every hide for `player_hides_today`, and a fourth for
  `hider_survival_roz`, on paths players take dozens of times a day. At $0.025–
  $0.04 a transaction this is now a measurable share of what a player spends.
- **Gas is doing more anti-farm work than the fee schedule** (§4l-ii). The cheapest
  farm wallet pays **$1.219 in fees and $0.85–$1.36 in gas** — gas is the larger
  half. That raises a design question the plan has not faced: §2.5's four-tier
  progressive hop schedule is a lot of machinery for the smaller of the two costs,
  and a flat price might now buy the same protection for less complexity. Worth
  revisiting once real gas is observed rather than quoted.
- **Is the typical casual paying 36% more acceptable?** At 60 hops/day the tiered
  schedule costs $0.525 against $0.40 flat, and that player earns 117.5 against a
  140–280 band. Both accepted above, but they compound: this profile pays more and
  earns less than the design originally intended.
- **The hard grid bounds now follow from `maxTreasuresPerRound`** (§2.4, §4m-i).
  At 2,840 and the starting K of 2.2 the maximum board is **500×500**, at 11.4
  treasures per 1,000 cells. That fixes the upper bound the front end, the merkle
  tooling and the keeper must handle. **Raising the cap raises the board as √T** —
  5,000 treasures needs 663×663 — so the open part is not the number but whether
  the off-chain stack is tested at 500×500 before launch.
- ~~The hop reward cap contradicts the hop target~~ **Resolved** (§2.4). The cap
  is **40**, inside the 35–45 hops-per-find band, and at `dailySoftCapRoz` = 136
  the daily cap no longer clips it back.
- ~~Should hiding be genuinely free?~~ **No** (§2.3). A hide costs $0.20 or $0.25
  in fee, plus the 12,833 units retained on a surviving claim — **$0.2128** all in
  for one of the first three. The retention is no longer the only cost of a hide,
  so the revenue argument that used to justify keeping it is weaker; it stays
  because it is what makes the claim path self-funding.
- **Should the allowance cover full participation?** It deliberately does not:
  28 hops are needed against a 20-hop allowance, so 8 hops (~$0.055) must be paid
  for. Since the bonus now pays once per calendar day, that is the whole cost —
  not the $1.00/day a per-round bonus demanded. The gap is no longer the binding
  constraint either, since §2.6's $0.60 threshold withdraws the bonus outright
  below it. Closing the gap alone would not reopen the hole.
