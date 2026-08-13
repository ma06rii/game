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
| Per hop | **1** | Hard cap at **32 hops** per round; nothing beyond it. Price rises with daily volume — §2.5 |

### Once per day, not per round

| Action | ROZ | Conditions |
|---|---|---|
| Participation bonus | **18** | Requires **30 hops**, and pays **once per calendar day** |

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
| Daily free hops | `dailyFreeHops` | **20** | Per calendar day, shared across all four rounds | Lets a player try the game at no cost |
| Participation minimum hops | `participationMinimumHops` | **30** | Per calendar day — the bonus pays once daily | Puts the 18-ROZ bonus out of reach of free hops alone |
| Per-round hop cap | `hopRewardCap` | **32** | Per **round** | Stops grinding within a single round |
| Daily free spawns | `dailyFreeSpawns` | **1** | Per calendar day | One free repositioning a day |
| Soft warning threshold | *(none — UI only)* | ~28 hops | Per round | Warns a player they are near the cap. No contract effect |

**Two orderings carry the design, and neither may be broken:**

1. **`dailyFreeHops` (20) < `participationMinimumHops` (30).** This is what caps
   a zero-cost wallet at **20 ROZ/day**. Raise the allowance above 30 and that
   figure jumps to **38** the moment the bonus becomes free — see §4l-i-a.
2. **`participationMinimumHops` (30) ≤ `hopRewardCap` (32).** The bonus needs 30
   of a possible 32, so participation is close to maximum effort in a round, not
   a floor.

Reaching the bonus therefore costs 10 paid hops — ten cents. It cannot be had
for nothing.

### The intended hierarchy

1. **Find / steal** — clearly the best single action
2. **Successful hide** (instant + survival) — strong and satisfying
3. **Participation** — meaningful but secondary, and now demanding: 30 of a
   possible 32 hops
4. **Per hop** — the light drip that rewards exploration itself

There is no longer a retention layer. It sat at position 4 and was triggered by
the daily spawn, which now pays nothing.

**The `+ $5 USDC` on find/steal already works and needs no new code.** A finder
takes the hider's stake through `validate_treasure_coordinates`, and claiming it
pays `5,000,000 − 12,833 = 4,987,167` USDC units. Only the 110 ROZ is new.

### Design targets and what year 1 can sustain

| Player type | Expected ROZ/day | |
|---|---|---|
| Light casual | 80 – 160 | 1–2 rounds, light hopping |
| Typical casual | 180 – 320 | 2–3 rounds, one hide, some searching |
| Active | 350 – 550 | Most rounds, consistent hiding and finding |

The Year 1 tranche of 855,000,000 gives a budget of **2,342,466 ROZ per day**:

| Player mix | Daily actives sustained |
|---|---|
| Light casual (80–160) | 14,600 – 29,300 |
| Typical casual (180–320) | 7,300 – 13,000 |
| Active (350–550) | 4,300 – 6,700 |

**Year 1 therefore supports roughly 4,000 to 13,000 daily actives** on a
realistic mix. That is the ceiling the rates imply. If the game is expected to
exceed it, the rates or the tranche need revisiting **before** launch — running
dry mid-year stops all new rewards until the next tranche is released.

### No player type now meets its target

Three changes compound — the 30-hop participation minimum, the removal of the
daily spawn reward, and participation moving to once per day. What the current
rates actually pay, and what a day now costs in hop fees:

| Player | Round pattern | Hops | Daily spend | **Before the gate** | **After the gate (§2.6)** | Target |
|---|---|---|---|---|---|---|
| Light casual | 2 rounds × 20 hops | 40 | $0.275 | 40 | **11** | 80 – 160 |
| Typical casual | 2.5 rounds × 25 hops | 62 | $0.665 | 142 | 160 | 180 – 320 |
| Active | 4 rounds × 32 hops | 128 | $3.445 | 336 | 336 | 350 – 550 |

The gate in §2.6 is what separates the two reward columns: the two heavier
players clear the $0.50 daily threshold and are unaffected, while the light
casual falls below it and drops to a fifth of their rewards.

Three causes, all deliberate individually:

- **Participation is unreachable below 30 hops in a round**, so light play earns
  nothing from it where 15 hops used to qualify.
- **The daily spawn reward is gone**, removing a floor that did not depend on
  effort.
- **Participation now pays once a day, not four times**, which costs the active
  player 54 ROZ on its own.

Every band is now missed, the active player included. Meanwhile the active
player's hop fees rose from $1.38 to $3.145 — earning less and paying more. The
anti-farm measures in §2.5 are working, but they are not free: they land on
honest players too. Either the targets or the rates need revisiting — see §9.

## 2.3 Daily free allowances (anti-frustration)

### The revised price list

| Action | Price | Contract value (USDC, 6dp) | Notes |
|---|---|---|---|
| Hide treasure | **Free** | `currentHiderFee` unchanged at `5000000` | Only the $5 stake is locked |
| Single hop | **$0.005 – $0.04** | tiered — see §2.5 | 20 free per day; the price rises with daily volume |
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

20 free hops against a 32-hop cap is roughly **two thirds of a round**, not all of
it. That is the point: the participation minimum is 30 hops, so **the bonus can
never be reached on free hops alone**. A player has to spend 10 cents' worth of
hops to earn it.

That single relationship — allowance below minimum — is what caps zero-cost
farming at 20 ROZ/day. See §4l-i-a.

The free tier costs **$0.30 per day** per player who uses it in full, down from
$4.00 at the old prices.

Players may spread the 20 hops across several rounds, but pay $0.10 for each
spawn beyond the first.

**The allowance does far less work than the price cut.** Dropping hops to $0.01
saves an active player $15.12/day; the allowance saves $0.30 on top. Worth
weighing against the complexity in §4l — most of the anti-frustration win is
already banked by the new prices.

### Two interactions worth noting

**Full participation costs more than the allowance covers — deliberately.** The
bonus needs 30 hops per round; across four rounds that is 120 hops a day, against
a 20-hop allowance. A player chasing participation in every round pays
**$1.00/day**.

That gap is not an oversight. Because 20 free hops fall short of the 30-hop
minimum, the bonus can never be earned for nothing — which is what caps zero-cost
farming at 20 ROZ/day (§4l-i-a). Closing the gap would reopen the hole.

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

### Two tensions worth resolving before launch

**The hop reward cap contradicts the hop target.** The model aims for 35–45 hops
per find, but §2.2 stops paying `rewardPerHop` after **32 hops** in a round. A
player earns nothing on exactly the hops where a find becomes likely. Either
raise the cap toward ~45 or lower the target — they should not disagree with each
other.

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
| 1 – 20 | **Free** (the §2.3 allowance) |
| 21 – 25 | $0.005 |
| 26 – 45 | $0.010 |
| 46 – 65 | $0.020 |
| 66 and beyond | $0.040 |

**The tiers must reset daily, never per round.** With per-round tiers a farmer
re-enters tier 1 four times a day and pays **$0.645** for 128 hops instead of
$3.145 — five times cheaper, which guts the measure entirely.

### The crossover sits at ~47 hops a day

Below it the new schedule is cheaper than the old flat $0.01; above it, dearer:

| Hops/day | Progressive | Old flat | |
|---|---|---|---|
| 30 | $0.075 | $0.10 | cheaper |
| 45 | $0.225 | $0.25 | cheaper |
| **48** | **$0.285** | **$0.28** | dearer |
| 60 | $0.525 | $0.40 | dearer |
| 128 | $3.145 | $1.08 | dearer |

That is the shape intended: light play gets cheaper, grinding gets dearer. Note
the typical casual at 60 hops/day now pays **31% more**, on top of already
earning below target (§2.2).

### Participation once per calendar day

The 18-ROZ bonus is claimable **once per day**, not once per round. With four
rounds a day this alone cuts the maximum daily hop-and-participation yield from
200 ROZ to **146**.

### The daily soft cap

Beyond `dailySoftCapRoz`, further hop and participation rewards are multiplied
down — 0.2× or zero. Casuals never reach it; grinders do.

**Set it near 100, not 140–160.** Because participation now pays once a day, the
theoretical maximum from hops plus participation is `128 + 18 = 146 ROZ`. A cap
at 150 or 160 is above the ceiling and **can never bind**. At 140 it clips six
ROZ. Only a value near 100 does real work.

### Free hops stay below the farm point

Measure 4 is already satisfied: `dailyFreeHops` (20) sits below
`participationMinimumHops` (30), so the bonus can never be had for nothing. See
§4l-i-a — that ordering is the rule to preserve.

---

### What these measures actually achieve

**Against one large wallet, they work well:**

| | Before | After |
|---|---|---|
| Cost of a maximum day | $1.38 | **$3.445** |
| Yield | 200 ROZ | **146 ROZ** |
| Break-even | $0.0069/ROZ | **$0.0236/ROZ** |

**3.4× more expensive.** A whale is meaningfully deterred.

**Against many small wallets, they make matters slightly worse.** A wallet doing
just 30 hops — enough for participation, using the free spawn — never leaves
tiers 1 and 2, where hops cost **half** the old flat rate:

| | Before | After |
|---|---|---|
| Cost per wallet | $0.10 | **$0.075** |
| Yield | 48 ROZ | 48 ROZ |
| Break-even | $0.00208 | **$0.00156** |
| Cost to drain Year 1 (~48,800 wallets) | $4,880/day | **$3,660/day** |

Progressive pricing punishes **concentration** and rewards **distribution**, and
wallets cost nothing to create. So the farmer's answer is simply more wallets,
each staying in the cheap tiers.

**What actually constrains the distributed attack is gas.** Thirty hops plus a
spawn is 31 transactions per wallet per day, against $0.075 of game fees. At any
plausible Starknet price the gas bill is several times the fees — so gas, not the
fee schedule, is doing the anti-farm work. That is worth **measuring** rather
than assuming, since it also sets the floor on what honest play costs.

Closing the distribution route needs a different kind of lever — a per-wallet
minimum spend, gating rewards on a funded balance, or proof of humanity. **That
is what §2.6 adds**, and it takes the cost of draining Year 1 from $3,660/day to
$16,430/day.

---

## 2.6 The Lightweight Gate

Four measures aimed at the one thing §2.5 could not reach: many small wallets.
The principle is that **full rewards are earned by players who actually spend**,
while free play stays open to everyone.

### The four measures

1. **A daily spend threshold.** Full hop and participation rewards require a
   wallet to have spent **≥ $0.50** that day. Below it, rewards are reduced.
2. **Free hops and the free spawn stay available to everyone.** Onboarding is
   unchanged — anyone can play immediately, they simply earn at a reduced rate
   until they spend.
3. **New wallets earn reduced rates** until they reach a small **lifetime**
   spend, suggested at $5.
4. **Optional proof-of-humanity boost** — a higher cap or a small bonus for a
   wallet with linked social.

### Measure 1 does the work §2.5 could not

$0.50/day is first reached at **54 hops plus one paid spawn** ($0.505):

| | Ungated (§2.5) | With the gate |
|---|---|---|
| Cost per farm wallet | $0.075 | **$0.505** |
| Yield | 48 ROZ | 72 ROZ |
| Break-even | $0.00156/ROZ | **$0.00701/ROZ** |
| Cost to drain Year 1 | $3,660/day | **$16,430/day** |

**4.5× more expensive**, and it lands precisely where progressive pricing failed.

### Measure 3 is the strongest lever, because it is one-off

A lifetime threshold attacks wallet *churn* rather than wallet *activity*, which
is the farmer's actual cost centre:

| Lifetime threshold | Cost to onboard 32,534 farm wallets |
|---|---|
| $1 | $32,534 |
| $2 | $65,068 |
| **$5** | **$162,670** |
| $10 | $325,340 |

At $5 that is a ten-day up-front barrier per wallet, against a gated running cost
of $16,430/day. It is the single most effective measure here.

### The honest cost: a light casual is switched off

| Player | Hops | Daily spend | Gate | ROZ | Target |
|---|---|---|---|---|---|
| Light casual | 40 | $0.275 | **reduced** | **11** | 80 – 160 |
| Typical casual | 62 | $0.665 | full | 160 | 180 – 320 |
| Active | 128 | $3.445 | full | 336 | 350 – 550 |

**A light casual and a small farmer are indistinguishable by spend.** The gate
cannot separate them, so it hits both. Eleven ROZ against a target of 80–160 is
not a marginal effect — that player has effectively been turned off.

This is the trade the gate asks for, and it should be made deliberately rather
than discovered after launch. See §9.

---

### Two rules that decide whether the gate works at all

**1. The hide stake must not count as spend.**

The $5 hide fee is refundable — a surviving hider claims back `4,987,167` of
`5,000,000`, so its true cost is **$0.0128**.

If the stake counted toward either threshold, a farmer would hide once and clear
a $5 lifetime gate for $0.0128 instead of $5 — **391× cheaper** — and both
measures 1 and 3 become free to bypass.

**Only irrecoverable fees may count:** hop fees, spawn fees, and the 12,833 units
the contract retains on each claim.

**2. Reduction multipliers must never compound.**

Three reductions can now apply to the same reward — the soft cap (0.2×), below
daily spend (0.2×), and new wallet (0.5×):

| | Result |
|---|---|
| If they multiply together | 0.2 × 0.2 × 0.5 = **0.02×** — a new casual player receives **2%** |
| If the lowest applies alone | **0.2×** — 20% |

Compounding would leave a new light player with essentially nothing on their
first day, which is the exact opposite of measure 2's intent. **Take the lowest
single multiplier.**

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
| `participationMinimumHops` | 30 | plain count, `u256` |
| `hopRewardCap` | 32 | plain count, `u256` — per **round** |
| `dailyFreeHops` | 20 | plain count, `u256` |
| `dailyFreeSpawns` | 1 | plain count, `u256` |
| `dailySoftCapRoz` | 100 (18dp) | see §2.5 — **not** 140–160, which cannot bind |
| `softCapMultiplierNum` / `Den` | 1 / 5 | 0.2× beyond the cap |
| `dailySpendThreshold` | `500000` ($0.50) | §2.6 measure 1 |
| `lifetimeSpendThreshold` | `5000000` ($5.00) | §2.6 measure 3 |
| `belowThresholdNum` / `Den` | 1 / 5 | 0.2× below the daily threshold |
| `newWalletNum` / `Den` | 1 / 2 | 0.5× below the lifetime threshold |
| `verifiedBonusNum` / `Den` | — | §2.6 measure 4, if adopted |

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
daily reward and its streak formula are gone. `participationMinimumHops` is
deliberately set **above** `dailyFreeHops`, which is what stops the bonus being
farmed for free.

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

**Two hop counters are required, and they cannot be merged.** The 32-hop reward
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
  reaching 30 hops proves they spawned.

Participation therefore needs one counter and one flag: count the hops, and
record that the bonus has been paid so it pays once per round rather than on
every hop past the thirtieth.

### 4f. Wiring each entrypoint

| Entrypoint | Credits |
|---|---|
| `hide_treasure` | `rewardHide`, and increments `hider_share_amounts` |
| `hide_treasure_bulk` | `rewardHide × treasureCount`, and adds `treasureCount` to `hider_share_amounts` — see §4m |
| `finder_player_generate_position` | **Nothing.** A spawn repositions the rabbit and pays no ROZ, free or paid. It consumes the free spawn allowance first, which affects the USDC charge only |
| `finder_player_move_position` | Charges the §2.5 tier price for the day's hop number; adds it to both spend counters; increments both hop counters; credits `rewardPerHop` under the round cap; credits `rewardParticipation` at 30 hops, **once per day**; applies the **single lowest** applicable multiplier — soft cap, below daily spend, or new wallet — never their product. The free/paid distinction gates only the USDC transfer — see §4l-i |
| `validate_treasure_coordinates` | moves a share between `hider_share_amounts` and `finder_share_amounts` |
| `claim_reward` | credits `hider_shares × rewardHideSurvived + finder_shares × rewardFind`, and sets `reward_token_claimed` only if that credit succeeded |
| `claim_reward_token_for_week` | retries the above for one week — see §4h |

Every one of these goes through `_accrueRewardToken` — a credit to the pending
map, never a transfer, and skipped rather than reverted when uncovered.

The five gameplay rewards ignore the helper's return value: they come round again
next round, so a skipped hop or hide is not worth tracking. Only the claim leg
records whether it landed.

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
dailyFreeHops:   u256,   // 20 - two thirds of a round against the 32 hop cap,
                         //      and deliberately BELOW participationMinimumHops
                         //      (30). That ordering is what caps a zero-cost
                         //      wallet at 20 ROZ/day - see 4l-i-a.
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
// know whether it was paid for. The hop counter, the 32-hop cap, the 30-hop
// participation test and the ROZ accrual all run exactly as they would for a
// paid hop. See 4l-i.
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
| Awards ROZ | Yes, `rewardPerHop` | **No — and neither does a paid spawn** |
| Counts toward the 30-hop participation minimum | Yes | n/a |
| Counts toward the 32-hop reward cap | Yes | n/a |
| Charges USDC | **No** | **No** |

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

Free hops earn ROZ, so a zero-cost wallet earns *something*. Two settings cap how
much: **`dailyFreeHops` is 20 and `participationMinimumHops` is 30.**

| | ROZ |
|---|---|
| 20 free hops × `rewardPerHop` | 20 |
| Participation — needs 30 hops, only 20 are free | **0** |
| Spawn — pays nothing, free or paid | 0 |
| **Total, at zero USDC cost** | **20/day** |

Reaching the 18-ROZ bonus costs 10 paid hops — ten cents. It cannot be had for
nothing.

That relationship is the whole defence, and it is worth stating as a rule:
**keep `dailyFreeHops` strictly below `participationMinimumHops`.** Raise the
allowance above 30 and zero-cost earnings jump from 20 to 38 immediately.

Against the Year 1 budget of 2,342,466 ROZ/day, roughly **117,000 throwaway
wallets** would be needed to drain the tranche, paying Starknet gas throughout.
Earlier settings needed only 48,800, so this is a **2.4× improvement** — achieved
purely by the ordering of two numbers, with no extra contract logic.

Remaining levers if it still looks too generous:

- **Lower `dailyFreeHops` further** — the zero-cost figure is exactly that number.
- **Accept it on testnet**, and gate on a funded balance before mainnet.

### 4l-ii. The residual farming route is the hide loop

Gating free actions removes zero-cost farming, but it leaves paid routes whose
ROZ yield may exceed their USDC cost. **The 10× price cut moved every one of
these 10× cheaper:**

| Route | ROZ | Real cost | Break-even |
|---|---|---|---|
| Per-hop | 1 | $0.01 | $0.01000 |
| 30 paid hops, which also earn the participation bonus | 48 | $0.30 | $0.00625 |
| Hide cycle, if unfound | 80 | $0.0128 | **$0.00016** |

There is no spawn row — a spawn pays nothing.

The hide loop is still the cheapest, because the $5 hide fee is *staked* rather
than spent — survive the round and the player claims back $4.99, keeping 80 ROZ
for the 12,833 units the contract retains. Its real cost is `P(found) × $5`, so
it is expensive in a busy game and nearly free in a quiet one. **With 6-hour
rounds there will be quiet ones.**

But the price cut has narrowed the gap: hopping and participation used to be
500× dearer than hiding, and are now only ~50×.

### What a maximising farm wallet now costs

| | |
|---|---|
| Daily cost | **$1.38** — 108 paid hops + 3 paid spawns |
| Daily yield | **200 ROZ** — 128 per-hop, 4 × 18 participation, 0 from spawns |
| Break-even | **$0.0069/ROZ**, i.e. a **$35M** market cap at 5B supply |
| To drain the Year 1 tranche | ~11,700 wallets/day, costing the farmer ~$16,200/day |

$35M is an ordinary valuation for a successful game token, so this is a live risk
rather than a theoretical one — and it arrives precisely when the token is doing
well.

Note the asymmetry the free allowance creates: it caps a **zero-cost** wallet at
20 ROZ/day, but a farmer willing to spend $1.38 is barely slowed. The allowance
defends against throwaway wallets, not against funded ones. The fix for the
latter is a tokenomics choice, not an engineering one; see §9.

### 4l-ii-a. Resolved — the free allowance no longer penalises the player

This section previously recorded a real problem: because free hops earned no ROZ
and the allowance was consumed automatically, taking it forfeited 30 per-hop ROZ
plus a blocked participation bonus for a saving of only $0.30. The allowance
became a **net loss** to the player once ROZ passed $0.00625, and the rational
move was to avoid the feature entirely.

**§4l-i now makes free hops identical to paid hops apart from the charge**, so
the trade disappears: a free hop saves $0.01 and earns exactly what a paid hop
earns. There is nothing left to route around.

The cost of that fix is the sybil surface in §4l-i-a — 48 ROZ/day for a wallet
that spends nothing. Kept here as a record of why the rule changed.

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
5. **Hop, cap and participation.** Move once — pending rises by `1e18`. At the
   **30th** hop, participation credits `18e18` **exactly once**, not per hop. Hop
   32 still credits; hop 33 credits nothing and the move itself still succeeds.
5a. **Participation is daily, not per round (§2.5).** After earning it in round 1,
   reach 30 hops again in round 2 — it must **not** credit a second time. Cross
   midnight UTC and it credits again.
5b. **Progressive pricing (§2.5).** Hop 21 charges `5000`, hop 26 charges
   `10000`, hop 46 charges `20000`, hop 66 charges `40000`. **The tiers must not
   reset at a round boundary** — hop 33, the first of round 2, still charges the
   tier its daily number falls in, not `5000`. This is the single most important
   assertion in the anti-farm work.
5c. **The soft cap.** Drive `player_hop_roz_today` past `dailySoftCapRoz`, then
   hop again — the credit is multiplied down, not full. Confirm it resets at
   midnight UTC.
5d. **The daily spend gate (§2.6).** At `player_spend_today` of `499999` a hop
   credits `0.2e18`; at `500000` it credits the full `1e18`.
5e. **The hide stake gives no spend credit — the highest-value assertion here.**
   A wallet that only calls `hide_treasure` or `hide_treasure_bulk`, however
   much it stakes, must leave `player_spend_today` and `player_lifetime_spend`
   at **zero**. If the stake counts, a $5 lifetime gate is clearable for $0.0128
   and both §2.6 measures are void.
5f. **New-wallet rate.** A wallet below `lifetimeSpendThreshold` earns at 0.5×
   even once it clears the daily threshold. Cross $5 lifetime and it earns full.
5g. **Multipliers do not compound.** With a new wallet, below the daily spend
   threshold, and past the soft cap all true at once, the applied multiplier is
   **0.2×, not 0.02×**. Assert the credited amount directly.
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
    - `get_free_hops_remaining` counts down from 30; at zero the next hop reverts
      for lack of approval rather than silently doing nothing.
    - Fund and approve the same wallet, then confirm the next hop charges exactly
      `10000` units ($0.01) and the next spawn `100000` ($0.10).
17. **Free and paid differ only in cost (§4l-i).** From the zero-balance wallet:
    - After 20 free hops in one round, pending ROZ is exactly **`20e18`** —
      `rewardPerHop` on every free hop, as if each had been paid for.
    - **Participation does not fire.** 20 hops is below the 30-hop minimum. This
      is the cap on zero-cost farming and the most important assertion here.
    - Fund the wallet, hop 10 more times. Participation credits `18e18` on the
      **30th** hop, once, bringing pending to `48e18` for $0.10.
    - The 32-hop cap counts free hops: hop 33 earns nothing. Free hops must not
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

- ~~Hop cap and participation minimum~~ — **32 and 30**. All four allowance and
  limit settings are summarised in one table in §2.2.
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
- **Is 4,000–13,000 daily actives the right year 1 ceiling?** That is what the
  rates and the 855M tranche imply together. Exceeding it exhausts the tranche
  early and stops all new rewards until the next release.
- **Sweeping USDC still strands outstanding claims** (§4j). Pre-existing, not
  fixed here, and worth a decision since the function is being changed anyway.
- **Farming break-evens fell 10× with the price cut** (§4l-ii). A maximising farm
  wallet now costs **$1.38/day** and yields **200 ROZ** — break-even at
  **$0.0069/ROZ**, a $35M market cap. ~11,700 wallets would drain the Year 1
  tranche for ~$16,200/day. That is an ordinary valuation for a successful game
  token, so it is a live risk, not a theoretical one. The hide loop remains the
  cheapest single route at $0.00016.
- ~~The free allowance costs an earning player money~~ **Resolved** — free hops
  are now identical to paid hops apart from the charge (§4l-i).
- ~~Zero-cost wallets earn 48 ROZ/day~~ **Reduced to 20** (§4l-i-a), by setting
  `dailyFreeHops` (20) below `participationMinimumHops` (30). About 117,000
  wallets would now be needed to drain Year 1, up from 48,800.
- ~~Should a free spawn earn the daily reward?~~ **Settled: spawning pays
  nothing**, free or paid. Free and paid now differ only in cost, everywhere.
- **The daily and streak retention layer no longer has a trigger.** It was
  attached to the spawn. Removing the spawn reward removed it, along with
  `player_last_spawn_day` and `player_streak_days`. Either accept that the game
  has no retention reward, or move the trigger to the player's **first hop of the
  day** — which needs the same day-index state and keeps spawns reward-free as
  decided. The nine-row streak table is preserved in git history if it returns.
- **No player type now meets its target** (§2.2). Light casual 40 against 80–160,
  typical 142 against 180–320, active 336 against 350–550 — and the active
  player's hop fees rose from $1.38 to $3.145 at the same time. The anti-farm
  measures land on honest players too. Either the targets or the rates need
  revisiting.
- ~~Progressive pricing makes distributed farming cheaper~~ **Addressed by §2.6.**
  The daily spend threshold takes the cost of draining Year 1 from $3,660/day to
  **$16,430/day**, and a $5 lifetime threshold adds a **$162,670** one-off
  onboarding barrier.
- **The Lightweight Gate switches off the light casual** (§2.6). At 40 hops and
  $0.275 daily spend they fall below the $0.50 threshold and earn **11 ROZ**
  against a target of 80–160. A light casual and a small farmer are
  indistinguishable by spend, so the gate cannot separate them. Options: lower
  the threshold, make the reduction gentler than 0.2×, or exempt a wallet's first
  N days.
- **What should the two thresholds be?** $0.50/day and $5 lifetime are the
  worked example, not a derived answer. The daily one sets where the casual
  cliff falls; the lifetime one sets the farm's onboarding cost.
- **Is measure 4 worth its centralisation?** A `player_verified` flag needs an
  attestor — a new privileged writer, and a target once ROZ has value.
- **The gate costs gas on every paid action** — two extra `u256` writes per hop
  and per spawn, on a path players take dozens of times a day.
- **How much anti-farm work is gas already doing?** 31 transactions per wallet
  per day against $0.075 of game fees. If gas is several times the fees, it is
  the binding constraint and the fee schedule is secondary. Worth measuring
  before tuning the tiers further.
- **What should `dailySoftCapRoz` be?** 140–160 as suggested **cannot bind** —
  the theoretical maximum is 146 ROZ once participation pays daily. Near 100 is
  the first value that does real work.
- **Is the typical casual paying 31% more acceptable?** At 60 hops/day the tiered
  schedule costs $0.525 against $0.40 flat, and that player already earns below
  target.
- ~~Is a 14×14 grid big enough for bulk hiding?~~ **Resolved by §2.4** — the grid
  is now sized from the hide count (`T × 40 × K`), so it grows to fit. The $1,000
  case produces a ~126×126 board.
- **What are the hard grid bounds, and therefore `maxTreasuresPerRound`?** (§2.4,
  §4m-i) The minimum and maximum grid size and the treasures-per-1,000-cells cap
  are stated as principles but not as numbers. `maxTreasuresPerRound` is derived
  from them, so it cannot be set until they are.
- **The hop reward cap contradicts the hop target** (§2.4). 35–45 hops per find
  against a 32-hop reward cap means players earn nothing on exactly the hops
  where a find becomes likely.
- **What is K's starting value?** The band is 1.8–2.5 and moves ±0.15 a round, so
  a bad opening value takes several rounds to correct — during which the map is
  visibly too dense or too sparse.
- **Should hiding be genuinely free?** The plan calls it free, but a surviving
  hider gets back `4,987,167` of their `5,000,000` stake — the contract retains
  12,833 units (~$0.0128) on every claim. With hop and spawn revenue down 92%,
  those retentions are now a much larger share of income, so removing them is not
  free either.
- **Should the allowance cover full participation?** It deliberately does not.
  30 hops × 4 rounds = 120 a day for participation in every round, against a
  20-hop allowance. A completionist pays $1.00/day. That gap is the anti-farming
  mechanism (§4l-i-a), so closing it would reopen the hole.
