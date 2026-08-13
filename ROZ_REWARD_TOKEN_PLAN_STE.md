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
| Each hop | 1 | Maximum 32 hops in a round |

### One reward for each day

| Action | ROZ | Conditions |
|---|---|---|
| Participation | 18 | The player must make 30 hops. The game gives this reward one time each day |

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
3. Participation - less important. The player must make 30 of a maximum of 32
   hops. Thus this is difficult.
4. Each hop - a small reward for exploration.

There is no retention reward now.

### How many players Year 1 can pay

| Player type | ROZ each day |
|---|---|
| Light casual | 80 - 160 |
| Typical casual | 180 - 320 |
| Active | 350 - 550 |

Year 1 gives 2,342,466 ROZ each day. Thus Year 1 can pay approximately **4,000 to
13,000 players each day**. If the game has more players, the tokens for Year 1
stop early.

### No player type gets the target reward now

| Player | Rounds and hops | Payment | ROZ before the gate | **ROZ with the gate** | Target |
|---|---|---|---|---|---|
| Light casual | 2 rounds, 20 hops each | $0.275 | 40 | **11** | 80 - 160 |
| Typical casual | 2.5 rounds, 25 hops each | $0.665 | 142 | 160 | 180 - 320 |
| Active | 4 rounds, 32 hops each | $3.445 | 336 | 336 | 350 - 550 |

The gate in section 5.2 causes the difference between the two ROZ columns.

There are three causes:

1. The participation bonus needs 30 hops in one round. A light casual player
   makes 20 hops. Thus this player gets no bonus.
2. The daily reward of 12 to 22 ROZ does not operate now.
3. The participation bonus operates one time each day, not in each round. This
   removes 54 ROZ from the active player.

**No player gets the target.** The active player also pays more: the hop cost
increased from $1.38 to $3.145. The controls against the farmers also decrease
the rewards for the correct players. You must change the targets or the rewards.
Refer to section 11.

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
| `dailyFreeHops` | **20** | Each day. All 4 rounds use the same 20 hops |
| `participationMinimumHops` | **30** | Each day. The bonus operates one time each day |
| `hopRewardCap` | **32** | Each **round** |
| `dailyFreeSpawns` | **1** | Each day |

There is also a warning at approximately 28 hops. This warning is in the frontend
only. The contract does not use it.

**Two rules control the sequence of these values. Do not break these rules.**

1. `dailyFreeHops` (20) must be less than `participationMinimumHops` (30). This
   rule keeps a wallet with no cost at **20 ROZ each day**. If the allowance
   increases to more than 30 hops, the wallet earns **38 ROZ**. Refer to section
   9.3.
2. `participationMinimumHops` (30) must not be more than `hopRewardCap` (32).
   Thus the bonus needs 30 hops of a maximum of 32 hops. The bonus is difficult.

Thus the bonus costs 10 paid hops. This is $0.10. A player cannot get the bonus
for no money.

### The free allowance

Each player gets **20 free hops and 1 free spawn each day**. The allowance is for
the day, not for one round. The player can use it in any round.

| Player | Cost before | Cost after |
|---|---|---|
| Light casual | $0.50 | $0.20 |
| Typical casual | $0.90 | $0.60 |
| Active | $1.68 | $1.38 |

The allowance saves $0.30 each day for all the players.

**The allowance is less than one full round.** The maximum is 32 hops in a round.
The allowance is 20 hops. This is correct: the participation bonus needs 30 hops.
Thus a player cannot get the bonus with free hops only. The player must pay for
10 hops.

This one rule controls the wallets that pay nothing. Refer to section 9.3.

**A free action is the same as a paid action.** Only the USDC cost is different:

| Behaviour | A free hop | A free spawn |
|---|---|---|
| Does the action | Yes | Yes |
| Gives ROZ | Yes, 1 ROZ | No. A paid spawn also gives no ROZ |
| Counts for the 30-hop minimum | Yes | Not applicable |
| Counts for the 32-hop maximum | Yes | Not applicable |
| Costs USDC | No | No |

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
| 1 to 20 | Free |
| 21 to 25 | $0.005 |
| 26 to 45 | $0.010 |
| 46 to 65 | $0.020 |
| 66 and more | $0.040 |

**The count must go back to zero one time each day. It must not go back to zero
at the end of a round.** If the count goes back to zero in each round, a wallet
stays in the first tier. Then 128 hops cost $0.645 and not $3.145. Thus the
control does not operate.

### The effect of the new prices

| Hops in a day | New price | Old price | Result |
|---|---|---|---|
| 30 | $0.075 | $0.10 | Less |
| 45 | $0.225 | $0.25 | Less |
| 48 | $0.285 | $0.28 | More |
| 60 | $0.525 | $0.40 | More |
| 128 | $3.145 | $1.08 | More |

The change point is approximately 48 hops. Below this number the new prices are
less. Above this number the new prices are more. This is correct: a light player
pays less, and a player who makes many hops pays more.

### The daily maximum reward

When a wallet earns more than `dailySoftCapRoz` ROZ from hops and participation,
the game decreases the subsequent rewards. The multiplier is 0.2.

**Use a value near 100. Do not use 140 to 160.** The participation reward now
operates one time each day. Thus the maximum from hops and participation is
128 + 18 = 146 ROZ. A maximum of 150 or 160 is more than 146. Thus it never
operates.

### What these controls do, and what they do not do

**They operate against one large wallet:**

| | Before | After |
|---|---|---|
| Cost of a maximum day | $1.38 | **$3.445** |
| ROZ | 200 | **146** |
| Cost for each ROZ | $0.0069 | **$0.0236** |

The cost is 3.4 times more. This is correct.

**They do not operate against many small wallets.** A wallet that makes 30 hops
stays in the first two tiers. These tiers are less expensive than before:

| | Before | After |
|---|---|---|
| Cost for each wallet | $0.10 | **$0.075** |
| ROZ | 48 | 48 |
| Cost to take all the Year 1 tokens | $4,880 each day | **$3,660 each day** |

The new prices are more expensive for one large wallet. But they are less
expensive for many small wallets. A wallet costs nothing to make. Thus a farmer
uses more wallets.

**Starknet gas is the real control.** A wallet makes 31 transactions each day.
The game fees are $0.075. The gas is more than the fees. Thus the gas stops the
farmers more than the prices do. Measure the gas. Do not estimate it.

To control the many-wallet method you need a different rule. Section 5.2 gives
these rules.

## 5.2 The Lightweight Gate

Section 5.1 does not control the many small wallets. These four rules do. The
principle is simple: **a player who pays gets the full rewards. A player who pays
nothing can still play, but gets less.**

### The four rules

1. **A daily payment limit.** A wallet must pay $0.50 or more in one day to get
   the full hop and participation rewards. Below this value, the rewards
   decrease.
2. **The free hops and the free spawn stay for all the players.** A new player
   can start immediately. The player gets less ROZ until the player pays.
3. **A new wallet gets less ROZ** until the total payments of that wallet are
   more than $5.
4. **Optional: a bonus for a person.** A wallet with a social account can get a
   higher maximum or a small bonus.

### Rule 1 controls the many small wallets

A wallet gets to $0.50 after 54 hops and 1 paid spawn:

| | Without the gate | With the gate |
|---|---|---|
| Cost for each wallet | $0.075 | **$0.505** |
| ROZ | 48 | 72 |
| Cost for each ROZ | $0.00156 | **$0.00701** |
| Cost to take all the Year 1 tokens | $3,660 each day | **$16,430 each day** |

The cost is **4.5 times more**. This is the control that section 5.1 does not
give.

### Rule 3 is the strongest control

A total payment limit controls the number of wallets, not the actions of one
wallet. This is the correct target:

| Total payment limit | Cost to start 32,534 wallets |
|---|---|
| $1 | $32,534 |
| $2 | $65,068 |
| **$5** | **$162,670** |
| $10 | $325,340 |

At $5, a farmer pays $162,670 one time. The daily cost is $16,430. Thus rule 3 is
more effective than rule 1.

### The gate stops the light casual player

| Player | Hops | Payment each day | Gate | ROZ | Target |
|---|---|---|---|---|---|
| Light casual | 40 | $0.275 | **Less** | **11** | 80 - 160 |
| Typical casual | 62 | $0.665 | Full | 160 | 180 - 320 |
| Active | 128 | $3.445 | Full | 336 | 350 - 550 |

**A light casual player and a small farmer pay the same amount.** Thus the gate
cannot see the difference. It decreases the rewards for both.

11 ROZ is very much less than the target of 80 to 160. This player gets almost
nothing. Make this decision before the game operates. Refer to section 11.

### Two rules that you must obey

**1. The hide stake is not a payment.**

The $5 hide fee comes back to the player. A hider gets `4,987,167` of
`5,000,000`. Thus the true cost is $0.0128.

If the stake was a payment, a farmer makes one hide and gets more than the $5
limit for $0.0128. This is **391 times** less expensive. Thus rules 1 and 3 do
not operate.

**Only these are payments:** the hop fees, the spawn fees, and the 12,833 units
that the contract keeps at each claim.

**2. Do not multiply the decreases together.**

Three rules can decrease the same reward: the daily maximum (0.2), the daily
payment limit (0.2), and the new wallet (0.5).

| Method | Result |
|---|---|
| Multiply them together | 0.2 x 0.2 x 0.5 = **0.02**. The player gets **2%** |
| Use the lowest value only | **0.2**. The player gets 20% |

A new light player gets almost no ROZ on the first day if you multiply them.
**Use the lowest value only.**

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
- Replace `currentGameTokenReward` with six rates and two limits. Give each one a
  setter function. Without setters, you must deploy a new contract each year to
  change the rates.

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
is now $3.445 each day for 146 ROZ. This is profitable if ROZ costs more than
**$0.0236**. Before, the value was $0.0069. Thus the cost is 3.4 times more.

**Many small wallets.** The new prices in section 5.1 do not control this method.
They make it **less** expensive. A wallet that makes 30 hops pays $0.075 and
earns 48 ROZ. The cost to take all the Year 1 tokens is $3,660 each day.

**The gate in section 5.2 controls this method.** With the daily payment limit,
the same wallet must pay $0.505. The cost to take all the Year 1 tokens becomes
**$16,430 each day**. This is 4.5 times more. The total payment limit of $5 adds
$162,670 more, one time.

**Starknet gas is also a control.** Measure it.

### 9.2 The hide loop

A hider pays $5. If a finder does not take the treasure, the hider gets $4.99
back. Thus the real cost is $0.0128 for 80 ROZ. This is profitable if ROZ costs
more than **$0.00016**.

This is the cheapest method. It is cheapest in the rounds with few players.

### 9.3 Wallets that pay nothing

Free hops give ROZ. Thus a wallet can earn tokens with no USDC:

| Source | ROZ |
|---|---|
| 20 free hops | 20 |
| Participation bonus. This needs 30 hops. Only 20 are free | **0** |
| Spawn. A spawn gives no ROZ | 0 |
| **Total each day, with no cost** | **20** |

Approximately **117,000** wallets can take all the tokens for Year 1. These
wallets pay Starknet gas only.

**Two numbers control this danger.** The free allowance is 20 hops. The
participation bonus needs 30 hops. Thus a wallet cannot get the bonus for nothing.
The wallet must pay for 10 hops.

Obey this rule: **keep the free allowance less than the participation minimum.**
If the allowance increases to more than 30 hops, a wallet with no cost earns 38
ROZ and not 20.

This is better than before. Before, a wallet earned 48 ROZ, and 48,800 wallets
could take all the tokens. Now the game needs 2.4 times more wallets. No new code
was necessary. Only the order of two numbers changed.

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
4. Hop 30 gives the participation bonus one time. Hop 33 gives nothing.
4a. The participation bonus operates one time each day. Make 30 hops in round 1,
   then make 30 hops in round 2. The bonus does not operate a second time.
4b. **The hop price increases correctly.** Hop 21 costs `5000`. Hop 26 costs
   `10000`. Hop 46 costs `20000`. Hop 66 costs `40000`. **Hop 33 is the first hop
   of round 2. It must not cost `5000`.** The count must not go back to zero at
   the end of a round. This is the most important test for the farm controls.
4c. When the daily ROZ is more than the maximum, the subsequent rewards decrease.
4d. A wallet that paid $0.49 gets 0.2 ROZ for a hop. A wallet that paid $0.50
   gets 1 ROZ.
4e. **A wallet that only hides gets no payment credit.** The payment totals stay
   at zero, for any quantity of stake. This is the most important test for the
   gate. If the stake is a payment, a farmer gets more than the $5 limit for
   $0.0128.
4f. A new wallet with a total payment of less than $5 gets 0.5 ROZ for a hop,
   also when the wallet paid more than $0.50 that day.
4g. **The decreases do not multiply.** When all three decreases are applicable,
   the multiplier is **0.2 and not 0.02**.
5. A spawn gives 0 ROZ. This is correct for a free spawn and a paid spawn.
6. **With no ROZ in the contract:** a hide, a move and a spawn all operate. The
   USDC claim pays in full. This is the most important test.
7. A wallet with no USDC and no approval can spawn one time and hop 20 times.
   The balance is 20 ROZ. **The participation bonus does not operate**, because
   20 hops is less than 30. This is the most important anti-farm test.
8. A bulk hide of $1,000 gives 200 shares. The gas is almost the same as one hide.
9. A claim for 1 share pays `4987167`. A claim for 10 shares pays `49871670`.
10. The total of the balances is never more than the ROZ that the contract holds.

## 11. Decisions that you must make

1. **How do you start each round?** A server, or a new function. This is the most
   urgent decision.
2. **What are the map size limits?** You cannot set the maximum number of
   treasures until you know them.
3. **What is the first value of K?** A wrong value needs many rounds to correct.
4. **Does the hop reward limit agree with the map size formula?** The formula
   targets 35 to 45 hops for each find. The reward stops at 32 hops.
5. **Is 4,000 to 13,000 players each day correct for Year 1?**
6. **Does the per-hop reward stay at 1 in year 2?** The calculation gives 0.74.
7. **Must the game have a retention reward?** The daily reward operated when a
   player made a spawn. A spawn gives no ROZ now, thus the daily reward and the
   streak bonus do not operate. You can accept this. Or you can give the reward
   for the first hop of each day. The first hop keeps the spawn free of rewards,
   as you decided.
8. **No player gets the target reward.** A light casual player gets 40 ROZ, and
   the target is 80 to 160. An active player gets 336 ROZ, and the target is 350
   to 550. The active player also pays $3.145 and not $1.38. You can decrease the
   participation minimum, increase the hop reward, add a retention reward, or
   change the targets.
12. **The gate stops the light casual player.** This player pays $0.275 each day.
    The limit is $0.50. Thus the player gets 11 ROZ and not 40. The target is 80
    to 160. A light casual player and a small farmer pay the same amount, thus
    the gate cannot see the difference. You can decrease the limit, decrease the
    reward less than 0.2, or give new players some free days.
15. **What are the two payment limits?** $0.50 each day and $5 in total are
    examples. They are not calculated answers. The daily limit decides where the
    light casual player stops. The total limit decides the cost for a farmer.
16. **Is rule 4 correct?** A verified flag needs a person that you trust. This
    person becomes a target when ROZ has a value.
13. **What is the value of the daily maximum reward?** Use a value near 100. A
    value of 140 to 160 never operates.
14. **How much does Starknet gas cost for each transaction?** If the gas is more
    than the game fees, the gas is the real control. Measure this before you
    change the prices again.
9. **Is a hide fully free?** The contract keeps $0.0128 at each claim.
10. **Can a round stop early when the players find all the treasures?**
11. **Must the sweep function protect the USDC that players can claim?**
