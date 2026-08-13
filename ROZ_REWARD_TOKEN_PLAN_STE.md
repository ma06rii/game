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
| Hide a treasure | 30 | Immediately |
| The treasure is not found in the round | 50 | At the claim |
| Find or steal a treasure | 110 | Also approximately $5 USDC |
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
2. A successful hide - 30 + 50 = 80.
3. Participation - less important. The player must make 28 of a maximum of 40
   hops. The player must also pay $0.60 in the day.
4. Each hop - a small reward for exploration.

There is no retention reward now.

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

Two rules of the calculation, because they change the values:

- **The payments increase in the order of the actions.** In each round the player
  makes the spawn before the hops of that round.
- **The participation bonus operates at the first action where the two conditions
  are true**: 28 hops and $0.60. Refer to section 7.

| Player | Rounds and hops | Payment | Gets through at | **Established** | **New wallet** | Target |
|---|---|---|---|---|---|---|
| Light casual | 2 rounds, 20 hops each | $0.265 | **Never** | **6** | **6** | 25 - 70 |
| Typical casual | 2.5 rounds, 25 hops each | $0.755 | Hop **55** | **114.1** | **101.1** | 140 - 280 |
| Active | 4 rounds, 32 hops each | $3.435 | Hop **60** | **285.9** | **242.4** | 300 - 500 |

The established values include one hide cycle for the casual player and the
active player. They include one find for the active player.

A wallet leaves the new wallet condition at $3 of total payments. The active
player needs 1 day. The typical casual player needs 4 days. The light casual
player needs 12 days.

The calculation for the typical casual player: 54 hops before the gate at 0.15
(**8.1**), 8 hops after the gate at 1.0 (**8**), the participation bonus (**18**),
and one hide cycle (**80**).

**No player type gets the target now.** The targets were correct for the older
values. The correction moved all three players down. The smaller hop rate of 0.15
moved them down a small amount more:

| Player | Before | With the correction, at 0.3 | **With the correction, at 0.15** |
|---|---|---|---|
| Light casual | 12 | 12 | **6** |
| Typical casual | 160 | 122.2 | **114.1** |
| Active | 336 | 294.7 | **285.9** |

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

**The rewards change with the order of the actions.** A player who makes the spawn
at the start of a round gets through the gate more quickly. Thus this player earns
more than a player who makes the same actions in a different order. Refer to
section 11.

There are three more causes for the light casual value of 6:

1. **The daily payment limit in section 5.2.** The light casual player does not
   get to $0.60. Thus the hop reward decreases to 0.15 and the participation bonus
   stops. A day with no gate gives this player 58 ROZ. They get 6 ROZ. The limit
   causes all 52 ROZ of the difference.
2. The daily reward of 12 to 22 ROZ does not operate now.
3. The participation bonus operates one time each day, not in each round. This
   removes 54 ROZ from the active player.

### Hops alone do not get to the light casual target

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

Thus the player must use the rewards that stay full below the gate. These are the
instant hide (30), the full hide cycle (80) and the find or steal (110). The
light casual player with **one instant hide gets 36 ROZ**. This is in the target
of 25 to 70. A full hide cycle gives 86 ROZ, which is more than the target.

This is the meaning of the target now: **a light casual player must hide. Hops
alone are not sufficient.** This is a correct design, because the gate does not
decrease the hide rewards. But section 9.2 shows that the hide loop is also the
cheapest route for a farmer ($0.00016 for each ROZ). Thus the only route into the
target is the route with the fewest controls. Refer to section 11.

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
| Hide a treasure | Free | The contract locks the $5 stake only |
| One hop | $0.005 to $0.04 | The price increases. Refer to section 5.1 |
| Spawn a new position | $0.10 | Was $1.00 |

The hop price and the spawn price decrease 10 times.

The hide price does not change, and the contract does not change. The $5 is a
stake, not a fee. The player gets the stake back if a finder does not take the
treasure.

**The stake is at risk.** A finder can take it. Also, the contract keeps 12,833
units (approximately $0.0128) at each claim. Thus a hide is not fully free.

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
4. **Optional: a bonus for a person.** A wallet with a social account can get a
   higher maximum or a small bonus.

### The rates

The rates are absolute values. They are not multipliers. Refer to rule 2 below.

**Rule 1 - the payments in the day:**

| Reward | Below $0.60 | $0.60 or more |
|---|---|---|
| Each hop | **0.15** | **1.0** |
| Participation bonus | **None** | **18** |
| Hide a treasure | Full | Full |
| The treasure is not found | Full | Full |
| Find or steal | Full | Full |

**Rule 3 - a wallet is new until $3 of total payments:**

| Reward | A new wallet |
|---|---|
| Each hop | **0.5** |
| Participation bonus | **9** |
| Daily maximum for hops and participation | **80 ROZ** |
| Hide a treasure | Full |
| The treasure is not found | Full |
| Find or steal | Full |

A wallet leaves the new condition permanently at $3 of total payments.

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
| Light casual | 40 | $0.265 | **Never** | **6** | **6** | 25 - 70 |
| Typical casual | 62 | $0.755 | Hop 55 | 114.1 | 101.1 | 140 - 280 |
| Active | 128 | $3.435 | Hop 60 | 285.9 | 242.4 | 300 - 500 |

**A light casual player and a small farmer pay the same amount.** Thus the gate
cannot see the difference. It decreases the rewards for both.

The light casual player gets 6 ROZ, and the minimum is 25. The change from $0.50
to $0.60 moved this player further from the limit.

**The other two players are also below their targets now.** The new targets in
section 4 were made when the values still gave the full rate to all the hops. The
correction puts the typical casual player 25.9 ROZ below the minimum, and the
active player 14.1 ROZ below. The correction is the larger cause. The rate of 0.15
adds 8.1 ROZ and 8.8 ROZ more.

**More hops cannot correct the light casual player.** The maximum payment below
$0.60 is $0.595, which is 64 hops. These hops give 64 x 0.15 = **9.6 ROZ**, and
there is no participation bonus. Thus 9.6 ROZ is the maximum for a day below the
gate, and the target starts at 25. Only the rewards that stay full below the gate
can get to the target. One instant hide moves this player from 6 to **36 ROZ**.
Refer to section 4. But refer also to section 9.2: the hide loop is the cheapest
route for a farmer.

**The two rules operate on the same players at the bottom.** The light casual
player is already at the minimum because of rule 1. Thus rule 3 takes nothing
more from this player. Rule 3 decreases the rewards only for the players who pay.

Make this decision before the game operates. Refer to section 11.

### Two rules that you must obey

**1. The hide stake is not a payment.**

The $5 hide fee comes back to the player. A hider gets `4,987,167` of
`5,000,000`. Thus the true cost is $0.0128.

If the stake was a payment, a farmer makes one hide and gets more than the $3
limit for $0.0128. This is **234 times** less expensive. Thus rules 1 and 3 do
not operate.

**Only these are payments:** the hop fees, the spawn fees, and the 12,833 units
that the contract keeps at each claim. A free hop is not a payment.

This rule did not change with the new values. It is the most important rule in
this section.

**2. Use the lowest rate. Do not multiply the rates together.**

A wallet can be new and also below the daily payment limit. The two tables do not
agree: 0.15 or 0.5 for each hop, and no bonus or 9 for participation.

> **Select the lowest value for each reward line. Do this for each line
> independently.**

| Condition | Each hop | Participation |
|---|---|---|
| Established, paid $0.60 today | 1.0 | 18 |
| Established, below $0.60 today | 0.15 | None |
| A new wallet, paid $0.60 today | 0.5 | 9 |
| **A new wallet, below $0.60 today** | **0.15** | **None** |

Absolute values remove this danger. Before, the rates were multipliers. Three
multipliers together gave 0.2 x 0.2 x 0.5 = **0.02**. Thus a new light player got
**2%** of the rewards on the first day.

The daily maximum is the only multiplier now. **Apply it one time, after you
select the rate. Do not multiply it with anything else.**

**Warning: do not check the last line of the table by memory.** The correct value
of **0.15** is also the value that the old multipliers gave from 0.5 x 0.3. Thus
the correct answer looks the same as the error that absolute values remove. A
multiplication of the **new** rates gives 0.5 x 0.15 = 0.075. Compare the result
with the stored value of `hopRewardBelowThreshold`. Refer to test 4g.

The new wallet maximum of 80 ROZ almost never operates. A new wallet must make
approximately 142 hops in one day before it operates.

### Rule 4 adds a person that you must trust

A verified flag needs a person or a server to approve each wallet. This is a new
privileged writer. It becomes a target when ROZ has a value. The flag is only as
good as the person who controls it.

## 6. Map size control

The players hide treasure in one round. The treasure becomes active in the next
round. Thus the system knows the number of treasures before the round starts.

The system calculates the map size with this formula:

```
Number of cells = T x 40 x K
```

- `T` is the number of treasures for the round.
- `40` is the target number of hops for each find.
- `K` is the search inefficiency factor. The first range is 1.8 to 2.5.

The map side increases with the square root of T:

| T | K = 1.8 | K = 2.0 | K = 2.5 |
|---|---|---|---|
| 10 | 27 x 27 | 29 x 29 | 32 x 32 |
| 100 | 85 x 85 | 90 x 90 | 100 x 100 |
| 196 | 119 x 119 | 126 x 126 | 140 x 140 |
| 500 | 190 x 190 | 200 x 200 | 224 x 224 |
| 1000 | 269 x 269 | 283 x 283 | 317 x 317 |

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
| `hopRewardBelowThreshold` | 0.15 ROZ | `150000000000000000` |
| `participationBelowThreshold` | 0 ROZ | `0` |
| `hopRewardNewWallet` | 0.5 ROZ | `500000000000000000` |
| `participationNewWallet` | 9 ROZ | `9000000000000000000` |
| `newWalletSoftCapRoz` | 80 ROZ | `80000000000000000000` |
| `dailySoftCapRoz` | 100 ROZ | `100000000000000000000` |

The values 0.15 and 0.5 are exact in 18 decimals. Thus there is no rounding
problem. Do not use fractions for these rates. Absolute values stop the danger in
section 5.2 rule 2.

**`hopRewardBelowThreshold` is the most important of these values, and not only
against the farmers.** Each day starts at zero payment. Thus it is the rate that
**each** wallet gets for the first hops of the day. Refer to section 4. It
controls the wallets that pay nothing and the start of each correct player's day
at the same time.

Two counters record the payments:

- `player_spend_today` - starts again each day.
- `player_lifetime_spend` - never starts again.

**Add to these two counters only when the player cannot get the money back.**
Add the hop fees, the spawn fees, and the 12,833 units from each claim. Do not
add the hide stake. Do not add a free hop.

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

### 7.6 Bulk hiding

A player can hide many treasures in one transaction. The player sends an amount
that divides exactly by the hide price. $1,000 gives 200 treasures.

**The contract does not need a loop.** The shares are a number. Thus the contract
does two storage writes and one transfer, for any quantity.

The contract must not compare the quantity with the map size. The map for the
next round does not exist yet. The map size reads as 0. Thus each bulk hide fails.
Use a maximum number of treasures for each round instead.

**You must also change the claim calculation.** The contract subtracts the fees
one time for each claim. For 200 shares in one claim, this is 200 times less than
200 separate claims. Change the calculation to subtract the fees for each share.
The result for one share does not change.

**Make this change at the same time as bulk hiding.** Section 9.2 shows why. In a
busy game the farmer loses the $5 stakes, and the deduction is a small part of the
cost. In a quiet round the finders take almost nothing, the stakes come back, and
**the deduction is the only cost that stays**. Thus without this change the cost
to take all the Year 1 tokens by hiding falls from $375 each day to approximately
**$1.88** each day. The change is least important for the safe condition and most
important for the dangerous one.

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

**This needs a guard.** The ROZ that the players earned is not yours. When the
function sweeps ROZ, it must release only the surplus. If it does not, the
coverage rule in 7.3 fails.

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

**Starknet gas is also a control.** Measure it.

**But the gate does not operate on each route.** Section 9.2 gives the route that
no control in this plan reaches.

### 9.2 The hide loop

A hider pays $5. If a finder does not take the treasure, the hider gets $4.99
back. Thus the cost is $0.0128 for 80 ROZ. This is profitable if ROZ costs more
than **$0.00016**.

**But $0.00016 is the minimum, not the usual cost.** That value is correct only
when no finder takes the treasure. This part gives the true cost.

**No control in this plan operates on a hide.** This is the important point. The
two tables in section 5.2 give the same values for the hide rewards, above the
limit and below it:

| Reward | Below $0.60 | $0.60 or more | A new wallet |
|---|---|---|---|
| Each hop | 0.15 | 1.0 | 0.5 |
| Participation | None | 18 | 9 |
| **Instant hide** | **Full** | **Full** | **Full** |
| **The treasure is not found** | **Full** | **Full** | **Full** |
| **Find or steal** | **Full** | **Full** | **Full** |

Rule 1 in section 5.2 also says that the hide stake is not a payment. This is
correct, because the player gets it back. Thus a hide does not get through the
gate, and the gate does not decrease a hide. The prices in section 5.1, the two
payment limits, the daily maximums and the free allowance all operate on hops and
participation. **No control operates on a hide.**

**The cost depends on the number of treasures that the finders take.** A hide
gives 30 ROZ always. It gives 50 ROZ more only when no finder takes it. When a
finder takes it, the finder also takes the $5.

To take all the Year 1 tokens, a farmer needs approximately **29,281 hides each
day**. This is approximately **7,320 hides in each round**. More hides do not make
the treasures more difficult to find: section 6 makes the map `T x 40 x K` cells,
thus the density stays the same.

| Finds by the correct players, in each round | Treasures taken | Cost for each ROZ | Cost each day | Profitable above |
|---|---|---|---|---|
| ~1,875 - a busy game, ~5,000 players each day | 25.6% | **$0.0192** | $45,000 | **$96M** |
| ~500 | 6.8% | $0.00461 | $10,800 | $23M |
| ~100 - a quiet round | 1.4% | $0.00102 | $2,390 | $5.1M |
| 0 - a round with no players | 0% | **$0.00016** | $375 | **$0.8M** |

**Read the first line first.** In a busy game the hide loop costs $96M, and the
hop route costs $107M. The two are approximately equal. The hide loop is **not**
134 times less expensive in a busy game. The value of 134 times compares the last
line with the hop route. That line is a round with no players.

**The danger is the time, not the quantity.** The farmer does not need a game with
no players. The farmer needs some quiet rounds, and hides in those rounds only. A
round is 6 hours, thus there will be quiet rounds. Nothing stops a farmer who
selects them. The cost changes by 120 times between a busy round and a quiet
round, and the farmer selects which one.

**Gas does not control this route.** Sections 5.1 and 9.1 say that gas is the real
control. `hide_treasure_bulk` removes it: 200 treasures in one transaction, for
almost the gas of one hide.

| | The hop route | The hide route |
|---|---|---|
| Transactions to take all the Year 1 tokens | ~5.3 million each day | **~147 each day** |
| Cost | $50,371 each day | $375 to $45,000 each day |
| Money necessary | None | $146,405, and the farmer **gets it back** |

This is approximately **36,000 times fewer transactions**. It is true for each
line of the table above.

**Two controls can stop this, and you have not made either one:**

- **The deduction for each treasure (section 7.6).** Without it, the contract
  takes the 12,833 units one time for each *claim*, not for each treasure. Thus a
  farmer who claims in bulk pays approximately **$1.88 each day** and not $375.
  This is the quiet round, where the deduction is the **only** cost that stays.
- **`maxTreasuresPerRound`.** This value stops a farmer who puts 7,320 treasures
  in one round. The value is in the contract, but section 11 says that you cannot
  select it until you select the map size limits. **Thus the one control for this
  route has no value in it.**

Section 4 also gives this route to the light casual player. Thus the cheapest farm
route and the correct route for the lightest player are the same action.

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

You cannot do this by hand. You must use a server, or add a function with no
arguments.

### 9.5 "Free" is not free

The player pays Starknet gas for each action. The game does not pay this. Thus
write "no game fee" and not "free" until the paymaster operates.

## 10. Tests

1. `scarb build` gives no errors. The build makes three contract classes.
2. The token gives `ROZ`, `18` and `5000000000000000000000000000`.
3. A hide adds exactly 30 ROZ to the balance. No ROZ moves.
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
4e. **A wallet that only hides gets no payment credit.** The payment totals stay
   at zero, for any quantity of stake. This is the most important test for the
   gate. If the stake is a payment, a farmer gets more than the $3 limit for
   $0.0128. This is 234 times less expensive.
4e-i. **A free hop gives no payment credit.** After 22 free hops, the two payment
   totals are still zero. Thus free play alone can never get to the limit.
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
8. A bulk hide of $1,000 gives 200 shares. The gas is almost the same as one hide.
9. A claim for 1 share pays `4987167`. A claim for 10 shares pays `49871670`.
10. The total of the balances is never more than the ROZ that the contract holds.

## 11. Decisions that you must make

1. **How do you start each round?** A server, or a new function. This is the most
   urgent decision.
2. **What are the map size limits?** You cannot set the maximum number of
   treasures until you know them.
3. **What is the first value of K?** A wrong value needs many rounds to correct.
4. ~~**Does the hop reward limit agree with the map size formula?**~~ **Corrected.**
   The formula targets 35 to 45 hops for each find. The reward limit is 40 now.
   But refer to decision 13: the daily maximum can still stop these rewards.
5. **Is 4,700 to 16,700 players each day correct for Year 1?** The first targets
   gave 4,000 to 13,000. The new targets in section 4 give more.
6. **Does the per-hop reward stay at 1 in year 2?** The calculation gives 0.74.
7. **Must the game have a retention reward?** The daily reward operated when a
   player made a spawn. A spawn gives no ROZ now, thus the daily reward and the
   streak bonus do not operate. You can accept this. Or you can give the reward
   for the first hop of each day. The first hop keeps the spawn free of rewards,
   as you decided.
8. **No player gets the target reward. This decision is open again.** The targets
   are 25 to 70, 140 to 280, and 300 to 500 now. You made these targets with the
   older values, which gave the full rate to all the hops. Section 5.2 does not
   permit this. With the correction, the light casual player gets **6**, the
   typical casual player gets **114.1**, and the active player gets **285.9**. All
   three are below their minimums again. The correction is the larger cause: it
   removes 37.8 ROZ and 41.3 ROZ. The rate of 0.15 removes 8.1 ROZ and 8.8 ROZ
   more. You can decrease the targets a second time, increase
   `hopRewardBelowThreshold`, or decrease `dailySpendThreshold` so that the players
   get through the gate sooner. Only the last one helps the light casual player,
   and it is also the one that makes the gate weaker.
12. **The light casual player is the furthest below the target.** This player pays
    $0.265 each day. The limit is $0.60. Thus the player gets 6 ROZ and not 58.
    The target is 25 to 70. A light casual player and a small farmer pay the same
    amount, thus the gate cannot see the difference. The change from $0.50 to
    $0.60 moved this player further from the limit. You can accept this, because
    one instant hide gives 36 ROZ (refer to decision 19). Or you can decrease the
    limit, increase `hopRewardBelowThreshold` above 0.15, give a small
    participation bonus below the limit instead of no bonus, or give new players
    some free days.
15. **Is $3 the correct total payment limit?** $3 gives a cost of $245,712 one
    time. $5 gives $409,520. Thus $3 gives approximately one half of the control.
    The two values increased with the corrected number of wallets, but the ratio
    did not change: the cost is still 4.9 days of the daily cost. The daily limit
    decides where the light casual player stops. The total limit decides the cost
    for a farmer.
16. **Is rule 4 correct?** A verified flag needs a person that you trust. This
    person becomes a target when ROZ has a value.
17. **Rule 3 decreases the rewards only for the players who pay.** A light casual
    player is already at the minimum from rule 1. Confirm that this is correct.
18. **Must the contract calculate the day again when a player gets to $0.60?**
    The plan says no. The rates operate from that moment only.

    **This is not a small decision now.** It is worth approximately 55 ROZ each
    day to the cheapest farm wallet - the difference between 28.6 and 83. It is
    worth 37.8 ROZ to the typical casual player. It is the largest control in the
    gate, larger than the $0.60 limit. All the values in this plan use it. If you
    change it, the farm cost goes back to $0.00741 for each ROZ, which is a market
    value of $37M. But all three players also go back into their targets. The two
    effects are large, and they operate against each other.
13. **What is the value of the daily maximum reward?** Use a value near 100. A
    wallet can get 136.35 ROZ on the usual route, and 178 ROZ only if it gets
    through the gate before it hops. Thus 150 to 160 almost never operates. But an
    active player gets only 95.85 ROZ, thus a maximum of 100 also almost never
    operates. Refer to decision 4: the daily maximum and the 40-hop maximum operate
    against each other, and neither one gets to the correct player.
14. **How much does Starknet gas cost for each transaction?** If the gas is more
    than the game fees, the gas is the real control. Measure this before you
    change the prices again.
9. **Is a hide fully free?** The contract keeps $0.0128 at each claim.
10. **Can a round stop early when the players find all the treasures?**
11. **Must the sweep function protect the USDC that players can claim?**
19. **A player below the gate must hide to get the target.** Hops give a maximum
    of 9.6 ROZ below the gate. This is 64 hops for $0.595, which is the maximum
    payment below $0.60. Thus hops alone cannot get to the minimum of 25, and the
    rate of 0.15 moved this further away. Only an instant hide (30) can, because
    the gate does not decrease the hide rewards. One instant hide moves the light
    casual player to 36 ROZ. But section 9.2 shows that the hide loop is also the
    cheapest route for a farmer in a quiet round ($0.00016 for each ROZ). Thus the
    lightest players use the route that no control reaches. Confirm that this is
    correct. Or increase `hopRewardBelowThreshold`, so that hops alone can get to
    25. Note that decision 22 operates on the same action.
20. **The rewards change with the order of the actions.** The payments increase in
    the order of the actions. Thus a player who makes a spawn at the start of a
    round gets through the gate sooner, and earns more, than a player who makes the
    same actions in a different order. All the values in this plan put the spawns
    first. The effect is small, and the player cannot see it. You can accept it, or
    you can select the rate for the day one time at a fixed moment.
21. **The participation bonus needs the two conditions at each hop.** If the
    contract gives the bonus at hop 28 only, a player who gets to 28 hops before
    $0.60 never gets the bonus. The typical casual player does this, at $0.145.
    That is 18 ROZ, and nothing shows the error. This is a rule and not a question,
    but a contract is easy to write the other way.
22. **How do you control the hide loop?** No control in this plan operates on a
    hide. Refer to section 9.2. In a busy game this is acceptable: the cost is
    $0.0192 for each ROZ, and the hop route costs $0.0215. In a quiet round the
    cost falls to $0.00016, which is a market value of $0.8M. A farmer selects the
    quiet rounds. You have two controls, and you have made neither one:
    - Select a value for `maxTreasuresPerRound`. Refer to decision 2 - you need the
      map size limits first. A farmer needs 7,320 hides in one round to take all
      the Year 1 tokens, and this value is the only control that can refuse them.
    - Make the deduction operate for each treasure, at the same time as bulk
      hiding. Refer to section 7.6.

    Be careful: decision 19 gives the same action to the light casual player. A
    control on the hide loop also operates on that player.
