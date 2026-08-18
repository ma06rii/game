

1. **How do you start each round?** A server, or a new function. This is the most urgent decision.

I plan to use aws eventbridge as the trigger every 6 hours and an aws lambda function which will start the new game round 

2. **What are the map size limits?** You cannot set the maximum number of treasures until you know them.  
   

Make the maximum number of treasures to be hidden 2,840. But make a setter function for this number; so that it can be changed in the future by the contract owner if needed.

3. **What is the first value of K?** A wrong value needs many rounds to correct.  
   

The initial value of K will be 2.2; but this may change when it is known what the first number of treasures hidden will be. This is most likely to be known closer to launch of the game.

4. **~~Does the hop reward limit agree with the map size formula?~~** **Corrected.** The formula targets 35 to 45 hops for each find. The reward limit is 40 now. But refer to decision 13: the daily maximum can still stop these rewards.  
     
5. **Is 4,700 to 16,700 players each day correct for Year 1?** The first targets gave 4,000 to 13,000. The new targets in section 4 give more.

This will be unknown util the game is actually launch and we see what the response will be like from the public.

6. **Does the per-hop reward stay at 1 in year 2?** The calculation gives 0.74.

The per hop reward will reduce proportionally to the amount of total reward tokens available in the tranche for that year. 

7. **Must the game have a retention reward?** The daily reward operated when a player made a spawn. A spawn gives no ROZ now, thus the daily reward and the streak bonus do not operate. You can accept this. Or you can give the reward for the first hop of each day. The first hop keeps the spawn free of rewards, as you decided.  
   

I accept this as it is 

8. **No player gets the target reward. This decision is open again.** The targets are 25 to 70, 140 to 280, and 300 to 500 now. You made these targets with the older values, which gave the full rate to all the hops. Section 5.2 does not permit this. With the correction, the light casual player gets **6**, the typical casual player gets **117.5**, and the active player gets **285.9**. The light casual player with 2 hides gets approximately 54, which is in the target. The other two are below their minimums. The correction is the larger cause: it removes 37.8 ROZ and 41.3 ROZ. The hop rate of 0.15 removes 8.1 ROZ and 8.8 ROZ more. The hide changes in section 5 give 3.4 ROZ back to the typical casual player. You can decrease the targets a second time, increase `hopRewardBelowThreshold`, or decrease `dailySpendThreshold` so that the players get through the gate sooner. Only the last one helps the light casual player, and it is also the one that makes the gate weaker.

I accept this as is. 

9. **The light casual player is the furthest below the target, and the middle is a trap.** This player pays $0.265 each day. The limit is $0.60. Thus the player gets 6 ROZ and not 58\. The target is 25 to 70\. A light casual player and a small farmer pay the same amount, thus the gate cannot see the difference. The change from $0.50 to $0.60 moved this player further from the limit. **Two hides give approximately 54 ROZ, and 2 hides with 42 hops give 30.3 ROZ below the gate. But one hide gives only 18 ROZ** \- less than both. A player who hides one time and stops is in the worst position, and nothing tells them this. You can accept this and put it in the display. Or you can decrease the limit, increase `hopRewardBelowThreshold` above 0.15, give a small participation bonus below the limit instead of no bonus, or give new players some free days.

I accept this as is. 

10. **Is $3 the correct total payment limit?** $3 gives a cost of $245,712 one time. $5 gives $409,520. Thus $3 gives approximately one half of the control. The two values increased with the corrected number of wallets, but the ratio did not change: the cost is still 4.9 days of the daily cost. The daily limit decides where the light casual player stops. The total limit decides the cost for a farmer.

I accept this as is. 

11. **Is rule 4 correct?** A verified flag needs a person that you trust. This person becomes a target when ROZ has a value.

No, remove rule 4 and the subsequent requirement to add a list of approved addresses.

12. **Rule 3 decreases the rewards only for the players who pay.** A light casual player is already at the minimum from rule 1\. Confirm that this is correct.  
    

Yes, this is correct.

13. **Must the contract calculate the day again when a player gets to $0.60?** The plan says no. The rates operate from that moment only.  
      
    **This is not a small decision now.** It is worth approximately 55 ROZ each day to the cheapest farm wallet \- the difference between 28.6 and 83\. It is worth 37.8 ROZ to the typical casual player. It is the largest control in the gate, larger than the $0.60 limit. All the values in this plan use it. If you change it, the farm cost goes back to $0.00741 for each ROZ, which is a market value of $37M. But all three players also go back into their targets. The two effects are large, and they operate against each other.  
    

No. The rates operate from that moment only.

14. **What is the value of the daily maximum reward?** Use a value near 100\. A wallet can get 136.35 ROZ on the usual route, and 178 ROZ only if it gets through the gate before it hops. Thus 150 to 160 almost never operates. But an active player gets only 95.85 ROZ, thus a maximum of 100 also almost never operates. Refer to decision 4: the daily maximum and the 40-hop maximum operate against each other, and neither one gets to the correct player.  
    

The value of the daily maximum reward should be 136\.

15. **How much does Starknet gas cost for each transaction?** If the gas is more than the game fees, the gas is the real control. Measure this before you change the prices again.

Starknet transaction (gas) fees currently average roughly $0.025–$0.04 USD per transaction, with meaningful variation by complexity.

16. **Is a hide fully free?** No \- a hide costs $0.20 now. The contract also keeps $0.0128 at each claim. Thus a hide that survives costs $0.2128.

No, a hide is not fully free.

17. **Can a round stop early when the players find all the treasures?**

Yes

18. **Must the sweep function protect the USDC that players can claim?**

Yes

19. **A player below the gate must hide to get the target.** Hops give a maximum of 9.6 ROZ below the gate. This is 64 hops for $0.595, which is the maximum payment below $0.60. Thus hops alone cannot get to the minimum of 25\. Hides can, in two directions: 2 hides and 42 hops give 30.3 ROZ below the gate, and the same 2 hides move the player through the gate to approximately 54 ROZ. One hide gives 18 ROZ and gets to neither. Confirm that "a light casual player must hide" is the correct shape for the target. Or increase `hopRewardBelowThreshold`, so that hops alone can get to 25\. Note that decision 22 operates on the same action.

Yes,"a light casual player must hide" is the correct shape for the target.

20. **The rewards change with the order of the actions.** The payments increase in the order of the actions. Thus a player who makes a spawn at the start of a round gets through the gate sooner, and earns more. Since section 5 this is much larger: **a typical casual player gets 117.5 ROZ with a round-3 hide, and 50.35 ROZ with a round-2 hide.** A hide before the gate gives 12 and not 80, and section 7.1a makes this permanent. This is 67 ROZ from the order only, and the player cannot see it. You can put a message in the display ("hide after you pay $0.60"). Or you can select the rate for the day one time at a fixed moment.

Yes, put a message in the display ("hide after you pay $0.60").

21. **The participation bonus needs the two conditions at each hop.** If the contract gives the bonus at hop 28 only, a player who gets to 28 hops before $0.60 never gets the bonus. The typical casual player does this, at $0.145. That is 18 ROZ, and nothing shows the error. This is a rule and not a question, but a contract is easy to write the other way.

Write the contract in a way that still follows the rule; but allows the player to get the bonus, after they meet the minimum spend threshold.

22. **~~How do you control the hide loop?~~** **Controlled** (sections 5, 5.2, 7.6). The gate operates on the hide rewards, a $0.20 fee applies, and the maximum is 3 treasures for each wallet each day. Find or steal stays at 110 for all the players, and this is intentional. The minimum for the route moves from **$0.8M to $22.8M**, and the transactions move from \~147 each day to \~500,000. Two smaller controls remain:  
      
    - Select a value for `maxTreasuresPerRound`. Refer to decision 2 \- you need the map size limits first. This is a second control now, not the only one. It stops the **total**: 15,616 wallets with 3 hides each still put 46,848 treasures in a day.  
    - Make the deduction operate for each treasure, at the same time as bulk hiding. Refer to section 7.6. The error is 3 times now, and it was 200 times.

    

    Be careful: decision 19 gives the same action to the light casual player. A new control on the hide loop also operates on that player.

    

    maxTreasuresPerRound should be 2,840

    Yes, make the deduction operate for each treasure, at the same time as bulk hiding.

    

    

    

23. **Do you still want bulk hiding?** The maximum of 3 counts treasures, thus `hide_treasure_bulk(1000000000)` \- the $1,000 call that gave 200 treasures \- fails now. The function stays, and it still saves two of the three transactions for a player who hides the daily maximum. But the use that it was made for is gone, and one wallet cannot make the 126 x 126 map in section 6\. Confirm that nobody needs this. If a company must fill a map for an event, you can add a list of approved addresses \- but that is a new person that you must trust, with the same problem as rule 4 \- or a separate function that gives no ROZ.  
    

Yes, I want to keep the bulk hiding. Please see specification below as follows : \- 

**Hide Treasure Rules – Final Specification**

### General Hide Rules (Applies to All Players)

| Parameter | Value | Notes |
| :---- | :---- | :---- |
| Treasure value | $5 USDC | Fixed stake per treasure |
| Single hide | Available to everyone | Creates 1 treasure |
| Instant Hide ROZ | Base × multipliers | See Section 2 |
| Hide Survives ROZ | Base × multipliers | See Section 2 |
| Find / Steal rewards | Always full | Never reduced |
| Stake return | Full $5 if treasure is unfound | Always |

**Non-refundable Fee (Tiered)**

| Treasures already hidden today | Fee per new treasure |
| :---- | :---- |
| 0 – 2 (first 3 of the day) | **$0.20** |
| 3 or more | **$0.25** |

---

### 2\. Reward Multipliers

Final ROZ \= Base ROZ × Bulk Multiplier × Wallet Rate

**Wallet Rate**

| Wallet Status | Rate |
| :---- | :---- |
| Established \+ met $0.60 daily spend | 1.00× |
| Established but below $0.60 daily spend | 0.15× |
| New Wallet (lifetime spend \< $3) | 0.50× |

**Bulk Size Multiplier (Extreme Curve)**

| Treasures in the transaction | Multiplier |
| :---- | :---- |
| 1 | 1.00× |
| 2 | 0.90× |
| 3 | 0.75× |
| 4 | 0.55× |
| 5 | 0.40× |
| 6 | 0.28× |
| 7 | 0.18× |
| 8 | 0.12× |
| 9–10 | 0.05–0.08× |
| 11+ | ≤ 0.03× |

---

### 3\. Bulk Hiding

**Access**

- All addresses can call the bulk hide function.

**Limits by Address Type**

| Address Type | Max treasures per bulk transaction | Daily treasure cap |
| :---- | :---- | :---- |
| Non-whitelisted | Remaining daily allowance (max 10\) | **10 per day** |
| Whitelisted | Unlimited | **No daily limit** |

**Whitelist Control**

- Only the contract owner can add or remove addresses from the bulk whitelist.

**Features that affect Bulk Hiding**

- Tiered non-refundable fee ($0.20 for the first 3 treasures of the day, $0.25 thereafter) applies to every treasure created in the bulk.  
- Extreme Bulk Size Multiplier applies to the entire bulk transaction.  
- Wallet Rate (New Wallet / Minimum Spend) still applies.  
- Each treasure created in a bulk is fully independent for the purposes of being found or surviving.  
- Daily treasure count (for non-whitelisted addresses) includes all treasures created via single hide and bulk hide.

---

### 4\. Design Intent

- Ordinary players can use bulk hide but remain strictly limited to 10 treasures per day.  
- Whitelisted addresses can perform large bulk hides with no daily cap.  
- The combination of tiered fee, extreme bulk multiplier, and wallet rate multipliers makes large-scale or repeated bulk hiding expensive and low-yielding.  
- Find/Steal rewards stay fully protected for all players.

---

**End of Specification**

---

**Whitelist Implementation Overview**

### Goal

Implement a Merkle-tree based whitelist for bulk treasure hiding on Starknet (Cairo).

- All addresses can call the bulk hide function.  
- **Non-whitelisted** addresses are limited to a maximum of **10 treasures per day**.  
- **Whitelisted** addresses have **no daily limit**.  
- The whitelist is managed by storing only a Merkle root on-chain.  
- Only the contract owner can update the Merkle root.  
- Users prove membership by submitting a Merkle proof \+ index.

---

### 1\. On-Chain Storage (Cairo)

struct Storage {

    // ... other storage ...

    whitelist\_merkle\_root: felt252,   // current Merkle root

    owner: ContractAddress,

}

Only the owner can update the root:

fn set\_whitelist\_merkle\_root(ref self: ContractState, new\_root: felt252) {

    self.only\_owner();

    self.whitelist\_merkle\_root.write(new\_root);

}

---

### 2\. Merkle Verification Function (Proof \+ Index style)

use core::poseidon::PoseidonTrait;

use core::hash::{HashStateTrait, HashStateExTrait};

fn verify\_merkle\_proof(

    leaf: felt252,

    proof: Span\<felt252\>,

    root: felt252,

    mut index: u32

) \-\> bool {

    let mut computed\_hash \= leaf;

    let mut i: u32 \= 0;

    let proof\_len \= proof.len();

    while i \< proof\_len {

        let sibling \= \*proof.at(i);

        if index % 2 \== 0 {

            // Current node is left child

            computed\_hash \= PoseidonTrait::new()

                .update(computed\_hash)

                .update(sibling)

                .finalize();

        } else {

            // Current node is right child

            computed\_hash \= PoseidonTrait::new()

                .update(sibling)

                .update(computed\_hash)

                .finalize();

        }

        index \= index / 2;

        i \+= 1;

    };

    computed\_hash \== root

}

---

### 3\. How Bulk Hide Uses the Whitelist

Inside the `hide_treasure_bulk` function:

let caller \= get\_caller\_address();

let root \= self.whitelist\_merkle\_root.read();

let leaf: felt252 \= caller.into();

let is\_whitelisted \= verify\_merkle\_proof(

    leaf,

    merkle\_proof,    // provided by user

    root,

    leaf\_index       // provided by user

);

if is\_whitelisted {

    // No daily limit

} else {

    // Enforce daily limit of 10 treasures

    // Check remaining allowance for the day

}

---

### 4\. Off-Chain Merkle Tree Generation (JavaScript)

**Recommended library:** `starknet-merkle-tree`

npm install starknet-merkle-tree

**Example script:**

import \* as Merkle from "starknet-merkle-tree";

import fs from "fs";

const whitelistedAddresses \= \[

  "0x123...",

  "0x456...",

  // more addresses

\];

const leaves \= whitelistedAddresses.map(addr \=\> \[addr\]);

const tree \= Merkle.StarknetMerkleTree.create(

  leaves,

  Merkle.HashType.Poseidon

);

console.log("Merkle Root:", tree.root);

// Generate proofs

const proofs \= {};

whitelistedAddresses.forEach((address, index) \=\> {

  proofs\[address\] \= {

    index: index,

    proof: tree.getProof(index)

  };

});

// Save files

fs.writeFileSync("whitelist-root.json", JSON.stringify({ root: tree.root }, null, 2));

fs.writeFileSync("whitelist-proofs.json", JSON.stringify(proofs, null, 2));

---

### 5\. Frontend / Backend Flow

1. Owner generates the tree off-chain and calls `set_whitelist_merkle_root(root)`.  
2. Backend stores the `whitelist-proofs.json` file (or serves proofs from a database).  
3. When a user wants to bulk hide:  
   - Frontend requests the proof \+ index for the user’s address.  
   - User calls `hide_treasure_bulk` with the proof and index.  
4. Contract verifies the proof against the stored root.

---

### 6\. Key Rules Summary

| Address Type | Can use bulk hide? | Daily treasure limit | Max per bulk transaction |
| :---- | :---- | :---- | :---- |
| Non-whitelisted | Yes | 10 | Remaining daily allowance (max 10\) |
| Whitelisted | Yes | No limit | Unlimited |

- Extreme Bulk Size Multiplier still applies to everyone.  
- Tiered non-refundable fee ($0.20 for first 3 of the day, $0.25 afterwards) still applies to everyone.  
- Wallet rate multipliers (New Wallet / Minimum Spend) still apply.

---

### 7\. Security Notes

- Only the owner can change the Merkle root.  
- Always use Poseidon hash for consistency with the verification function above.  
- Make sure the leaf value is simply the address converted to `felt252`.  
- The index used in the proof must match the index used when generating the tree.

---

This document contains everything needed to implement the whitelist system.

24. **Three settings operate together, and nothing protects the relation.** `dailyHideCap` x `hideFee` \= `dailySpendThreshold`, which is 3 x $0.20 \= $0.60. This makes the maximum number of hides get through the gate exactly. The owner can change all three, and they are independent. `hideFee` at $0.25 lets two hides get through the gate. `dailyHideCap` at 2 stops hides from getting through at all. Put a test in the set functions, or write the relation next to them and accept the danger.

Yes, put a test in the set function.