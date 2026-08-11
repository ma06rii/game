# Claim Function - Report in Simplified Technical English

This report gives the same information as `CLAIM_FUNCTIONALITY_ASSESSMENT.md`.
This report uses the ASD-STE100 writing rules.

The writing rules are:

- Short sentences. Each sentence has one instruction or one idea.
- The active voice.
- Simple verb tenses.
- One meaning for each word. One word for each meaning.
- Vertical lists and tables for complex information.

The technical names do not change. Examples of technical names are
`claim_reward`, `get_game_week`, `start_new_game`, and the contract addresses.

---

## 1. Introduction

This report tells you about the claim function of the game contract. The claim
function does not operate. This report tells you why it does not operate. It
also tells you what you must do.

All the data in this report is correct. I read the contract code. I also read
the values from the network.

## 2. The condition of the contract

The contract address is
`0x0407390e9074fab2526d2cca38ed6922bcde406ccc0993809bc0e0b327c1e2e0`.

The contract is correct. These values are correct:

- The game token is USDC.
- The VRF provider is the mock provider.
- The hider fee is 5000000 units. This is $5.00.
- The spawn fee is 1000000 units. This is $1.00.
- The minimum allowance is 7000000 units. This is $7.00.

The contract holds 11800000 USDC units. This is $11.80. Thus the contract has
sufficient money to pay the rewards.

**The game week is 0.** This value is the cause of the first problem.

## 3. Why the claim function does not operate

There are two problems. The two problems are independent. You must correct both
problems.

### 3.1 Problem 1 - the game week is 0

The `claim_reward` function has one condition. The game week that the player
claims must be less than the current game week.

The current game week is 0. The game week is an unsigned number. No unsigned
number is less than 0. Thus the condition is always false. Thus no player can
claim.

The `hide_treasure` function is also important here. This function adds the
shares to the subsequent week. Two players used `hide_treasure` in week 0. Thus
the contract holds their shares in week 1.

To claim the week 1 shares, the current game week must be 2 or more.

### 3.2 Problem 2 - the frontend has no claim code

The frontend does not have a claim function. The code is not there.

- The frontend does not call `claim_reward` at any location.
- The claim button is always disabled. The value is a constant.
- The button has no click function.
- The frontend has no data for a previous week. It has data for the current week
  and the subsequent week only.

## 4. How the contract calculates a reward

The contract calculates the reward with this formula:

```
reward = (shares x hider fee) - gas fee reservation - game master fee - game landowner fee
```

The contract subtracts the three fees one time for each claim. It does not
subtract the fees for each share. Two examples show the result:

| Condition | Reward |
|---|---|
| Two players, one share for each player | 4987167 units for each player |
| One player, two shares | 9987167 units for that player |

The contract holds sufficient USDC for the two conditions.

## 5. How to increase the game week

The `start_new_game` function increases the game week by 1. The function writes
six values:

- the current game week
- the three fee values
- the merkle root and the two fees for the new week
- the grid size for the new week
- the number of hiders for the new week
- the treasure total for the new week

The function does not change the shares of the players. Thus an increase of the
game week cannot cause a loss of a player reward.

### 5.1 Two dangers

**Danger 1.** The function writes over the number of hiders for the new week. It
does not add to the number. Week 1 holds the value 2 now. You must supply the
value 2 again. If you supply a different value, you lose the count. This error
occurred on the previous contract.

**Danger 2.** The three fee values are global. The reward calculation reads the
global hider fee. If you supply a different hider fee, the contract changes the
value of all the rewards that the players did not claim.

### 5.2 Procedure

1. Read the number of hiders for week 1.
2. Call `start_new_game`. Supply the value from step 1.
3. Read the number of hiders for week 2.
4. Call `start_new_game` again. Supply the value from step 3.
5. The players can now claim week 1.

**Note:** a u256 argument has two parts, the low part and the high part. For the
week 0 merkle root, the low part is `0x92fe3fb625937ab468940c4c58966849`. The
high part is `0xbc19a39ffdeb3ff487a290fd65626b95`.

**Note:** use the `--url` option with a 0.10 endpoint. Do not use the
`--network sepolia` option. That option gives the error `-32603`.

## 6. Problems in the contract

There are five problems in the contract. **No problem stops the claim function.**

| Problem | Result |
|---|---|
| There is no getter for the claimed rewards | The frontend cannot see that the contract paid a reward before. The claim then fails. |
| The reward calculation uses the current fee | If you change a fee, the contract changes the value of the old rewards. |
| The validate function reads the wrong merkle root | This is a problem only for a week in the past. |
| The contract does not send the GTR token | The frontend shows a GTR value. The claim function does not pay it. |
| The subtraction can go below zero | This is not possible with the fee values of today. |

If you correct these problems, you must make a new contract. A new contract has
these costs:

- A new declare costs approximately 41 STRK.
- The new contract starts at week 0.
- You lose the $11.80.
- You lose the two shares and all the player positions.

## 7. Frontend work

### 7.1 Code that you can use again

- The function `executeAndConfirm` sends a transaction and finds an error.
- The function `showTxError` shows an error to the player.
- The session policy permits `claim_reward` now. You do not have to change it.

### 7.2 Code that you must write

- a claim function
- data for a previous week
- an enabled button with a click function
- an indication that the contract paid the reward before (this needs the
  contract getter)

### 7.3 Old data

The frontend keeps old data. This causes errors after an increase of the game
week:

- The frontend reads the game week one time only, at the start.
- The Pusher event shows a message only. It does not read the new data.
- The WebSocket uses the game week from the start.
- One function hides its errors. It then shows the value 0.

## 8. Decisions that you must make

1. **The order of the work.** Do you write the frontend code first? Or do you
   make a new contract first?
2. **The contract corrections.** Which corrections do you put in the new
   contract?
3. **The GTR token.** Must the contract pay this token? Or is the value only an
   estimate?
4. **The finder rewards.** A server must call the validate function. Do you have
   a plan for this server?

## 9. Recommended procedure

1. Increase the game week two times. Use the procedure in section 5.2. This
   costs no money and breaks nothing.
2. Call `claim_reward` for week 1 from the account of the player. Do this before
   you write frontend code. If the contract pays 4987167 units, the contract is
   correct.
3. Write the frontend claim code. Use the current contract.
4. Put the contract corrections in the subsequent new contract.

Step 2 is important. It costs one transaction. It shows you clearly if the
problem is in the contract or in the frontend. All the work after step 2 is
frontend work. That work does not need a new contract.
