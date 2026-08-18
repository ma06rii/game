**Whitelisted Address Limits – Implementation Overview**

### Goal
Whitelisted addresses have special privileges for hiding treasures, but with two important limits to protect the game:

1. **Personal/Round Cap**: Maximum **250 treasures per round**
2. **Soft Rate Limit**: Maximum **80 treasures per hour**

These limits only apply to **whitelisted** addresses.  
Non-whitelisted addresses remain limited to 10 treasures per day.

---

### 1. Personal / Round Cap (250 treasures per round)

**Purpose**  
Prevent a single whitelisted address from filling most or all of the global round capacity (~2,840 treasures).

**Rules**
- Each whitelisted address can create a maximum of **250 treasures** in any single round.
- This counter resets when a new round starts.
- The global round capacity (~2,840) is still enforced for everyone (including whitelist).

**Storage needed**
```cairo
// Key: address + round_id
whitelist_round_count: Map<(ContractAddress, u64), u32>
```

**Logic**
```cairo
let current_round_id = self.current_round_id.read();
let already_created = self.whitelist_round_count.read((caller, current_round_id));

assert(already_created + treasures_to_create <= 250, 'Whitelist round cap exceeded');

self.whitelist_round_count.write(
    (caller, current_round_id),
    already_created + treasures_to_create
);
```

---

### 2. Soft Rate Limit (80 treasures per hour)

**Purpose**  
Prevent a whitelisted address from dumping a large number of treasures immediately at the start of a round (which would block normal players).

**Rules**
- A whitelisted address can create a maximum of **80 treasures in any rolling 1-hour window**.
- Uses a simple hourly bucket (resets after 3600 seconds).

**Storage needed**
```cairo
whitelist_hour_start: Map<ContractAddress, u64>,   // timestamp when current hour window started
whitelist_hour_count: Map<ContractAddress, u32>,   // treasures created in current window
```

**Logic**
```cairo
fn enforce_whitelist_rate_limit(
    ref self: ContractState,
    caller: ContractAddress,
    treasures_to_create: u32
) {
    let current_time = get_block_timestamp();
    let one_hour: u64 = 3600;

    let mut window_start = self.whitelist_hour_start.read(caller);
    let mut count_in_window = self.whitelist_hour_count.read(caller);

    // Reset window if more than 1 hour has passed
    if current_time >= window_start + one_hour {
        window_start = current_time;
        count_in_window = 0;
    }

    let new_count = count_in_window + treasures_to_create;
    assert(new_count <= 80, 'Whitelist hourly limit exceeded');

    // Update storage
    self.whitelist_hour_start.write(caller, window_start);
    self.whitelist_hour_count.write(caller, new_count);
}
```

---

### 3. Order of Checks (Recommended)

When a **whitelisted** address calls the hide / bulk hide function, perform checks in this order:

1. Verify Merkle proof → confirm they are whitelisted
2. Check **Personal/Round Cap** (250 per round)
3. Check **Hourly Rate Limit** (80 per hour)
4. Check Global Round Capacity (~2,840)
5. Apply fees, Daily Volume Multiplier, Wallet Rate, etc.
6. Create the treasures and update all counters

---

### 4. Summary Table

| Limit                        | Value          | Applies To          | Resets When          |
|-----------------------------|----------------|---------------------|----------------------|
| Personal / Round Cap        | 250            | Whitelisted only    | New round starts     |
| Soft Rate Limit             | 80 per hour    | Whitelisted only    | Every 3600 seconds   |
| Global Round Capacity       | ~2,840         | Everyone            | New round starts     |
| Daily Cap (normal players)  | 10             | Non-whitelisted     | Every calendar day   |

---

### 5. Design Intent

- Whitelisted addresses receive a clear privilege (much higher limits than normal players).
- They cannot instantly monopolise a round.
- Normal players still have a fair opportunity to hide throughout the round.
- Implementation remains relatively simple and gas-efficient.

This document contains everything needed to implement both the 250-per-round cap and the 80-per-hour rate limit for whitelisted addresses.