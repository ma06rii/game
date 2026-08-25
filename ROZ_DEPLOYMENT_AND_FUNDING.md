# ROZ deployment state and funding runbook

Operational notes for the live Sepolia deployment. Every address and balance
below was **read from the chain**, not copied from a note.

For what the contract does, see `ROZ_REWARD_TOKEN_PLAN.md`. For what was built
and how to run the tests, see `ROZ_IMPLEMENTATION_NOTES.md`.

---

## 1. Live addresses

| Contract | Address |
|---|---|
| **Game** | `0x0771fdfb9c6f81b19a08b6f883878f52f6264b00b92d55516dfaa8a913cd834c` |
| **ROZ reward token** | `0x03a5c8760ed42b8d916f2a37e55335c38979e9ec91c963d0be351e2c285d445b` |
| **USDC (game token)** | `0x0512feAc6339Ff7889822cb5aA2a86C848e9D392bB0E3E237C008674feeD8343` |
| **VRF provider (mock)** | `0x01baad38bde8d3d60eebab5b96f72a297d52e6d1386bc3d4ec5344d9a30388bd` |
| **Owner / deployer** | `0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833` |

### Verified

| Check | Result |
|---|---|
| Game contract runs the claim-view build | `get_claimable_weeks` answers `array![]` — the entrypoint exists on no earlier deployment |
| Game is wired to the token | `get_game_reward_token()` → `0x03a5c876…5d445b` |
| Game is wired to USDC | `get_game_token()` → `0x0512feac…eed8343` |
| Token identity | `symbol()` = `"ROZ"`, `decimals()` = 18 |
| Total supply | 5,000,000,000 ROZ |
| Owner balance | 5,000,000,000 ROZ — the whole supply |
| **Game contract balance** | **0 ROZ, 0 USDC** — freshly deployed, `get_game_week()` is `0` |

### Two superseded game contracts

| Address | Why it was replaced | Two-token sweep? |
|---|---|---|
| `0x0783f240…d350a9` | no `get_reward_claimed` / `get_claimable_weeks` | **yes** |
| `0x0407390e…c1e2e0` | predates the ROZ work entirely | **no** |

**`0x0783f240…d350a9` still holds $15.60 of USDC**, of which $15.00 is owed to
players as hider stakes and only $0.60 is sweepable. Those stakes did not
migrate and need claiming or writing off before that address is abandoned.

**The frontend still points at `0x0783f240…d350a9`** — `controllerPolicies.js:14`
and `Middle.vue:41`, which must stay in step with each other. The `0x0407390e…`
in `controllerPolicies.js:9` is one of three commented-out historical entries,
not a live reference.

---

## 2. Why funding matters

Until the game contract holds ROZ, the coverage rule in §4c-i refuses every
credit. **Gameplay still works** — that is the whole point of accruing rather
than transferring — but `RewardTokenAccrualSkipped` fires on every rewarded
action and nobody earns anything.

The token has **no mint function**, so transferring one year's tranche at a time
is what enforces the emission schedule. The balance is the cap; no contract code
is involved.

| Year | Tranche | Raw, 18 dp |
|---|---|---|
| **1** | **855,000,000** | **`855000000000000000000000000`** |
| 2 | 630,000,000 | `630000000000000000000000000` |
| 3 | 405,000,000 | `405000000000000000000000000` |
| 4 | 225,000,000 | `225000000000000000000000000` |
| 5+ | 135,000,000 | released across years 5–8 |

Year 1 is 17.1% of supply.

---

## 3. The funding command

`transfer` moves from the caller, and the owner account holds the whole supply.

```bash
# Dry run first - estimates the fee without sending.
sncast --account=account_braavos invoke \
  --contract-address 0x03a5c8760ed42b8d916f2a37e55335c38979e9ec91c963d0be351e2c285d445b \
  --function transfer \
  --arguments '0x0771fdfb9c6f81b19a08b6f883878f52f6264b00b92d55516dfaa8a913cd834c, 855000000000000000000000000' \
  --network sepolia \
  --dry-run

# Then for real - same command, without --dry-run.
sncast --account=account_braavos invoke \
  --contract-address 0x03a5c8760ed42b8d916f2a37e55335c38979e9ec91c963d0be351e2c285d445b \
  --function transfer \
  --arguments '0x0771fdfb9c6f81b19a08b6f883878f52f6264b00b92d55516dfaa8a913cd834c, 855000000000000000000000000' \
  --network sepolia
```

**On the u256.** 855,000,000 × 10¹⁸ = `855000000000000000000000000`, which is
below 2¹²⁸ and so fits in one felt. `--arguments` takes it as a single value.
With `--calldata` you must pass both limbs yourself:

```bash
  --calldata 0x0771fdfb9c6f81b19a08b6f883878f52f6264b00b92d55516dfaa8a913cd834c \
             855000000000000000000000000 0
```

**On `--network sepolia`.** `FIX_CLAIM_REWARDS.md` records it failing with
`-32603` for a *declare* — estimating a 550 KB class broke the public provider.
That does not apply to an invoke, and every read-only call against these
contracts worked over `--network sepolia`. If it does fail, substitute
`--url "$STARKNET_RPC_V0_10"` with the spec-0.10 Alchemy endpoint.

---

## 4. Verify

```bash
ROZ=0x03a5c8760ed42b8d916f2a37e55335c38979e9ec91c963d0be351e2c285d445b
GAME=0x0771fdfb9c6f81b19a08b6f883878f52f6264b00b92d55516dfaa8a913cd834c
OWNER=0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833

# Game contract holds the tranche
sncast call --contract-address $ROZ --function balance_of \
  --arguments "$GAME" --network sepolia      # -> 855000000000000000000000000

# Owner drops to 4,145,000,000
sncast call --contract-address $ROZ --function balance_of \
  --arguments "$OWNER" --network sepolia     # -> 4145000000000000000000000000

# Nothing owed to players yet, so the whole balance is still recoverable
sncast call --contract-address $GAME --function get_sweepable_balance \
  --arguments "$ROZ" --network sepolia       # -> 855000000000000000000000000
```

**Then take one gameplay action** and confirm
`get_reward_token_pending(<player>)` is non-zero. A balance alone proves the
tokens arrived; only an accrual proves the coverage rule is satisfied.

---

## 5. Two things worth deciding first

**Consider under-funding deliberately.** §7 test 7 covers the unfunded path:
gameplay succeeds, `RewardTokenAccrualSkipped` fires, and `claim_reward` still
pays USDC in full. Sending the whole tranche removes the chance to exercise that
on Sepolia. A small transfer, a check, then a top-up costs one extra
transaction — and that path is the reason the accrual design exists.

**Order matters at every year boundary.** Transfer the tranche **first**, then
apply the taper with the three rate setters — `update_reward_rates`,
`update_new_wallet_rates` and `update_below_threshold_rates`. Lowering the rates
first pays anyone claiming in between at the new, reduced rate out of the old
balance.

---

## 6. Recovering ROZ

`withdraw_token_balance(tokenAddress, receiver)` — note the token comes **first**;
the signature changed from `(receiver)`.

For the reward token it releases only the **surplus above
`total_reward_token_pending`**, so it can never take ROZ that players have
already accrued. The same guard applies to USDC via `total_usdc_claimable`. Any
other token is fully sweepable.

Check before acting with `get_sweepable_balance(tokenAddress)`.

**This is why funding the current contract is safe**, and why the address in §3
matters. `0x0407390e…` swept only the configured game token, so ROZ sent there
would be stuck permanently with no recovery path at all. `0x0783f240…` does have
the two-token sweep, so ROZ sent there by mistake is recoverable — but it is a
wasted round trip on a transfer worth 17% of supply, and the sweep would have to
be run from the owner account before the tokens could be sent on.

---

## 7. Known gap

**Do not point `update_game_reward_token` at an address with no contract behind
it.** The contract handles the address being *unset* (zero) gracefully — it skips
the credit and emits the skip event. But an address pointing at nothing makes
`balance_of` revert, and that takes the whole hop or hide with it.

It fails loudly on the first transaction rather than silently, but it does
contradict the principle that gameplay never depends on reward plumbing.
