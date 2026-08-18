**Hide Treasure Rules – Final Specification**  
*(Updated with Daily Volume Multiplier)*

### 1. General Hide Rules (Applies to All Players)

| Parameter                  | Value                              | Notes |
|----------------------------|------------------------------------|-------|
| Treasure value             | $5 USDC                            | Fixed stake per treasure |
| Single hide                | Available to everyone              | Creates 1 treasure |
| Instant Hide ROZ           | Base × multipliers                 | See Section 2 |
| Hide Survives ROZ          | Base × multipliers                 | See Section 2 |
| Find / Steal rewards       | Always full                        | Never reduced |
| Stake return               | Full $5 if treasure is unfound     | Always |

**Non-refundable Fee (Tiered)**

| Treasures already hidden today | Fee per new treasure |
|--------------------------------|----------------------|
| 0 – 2 (first 3 of the day)     | **$0.20**            |
| 3 or more                      | **$0.25**            |

---

### 2. Reward Multipliers

```text
Final ROZ = Base ROZ × Daily Volume Multiplier × Wallet Rate
```

**Wallet Rate**

| Wallet Status                              | Rate  |
|--------------------------------------------|-------|
| Established + met $0.60 daily spend        | 1.00× |
| Established but below $0.60 daily spend    | 0.15× |
| New Wallet (lifetime spend < $3)           | 0.50× |

**Daily Volume Multiplier**  
*(Based on how many treasures the wallet has **already** created today before this transaction)*

| Treasures already created today | Multiplier applied to new treasures |
|---------------------------------|-------------------------------------|
| 0 – 2                           | 1.00×                               |
| 3 – 4                           | 0.70×                               |
| 5 – 6                           | 0.40×                               |
| 7 – 8                           | 0.20×                               |
| 9 – 10                          | 0.08×                               |
| 11+                             | 0.03×                               |

This multiplier applies whether the player uses single hide or bulk hide.

---

### 3. Bulk Hiding

**Access**
- All addresses can call the bulk hide function.

**Limits by Address Type**

| Address Type       | Max treasures per bulk transaction | Daily treasure cap      |
|--------------------|------------------------------------|-------------------------|
| Non-whitelisted    | Remaining daily allowance (max 10) | **10 per day**          |
| Whitelisted        | Unlimited                          | **No daily limit**      |

**Whitelist Control**
- Only the contract owner can add or remove addresses from the whitelist (via Merkle root).

**Features that affect Bulk Hiding**
- Tiered non-refundable fee ($0.20 for the first 3 of the day, $0.25 thereafter) applies to every treasure.
- **Daily Volume Multiplier** applies based on how many treasures the wallet has already created that day.
- Wallet Rate (New Wallet / Minimum Spend) still applies.
- Each treasure is fully independent for finding and surviving.
- Daily treasure count for non-whitelisted addresses includes both single and bulk hides.

---

### 4. Design Intent

- Ordinary players can use both single and bulk hide but are limited to 10 treasures per day.
- Whitelisted addresses can perform large bulk hides with no daily cap.
- The **Daily Volume Multiplier** penalises high volume regardless of whether the player uses single hides or bulk hides. This closes the previous loophole.
- Combined with the tiered fee and wallet rate multipliers, large-scale or repeated hiding becomes increasingly expensive and low-yielding.
- Find/Steal rewards remain fully protected.

---

**End of Specification**