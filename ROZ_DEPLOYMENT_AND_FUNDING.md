# ROZ deployment state and funding runbook

Operational notes for the live Sepolia deployment. Every address and balance
below was **read from the chain**, not copied from a note.

For what the contract does, see `ROZ_REWARD_TOKEN_PLAN.md`. For what was built
and how to run the tests, see `ROZ_IMPLEMENTATION_NOTES.md`.

---

## 1. Live addresses

| Contract | Address |
|---|---|
| **Game** | `0x01aff92bfd50b4953f8b53a95dee15065e89c44e1d98ab4f27d57b6587f1472b` |
| **ROZ reward token** | `0x03a5c8760ed42b8d916f2a37e55335c38979e9ec91c963d0be351e2c285d445b` |
| **USDC (game token)** | `0x0512feAc6339Ff7889822cb5aA2a86C848e9D392bB0E3E237C008674feeD8343` |
| **VRF provider (mock)** | `0x01baad38bde8d3d60eebab5b96f72a297d52e6d1386bc3d4ec5344d9a30388bd` |
| **Owner / deployer** | `0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833` |

### Verified

| Check | Result |
|---|---|
| Deployment identity | class `0x051de976…e0aafb`, block `14484189` |
| Minimum rollover readiness | `get_min_treasures_to_start()` = `2` |
| Game is wired to the token | `get_game_reward_token()` → `0x03a5c876…5d445b` |
| Game is wired to USDC | `get_game_token()` → `0x0512feac…eed8343` |
| Token identity | `symbol()` = `"ROZ"`, `decimals()` = 18 |
| Total supply | 5,000,000,000 ROZ |
| Owner balance | 5,000,000,000 ROZ — the whole supply |
| **Game contract balance** | **0 ROZ, 0 USDC** — verified on 2026-09-03 |
| Lifecycle after bootstrap expiry | round `0`, `ENDING`; round `1` did not open with zero staged treasures |

### Live parameter changes

| UTC date | Change | Transaction | Block | Verified result |
|---|---|---|---|---|
| 2026-09-11 | `dailyFreeHops`: 22 → 20 via owner-only `update_hop_limits(28, 40, 20, 1)` | `0x0545c00bd73150a4642014d62047ebcefcc4f0708d5d06800c94c2fd11b5a311` | `14900145` | `get_hop_limits()` → `(28, 40, 20, 1)` |

This update is not retroactive. A wallet that had already used 20 or more free
hops that day immediately had zero remaining, but no earlier hop was charged;
its next hop used the normal price tier. "Free" here means no USDC game fee.
Gas remains payable in STRK.

### Superseded game contracts

Newest first. **State never migrates between deployments** — each redeploy leaves
its player money behind.

| Address | Why it was replaced | Two-token sweep? |
|---|---|---|
| `0x00430dcb…fa83a` | no minimum-treasure rollover gate | **yes** |
| `0x0771fdfb…cd834c` | no missed-ROZ ledger | **yes** |
| `0x0783f240…d350a9` | no `get_reward_claimed` / `get_claimable_weeks` | **yes** |
| `0x0407390e…c1e2e0` | predates the ROZ work entirely | **no** |

**`0x0771fdfb…cd834c` is at week 5 and still holds $22.13 of USDC**, of which
**$20.08 is owed to players** as hider stakes and only $2.05 is sweepable. Those
stakes are claimable only while the frontend still points there — settle or
write them off before repointing. `0x0783f240…d350a9` holds $15.60 on the same
footing, $15.00 of it owed.

The frontend now uses one shared address source and points at the live deployment
above. Superseded balances and claims do not migrate automatically; accessing a
legacy claim still requires deliberately reconnecting to that old contract.

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
  --arguments '0x01aff92bfd50b4953f8b53a95dee15065e89c44e1d98ab4f27d57b6587f1472b, 855000000000000000000000000' \
  --network sepolia \
  --dry-run

# Then for real - same command, without --dry-run.
sncast --account=account_braavos invoke \
  --contract-address 0x03a5c8760ed42b8d916f2a37e55335c38979e9ec91c963d0be351e2c285d445b \
  --function transfer \
  --arguments '0x01aff92bfd50b4953f8b53a95dee15065e89c44e1d98ab4f27d57b6587f1472b, 855000000000000000000000000' \
  --network sepolia
```

**On the u256.** 855,000,000 × 10¹⁸ = `855000000000000000000000000`, which is
below 2¹²⁸ and so fits in one felt. `--arguments` takes it as a single value.
With `--calldata` you must pass both limbs yourself:

```bash
  --calldata 0x01aff92bfd50b4953f8b53a95dee15065e89c44e1d98ab4f27d57b6587f1472b \
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
GAME=0x01aff92bfd50b4953f8b53a95dee15065e89c44e1d98ab4f27d57b6587f1472b
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
apply the taper with a single `set_params` batch carrying the thirteen rate keys
(`rewardHide` … `rewardHideSurvivedNewWallet`). Lowering the rates first pays
anyone claiming in between at the new, reduced rate out of the old balance.

Doing all thirteen in **one** batch is not merely convenient: the full and
reduced rates are only meaningful relative to each other, and a batch cannot be
observed half-applied.

---

## 6. Recovering ROZ

`withdraw_token_balance(tokenAddress, receiver)` — note the token comes **first**;
the signature changed from `(receiver)`.

For the reward token it releases only the **surplus above
`total_reward_token_pending`**, so it can never take ROZ that players have
already accrued. The same guard applies to USDC via `total_usdc_claimable`. Any
other token is fully sweepable.

Check before acting with `get_sweepable_balance(tokenAddress)`.

**From the §8 build onward the ROZ guard also subtracts
`total_reward_token_missed`** — rewards players earned while the contract was
unfunded and have not converted yet. Equally theirs, just not yet in a payable
form. Note the cost: a wallet that never returns to call
`claim_missed_reward_token` holds that much back from the owner permanently.

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

---

## 8. Redeploying the game contract

**The game contract is now upgradeable.** It carries `UpgradeableComponent`,
`PausableComponent`, `AccessControlComponent` and `SRC5`, with `PAUSE_ROLE`,
`ADMIN_ROLE` and `UPGRADE_ROLE` and a delayed-upgrade proposal flow — see
`docs/UPGRADES_AND_PAUSE.md`, which is the runbook for it. A code change no
longer requires a redeploy; it requires a declare and a proposed class
replacement.

**The currently published address predates that mechanism** and cannot call
`replace_class_syscall`, so moving onto the upgradeable class needs one last
declare → deploy → repoint. Every class from that one onward upgrades in place.
This full sequence has been needed three times so far; it should not be needed
again.

### Declare and deploy

```bash
cd /home/ii/development/personal/game-worktrees/bug-vrf-game
export SCARB_CACHE="$CLAUDE_JOB_DIR/tmp/scarb-cache"
export CARGO_HOME="$CLAUDE_JOB_DIR/tmp/cargo-home"

# 1. Build clean, and refuse to ship if anything is red.
scarb build && snforge test || echo "STOP - do not declare"

# 2. Declare. Prints the class hash; step 3 needs it.
sncast --account=account_braavos declare \
  --contract-name=HelloStarknet \
  --network=sepolia

# 3. Deploy. SEVEN constructor arguments, in this order:
#      (vrfProvider, gameToken, rewardToken, roundKeeper,
#       admin, pauser, upgradeDelay)
#    The keeper is the only account allowed to validate finds, expire rounds
#    and open the next round. admin and pauser MUST be different accounts -
#    the constructor asserts it. upgradeDelay is in seconds.
CLASS_HASH=<paste from step 2>

sncast --account=account_braavos deploy \
  --class-hash "$CLASS_HASH" \
  --arguments '0x01baad38bde8d3d60eebab5b96f72a297d52e6d1386bc3d4ec5344d9a30388bd, 0x0512feac6339ff7889822cb5aa2a86c848e9d392bb0e3e237c008674feed8343, 0x03a5c8760ed42b8d916f2a37e55335c38979e9ec91c963d0be351e2c285d445b, <round-keeper-address>, <admin-address>, <pauser-address>, <upgrade-delay-seconds>' \
  --network sepolia
```

The first six constructor arguments are plain `ContractAddress`, one felt each,
and `upgradeDelay` is a `u64`, so `--arguments` and `--constructor-calldata` are
equivalent here. **The ROZ token does not change** — the same address is reused
every time.

**The deployed contract is paused and holds no settings.** Go straight to
"Post-deploy initialisation" below before doing anything else.

**The owner is hardcoded**, not a constructor argument. Deploying from any
account still produces a contract owned by `0x052a2b0b…023833`, which is
`account_braavos`.

### The declare is the step that fails

`FIX_CLAIM_REWARDS.md` records `--network sepolia` returning **`-32603`** on a
declare — estimating a large class broke the public provider. That was a 550 KB
class and they have only grown since, so treat this as likely rather than
possible:

```bash
sncast --account=account_braavos declare \
  --contract-name=HelloStarknet \
  --url "$STARKNET_RPC_V0_10"
```

Set `STARKNET_RPC_V0_10` to the spec-0.10 endpoint first. **The API key is
currently in plaintext in `FIX_CLAIM_REWARDS.md:77`, which is committed** — worth
rotating and moving into the environment.

`--network sepolia` is fine for the deploy and for every call below. The
estimation problem is specific to declaring a large class.

### Post-deploy initialisation - the contract deploys PAUSED and empty

**The class does not set its own defaults.** `_initialiseRewardSettings` used to
write about ninety constants in the constructor; it cost **5,329 of the 81,920
casm felts** Starknet allows a class, and it was removed to get the contract
closer to that limit. A freshly deployed game therefore has every rate, limit,
fee and band at **zero**, and **deploys paused** so that a half-initialised game
cannot be played. Hiding, hopping and `start_next_round` all `assert_not_paused`.

Run this as the **admin**, then unpause as the **pauser**. The sequence is
mirrored exactly by `initialise_game_settings` in `tests/test_contract.cairo`, so
a mistake here shows up as a failing test rather than on chain.

**All thirty-five scalar settings go in ONE `set_params` call.** Twelve separate
setters used to do this; their compiler-generated wrappers alone cost 7,922 of
the 81,920 casm felts Starknet allows a class, and removing them is part of what
brings the contract under that limit.

`set_params` applies the batch and then validates the **whole** configuration, so
there is no ordering rule to remember any more - but there is a stronger one in
its place:

> **The first batch must carry all thirty-five settings.** Every setting on a
> fresh contract is zero, so a partial first batch fails
> `'free hops >= participation'` and writes nothing. That is deliberate: it is
> what stops a half-configured game from running.

Later, a single setting can be changed on its own, because the rest of the
configuration is already consistent.

```bash
GAME=<address from step 3>

sncast --account=account_braavos invoke --contract-address $GAME \
  --network sepolia --function set_params --arguments \
"array![
 'rewardHide','rewardHideSurvived','rewardFind','rewardParticipation','rewardPerHop',
 'hopRewardBelowThreshold','participationBelowThreshold','rewardHideBelowThreshold',
 'hideSurvivedBelowThreshold','hopRewardNewWallet','participationNewWallet',
 'rewardHideNewWallet','rewardHideSurvivedNewWallet','participationMinimumHops',
 'hopRewardCap','dailyFreeHops','dailyFreeSpawns','dailySoftCapRoz',
 'newWalletSoftCapRoz','softCapMultiplierNum','softCapMultiplierDen',
 'dailySpendThreshold','lifetimeSpendThreshold','hideFeeBase','hideFeeHigh',
 'hideFeeTierBoundary','dailyHideCap','maxTreasuresPerRound','whitelistRoundCap',
 'whitelistCollectiveCap','whitelistHourlyCap','gasFeeReservation','gameMasterFee',
 'gameLandownerFee','minimumAllowance'
], array![
 30000000000000000000, 50000000000000000000, 110000000000000000000,
 18000000000000000000, 1000000000000000000,
 150000000000000000, 0, 4500000000000000000, 7500000000000000000,
 500000000000000000, 9000000000000000000, 15000000000000000000, 25000000000000000000,
 28, 40, 20, 1,
 136000000000000000000, 80000000000000000000, 1, 5,
 600000, 3000000,
 200000, 250000, 3, 10, 2840,
 250, 1200, 80,
 3333, 8333, 1167, 7000000
]"
```

**One key is not its field name.** `rewardHideSurvivedBelowThreshold` is 32
characters and a `felt252` short string holds 31, so its key is
`hideSurvivedBelowThreshold`. Every other key is the storage field name exactly.

The two indexed schedules keep their own setters, because they are already
parameterised by band index:

```bash
A="sncast --account=account_braavos invoke --contract-address $GAME --network sepolia"

# Progressive hop prices. Band 3 is open-ended.
$A --function update_hop_price_band --arguments '0, 25, 5000'      # $0.005
$A --function update_hop_price_band --arguments '1, 45, 10000'     # $0.010
$A --function update_hop_price_band --arguments '2, 65, 20000'     # $0.020
$A --function update_hop_price_band --arguments '3, 340282366920938463463374607431768211455, 40000'

# Daily Volume Multiplier. Band 5 is the open-ended tail.
$A --function update_volume_band --arguments '0, 2, 1, 1'          # 1.00x
$A --function update_volume_band --arguments '1, 4, 7, 10'         # 0.70x
$A --function update_volume_band --arguments '2, 6, 2, 5'          # 0.40x
$A --function update_volume_band --arguments '3, 8, 1, 5'          # 0.20x
$A --function update_volume_band --arguments '4, 10, 2, 25'        # 0.08x
$A --function update_volume_band --arguments '5, 340282366920938463463374607431768211455, 3, 100'

# Finally, unpause AS THE PAUSER - not the admin.
sncast --account=<pauser account> invoke --contract-address $GAME \
  --function unpause --network sepolia
```

**The whitelist merkle root is deliberately not set.** Storage is zero-initialised
and a zero root fails every proof, which means nobody is whitelisted - the correct
starting state. Publish one with `set_whitelist_merkle_root` when there is a list.

**Verify before unpausing.** Every setting has a getter, so read them all back:

```bash
for f in get_reward_rates get_below_threshold_rates get_new_wallet_rates \
         get_hop_limits get_soft_caps get_gate_thresholds get_hide_settings \
         get_whitelist_caps; do
  echo -n "$f: "
  sncast call --contract-address $GAME --function $f --network sepolia
done
```

A zero anywhere means a step was missed. **An unset game is not inert** - it would
hand out free hops that earn nothing, which is silent and wrong rather than loud
and wrong. That is the whole reason the contract deploys paused.

### Verify before trusting it

```bash
GAME=<address from step 3>

# Proves this is the intended build - pick an entrypoint no earlier
# deployment has. get_total_reward_token_missed for the missed-ROZ build,
# get_claimable_weeks for the claim-view build before it.
sncast call --contract-address $GAME --function get_total_reward_token_missed \
  --network sepolia                                          # -> 0_u256

sncast call --contract-address $GAME --function get_game_reward_token --network sepolia
sncast call --contract-address $GAME --function get_game_token        --network sepolia
sncast call --contract-address $GAME --function get_vrf_provider      --network sepolia
sncast call --contract-address $GAME --function get_game_week         --network sepolia  # -> 0_u256
sncast call --contract-address $GAME --function owner                 --network sepolia
```

### Then, in this order

1. **Settle the old contract first.** It holds player money — USDC stakes that
   are claimable while the frontend still points at it, and unreachable
   afterwards. Check with `get_sweepable_balance`; only the surplus above
   `total_usdc_claimable` is the owner's.
2. Sweep whatever is left with `withdraw_token_balance(tokenAddress, receiver)`.
3. Repoint the shared frontend address source and `VITE_GAME_CONTRACT_ADDRESS`;
   gameplay and Cartridge session policies both consume that source. Leave the
   ROZ token address unchanged.
4. Follow the coordinated round bootstrap in §9 to open round 1. The contract
   starts with an empty round 0; do not call live actions with a round id.
5. Update the address in the docs that carry it —
   `ROZ_DEPLOYMENT_AND_FUNDING.md`, `ROZ_IMPLEMENTATION_NOTES.md`,
   `FRONTEND_ROZ_CHANGES.md`, `FRONTEND_CLAIM_DEFECTS.md` and
   `CLAIM_REWARDS_ASSESSMENT.md`.

**ROZ funding is deliberately not in this list.** A new contract starts with a
zero balance, so accrual is skipped and — from the missed-ROZ build onward —
recorded rather than lost. Gameplay and USDC claims are unaffected. Fund it as a
separate decision, using §3 pointed at the new address.

---

## 9. Opening a round

`start_next_round` is the only normal round-advancing call. It is keeper-only,
takes one `NextRoundParams` struct, derives `currentGameWeek + 1` inside the
contract, and can run only after the current round emitted `RoundEnded` and its
end buffer elapsed. The expected treasure count and hidden value are assertions
against the contract's staged facts; they are never writes.

The AWS `StartNextRound` Lambda reads `CONFIG#FEES` and `CONFIG#ROUND`, queries
the staged `Game#Room0#Week<N>` rows, computes the Merkle root/grid/coordinates,
checks `get_next_round_totals()`, and submits the struct. There is no public API
for this call and no repeating six-hour cron. The constructor's empty round 0
is allowed to run its timer once. After that expiry, round 0 remains `ENDING`
until at least two treasures are staged for round 1. Every later rollover has
the same minimum; `start_next_round` enforces it on-chain, and the Lambda avoids
loading the signer or submitting a transaction while the DynamoDB count is
below it. Hides remain available during `ENDING`, and each accepted hide event
retries the normal start flow so the round opens automatically once the minimum
and buffer are both satisfied.

The serialized struct contains (in declaration order): Merkle root, grid X/Y,
expected active count/value, hider stake, hide fee base/high, four hop prices,
spawn fee, round duration, minimum duration, blackout and end buffer. Use the
ABI-generated struct serializer; do not hand-copy the retired positional
`start_new_game` calldata.
