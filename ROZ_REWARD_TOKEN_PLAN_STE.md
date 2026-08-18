# ROZ Reward Token Plan - Report in Simplified Technical English

This report gives the same information as `ROZ_REWARD_TOKEN_PLAN.md`. This report
uses the ASD-STE100 writing rules.

The writing rules are:

- Short sentences. Each sentence has one instruction or one idea.
- The active voice.
- Simple verb tenses.
- One meaning for each word. One word for each meaning.
- Vertical lists and tables for complex information.

The technical names do not change. Examples are `ROZToken`, `claim_reward` and
`hide_treasure_bulk`. All the numbers are the same as the numbers in the detailed
report.

**This report is shorter than the detailed report.** The detailed report has 1,408
lines. A word-for-word version in Simplified Technical English is longer than the
original and more difficult to use. Thus this report gives every decision, number
and danger, but not all the reasons. Read `ROZ_REWARD_TOKEN_PLAN.md` if you must
write the code.

---

## 1. Introduction

The game gives two rewards to the players:

- **USDC** - the value of the hidden treasure.
- **ROZ** - the game reward token.

The USDC rewards operate now. The ROZ rewards do not operate. This report tells
you what you must do to make them operate.

The game does not calculate a USD price for ROZ. There is no price source in the
reward code. The market decides the value of ROZ.

## 2. The token

The file `src/game_reward_token.cairo` has the token contract:

| Item | Value |
|---|---|
| Name | `ROZToken` |
| Symbol | `ROZ` |
| Decimals | 18 |
| Total supply | 5,000,000,000 |
| Mint after deployment | Not possible |

The contract makes all the tokens one time, at deployment. It sends them to one
address. There is no mint function after that. Thus the game contract can pay
only the tokens that you send to it.

**One problem stops the token now.** The file does not compile:

1. The file `src/lib.cairo` does not declare the module. Thus the build does not
   see the file.
2. The file uses the OpenZeppelin version 3 import paths. The project uses
   version 2.0.0.

Version 2.0.0 has all the necessary parts. Only the paths are different. Thus you
must change four import lines. You do not have to change the dependency.

## 3. The supply schedule

**45% of the supply is for the players.** This is 2,250,000,000 ROZ. The other
55% stays in your account.

| Period | Part of the pool | ROZ |
|---|---|---|
| Year 1 | 38% | 855,000,000 |
| Year 2 | 28% | 630,000,000 |
| Year 3 | 18% | 405,000,000 |
| Year 4 | 10% | 225,000,000 |
| Year 5 and after | 6% | 135,000,000 |
| **Total** | **100%** | **2,250,000,000** |

**The tranche is the control.** Send one year of tokens to the game contract at a
time. The contract cannot pay more tokens than it holds. Thus you do not need
code to apply the schedule.

The reward rates decrease each year. The rates change with the percentages.

## 4. What the players earn

A game round is **6 hours**. There are 4 rounds each day.

### Rewards for each round

| Action | ROZ | Conditions |
|---|---|---|
| Hide a treasure | 30 | Immediately. The value decreases to 4.5 or 15, and then the **Daily Volume Multiplier** operates. Costs $0.20 or $0.25, and the maximum is 10 each day. Refer to section 5 |
| The treasure is not found in the round | 50 | At the claim. The value decreases to 7.5 or 25, and then the Daily Volume Multiplier operates. The contract selects the rate **when the player hides**, not at the claim. Refer to section 7 |
| Find or steal a treasure | 110 | Also approximately $5 USDC. **This is the only reward that stays full for all the players** |
| Each hop | 1 | Maximum 40 hops in a round. The value decreases to 0.15 or 0.5. Refer to section 5.2 |

### One reward for each day

| Action | ROZ | Conditions |
|---|---|---|
| Participation | 18 | The player must make 28 hops. The game gives this reward one time each day. The value decreases to 9, or to 0. Refer to section 5.2 |

Before, the game gave this reward in each round. There are 4 rounds each day.
Thus the reward operated 4 times. Now it operates one time each day.

### A spawn gives no ROZ

A spawn moves the rabbit to a new position. It gives no ROZ. This is correct for
a free spawn and also for a paid spawn.

Thus a free spawn and a paid spawn are the same, except for the $0.10. This is
the same rule that the hops obey.

**The game has no daily reward now.** The daily reward and the streak bonus
operated when a player made a spawn. A spawn gives no ROZ, thus these rewards do
not operate. Refer to section 11.

### The order of the rewards

1. Find or steal - the best single action.
2. A successful hide - 30 + 50 = 80 for a player who paid $0.60 that day, and
   12 for a player who did not. **The first 3 hides of a day give the full value.
   The 4th hide and after give much less** (section 5). Thus this position is
   correct for a player, and not for a farmer.
3. Participation - less important. The player must make 28 of a maximum of 40
   hops. The player must also pay $0.60 in the day.
4. Each hop - a small reward for exploration.

There is no retention reward now.

**Find or steal is the one reward that the gate never decreases.** This is
correct, for two reasons. A find needs the hidden treasure of a different player,
and it takes that player's stake. Thus a farmer cannot find their own treasures in
a closed loop, as they can with hops and hides. A find is also the action that
controls the hide loop: each find is a farm hide that did not survive. Refer to
section 9.2. If you decrease this reward, you make the control weaker.

### How many players Year 1 can pay

These targets are new. The first targets were 80 - 160, 180 - 320 and 350 - 550.
The gate in section 5.2 did not let a player get these values. You had two
choices. You could decrease the controls against the farmers, or you could
correct the targets. **You corrected the targets.** No rate, limit or allowance
changed. Refer to section 11.

| Player type | ROZ each day |
|---|---|
| Light casual - **below the gate** | 25 - 70 |
| Typical casual - **above the gate** | 140 - 280 |
| Active | 300 - 500 |

Year 1 gives 2,342,466 ROZ each day.

| Player type | Number of players each day |
|---|---|
| Light casual (25 - 70) | 33,500 - 93,700 |
| Typical casual (140 - 280) | 8,400 - 16,700 |
| Active (300 - 500) | 4,700 - 7,800 |

Thus Year 1 can pay approximately **4,700 to 16,700 players each day**. The first
targets gave 4,000 to 13,000. Year 1 pays approximately one quarter more players
now. No rate changed. Only the targets changed. If the game has more players, the
tokens for Year 1 stop early.

### No player type gets the target reward

**These values obey the rule in section 5.2: the gate does not operate on the
earlier actions.** A player gets `hopRewardBelowThreshold` for each hop before the
payment gets to $0.60. The player gets the full rate only from that hop. Earlier
versions of this table gave the full rate to all the hops. That was not correct,
and it made all three values too large.

Three rules of the calculation, because they change the values:

- **The payments increase in the order of the actions.** In each round the player
  makes the spawn before the hops of that round.
- **The participation bonus operates at the first action where the two conditions
  are true**: 28 hops and $0.60. Refer to section 7.
- **The player hides after the payment gets to $0.60.** Section 5 gives the hide
  rewards to the gate also. Thus this rule is worth 68 ROZ to a typical casual
  player. Refer to the note about the order of the actions.

| Player | Rounds and hops | Payment | Gets through at | **Established** | **New wallet** | Target |
|---|---|---|---|---|---|---|
| Light casual, no hide | 2 rounds, 20 hops each | $0.265 | **Never** | **6** | **6** | 25 - 70 |
| Light casual, **2 hides** | 2 rounds, 20 hops each | $0.765 | Hop **34** | **~54** | ~54 | 25 - 70 |
| Typical casual | 2.5 rounds, 25 hops each | $0.955 | The **round-3 hide** | **117.5** | **62.5** | 140 - 280 |
| Active | 4 rounds, 32 hops each | $3.635 | Hop **60** | **285.9** | **202.4** | 300 - 500 |

The established values include one hide cycle for the casual player and the
active player. They include one find for the active player.

A wallet leaves the new wallet condition at $3 of total payments. The active
player needs 1 day. The typical casual player needs 4 days. The light casual
player needs 12 days. A wallet that only hides needs **5** days, at $0.20 for
each hide and 3 hides each day.

The calculation for the typical casual player: 50 hops before the gate at 0.15
(**7.5**), 12 hops after the gate at 1.0 (**12**), the participation bonus
(**18**), and one full hide cycle (**80**).

**The section 5 hide changes do almost nothing to the established players.** The
typical casual player *gets 3.4 ROZ more*, because the $0.20 hide fee is a payment
and moves this player through the gate sooner. The active player gets the same and
pays $0.20 more. The new wallet values decrease, which is correct.

**Two player types are still below the target, and this is not new.** You made the
targets when the values still gave the full rate to all the hops:

| Player | The first values | With the correction, at 0.3 | At 0.15 | **With the gate on hides** |
|---|---|---|---|---|
| Light casual | 12 | 12 | 6 | **6** (~54 with 2 hides) |
| Typical casual | 160 | 122.2 | 114.1 | **117.5** |
| Active | 336 | 294.7 | 285.9 | **285.9** |

**A light casual player who hides 2 times is now in the target**, at approximately
54 ROZ. This is new. Two hides cost $0.40. With the hop and spawn payments this
moves the player through the gate at hop 34, and then all the rewards are full.
The route into the target changed: before it was one hide at the full 30, and now
it is two hides that get through the gate. One hide alone gives 18, which is not
sufficient.

**The correction is the larger cause, not the new rate.** The correction removes
37.8 ROZ from the typical casual player and 41.3 ROZ from the active player. The
new rate removes 8.1 ROZ and 8.8 ROZ more. You must decrease the targets again,
or increase a rate. Refer to section 11.

**`hopRewardBelowThreshold` does not operate only on the farmers.** Each day
starts at zero payment. Thus **each** player gets this rate for the first hops of
the day: 54 hops for the typical casual player, and 59 hops for the active
player. Section 9.3 calls this the value that controls the wallets that pay
nothing. It is also the value that controls the start of each correct player's
day.

**The rewards change with the order of the actions, and the hides make this much
larger.** A player who makes the spawn at the start of a round gets through the
gate more quickly, and earns more. That was a small quantity. Now the gate also
operates on the hide rewards. Thus **the same typical casual player gets 117.5 ROZ
with a round-3 hide, and 50.35 ROZ with a round-2 hide** - a difference of 67 ROZ
from the order only. A hide before the gate gives 12 and not 80, and the rule in
section 7 makes this permanent. The player cannot see this. A message that says
"hide after you pay $0.60" gives real help. Refer to section 11.

There are three more causes for the light casual value of 6:

1. **The daily payment limit in section 5.2.** The light casual player does not
   get to $0.60. Thus the hop reward decreases to 0.15 and the participation bonus
   stops. A day with no gate gives this player 58 ROZ. They get 6 ROZ. The limit
   causes all 52 ROZ of the difference.
2. The daily reward of 12 to 22 ROZ does not operate now.
3. The participation bonus operates one time each day, not in each round. This
   removes 54 ROZ from the active player.

### The light casual target needs hides, not hops

The light casual target is a target **below the gate**. Thus you must make sure
that a player below the gate can get it. Hops alone do not get it:

| | |
|---|---|
| The maximum payment below $0.60 | **$0.595 - 64 hops** |
| The ROZ from these hops | 64 x 0.15 = **9.6** |
| Participation bonus | **None** - the gate stops it |

**9.6 ROZ is the maximum for one day of hops below the gate.** The target starts
at 25. Hop number 65 costs $0.615 and gets through the gate. Then the player is
not a player below the gate.

**Hides increase this maximum to 30.3, which gets to the target.** Two hides cost
$0.40 in fees. This leaves space for 42 hops before $0.60:

| | ROZ | Payment |
|---|---|---|
| 2 hide cycles below the gate (4.5 + 7.5 each) | 24 | $0.40 |
| 42 hops x 0.15 | 6.3 | $0.185 |
| Participation bonus - the gate still stops it | 0 | - |
| **Total, below the gate** | **30.3** | **$0.585** |

Thus a player below the gate can get to the bottom of the target. This is a
change: before, the target was not possible below the gate. The gate decreased
each hide, but the $0.20 fee also made a hide a way to pay. The maximum increased
from 9.6 to 30.3.

The better result for the player is to get **through** the gate: **the same two
hides move the light casual player over $0.60, to approximately 54 ROZ**, because
all the rewards are full then. One hide gives 18 ROZ. This is less than the target,
and also less than a careful day below the gate. **The worst position is between
the two.**

This is the meaning of the target now: **a light casual player must hide. Hops
alone are not sufficient.** The conflict here is much smaller than before. Before,
no control operated on a hide, thus the route into the target and the cheapest
farm route were the same **uncontrolled** action. Sections 5 and 5.2 now put the
gate on the hides also. Thus the two share an action but not a danger: section 9.2
gives the hide loop a minimum of $22.8M and not $0.8M. A new control on the hide
loop still operates on this player. Keep the two together. Refer to section 11.

Two more points are important:

**The two controls operate on the same players at the bottom.** The light casual
player is already at the minimum because of the daily payment limit. Thus the new
wallet condition takes nothing more from this player. The new wallet condition
decreases the rewards only for the players who pay.

**The 40-hop maximum does not help the active player.** The hops and the
participation bonus of this player give **95.85** ROZ. The daily maximum
(`dailySoftCapRoz`) is near 100 ROZ. Thus this player is below the daily maximum,
and also far below the 40-hop maximum. The 40-hop maximum gives this player
nothing. Refer to section 5.1.

**The decision was made one time, and the correction opens part of it again.** The
active player pays more: the hop cost increased from $1.38 to $3.135. The controls
against the farmers also decrease the rewards for the correct players. You changed
the targets and not the rewards, because a target is much less dangerous to change
than a control against the farmers. That decision is still correct. But the values
below the decision changed: with the correction in section 5.2, the new targets
are also too large, and all three players are below them. Refer to section 11.

## 5. Prices and free allowances

### The prices

| Action | Price | Notes |
|---|---|---|
| Hide a treasure | **$0.20 or $0.25** and a $5 stake | **Maximum 10 each day.** The contract never returns the fee. It returns the $5 |
| One hop | $0.005 to $0.04 | The price increases. Refer to section 5.1 |
| Spawn a new position | $0.10 | Was $1.00 |

The hop price and the spawn price decrease 10 times.

### A hide is not free now, and the quantity has a price

Three controls. All operate on the hide loop in section 9.2 - the route that no
other control reached. Together they let a player hide freely, and make a large
quantity of hides not profitable:

| Setting | Value | Storage |
|---|---|---|
| Hide fee, treasures **1 to 3** of the day | **$0.20** | `hideFeeBase` `200000` |
| Hide fee, treasure **4 and after** | **$0.25** | `hideFeeHigh` `250000` |
| Where the fee increases | **3** | `hideFeeTierBoundary` |
| Daily treasure maximum | **10 for each wallet, each day** | `dailyHideCap` |

**All the limits count treasures, not transactions.** Thus a bulk call of four
counts as four, and pays four fees. Refer to section 7.6.

**The fee is a payment for the section 5.2 limits. The $5 stake is not.** The
contract never returns the fee, thus rule 1 makes it a payment. The contract
returns the stake, thus it is not a payment. This difference stops a farmer from
getting through the gate for nothing.

### The Daily Volume Multiplier

The hide rewards decrease with the number of treasures that the wallet **already
made today**, before this treasure:

| Already made today | Multiplier | Thus it operates on treasure number |
|---|---|---|
| 0 to 2 | **1.00x** | 1, 2, 3 |
| 3 to 4 | 0.70x | 4, 5 |
| 5 to 6 | 0.40x | 6, 7 |
| 7 to 8 | 0.20x | 8, 9 |
| 9 to 10 | 0.08x | 10, 11 |
| 11 and more | 0.03x | 12 and more - whitelisted addresses only |

**The multiplier uses the daily count, not the number in the transaction.** This
difference is important. An earlier version used the number in the transaction. A
farmer avoided it: they made ten single hides and not one bulk call of ten. The
daily count makes a single hide and a bulk hide give exactly the same result.
Thus there is no method to avoid it. Section 9.2 shows the effect.

**Three settings meet at 3, and this is intentional:**

```
hideFeeTierBoundary (3)  x  hideFeeBase ($0.20)  =  dailySpendThreshold ($0.60)
                         ^
        also the first band of the Daily Volume Multiplier
```

Thus the first 3 hides of a player cost the small fee, give the full multiplier,
and put the player exactly on the payment limit. **Three hides is the correct
shape of a normal day of hiding.** Each treasure after that has a price for the
quantity. Section 5.2 rule 1 gives the relation that the set functions protect.

**The stake is also at risk.** A finder can take it. Also, the contract keeps
12,833 units (approximately $0.0128) at each claim. Thus one of the first three
hides costs **$0.2128** in total if it survives, and $5.20 if a finder takes it.

### The four limits

Four values control the free play and the maximum reward. This table gives all
four values. The owner can change each value. Refer to section 7.1.

| Setting | Value | When it starts again |
|---|---|---|
| `dailyFreeHops` | **22** | Each day. All 4 rounds use the same 22 hops |
| `participationMinimumHops` | **28** | Each day. The bonus operates one time each day |
| `hopRewardCap` | **40** | Each **round** |
| `dailyFreeSpawns` | **1** | Each day |

There is also a warning at approximately 36 hops. This warning is in the frontend
only. The contract does not use it.

**Two rules control the sequence of these values. Do not break these rules.**

1. `dailyFreeHops` (22) must be less than `participationMinimumHops` (28). Thus a
   player cannot get the bonus with free hops only.
2. `participationMinimumHops` (28) must not be more than `hopRewardCap` (40).
   Thus the bonus needs 28 hops of a maximum of 40 hops. This is 70% of a round.

The difference is 6 hops. These 6 hops cost $0.045.

**These two rules are no longer the primary control.** The daily payment limit in
section 5.2 stops the participation bonus below $0.60 each day. The number of
hops is not important below that limit. Keep these two rules, but know that the
payment limit does the work.

### The free allowance

Each player gets **22 free hops and 1 free spawn each day**. The allowance is for
the day, not for one round. The player can use it in any round.

| Player | Cost before | Cost after |
|---|---|---|
| Light casual | $0.50 | $0.18 |
| Typical casual | $0.90 | $0.58 |
| Active | $1.68 | $1.36 |

The allowance saves $0.32 each day for all the players.

**The allowance is less than one full round.** The maximum is 40 hops in a round.
The allowance is 22 hops. This is 55% of a round. This is correct: the
participation bonus needs 28 hops. Thus a player cannot get the bonus with free
hops only. The player must pay for 6 hops.

**A free hop does not count for the payment limits in section 5.2.** A free hop
costs nothing. Thus it adds nothing to the payment counters. Thus free hops alone
can never get to the $0.60 limit. Refer to section 9.3.

**A free action is the same as a paid action.** Only the USDC cost is different:

| Behaviour | A free hop | A free spawn |
|---|---|---|
| Does the action | Yes | Yes |
| Gives ROZ | Yes, at the rate from section 5.2 | No. A paid spawn also gives no ROZ |
| Counts for the 28-hop minimum | Yes | Not applicable |
| Counts for the 40-hop maximum | Yes | Not applicable |
| Costs USDC | No | No |
| Counts for the payment limits | **No** | **No** |

The hops are the same because both give ROZ. The spawns are the same because
neither gives ROZ.

Thus the code is more simple. The free test controls the payment only. All the
other steps operate in the same way.

**A free spawn does not need an approval.** A new player can spawn and hop with no
USDC and no approval. This is necessary. If the approval check stays at the start
of the spawn function, no new player can use the free allowance.

## 5.1 The hop price increases with use

The price of a hop increases when a wallet makes many hops in one day:

| Hop number in the day | Price |
|---|---|
| 1 to 22 | Free |
| 23 to 25 | $0.005 |
| 26 to 45 | $0.010 |
| 46 to 65 | $0.020 |
| 66 and more | $0.040 |

**The count must go back to zero one time each day. It must not go back to zero
at the end of a round.** If the count goes back to zero in each round, a wallet
stays in the first tier. Then 32 hops in each of 4 rounds cost $0.34 and not
$3.135. Thus the control does not operate.

### The effect of the new prices

| Hops in a day | New price | Old price | Result |
|---|---|---|---|
| 30 | $0.065 | $0.08 | Less |
| 45 | $0.215 | $0.23 | Less |
| 46 | $0.235 | $0.24 | Less |
| 47 | $0.255 | $0.25 | More |
| 60 | $0.515 | $0.38 | More |
| 128 | $3.135 | $1.06 | More |

The change point is 47 hops. Below this number the new prices are less. Above
this number the new prices are more. This is correct: a light player pays less,
and a player who makes many hops pays more.

### The daily maximum reward

When a wallet earns more than `dailySoftCapRoz` ROZ from hops and participation,
the game decreases the subsequent rewards. The multiplier is 0.2.

**Use a value near 100.** The hop maximum is 40 in a round. Thus the maximum from
hops and participation is 160 + 18 = 178 ROZ. But the rule in section 5.2 puts
this value out of reach: a wallet that hops to the limit gets 0.15 for the first
49 hops, thus a day of 160 hops gives **136.35** ROZ. Only a wallet that gets
through the gate **before** it hops gets 178 ROZ. Six paid spawns do this, for
$0.60. That is the behaviour of a farmer, not of a player.

Thus a maximum of 150 or 160 operates only on that route. A value near 100
operates for more players.

**The 40-hop maximum and the daily maximum operate against each other at the top,
and neither one gets to the correct player.** The 40-hop maximum was made larger
to give a reward on the hops where a find is probable. But the active player gets
**95.85** ROZ from hops and participation. This is below a daily maximum of 100,
and far below the 40-hop maximum. Thus the change does not help this player.
Refer to section 11.

### What these controls do, and what they do not do

**They operate against one large wallet:**

| | Before | After |
|---|---|---|
| Cost of a maximum day (160 hops, 4 spawns) | $1.68 | **$4.715** |
| ROZ | 232 | **136.35** |
| Cost for each ROZ | $0.0072 | **$0.0346** |

The cost is 4.8 times more. This is correct. The value is 136.35 ROZ and not 178
ROZ, because the first 49 hops of the day give 0.15 each. Refer to section 5.2.

**They do not operate against many small wallets.** A wallet that makes 28 hops
stays in the first two tiers. These tiers are less expensive than before:

| | Before | After |
|---|---|---|
| Cost for each wallet | $0.06 | **$0.045** |
| ROZ | 46 | 46 |
| Cost to take all the Year 1 tokens | $3,055 each day | **$2,292 each day** |

The new prices are more expensive for one large wallet. But they are less
expensive for many small wallets. A wallet costs nothing to make. Thus a farmer
uses more wallets.

**Starknet gas is the real control.** A wallet makes 29 transactions each day.
The game fees are $0.045. The gas is more than the fees. Thus the gas stops the
farmers more than the prices do. Measure the gas. Do not estimate it.

To control the many-wallet method you need a different rule. Section 5.2 gives
these rules.

## 5.2 The Lightweight Gate

Section 5.1 does not control the many small wallets. These four rules do. The
principle is simple: **a player who pays gets the full rewards. A player who pays
nothing can still play, but gets less.**

### The four rules

1. **A daily payment limit.** A wallet must pay **$0.60** or more in game fees in
   one day to get the full hop and participation rewards. Below this value, the
   rewards decrease.
2. **The free hops and the free spawn stay for all the players.** A new player
   can start immediately. The player gets less ROZ until the player pays.
3. **A new wallet gets less ROZ** until the total payments of that wallet get to
   **$3**.

**A fourth rule was considered and removed.** It gave a bonus to a wallet with a
social account. It needed a person to approve each wallet, which is a new
privileged writer and a target when ROZ has a value. It also gave little that the
three payment rules do not give. The flag `player_verified` and the values
`verifiedBonusNum`/`Den` are **not** in the design.

One privilege does exist: the owner controls the bulk hide whitelist (section
7.6a). This is a different thing - it gives no ROZ bonus, only higher hide limits,
and the owner already controls each set function in section 7.1.

### The rates

The rates are absolute values. They are not multipliers. Refer to rule 2 below.

**Rule 1 - the payments in the day:**

| Reward | Below $0.60 | $0.60 or more |
|---|---|---|
| Each hop | **0.15** | **1.0** |
| Participation bonus | **None** | **18** |
| Hide a treasure | **4.5** | 30 |
| The treasure is not found | **7.5** | 50 |
| Find or steal | **110 - full** | **110 - full** |

**Rule 3 - a wallet is new until $3 of total payments:**

| Reward | A new wallet |
|---|---|
| Each hop | **0.5** |
| Participation bonus | **9** |
| Daily maximum for hops and participation | **80 ROZ** |
| Hide a treasure | **15** |
| The treasure is not found | **25** |
| Find or steal | **110 - full** |

A wallet leaves the new condition permanently at $3 of total payments.

**Find or steal is the one reward that no rule decreases.** A find needs the
hidden treasure of a different player, and it takes that player's stake. Thus a
farmer cannot make a closed loop with it, as they can with hops and hides. It also
controls the hide loop: each find is a farm hide that did not survive. Refer to
section 9.2.

**The hides came into this table in section 5**, with a tiered fee and a maximum
of 10 each day. Before that change, no control in this plan operated on a hide.
The hide values above are the **wallet rate**. The contract then operates the
section 5 Daily Volume Multiplier on the value that it selects - refer to rule 2.

**The rates operate from the moment the wallet gets to the limit. They do not
operate on the earlier actions.** A player who gets to $0.60 at hop 65 earns 0.15
for hops 1 to 64. The player earns 1.0 from hop 65. To calculate the day again
would be complex. It would also let a farmer make many inexpensive hops first and
then make them more valuable.

**This rule gives the gate most of its strength. It is easy to calculate wrong.**
Each day starts at zero payment. Thus **each** wallet - a farm wallet and a
correct player - gets the smaller rate for the first hops of the day. A wallet
does not get 65 hops at 1.0 for $0.615. It gets 64 hops at 0.15 and 1 hop at 1.0.
All the values in this plan use this rule. Two results follow, and both are in
this document: the cheapest farm route costs much more than a simple calculation
gives (below), and the correct players earn less than the older values gave
(section 4).

**Two more rules are necessary.** First, **the participation bonus operates at the
first action where the two conditions are true** - 28 hops in the day, and $0.60
paid in the day. It does not operate at hop 28 only. A player can get to 28 hops
and stay below $0.60. The typical casual player in section 4 does this at hop 28,
with $0.145 paid. This player must still get the bonus when the payment gets to
$0.60 later. Second, **the payments increase in the order of the actions.** Thus a
player who makes a spawn early gets through the gate more quickly, and earns more.
Refer to section 11.

### Rule 1 controls the many small wallets

A wallet gets to $0.60 after **65 hops** ($0.615). A farmer does not use a spawn
to get to the limit. A spawn costs $0.10 and gives no ROZ. A hop in the same
price tier costs $0.02 and gives ROZ.

The wallet gets **28.6 ROZ** at that point, not 65 + 18. The first 64 hops give
0.15 each, and only hop 65 gives 1.0:

`64 x 0.15 + 1.0 + 18 = 9.6 + 1 + 18 = 28.6`

| | Without the gate | With the gate |
|---|---|---|
| Cost for each wallet | $0.045 | **$0.615** |
| ROZ | 46 | **28.6** |
| Cost for each ROZ | $0.00098 | **$0.0215** |
| Number of wallets to take all the Year 1 tokens | 50,923 | **81,904** |
| Cost to take all the Year 1 tokens | $2,292 each day | **$50,371 each day** |
| Market value with 5,000,000,000 tokens | $4.9M | **$107M** |

The cost is **22 times more**. This is the control that section 5.1 does not
give. The gate makes the farmer pay more, and it also decreases what the wallet
earns. The second effect is the larger one.

**More than 65 hops does not help the farmer.** Each hop after hop 65 costs $0.04
and gives 1 ROZ. This is more expensive than the average of $0.0215. Thus the
cheapest wallet stops at 65 hops. A farmer who wants all 178 ROZ must get through
the gate before the first hop. Six paid spawns do this for $0.60. That day costs
$5.015 for 178 ROZ, which is $0.0282 for each ROZ. This is still more expensive
than stopping at 65 hops.

### Rule 3 controls the number of wallets

A total payment limit controls the number of wallets, not the actions of one
wallet. This is the correct target:

| Total payment limit | Cost to start 81,904 wallets |
|---|---|
| $1 | $81,904 |
| $2 | $163,808 |
| **$3 (selected)** | **$245,712** |
| $5 | $409,520 |
| $10 | $819,040 |

At $3, a farmer pays $245,712 one time. This is 4.9 days of the daily cost. At $5
the farmer pays $409,520, which is 8.1 days. Thus the value of $3 gives
approximately one half of the control that $5 gives. Make this decision. Refer to
section 11.

The two costs increased with the corrected number of wallets. But the ratio did
not change. The one-time cost is still approximately five days of the daily cost,
because the two values use the same number of wallets.

### Corrected - the wallets that pay nothing are now the least productive

This part gave a problem before. The free allowance increased from 20 to 22 hops,
and the hop rate below the limit was 0.3 and not 0.2. Thus a wallet that paid only
the gas earned **more** than before. The rate of **0.15** corrects this:

| | The first values | Before | **Now** |
|---|---|---|---|
| ROZ each day with no cost | 20 x 0.2 = **4** | 22 x 0.3 = 6.6 | **22 x 0.15 = 3.3** |
| Number of wallets to take all the Year 1 tokens | 585,617 | 354,919 | **709,838** |

The free allowance is still 22 hops. The rate did all of this. **709,838 wallets
is 21% more than the first values ever needed.** Thus this route is not only
corrected - it is the most difficult it has been. Rule 1 operates on the wallets
that pay, and this effect operates on the wallets that never pay. The two now
operate in the same direction.

### Each player type stays below the target

| Player | Hops | Payment each day | Gets through at | Established | New wallet | Target |
|---|---|---|---|---|---|---|
| Light casual, no hide | 40 | $0.265 | **Never** | **6** | **6** | 25 - 70 |
| Light casual, 2 hides | 40 | $0.765 | Hop 34 | **~54** | ~54 | 25 - 70 |
| Typical casual | 62 | $0.955 | The round-3 hide | 117.5 | 62.5 | 140 - 280 |
| Active | 128 | $3.635 | Hop 60 | 285.9 | 202.4 | 300 - 500 |

**A light casual player and a small farmer pay the same amount.** Thus the gate
cannot see the difference. It decreases the rewards for both.

The light casual player gets 6 ROZ, and the minimum is 25. The change from $0.50
to $0.60 moved this player further from the limit.

**The other two players are also below their targets now.** The new targets in
section 4 were made when the values still gave the full rate to all the hops. The
correction puts the typical casual player 22.5 ROZ below the minimum, and the
active player 14.1 ROZ below. The correction is the larger cause. The hop rate of
0.15 adds 8.1 ROZ and 8.8 ROZ more.

**More hops cannot correct the light casual player.** The maximum payment below
$0.60 is $0.595, which is 64 hops. These hops give 64 x 0.15 = **9.6 ROZ**, and
there is no participation bonus. Thus 9.6 ROZ is the maximum for a day of hops
below the gate, and the target starts at 25.

**Hides can correct it, in two directions.** Two hides and 42 hops give **30.3
ROZ** below the gate. Or the same two hides move the player **through** the gate,
to approximately **54 ROZ**. Both get to the target. One hide gives 18 ROZ, which
gets to neither. Refer to section 4.

**The two rules operate on the same players at the bottom.** The light casual
player is already at the minimum because of rule 1. Thus rule 3 takes nothing
more from this player. Rule 3 decreases the rewards only for the players who pay.

Make this decision before the game operates. Refer to section 11.

### Two rules that you must obey

**1. A hide payment has two parts. Only one part is a payment.**

Since section 5 a hide costs **$5.20** or **$5.25**: a fee of `$0.20` or `$0.25`,
and a `$5.00` stake. The contract must treat the two parts differently. An error
here stops rules 1 and 3.

| Part of the payment | Does it come back? | Is it a payment? |
|---|---|---|
| `hideFeeBase` / `hideFeeHigh` - $0.20 or $0.25 | **No, never** | **Yes** |
| `currentHiderFee` - the $5 stake | **Yes**, less 12,833 units at the claim | **No** |
| The 12,833 units at the claim | No | **Yes** |

**Only the money that does not come back is a payment:** the hop fees, the spawn
fees, the hide fee at the correct tier, and the 12,833 units. Never the stake. A
free hop is not a payment.

If the stake was a payment, a farmer makes one hide and gets more than the $3
limit for the $0.2128 that a hide really costs. This is **14 times** less
expensive. The $0.20 fee already made this problem much smaller: before the fee, a
hide cost $0.0128 and the difference was **234 times**. It is smaller, but it is
not zero, and the rule stays.

**The gate uses the fee tier, not the daily maximum:**

```
hideFeeTierBoundary (3)  x  hideFeeBase ($0.20)  =  dailySpendThreshold ($0.60)
```

The first 3 hides of a day cost the small fee and put the wallet exactly on the
limit - not less, not more. This gives a light player a clear route through the
limit (section 4). It gives a farmer no route that is less expensive than the
other routes.

**The set functions must test this relation, and it is easy to write the wrong
one.** The relation is **not** `dailyHideCap x hideFeeBase`: the maximum is 10,
and 10 x $0.20 is $2.00. Three values can change, and each one breaks the relation
in a different way:

| Change | Result |
|---|---|
| `hideFeeBase` to $0.25 | two hides get through the gate; the third pays too much |
| `hideFeeTierBoundary` to 2 | hides alone cannot get to $0.60 at the small fee |
| `dailySpendThreshold` to $0.50 | two hides get through; the fee tier means nothing |

`dailyHideCap` (10) is **not** in this relation. It controls the quantity. It has
no part in getting through the gate. Refer to section 7.1 for the test.

**2. Use the lowest rate. Do not multiply the rates together.**

A wallet can be new and also below the daily payment limit. The two tables do not
agree: 0.15 or 0.5 for each hop, no bonus or 9 for participation, and 4.5 or 15
for a hide.

> **Select the lowest value for each reward line. Do this for each line
> independently.**

| Condition | Each hop | Participation | Hide | Not found | Find |
|---|---|---|---|---|---|
| Established, paid $0.60 today | 1.0 | 18 | 30 | 50 | 110 |
| Established, below $0.60 today | 0.15 | None | 4.5 | 7.5 | 110 |
| A new wallet, paid $0.60 today | 0.5 | 9 | 15 | 25 | 110 |
| **A new wallet, below $0.60 today** | **0.15** | **None** | **4.5** | **7.5** | **110** |

The find column does not change. This is intentional - refer to the note above.

Absolute values remove this danger. Before, the rates were multipliers. Three
multipliers together gave 0.2 x 0.2 x 0.5 = **0.02**. Thus a new light player got
**2%** of the rewards on the first day.

**The section 5 Daily Volume Multiplier does not make this danger again, because
no reward line ever gets two multipliers:**

| Reward line | The contract selects | Then it operates | Number of multipliers |
|---|---|---|---|
| Each hop | an absolute rate | the daily maximum, if necessary | **1 maximum** |
| Participation | an absolute rate | the daily maximum, if necessary | **1 maximum** |
| Hide a treasure | an absolute rate | the Daily Volume Multiplier | **exactly 1** |
| The treasure is not found | an absolute rate | the Daily Volume Multiplier | **exactly 1** |
| Find or steal | 110, always | nothing | **0** |

The daily maximum operates on the hops and the participation bonus only. The
volume multiplier operates on the hides only. **They never meet.** Select the
absolute rate first, operate the one multiplier that the line permits, and stop.

**Warning: do not check the last line of the table by memory.** The correct value
of **0.15** is also the value that the old multipliers gave from 0.5 x 0.3. Thus
the correct answer looks the same as the error that absolute values remove. A
multiplication of the **new** rates gives 0.5 x 0.15 = 0.075. Compare the result
with the stored value of `hopRewardBelowThreshold`. Refer to test 4g.

The new wallet maximum of 80 ROZ almost never operates. A new wallet must make
approximately 142 hops in one day before it operates.

## 6. Map size control

The players hide treasure in one round. The treasure becomes active in the next
round. Thus the system knows the number of treasures before the round starts.

The system calculates the map size with this formula:

```
Number of cells = T x 40 x K
```

- `T` is the number of treasures for the round.
- `40` is the target number of hops for each find.
- `K` is the search inefficiency factor. The range is 1.8 to 2.5. **It starts at
  2.2.**

**K starts at 2.2.** This is the middle of the range, and a small quantity toward
the sparse side. A map that is too easy is more difficult to correct than a map
that is too difficult. Examine this value again when you know the real `T` of the
first round. You will not know this until the launch is near.

The map side increases with the square root of T:

| T | K = 1.8 | **K = 2.2** | K = 2.5 |
|---|---|---|---|
| 10 | 27 x 27 | **30 x 30** | 32 x 32 |
| 100 | 85 x 85 | **94 x 94** | 100 x 100 |
| 196 | 119 x 119 | **131 x 131** | 140 x 140 |
| 500 | 190 x 190 | **210 x 210** | 224 x 224 |
| 1000 | 269 x 269 | **297 x 297** | 317 x 317 |
| **2,840** - `maxTreasuresPerRound` | 452 x 452 | **500 x 500** | 533 x 533 |

**The last line gives the maximum map size.** `maxTreasuresPerRound` is **2,840**
(section 7.6). Thus at the first K the largest map is `2,840 x 40 x 2.2` =
249,920 cells, which is **500 x 500**. This is 11.4 treasures for each 1,000
cells, which is inside the density limit. **If you increase
`maxTreasuresPerRound`, the map becomes larger with the square root of T.** 5,000
treasures need 663 x 663. Thus you must test what the display and the merkle tools
can do first.

### How to change K

| The recent median hops for each find | Action |
|---|---|
| Less than 32 | Increase K |
| 32 to 48 | Do not change K |
| More than 48 | Decrease K |

Change K by a maximum of 0.15 each round.

### Rules that you must obey

- Keep a minimum distance between the treasures.
- Use minimum and maximum limits for the map size.
- Use a maximum number of treasures for each 1,000 cells.
- Keep the coordinates secret until a player finds the treasure.
- Do not limit the number of players.
- Record each decision.

**A server does this work, not the contract.** The contract cannot calculate a
median of past rounds. The function `start_new_game` already accepts the map size
for each round. Thus the contract needs almost no new code for this.

### `T` now has a limit at each end

No wallet can make more than 10 treasures each day, or 250 in a round if it is
whitelisted. And no round can hold more than **2,840** treasures in total. Thus
`T` moves inside a range that you know. The budget of one player no longer decides
it, and K never receives a large sudden change that it cannot correct at 0.15
each round.

The formula does not change. The values that it must operate on do. Refer to
section 7.6.

## 7. What the contract must do

### 7.1 New addresses and rates

- Add the reward token address to the storage. Set it at the deployment. Let the
  owner change it later.
- Replace `currentGameTokenReward` with six rates and the limits below. Give each
  one a setter function. Without setters, you must deploy a new contract each year
  to change the rates.

The limits and the decreased rates from section 5.2:

| Name | Value | Raw value |
|---|---|---|
| `participationMinimumHops` | 28 | a count |
| `hopRewardCap` | 40 | a count, for each **round** |
| `dailyFreeHops` | 22 | a count |
| `dailyFreeSpawns` | 1 | a count |
| `dailySpendThreshold` | $0.60 | `600000` |
| `lifetimeSpendThreshold` | $3.00 | `3000000` |
| `hideFeeBase` | $0.20 | `200000` — treasures 1 to 3 of the day. A **fee**, not the stake |
| `hideFeeHigh` | $0.25 | `250000` — treasure 4 and after |
| `hideFeeTierBoundary` | 3 | a count — where the fee increases |
| `dailyHideCap` | **10** | a count, for each calendar day, of **treasures** |
| `maxTreasuresPerRound` | **2,840** | a count — the total for the round, everyone |
| `whitelistRoundCap` | **250** | a count — for each whitelisted address, each round |
| `whitelistCollectiveCap` | **1,200** | a count — for **all** the whitelisted addresses together, each round |
| `whitelistHourlyCap` | **80** | a count — for each whitelisted address, each hour |
| `hopRewardBelowThreshold` | 0.15 ROZ | `150000000000000000` |
| `participationBelowThreshold` | 0 ROZ | `0` |
| `rewardHideBelowThreshold` | **4.5 ROZ** | **`4500000000000000000`** |
| `rewardHideSurvivedBelowThreshold` | **7.5 ROZ** | **`7500000000000000000`** |
| `hopRewardNewWallet` | 0.5 ROZ | `500000000000000000` |
| `participationNewWallet` | 9 ROZ | `9000000000000000000` |
| `rewardHideNewWallet` | **15 ROZ** | **`15000000000000000000`** |
| `rewardHideSurvivedNewWallet` | **25 ROZ** | **`25000000000000000000`** |
| `newWalletSoftCapRoz` | 80 ROZ | `80000000000000000000` |
| `dailySoftCapRoz` | **136 ROZ** | `136000000000000000000` |

There is no `verifiedBonusNum`/`Den` and no `player_verified`. Section 5.2 removed
the fourth rule.

**The Daily Volume Multiplier from section 5.** Six bands, and the owner can
change each one. Store each as a numerator and a denominator, thus the values are
exact:

| Treasures already made today | Multiplier | Num / Den |
|---|---|---|
| 0 to 2 | 1.00x | 1 / 1 |
| 3 to 4 | 0.70x | 7 / 10 |
| 5 to 6 | 0.40x | 2 / 5 |
| 7 to 8 | 0.20x | 1 / 5 |
| 9 to 10 | 0.08x | 2 / 25 |
| 11 and more | 0.03x | 3 / 100 |

**The test in the set functions - write this one with care:**

```cairo
// 5.2 rule 1. The gate uses the FEE TIER, not the daily maximum: the first
// hideFeeTierBoundary hides of a day must put a wallet exactly on
// dailySpendThreshold. Each set function that changes one of the three
// values must test this again.
assert(
    self.hideFeeTierBoundary.read() * self.hideFeeBase.read()
        == self.dailySpendThreshold.read(),
    'hide fee gate mismatch',
);
```

It is **not** `dailyHideCap x hideFeeBase`. That was the relation when the maximum
was 3, and 10 x `200000` is `2000000`. `dailyHideCap` controls the quantity and
has no part in getting through the gate.

**There is no decreased value for a find.** A find or steal gives 110 ROZ to each
wallet, in each condition. Refer to section 5.2.

The values 0.15, 0.5, 4.5, 7.5, 15 and 25 are exact in 18 decimals. Thus there is
no rounding problem. Do not use fractions for these rates. Absolute values stop
the danger in section 5.2 rule 2.

**`hopRewardBelowThreshold` is the most important of these values, and not only
against the farmers.** Each day starts at zero payment. Thus it is the rate that
**each** wallet gets for the first hops of the day. Refer to section 4. It
controls the wallets that pay nothing and the start of each correct player's day
at the same time.

Two new maps for each player. Both use patterns that the contract has already:

```cairo
// Uses the day as a key, thus it starts again each day. This is the same
// pattern as player_free_hops_used. It controls BOTH the section 5 fee tier
// and the Daily Volume Multiplier. Thus you must read it BEFORE you count the
// current treasure, and write it after.
player_hides_today:  LegacyMap<(u64, ContractAddress), u256>,

// Uses the round as a key, with hider_share_amounts. It collects the survival
// reward THAT THE CONTRACT SELECTED AT THE HIDE. Thus a later gate crossing
// cannot change the value of an earlier hide.
hider_survival_roz:  LegacyMap<(u256, ContractAddress), u256>,
```

**The bulk hide whitelist** (section 7.6a). One root and three counters. The
counters exist because a whitelisted address does not obey `dailyHideCap` and
needs its own limits:

```cairo
// Only the owner writes this. A leaf is the address as felt252, with the
// Poseidon hash. Refer to section 7.6a for the tree and the proof.
whitelist_merkle_root: felt252,

// 250 treasures in each ROUND for a whitelisted address, thus one address
// cannot take all of the 2,840 of the round. The round is the key, thus it
// starts again each round.
whitelist_round_count: LegacyMap<(ContractAddress, u64), u32>,

// 1,200 treasures in each ROUND for ALL the whitelisted addresses together.
// The value above limits one address. This value limits the group, because
// 250 for each address does not add together: eleven addresses would take
// 2,750 of the 2,840 and leave 90 for all the other players. Each treasure
// from a whitelisted caller increases it, single or bulk. A hide that is not
// whitelisted never changes it.
whitelist_round_total: LegacyMap<u64, u32>,

// 80 treasures in each HOUR, thus a whitelisted address cannot put all of its
// round quantity in the first minutes and stop the normal players.
whitelist_hour_start: LegacyMap<ContractAddress, u64>,
whitelist_hour_count: LegacyMap<ContractAddress, u32>,
```

Two counters record the payments:

- `player_spend_today` - starts again each day.
- `player_lifetime_spend` - never starts again.

**Add to these two counters only when the player cannot get the money back.**
Add the hop fees, the spawn fees, the **hide fee at the correct tier**, and the
12,833 units from each claim. **Do not add the $5 hide stake.** Do not add a free
hop.

### 7.1a How the contract selects a rate

Four rewards use this sequence now: each hop, participation, the instant hide and
the survival reward. Only find or steal does not - it gives 110 always.

```
0. Take the fee first, thus today's payment is correct before you read the rate
1. Select the base rate:      rewardPerHop / rewardParticipation /
                              rewardHide / rewardHideSurvived
2. If total payment < $3:     take the lower of the rate and the new wallet rate
3. If today's payment < $0.60: take the lower of the rate and the below rate
4. Operate the ONE multiplier that the line permits:
     - each hop / participation -> the daily maximum, if the day total is more
     - hide / not found         -> the Daily Volume Multiplier for the number
                                   of this treasure (section 5)
     - find / steal             -> none, never
```

Steps 2 and 3 **take the lower value**. They never multiply. Step 4 operates **one
multiplier at most**, and the two multipliers never operate on the same line.
Refer to section 5.2 rule 2.

**The volume multiplier reads the count BEFORE this treasure.** Treasure 1 of the
day sees `player_hides_today == 0` and takes the 1.00x band. Treasure 4 sees 3 and
takes 0.70x. Inside a bulk call the count increases for each treasure. Thus
`hide_treasure_bulk(4)` pays 1.00x, 1.00x, 1.00x, 0.70x - which is the same as
four single hides. **This equality is the design**: it stops a farmer who divides
a bulk call to avoid the multiplier.

**Step 0 gives the full rate to the action that gets through the gate.** The
contract takes the fee, adds it to the counters, and reads the rate after that.
Thus hop 65 gives 1.0, and the third hide of a day gives 30.

**The participation bonus needs both conditions at each hop.** The contract must
not give it at hop 28 and then forget it. A player can get to 28 hops below $0.60.
The typical casual player in section 4 does this, at $0.145. This player must get
the bonus when the payment gets to $0.60 later.

**The contract selects the survival rate when the player hides, not at the
claim.** This is important, because the simple method is wrong. `claim_reward`
gives `hider_shares x rewardHideSurvived`, and a player can call it some days
after the hide - on a new day, with that day's payment at zero. To select the rate
at the claim would give a correct player 7.5 and not 50 for a claim on a Monday
morning. It would also let a farmer claim only on the days they already paid
$0.60. Both directions are wrong.

Thus `hide_treasure` selects the survival rate with the sequence above and adds it
to `hider_survival_roz`. `claim_reward` gives **that value**, and never a new one:

```cairo
// At the hide - the gate condition now is the condition that counts, always.
let survivalRate = _resolveGatedRate(rewardHideSurvived, caller);
hider_survival_roz.write((round, caller), stored + survivalRate);
```

**When a finder takes a share, subtract the average** - `stored / share_count`.
The shares are one number, thus the contract cannot see which share the finder
took. With a maximum of 3 hides each day the error is small. A map for each rate
would be exact, but it uses more storage. Refer to section 11.

### 7.2 Add the rewards to a balance. Do not send them

The contract adds ROZ to a balance for each player. A different function sends
the balance.

This is important. If the contract sends ROZ at each action, and the contract has
no ROZ, then the players cannot hide, move or spawn. The game stops. With a
balance, the game continues.

### 7.3 The coverage rule

The contract adds ROZ to a player balance only if it can pay all the balances:

```
total of the balances <= the ROZ that the contract holds
```

If the contract cannot pay, it does not add the reward. It does not stop the
action. Thus the function that sends ROZ can never fail.

The contract also emits an event at each refusal. Thus the players can see that
the rewards stopped.

### 7.4 Two types of share

The contract cannot see the difference between these two conditions:

- A hider keeps the treasure. The reward is 50 ROZ.
- A finder takes the treasure. The reward is 110 ROZ.

The contract uses one counter for both. Thus you must add two counters, one for
the hiders and one for the finders.

### 7.5 Two claim functions

| Function | Sends | Can a low ROZ balance stop it? |
|---|---|---|
| `claim_reward` | USDC | No |
| `claim_reward_tokens` | ROZ | No |

`claim_reward` continues to operate as before. It sends the USDC first. Then it
adds the ROZ to the balance. Thus a low ROZ balance does not stop the USDC.

If the contract cannot add the ROZ, the player can come back later. A second flag
records the ROZ part. The function `claim_reward_token_for_week` tries again.

### 7.6 Bulk hiding - open to everyone, with four limits

A player can hide some treasures in one transaction. The player sends an amount
that divides exactly by the hide price. **Each address can call this function.**
The difference is the number of treasures that each address may make.

| The address | In one transaction | Each day | Each round | Each hour |
|---|---|---|---|---|
| Not whitelisted | what stays of the daily quantity | **10** | - | - |
| Whitelisted (section 7.6a) | no limit | no limit | **250** | **80** |
| **All the whitelisted together** | - | - | **1,200** | - |
| **Everyone** | - | - | **2,840 in total** | - |

The fourth line stops the third line from adding together: 250 is a limit for one
address, and not for a group of addresses.

**Each limit counts treasures, not transactions.** The section 5 fee tier does the
same, and so does the Daily Volume Multiplier. This one rule is what makes bulk
hiding safe: **a bulk call of N gives exactly the same result as N single hides** -
the same fees, the same multipliers, the same ROZ. Thus there is no advantage to
divide a call, and none to join calls together.

**The contract does not need a loop for the shares.** They are a number, thus the
transfer and the share write stay simple. But the fee and the reward change for
each treasure, because both use the quantity that the wallet already made. The
contract calculates both from a count that increases, not from a loop over the
storage.

The contract must not compare the quantity with the map size. The map for the next
round does not exist yet. The map size reads as 0. Thus each bulk hide fails. Use
`maxTreasuresPerRound` instead. That value protects the **total** for the round,
across all the wallets - it is the only limit that a whitelisted address cannot
pass.

**You must also change the claim calculation.** The contract subtracts the fees
one time for each claim. This was 200 times less than 200 separate claims. A
normal wallet can now make 10 treasures each day, thus the error is **10 times**.
On the cheapest farm route, which uses 5, it is 5 times. Change the calculation to
subtract the fees for each share. The result for one share does not change.

**The limits have removed most of this problem.** The error moves the cheapest farm
wallet from $1.209 to $1.158 each day, which is approximately 4%. Thus this is not
urgent now. But the calculation is still wrong: the fees are for each treasure, and
the contract must subtract them for each treasure. The change is one line. A
whitelisted address that claims 250 shares one time would still pay 250 times too
little, and that is the condition that keeps this change necessary.

### 7.6a The bulk hide whitelist

Some addresses must make more than 10 treasures each day - to fill a map for an
event, or for a partner with a promotion. The whitelist permits this, and **it
permits nothing else**: no ROZ bonus, no different rate, and no exception from the
fee tiers or the Daily Volume Multiplier. It removes one limit and adds two
smaller ones.

| | Not whitelisted | Whitelisted |
|---|---|---|
| Daily treasure maximum | **10** | none |
| Each round, one address | - | **250** |
| Each round, **all the whitelisted together** | - | **1,200** |
| Each hour | - | **80** |
| Round total, shared | 2,840 | 2,840 |
| Fee tiers, volume multiplier, wallet rate | operate | **operate the same** |

**Why a Merkle root and not a map.** A map costs one write for each address, and
one transaction for each change. A root is one `felt252`. The list stays off the
contract, and the caller gives a proof. To add fifty addresses costs one call.

```cairo
// Only the owner writes this. A new root replaces the whole list. There is no
// function to add or remove one address, and this is intentional: the list is
// always exactly what the published tree says.
whitelist_merkle_root: felt252,

fn set_whitelist_merkle_root(ref self: ContractState, new_root: felt252) {
    self.ownable.assert_only_owner();
    self.whitelist_merkle_root.write(new_root);
}
```

**The contract tests the proof with Poseidon.** The index tells the contract if
each step is on the left or the right:

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

        // The lowest bit of the index gives the side of this node. If you use
        // the wrong side, the hash looks correct but never equals the root.
        // Then a whitelisted caller silently returns to the 10 a day maximum.
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

**A leaf is the address of the caller as `felt252`, and nothing more.** Not the
address with a limit, and not a hash of the address. The tool below makes the tree
the same way. The two must agree exactly, or each proof fails.

**The order of the tests, and the order is important:**

```
1. Test the proof            -> is this caller whitelisted?
2. The round maximum         -> 250 for THIS address in this round?
3. The hour maximum          -> 80 for THIS address in the last 3,600 seconds?
4. The group maximum         -> 1,200 for ALL the whitelisted in this round?
5. The round total           -> 2,840 for everyone?
6. Fees, volume multiplier, wallet rate
7. Make the treasures, and write each counter
```

**The order is personal, then group, then everyone.** This is what makes the three
errors mean three different things:

| The error | What it tells the caller |
|---|---|
| `'whitelist round cap'` | **you** used your 250 |
| `'whitelist group cap'` | the whitelist together used its 1,200 |
| `'round treasure cap'` | the round is full, for everyone |

A whitelisted address that used its own quantity must not read that the round is
full. An address that the group maximum stops must not think that its own maximum
stopped it. A player who is not whitelisted can only ever see the third error.

**The hour limit is a simple counter that starts again**, and not a true moving
window. It is less expensive, and it is sufficient:

```cairo
fn enforce_whitelist_rate_limit(
    ref self: ContractState, caller: ContractAddress, treasures: u32,
) {
    let now = get_block_timestamp();
    let mut window_start = self.whitelist_hour_start.read(caller);
    let mut count = self.whitelist_hour_count.read(caller);

    // A simple counter: after one hour the window starts again. Thus two full
    // groups CAN arrive 1 second apart, on the two sides of the hour. This is
    // acceptable, because the 250 round maximum still protects the round.
    if now >= window_start + 3600 {
        window_start = now;
        count = 0;
    }

    assert(count + treasures <= self.whitelistHourlyCap.read(), 'whitelist hourly limit');

    self.whitelist_hour_start.write(caller, window_start);
    self.whitelist_hour_count.write(caller, count + treasures);
}
```

**The contract tests the group maximum with a total for the round:**

```cairo
// 1,200 for ALL the whitelisted addresses in this round. The 250 above limits
// one address. This limits the group, because the maximums for each address do
// not add together: eleven addresses at 250 each would take 2,750 of the 2,840
// and leave 90 for all the other players.
let groupSoFar: u32 = self.whitelist_round_total.read(gameWeek);

assert(
    groupSoFar + treasures <= self.whitelistCollectiveCap.read(),
    'whitelist group cap',
);

self.whitelist_round_total.write(gameWeek, groupSoFar + treasures);
```

**What the three limits give.**

| The limit | The result |
|---|---|
| **250** in a round, for one address | one address takes a maximum of **8.8%** of the round |
| **1,200** in a round, for all together | the whitelist takes a maximum of **42.3%**, with any number of addresses |
| **80** each hour, for one address | to place 250 needs **3.1 hours** of a 6-hour round |

The first stops one address from taking the round. The second stops a **group** of
addresses from taking it. The third stops any of them from taking the first
minutes.

**Thus 1,640 places - 57.7% - are always free for the normal players**, with any
number of whitelisted addresses. Before the group maximum this value was **90**,
because eleven addresses at 250 each take 2,750 of the 2,840.

**The group maximum first operates at five whitelisted addresses.** Four can each
use their full 250 (1,000 in total, which is below the maximum). A fifth would make
the group 1,250, thus the contract stops it at 200. Below five addresses it never
operates, thus a short list pays nothing for it.

**1,640 is a minimum, and not a maximum.** The normal players have only the 2,840
limit. If the whitelist places nothing, they can take all the round. The 1,200
limits the whitelist group; the contract does not keep it for them.

And a farm is still not profitable: at 250 in each round and 4 rounds, the 0.03x
band controls almost all of it, thus **1,000 treasures give 2,834 ROZ for $263** -
which is **$0.0928** for each ROZ, or a market value of **$464M**. **To whitelist
an address does not make a farm profitable for it**, and the group maximum now
also limits what a group of stolen whitelist keys could take.

**To make the tree, off the contract.** Use `starknet-merkle-tree` with Poseidon
and one element in each leaf:

```js
import * as Merkle from "starknet-merkle-tree";
import fs from "fs";

const whitelistedAddresses = ["0x123...", "0x456..."];

// One element in each leaf, and that element is the address. This must be the
// same as `let leaf: felt252 = caller.into();` in the contract.
const tree = Merkle.StarknetMerkleTree.create(
  whitelistedAddresses.map(addr => [addr]),
  Merkle.HashType.Poseidon,
);

const proofs = {};
whitelistedAddresses.forEach((address, index) => {
  // The index is part of the proof. The contract needs it for the side of each
  // step. Keep it with the proof. Do not make it again separately.
  proofs[address] = { index, proof: tree.getProof(index) };
});

fs.writeFileSync("whitelist-root.json", JSON.stringify({ root: tree.root }, null, 2));
fs.writeFileSync("whitelist-proofs.json", JSON.stringify(proofs, null, 2));
```

**The sequence:** the owner makes the tree and calls `set_whitelist_merkle_root`.
The server gives the proofs from `whitelist-proofs.json`. The display asks for the
proof and the index of the caller, and gives both to `hide_treasure_bulk`.

**Make the proofs again each time the list changes.** Each index moves when you
make the tree again. Thus an old proof file silently returns addresses to the 10 a
day maximum. Publish the root and the proof file together.

A caller who is not whitelisted gives an empty proof and any index. The test fails
and the daily maximum operates. **A failed proof is not an error** - it is the
normal condition for almost every caller.

### 7.7 New events

The contract emits nothing when a player finds a treasure. Thus you cannot
calculate the median hops for each find. Thus you cannot adjust K.

Add these events:

| Event | Records |
|---|---|
| `TreasureFound` | The find and the number of hops |
| `RewardClaimed` | The USDC claim |
| `RewardTokenClaimed` | The ROZ claim |
| `RewardTokensWithdrawn` | The ROZ that leaves the contract |
| `RewardTokenAccrualSkipped` | A reward that the contract could not pay |

### 7.8 A more flexible sweep function

Change `withdraw_token_balance` to accept a token address. Then the owner can
recover any token.

**This needs a guard for the two tokens.** The ROZ that the players earned is not
yours, and the USDC that they can claim is not yours.

For the ROZ, the guard is one line: subtract `total_reward_token_pending`. If you
do not, the coverage rule in 7.3 fails.

**For the USDC the guard needs a new value.** The contract calculates the USDC
that it owes from the shares, when a player asks. It never adds the total
together. Thus there is nothing to subtract. Add this value:

```cairo
// The same idea as total_reward_token_pending. Increase it by currentHiderFee
// at each treasure that a player hides. Decrease it when a claim pays, or when
// a finder takes a stake. Then the sweep releases only the surplus.
total_usdc_claimable: u256,
```

Then the two conditions read the same way, and this is the purpose - one rule,
two tokens:

```cairo
if (tokenAddress == self.game_reward_token_contract_address.read()) {
    sweepableAmount -= self.total_reward_token_pending.read();
} else if (tokenAddress == self.game_token_contract_address.read()) {
    sweepableAmount -= self.total_usdc_claimable.read();
}
```

This is a new value and not a guard on a value that exists. Thus it costs a write
at the hide and at the claim. This is correct: without it, the sweep can take
money that the players own, and nothing shows the error.

## 8. How to deploy

Use an explicit `--url` for a 0.10 endpoint. Do not use `--network sepolia`.

### Phase 1 - the token only

1. Correct the four import lines in `src/game_reward_token.cairo`.
2. Add `mod game_reward_token;` to `src/lib.cairo`.
3. Build with `scarb build`.
4. Declare and deploy `ROZToken`. Give it two arguments: your address, then your
   address again.
5. Examine `symbol()`, `decimals()` and `total_supply()`.

Phase 1 is independent. You can do it now.

### Phase 2 - the game contract

6. Make the changes in section 7.
7. Deploy the game contract with three arguments: the mock VRF address, the USDC
   address, then the ROZ address.
8. Send ROZ to the game contract.
9. Examine `get_game_reward_token()`.

### Each year

Send the tokens for the year. Then set the new rates. Send the tokens first. If
you decrease the rates first, the early players get less.

## 9. The dangers

### 9.1 Farm wallets

**One large wallet.** The new prices in section 5.1 control this method. The cost
is now $4.715 each day for 136.35 ROZ. This is profitable if ROZ costs more than
**$0.0346**. Before, the value was $0.0072. Thus the cost is 4.8 times more.

**Many small wallets.** The new prices in section 5.1 do not control this method.
They make it **less** expensive. A wallet that makes 28 hops pays $0.045 and
earns 46 ROZ. The cost to take all the Year 1 tokens is $2,292 each day.

**The gate in section 5.2 controls this method.** With the daily payment limit,
the same wallet must pay $0.615 and it earns **28.6** ROZ. The cost to take all
the Year 1 tokens becomes **$50,371 each day**. This is 22 times more. The total
payment limit of $3 adds $245,712 more, one time.

**A farmer selects the least expensive wallet, not the largest wallet.** Thus the
wallet that makes 65 hops for $0.615 is the danger. It is profitable if ROZ costs
more than **$0.0215**. This is a market value of $107M with 5,000,000,000 tokens.
This is a large value for a game token. Thus this danger is not near. The older
value of $37M came from a calculation that gave the full rate to all 65 hops.
Section 5.2 does not permit this.

**Starknet gas is the largest control, and you have measured it.** A transaction
costs **$0.025 to $0.04**. The hop route needs 66 transactions for 28.6 ROZ, thus
gas adds $1.65 to $2.64 to the $0.615 of fees. The true cost is **$0.079 to
$0.114** for each ROZ, which is a market value of **$396M to $569M**. **The hop
route is not profitable.**

**The cheapest route mixes hides and hops.** Section 9.2 gives it: 5 hides and 28
hops give 262 ROZ for $1.209 of fees and $0.85 to $1.36 of gas. This is **$0.0079
to $0.0098** for each ROZ, or **$39M to $49M**. This is the value to watch.

### 9.2 The hide loop, and how section 5 controlled it

This was the worst route in the plan. Three changes in sections 5 and 5.2
controlled it.

#### What made a hide inexpensive before

Keep this, because it gives the reason for the three changes. Before section 5, a
hide was the one action that **no control in this plan reached**. The two tables in
section 5.2 gave the hide rewards in full, above the limit and below it. Rule 1
excluded the $5 stake, because the player gets it back. And
`hide_treasure_bulk` placed 200 treasures in one transaction. A hide that survived
gave 80 ROZ for the 12,833 units at the claim - **$0.00016 for each ROZ**,
profitable at a market value of $0.8M, in **147 transactions each day**.

#### The three changes

| Change | Result for the route |
|---|---|
| The gate operates on the hide rewards (5.2) | A hide cycle below the gate gives **12**, not 80 |
| The tiered fee (section 5) | A real cost that never comes back, and it **is a payment** |
| **The Daily Volume Multiplier** (section 5) | Treasure 4 of a day gives 0.70x, treasure 10 gives 0.08x |
| The maximums for each wallet and each round | 10 each day for one wallet, 2,840 in each round |

**The volume multiplier is what makes the maximum of 10 safe.** The maximum is 10
and not 3. Alone, that would make a farm **less** expensive: each hide that
survives adds 80 ROZ for $0.25. The multiplier removes this. After the third
treasure the ROZ decreases more quickly than the fee increases.

#### The cheapest wallet is still 3 hides and 28 hops

The hide fees get through the gate exactly - 3 x $0.20 = $0.60. Then the 22 free
hops give the full 1.0 and not 0.15. All three hides are in the 1.00x band:

| Step | Payment after | Volume | ROZ |
|---|---|---|---|
| Hide 1 | $0.20 - below | 1.00x | 4.5 + 7.5 |
| Hide 2 | $0.40 - below | 1.00x | 4.5 + 7.5 |
| Hide 3 | **$0.60 - gets through** | 1.00x | 30 + 50 |
| 22 free hops | $0.60 | - | 22 |
| Hops 23 to 28 (+$0.045) | $0.645 | - | 6 |
| Participation | - | - | 18 |
| **Total** | **$0.6835 in total** | | **150 ROZ** |

**More than three hides is worse, and this is the purpose.** The complete curve
for the farmer:

| Hides | ROZ | Cost | For each ROZ | Market value |
|---|---|---|---|---|
| 1 | 39.1 | $0.628 | 0.01606 | $80.3M |
| 2 | 49.4 | $0.631 | 0.01275 | $63.8M |
| **3** | **150.0** | **$0.683** | **0.00456** | **$22.8M** |
| 4 | 206.0 | $0.946 | 0.00459 | $23.0M |
| 5 | 262.0 | $1.209 | 0.00461 | $23.1M |
| 7 | 326.0 | $1.735 | 0.00532 | $26.6M |
| 10 | 364.4 | $2.523 | 0.00692 | $34.6M |

**The change from 3 to 10 cost nothing.** The minimum stays at $22.8M, which is
the same value that the maximum of 3 gave. One hide and two hides are much worse,
not better: a wallet without three hides must **hop** to $0.60, and it uses 44 to
55 hops at 0.15 to arrive.

| | Before section 5 | **Now** |
|---|---|---|
| Cost for each ROZ, all hides survive | $0.00016 → **$0.8M** | **$0.00456 → $22.8M** |
| Cost for each ROZ, a busy game | $0.0192 → $96M | **$0.0221 → $110M** |
| Cost each day, a quiet round | $375 | **$10,674** |
| Number of wallets | ~1 | **15,616 each day** |
| **Transactions** | **~147 each day** | **~500,000 each day** |

**The minimum increased 28 times, and the transactions increased 3,400 times.**

#### The cost still depends on the treasures that the finders take

A hide gives 30 ROZ always. It gives 50 ROZ more only when no finder takes it.
When a finder takes it, the finder also takes the $5. For each wallet of 3 hides,
the 39 ROZ of instant rewards and the 46 ROZ from the hops are certain. Only the
65 ROZ of survival rewards is at risk.

To take all the Year 1 tokens a farmer needs **15,616 wallets**, thus **46,848
hides each day**, or approximately **11,712 in each round**. More hides do not make
the treasures more difficult to find: section 6 makes the map `T x 40 x K` cells,
thus the density stays the same.

| Finds by the correct players, in each round | Treasures taken | Cost for each ROZ | Cost each day | Profitable above |
|---|---|---|---|---|
| ~1,875 - a busy game, ~5,000 players each day | 16.0% | **$0.0221** | $48,150 | **$110M** |
| ~500 | 4.3% | $0.0100 | $21,700 | $50M |
| ~100 - a quiet round | 0.9% | $0.00560 | $12,100 | $28M |
| 0 - a round with no players | 0% | **$0.00456** | $10,674 | **$22.8M** |

**Read the last line first now.** It is the best condition for the farmer, and
$22.8M is not extreme. The same line gave $0.8M before section 5. The first line
at $110M is **more** expensive than the hop route at $107M.

**The danger from the time is much smaller.** A farmer still prefers the quiet
rounds. But the difference between the first line and the last line is **4.8
times** now, and it was 120 times. The contract takes the $0.20 fee if the treasure
survives or not. Thus the fee gives a minimum that the farmer cannot avoid with a
good time.

#### Gas controls this route again, and you have measured the gas

Sections 5.1 and 9.1 say that gas is the real control. `hide_treasure_bulk`
removed it before: 200 treasures in one transaction. The maximums count treasures,
thus they do not remove it now:

| | The hop route | The hide route, before | **The hide route now** |
|---|---|---|---|
| Transactions to take all the Year 1 tokens | ~5.3 million each day | ~147 each day | **~500,000 each day** |
| Fees | $50,371 each day | $375 to $45,000 | **$10,674 to $48,150** |
| Money necessary | None | $146,405, returned | $234,240, returned |

15,616 wallets x 32 transactions each - 3 hides, 28 hops and one claim. This is
approximately **3,400 times more transactions** than before.

**At $0.025 to $0.04 for each transaction, gas is now more than the game fees on
each route.** Thus the values above are too small:

| Route | Fees | Gas | Total | For each ROZ | Market value |
|---|---|---|---|---|---|
| 3 hides + 28 hops (32 tx) | $0.683 | $0.80 to $1.28 | $1.48 to $1.96 | $0.0099 to $0.0131 | **$49M to $65M** |
| **5 hides + 28 hops (34 tx)** | $1.209 | $0.85 to $1.36 | $2.06 to $2.57 | **$0.0079 to $0.0098** | **$39M to $49M** |
| 65 hops only (66 tx) | $0.615 | $1.65 to $2.64 | $2.27 to $3.26 | $0.079 to $0.114 | $396M to $569M |

**Gas changes the best wallet for the farmer.** With the fees only, the farmer
stops at three hides. With the gas, the best number is **five**, because more
treasures in one wallet divide the fixed cost of the 29 hop and claim
transactions. The minimum increases from $22.8M to **$39M to $49M**.

#### The round maximum gives a limit on the quantity

The values above give the price. `maxTreasuresPerRound` gives **how much a farmer
can take at any price**, and this is the limit that operates:

```
2,840 in each round  x  4 rounds  =  11,360 treasures each day
11,360  /  5 for each wallet      =   2,272 farm wallets
2,272   x  262 ROZ                = 595,264 ROZ each day
```

The Year 1 budget is 2,342,466 ROZ each day. Thus this is **25.4%**. **A hide farm
cannot take all the tokens** - not at any price, and not with any number of
wallets. After one quarter of the daily tokens the farmer must use the hop route
at $396M or more, and nobody does this.

This is a different type of protection, and a better one: it does not change with
the ROZ price, with the gas, or with the number of treasures that the finders take.
But honest hiders use the same 2,840 places. Refer to section 11.

**One change remains:**

- **The deduction for each treasure (section 7.6).** The maximum of 10 makes this
  error 10 times, not 200 times, and it moves the cheapest wallet approximately
  4%. Thus it is not urgent now, but the calculation is still wrong and the change
  is one line. A whitelisted address that claims 250 shares one time makes the
  error 250 times, and that condition keeps the change necessary.

Section 4 also gives this route to the light casual player. Thus the two use the
same action. But since section 5 they no longer have the same danger.

### 9.3 Wallets that pay nothing

Free hops give ROZ. Thus a wallet can earn tokens with no USDC.

A wallet that pays nothing cannot get to the $0.60 limit. A free hop adds nothing
to the payment counters. Thus each hop gives 0.15 ROZ and not 1.0 ROZ:

| Source | ROZ |
|---|---|
| 22 free hops x **0.15** | 3.3 |
| Participation bonus. It stops below $0.60. Also, 22 is less than 28 | **0** |
| Spawn. A spawn gives no ROZ | 0 |
| **Total each day, with no cost** | **3.3** |

Approximately **709,838** wallets can take all the tokens for Year 1. These
wallets pay Starknet gas only.

**Two controls stop the participation bonus.** The payment limit stops it. Also,
the free allowance (22) is less than the participation minimum (28). One control
is sufficient. Two controls cost nothing more.

Obey this rule: **keep the free allowance less than the participation minimum.**
But know that the payment limit is the primary control now.

**This was a problem before. The smaller rate corrects it.** The values changed
three times:

| The values | ROZ each day with no cost | Wallets necessary |
|---|---|---|
| 20 free hops, 0.2 multiplier | 4 | 585,617 |
| 22 free hops, 0.3 | 6.6 | 354,919 |
| **22 free hops, 0.15** | **3.3** | **709,838** |

The allowance is still 22 hops. The rate did all of this. 709,838 wallets is 21%
more than the first values needed. Thus this route is the most difficult it has
been.

**But be careful with this value.** `hopRewardBelowThreshold` does not operate
only on the wallets that pay nothing. Each day starts at zero payment. Thus it is
also the rate for the first hops of each correct player's day: 54 hops for the
typical casual player, and 59 hops for the active player. The change from 0.3 to
0.15 removed 8.1 ROZ and 8.8 ROZ from these two players. To make the value smaller
again is not free. `dailyFreeHops` is the other control, and it operates only
inside the allowance.

### 9.4 1,460 rounds each year

A round is 6 hours. Thus you must call `start_new_game` 1,460 times each year. The
function has eight arguments and no checks. One error damages the economics of
that round. This error occurred before.

**Decided: a server outside the contract, on AWS.** An **EventBridge** schedule
operates every 6 hours and starts a **Lambda** function. The Lambda calls
`start_new_game` with the values from section 6. The contract does not change.

Three points that you must design for:

- **The Lambda must operate two times safely.** EventBridge tries again after a
  failure. To call `start_new_game` two times for the same round would change that
  round's values a second time, which is the error that this section describes.
  Test the current round number before you write.
- **The key of the Lambda is privileged.** It is the only account that can start a
  round. If a person takes it, they stop or damage the game. Protect it like the
  owner key.
- **The eight arguments still have no checks.** To calculate them in one Lambda
  that you examined is much better than to do it by hand 1,460 times each year.
  But the contract still accepts a wrong value with no error.

**Decided: a round can stop early** when the players find each treasure. The
contract can see this now: `total_reward_shares_for_hiders` decreases at each
correct find, thus zero means that the players found all of them. The
recommendation is that **the server does this**, and not the player whose find
makes the count zero - that player would pay the gas for everyone. The cost is a
maximum of 6 hours of an empty round.

A function `advance_round()` in the contract is still the better answer for later.
It removes the eight arguments, and anyone could call it after a time limit if the
server stops. Refer to section 11.

### 9.5 "Free" is not free

The player pays Starknet gas for each action. The game does not pay this. Thus
write "no game fee" and not "free" until the paymaster operates.

## 10. Tests

1. `scarb build` gives no errors. The build makes three contract classes.
2. The token gives `ROZ`, `18` and `5000000000000000000000000000`.
3. A hide by a wallet that paid $0.60 that day adds exactly 30 ROZ to the balance.
   No ROZ moves. The contract takes $5.20: the $5 stake and the $0.20 fee.
4. Hop 28 gives the participation bonus one time. Hop 41 gives nothing.
4a. The participation bonus operates one time each day. Make 28 hops in round 1,
   then make 28 hops in round 2. The bonus does not operate a second time.
4b. **The hop price increases correctly.** Hops 1 to 22 cost nothing. Hop 23 costs
   `5000`. Hop 26 costs `10000`. Hop 46 costs `20000`. Hop 66 costs `40000`.
   **Hop 41 is the first hop of round 2. It must not cost `5000`.** The count must
   not go back to zero at the end of a round. This is the most important test for
   the farm controls.
4c. When the daily ROZ is more than the maximum, the subsequent rewards decrease.
4d. A wallet that paid `599999` gets 0.15 ROZ for a hop, and gets **no**
   participation bonus at hop 28. A wallet that paid `600000` gets 1 ROZ and gets
   18 ROZ for the bonus. Test the bonus. The gate stops the bonus. It does not
   decrease the bonus.
4d-i. **The hop that gets through the gate gives the full rate. The earlier hops
   do not change.** Let a new wallet make 65 hops with no spawns. Hops 1 to 64
   must each give `0.15e18`. Hop 65 must give `1e18`. The total balance is
   `28.6e18` with the participation bonus. Read the balance again after hop 65 and
   make sure that the first 64 rewards did **not** increase. Most of the strength
   of the gate is in this rule. A contract that calculates the day again gives this
   wallet almost three times more.
4d-ii. **The participation bonus operates after a late gate crossing.** Make 28
   hops while the wallet is still below $0.60. There must be no bonus. Then
   continue to hop until the payment gets to $0.60. The `18e18` must operate at
   that hop. A wallet that never gets to $0.60 never gets the bonus. An error here
   removes 18 ROZ from each correct player, each day. A test that pays first does
   not find this error.
4e. **A hide counts the fee as a payment and the stake as nothing. This is the
   most important test for the gate.** A wallet that only hides, 3 times, must
   finish with the two payment totals at **exactly `600000`** - the three $0.20
   fees, and no unit of the $15 stake. Test the number, and not only that it is
   more than zero: `15600000` means that the stake is a payment, and then a farmer
   gets more than the $3 limit for the $0.2128 that a hide really costs. This is
   **14 times** less expensive, and rules 1 and 3 stop. Refer to section 5.2
   rule 1.
4e-i. **A free hop gives no payment credit.** After 22 free hops, the two payment
   totals are still zero. Thus free play alone can never get to the limit.
4e-ii. **Three hides get through the daily gate exactly, and the third gives the
   full rate.** From test 4e: hides 1 and 2 give `4.5e18` each. Hide 3 - the hide
   that makes the payment `600000` - gives **`30e18`**, because the contract takes
   the fee before it selects the rate. Refer to section 7.1a. All three are in the
   1.00x volume band, thus no multiplier operates.
4e-iii. **The fee increases at treasure 4.** Hides 1 to 3 each send `200000` of
   `hideFeeBase`. Hide 4 sends `250000`. After ten hides `player_spend_today` is
   exactly `600000 + 7 x 250000 = 2350000`, and no unit of the `$50` of stake is
   in either counter.
4e-iv. **The Daily Volume Multiplier, band by band.** With a wallet that got
   through the gate at hide 3, the instant hide rewards for ten hides must be:

   | Treasure | 1 to 3 | 4 to 5 | 6 to 7 | 8 to 9 | 10 |
   |---|---|---|---|---|---|
   | Band | 1.00x | 0.70x | 0.40x | 0.20x | 0.08x |
   | Reward | `30e18` | `21e18` | `12e18` | `6e18` | `2.4e18` |

   Test the **10th** reward specifically - `2.4e18`. This is the band that a farmer
   arrives at, and an error of one in the index gives the wrong value here.
4e-v. **A bulk call equals the same number of single hides - the test that closes
   section 9.2.** Use one wallet with `hide_treasure` ten times, and a second
   wallet with `hide_treasure_bulk(50000000)`. **The two must finish with the same
   ROZ balance and the same `player_spend_today`.** If the bulk is less expensive
   or more generous by any quantity, a farmer divides or joins calls to use the
   difference.
4e-vi. **The daily hide maximum.** The 11th `hide_treasure` in a day fails with
   `'daily hide cap'`. Move past midnight UTC and it operates. Also,
   `hide_treasure_bulk(55000000)` - eleven treasures - fails from a wallet that did
   not hide that day, because **the maximum counts treasures, not calls**. Refer to
   section 7.6. `hide_treasure_bulk(50000000)` operates and leaves the count at 10.
4e-vii. **The hide rates in the three conditions.** Below the limit a hide gives
   `4.5e18`. A new wallet that paid $0.60 gives `15e18`. An established wallet that
   paid $0.60 gives `30e18`. All at the 1.00x band, thus the volume multiplier does
   not change the result.
4e-viii. **The contract selects the survival rate at the hide.** Hide one time
   below $0.60 - `hider_survival_roz` must hold `7.5e18`. Then get through the
   gate, let the round finish with no finder, and claim: the reward is **`7.5e18`
   and not `50e18`**. Then test the other direction: hide after the gate, and claim
   some days later with that day's payment at zero. The reward must still be
   `50e18`. The two directions are both important. The first is the method of a
   farmer. The second removes 42.5 ROZ from a correct player who claims on a Monday
   morning.
4e-ix. **The contract never decreases a find.** A wallet below the daily limit,
   that is also a new wallet with zero total payments, gets the full **`110e18`**
   for a correct find. No condition decreases it. Refer to section 5.2.
4e-x. **The test in the set function (section 7.1).** `set_hide_fee_base(250000)`
   must fail with `'hide fee gate mismatch'` while `hideFeeTierBoundary` is 3 and
   `dailySpendThreshold` is `600000`, because 3 x `250000` is `750000`. To change
   the base and the limit together, so that the multiplication is correct, must
   operate. Test also that a change to `dailyHideCap` alone - to 5, or to 50 -
   **never** fails: the maximum is not part of the relation.
4f. A new wallet with a total payment of less than $3 gets 0.5 ROZ for a hop and
   9 ROZ for the bonus, also when the wallet paid more than $0.60 that day. At $3
   the same actions give 1 ROZ and 18 ROZ.
4g. **Use the lowest rate. Do not multiply the rates.** A new wallet that is also
   below $0.60 gets **0.15 ROZ** for a hop. This is the lower of the new wallet
   rate (0.5) and the rate below the limit (0.15). It gets **no** participation
   bonus. Test the value that the contract adds. Two incorrect answers: **0.5 ROZ**
   from the new wallet rate alone, and **0.075 ROZ** from a multiplication of the
   two rates.

   **Do not check this value by memory.** 0.15 is also the value that the old
   multipliers gave from 0.5 x 0.3. Thus the correct answer looks the same as the
   error. Compare the result with the stored value of `hopRewardBelowThreshold`.
5. A spawn gives 0 ROZ. This is correct for a free spawn and a paid spawn.
6. **With no ROZ in the contract:** a hide, a move and a spawn all operate. The
   USDC claim pays in full. This is the most important test.
7. A wallet with no USDC and no approval can spawn one time and hop 22 times.
   The balance is **3.3 ROZ**, because the wallet is below $0.60. **The
   participation bonus does not operate**, for two reasons: the wallet is below
   $0.60, and 22 hops is less than 28. This is the most important anti-farm test.
7a. Give USDC to the same wallet. Let it hop to hop 65. The hops after `600000`
   give 1 ROZ. The earlier hops keep 0.15 ROZ. The contract does not calculate
   them again.
8. A bulk hide of $1,000 **fails** with `'daily hide cap'` from a wallet that is
   not whitelisted. A bulk hide of $50 gives 10 shares, and the contract also
   takes `2350000` of fees.
8a. **The whitelist (section 7.6a).** A wallet in the published tree, with the
   correct proof and index, can make more than 10 treasures in a day. The **same
   wallet with an empty proof returns to the 10 a day maximum** - a failed proof is
   the normal condition, not an error. A wallet with a correct proof and the
   **wrong index** also fails and returns to 10; this is the most probable error
   with the tools, and it fails silently. The 251st treasure in one round fails
   with `'whitelist round cap'`. The 81st treasure in one hour fails with
   `'whitelist hourly limit'`; move 3,600 seconds and it operates. Only the owner
   can call `set_whitelist_merkle_root`.
8b. **The group maximum for the whitelist (section 7.6a).** Five whitelisted
   addresses each try 250 treasures in one round. The first four operate (1,000 in
   total). The fifth places **200 and then fails** with `'whitelist group cap'`,
   thus the group total is exactly **1,200** and not 1,250. **Then a wallet that
   is not whitelisted can still hide.** This is the reason for the whole maximum:
   with the whitelist finished, 1,640 places stay, and a normal player must not
   see `'round treasure cap'`. Test also that the three errors are different: an
   address that used its own 250 gets `'whitelist round cap'` and **not**
   `'whitelist group cap'`; a new whitelisted address, after the group is full,
   gets `'whitelist group cap'` and **not** `'round treasure cap'`. The total
   starts again in the next round. With four addresses or fewer the maximum never
   operates, and a hide that is not whitelisted never changes the total.
9. A claim for 1 share pays `4987167`. A claim for 10 shares pays `49871670`, and
   **not** `49987167`. Ten is the largest claim for a normal wallet. A whitelisted
   address can get to 250, where the error would be 250 times.
10. The total of the balances is never more than the ROZ that the contract holds.
11. **The sweep function protects the two tokens (section 7.8).** With ROZ in the
    balances and USDC that players can claim, the sweep must release only the
    surplus of each one. Take the ROZ and test that `claim_reward_tokens` still
    pays in full. Take the USDC and test that `claim_reward` still pays `4987167`.
    A third, different token releases all of its balance.
12. **The server that starts each round operates two times safely.** To call
    `start_new_game` two times for the same round must not change the values of
    that round. AWS EventBridge tries again, thus this will happen.

## 11. Decisions

### The decisions that you made

1. ~~**How do you start each round?**~~ **AWS EventBridge every 6 hours, with an
   AWS Lambda function** that calls `start_new_game`. The contract does not
   change. Refer to section 9.4. The Lambda must operate two times safely, because
   EventBridge tries again. Its key is as important as the owner key.
2. ~~**What are the map size limits?**~~ **`maxTreasuresPerRound` is 2,840**, with
   a set function. At the first K this gives a maximum map of **500 x 500** and
   11.4 treasures for each 1,000 cells. Refer to section 6.
3. ~~**What is the first value of K?**~~ **2.2**, and you examine it again when you
   know the real `T` of the first round.
4. ~~**Does the hop reward limit agree with the map size formula?**~~ **Corrected.**
   The formula targets 35 to 45 hops for each find. The reward limit is 40. At
   `dailySoftCapRoz` = 136 the daily maximum no longer stops these rewards.
6. ~~**Does the per-hop reward stay at 1 in year 2?**~~ **No. It decreases with the
   tokens of that year.** 630M / 855M = **0.7368**, which gives the 0.74. The same
   proportion operates for each later year.
7. ~~**Must the game have a retention reward?**~~ **No, accepted as it is.** The
   game has no retention reward.
11. ~~**Is rule 4 correct?**~~ **No. Rule 4 is removed** (section 5.2). A verified
    flag needs a person to approve each wallet, which is a new privileged writer
    and a target when ROZ has a value. Section 5.2 has three rules now. The bulk
    hide whitelist (section 7.6a) does exist, but it gives no ROZ bonus - only
    higher hide limits.
12. ~~**Rule 3 decreases the rewards only for the players who pay.**~~ **Confirmed
    correct.** A light casual player is already at the minimum from rule 1, thus
    rule 3 takes nothing more from them. The name is not correct for this, and the
    behaviour is: the rule prices the change of wallets, and a wallet that never
    pays is not worth changing.
13. ~~**Must the contract calculate the day again at $0.60?**~~ **No.** The rates
    operate from that moment only. To change this would return the farm cost to
    $0.00741 for each ROZ and would put the typical casual and active players back
    in their targets - but the farm effect is the larger of the two.
14. ~~**What is the daily maximum reward?**~~ **`dailySoftCapRoz` = 136.** It is a
    small quantity below the natural maximum of 136.35, thus it stops only the
    route that pays for spawns before it hops. Refer to section 5.1.
15. ~~**How much does Starknet gas cost?**~~ **$0.025 to $0.04 for each
    transaction**, measured. It is now more than the game fees on each route
    (section 9.2), and this is why the cheapest farm wallet moved from three hides
    to five.
16. ~~**Is a hide fully free?**~~ **No.** A hide costs $0.20 or $0.25, and the
    contract also keeps $0.0128 at each claim. Thus one of the first three hides
    costs $0.2128 if it survives.
17. ~~**Can a round stop early?**~~ **Yes**, when the players find each treasure.
    The recommendation is that the server does this and not the finder, thus one
    player does not pay the gas for everyone. Refer to section 9.4.
18. ~~**Must the sweep function protect the USDC?**~~ **Yes** (section 7.8). This
    needs a new value - a total of the USDC that players can claim - because the
    contract calculates the USDC from the shares and never adds it together.
19. ~~**Is "a light casual player must hide" correct?**~~ **Yes.** Two hides give
    approximately 54 ROZ, and 2 hides with 42 hops give 30.3 ROZ below the gate.
20. ~~**The rewards change with the order of the actions.**~~ **Put a message in
    the display: "hide after you pay $0.60".**
21. ~~**The participation bonus needs the two conditions.**~~ **Confirmed.** The
    contract obeys the rule, and the player gets the bonus after they pass the
    payment limit. Refer to section 7.1a.
22. ~~**How do you control the hide loop?**~~ **Controlled** (sections 5, 5.2,
    7.6). `maxTreasuresPerRound` is 2,840, and the deduction operates for each
    treasure with the bulk hiding.
23. ~~**Do you still want bulk hiding?**~~ **Yes**, and section 7.6 gives the new
    specification. Each address can use it. The Daily Volume Multiplier and the
    tiered fee control the quantity, and section 7.6a gives the whitelist.
24. ~~**Nothing protects the relation between the three settings.**~~ **The set
    functions test it** (section 7.1). The relation is
    `hideFeeTierBoundary x hideFeeBase == dailySpendThreshold`, and **not**
    `dailyHideCap x hideFeeBase`.

### The decisions that stay open

5. **Is 4,700 to 16,700 players each day correct for Year 1?** **You cannot know
   this before the launch** - it depends on the response of the public. Measure it
   in the first week. If the game has more players, the tokens for Year 1 stop
   early.
8. **No player type gets the target reward - accepted as it is.** The targets are
   25 to 70, 140 to 280, and 300 to 500. The light casual player gets **6** (or
   approximately 54 with two hides), the typical casual player gets **117.5**, and
   the active player gets **285.9**. You examined the three options - decrease the
   targets again, increase `hopRewardBelowThreshold`, or decrease
   `dailySpendThreshold` - and **you took none of them**, because only the last one
   helps the light casual player and it is also the one that makes the gate weaker.
   Examine this first if the real players stop early.
12. **The light casual player is the furthest below the target, and the middle is
    a trap - accepted as it is.** This player pays $0.265 each day and gets 6 ROZ,
    and the target starts at 25. **Two hides give approximately 54 ROZ, and 2 hides
    with 42 hops give 30.3 ROZ below the gate. But one hide gives only 18 ROZ** -
    less than both. A player who hides one time and stops is in the worst position,
    and nothing tells them this. Put it in the display.
15. **Is $3 the correct total payment limit? - accepted as it is.** $3 gives a
    cost of $245,712 one time. $5 gives $409,520, thus $3 gives approximately one
    half of the control. Accepted: the ratio does not change - the cost is 4.9 days
    of the daily cost with each value - and the daily limit decides where the light
    casual player stops.
25. ~~**The whitelist protects each address, and not the group.**~~ **Corrected
    with a maximum for the group** (section 7.6a). The maximum of 250 for each
    address did not add together: eleven such addresses would take 2,750 of the
    2,840 and leave **90** for all the other players. `whitelistCollectiveCap` =
    **1,200** now limits all the whitelisted addresses together. Thus **1,640
    places - 57.7% - are always free for the normal players**, with any number of
    addresses on the list. The maximum first operates at **five** addresses, thus a
    short list pays nothing for it, and it costs one counter for each round. A farm
    was never the danger here (a whitelisted address needs a market value of
    **$464M**); to stop the normal players was the danger.
30. **The 1,640 places are sufficient for one hide from each player, and not for
    two** (section 7.6a). With the honest demand from decision 27:

    | 5,000 players each day, each hiding | In a round | Against 1,640 | Against 2,840 |
    |---|---|---|---|
    | one time | 1,250 | **it fits** | it fits |
    | two times - what section 4 asks of a light casual player | 2,500 | **it does not fit** | it fits |

    With two hides from each player, the normal players need the whitelist to use
    less than 340 of its 1,200. The contract does not stop them - 1,640 is a
    minimum and not a maximum, and all the 2,840 stays available. But **the minimum
    alone does not cover the behaviour that the design asks for.** To give both
    groups all that they want needs **3,700 in a round**, which at K = 2.2 is a map
    of **571 x 571** - larger than the 500 x 500 that section 6 gives as the
    maximum. Thus you cannot correct this with a larger `maxTreasuresPerRound`
    until you examine the map size limit again. Watch it with the 70% measurement
    in decision 27.
26. **Is 25.4% of the tokens the correct limit for a hide farm?** (section 9.2).
    Each round has **2,840 places for treasures**. All the players share them. If
    a farmer takes each place in each round, the farmer earns **595,264 ROZ each
    day - one quarter of the tokens for that day**. This is the worst condition
    that the limit permits. The question is simple: is one quarter too much to
    give to a farmer?

    A smaller limit decreases this by the same proportion. 1,420 gives the farmer
    12.7%. But **the contract cannot see whose treasure is in a place.** A place is
    a place. The first player to arrive takes it, and nothing on it says who. Thus
    a smaller limit also decreases honest hiding by the same quantity. There is one
    control, and it moves the two sides together.

    **A place that a farmer uses is worth less than a place that a player uses.
    This is a reason to keep 2,840:**

    | Who | ROZ for each place |
    |---|---|
    | An honest player, 1 hide | **80** |
    | A farm wallet, 5 hides (216 / 5) | **43.2** |

    Treasures 4 and 5 of a farmer give 0.70x. Thus a farmer gets **1.9 times less
    for each place** than a player who hides one time. A smaller limit costs the
    honest players almost two times more than it costs a farm.
27. **The places are more full at the launch than they appear** (section 7.6). The
    capacity is 2,840 in a round, and 11,360 each day. The honest demand with
    5,000 players each day:

    | Each player hides | In a round | Capacity used |
    |---|---|---|
    | one time | 1,250 | **44%** |
    | two times - what section 4 asks of a light casual player | 2,500 | **88%** |

    **Plan for two.** Section 4 tells a light casual player to hide two times,
    because this is the route to the target of 25 to 70. Thus many hides is what
    the design asks for, and not a maximum. With 16,700 players each day - the top
    of the Year 1 range - two hides each is **8,350 in a round, which is
    approximately 3 times the capacity**.

    **When the places finish, the first player to arrive takes them, and one side
    is a machine.** A program can hide at the second that a round starts. A person
    cannot. Thus the places do not fill equally: they fill with the wallets that
    watch for the block, and the honest players get `'round treasure cap'`. Time in
    the game gives no priority: a wallet from this morning has the same right as a
    wallet that played for one year.

    Watch this. Do not correct it before it happens - but use a number and not an
    opinion: **measure the places used in each round, and act if it passes 70%.**
    Then you can give each wallet a maximum for each round, and not only the
    whitelisted addresses. Or you can increase 2,840 - but the map increases with
    the square root of T, thus you must first test 500 x 500. Refer to section 6.
28. **The gas does more against the farmers than the price list does** (section
    9.2). The cheapest farm wallet pays **$1.209 of fees and $0.85 to $1.36 of
    gas** - the gas is the larger part. Thus section 5.1 has four price tiers for
    the smaller of the two costs. One flat price could give the same protection
    with less complexity. Examine this when you have measured the real gas.
29. **The server is one point of failure** (section 9.4). EventBridge and Lambda
    is decided, but the key of the Lambda can start or damage any round, and one
    invocation that fails means a round never starts. A function `advance_round()`
    in the contract, that anyone can call after a time limit, would remove this
    privilege. Keep it for later.
