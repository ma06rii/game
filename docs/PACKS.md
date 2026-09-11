# Cartridge Arcade starter packs

`TreasureGameStarterpack` is the inventory-backed implementation used by
Cartridge Arcade after Arcade has collected a pack's purchase price. It does
not charge the buyer, implement game actions, or sponsor Starknet gas. The
contract sends USDC, STRK, and ROZ already held at its own address directly to
the recipient supplied by Arcade.

The implementation exposes Cartridge's required interface:

```cairo
fn on_issue(
    ref self,
    recipient: ContractAddress,
    starterpack_id: u32,
    quantity: u32,
);

fn supply(self, starterpack_id: u32) -> Option<u32>;
```

`supply` returns `Option::None` for every ID because neither logical pack has
an on-chain issuance ceiling. Actual issuance remains limited by the
contract's token balances. Only the configured Arcade registry may call
`on_issue`; this prevents arbitrary callers from draining inventory.

## Pack configuration

| Pack | Arcade price | Reissuable in Arcade | USDC issued | STRK issued | ROZ issued |
| --- | ---: | --- | ---: | ---: | ---: |
| Welcome | $9.99 | false | `6_000_000` | `2_500_000_000_000_000_000` | `1_000_000_000_000_000_000_000` |
| Week | $29.99 | true | `18_000_000` | `6_000_000_000_000_000_000` | `3_000_000_000_000_000_000_000` |

USDC uses 6 decimals. STRK and the repository's ROZ token use 18 decimals.
The Arcade price is separate from these issued amounts: changing amounts in
this contract does not change the Arcade listing price, and changing an
Arcade price does not change this contract's transfers.

Welcome must be purchased with `quantity == 1`. A recipient can receive it
only once, even if the owner later changes the Welcome pack ID. Week accepts
any nonzero `u32` quantity, multiplies all three stored base amounts by that
quantity, and has no per-wallet cap. Past issues are never topped up after an
amount update.

## Hide-stake safety floor

`min_hide_stake_usdc` defaults to `5_000_000`. It is only a safety check in
the pack contract; it does not update or read the game contract's live hide
stake. The game admin must update the game hide stake and this value together.

Both logical packs must always issue at least one live minimum hide stake.
Accordingly:

- `set_pack_amounts` rejects Welcome USDC below the stored minimum.
- `set_pack_amounts` rejects Week USDC below the stored minimum.
- `set_min_hide_stake_usdc` rejects zero and rejects a value above either
  current pack's USDC amount.

When raising the game hide stake, first raise any pack amount that would fall
below the new floor, then set `min_hide_stake_usdc`, then update the game
contract in the same maintenance operation. When lowering it, lower the game
stake and pack safety floor as one reviewed operation before lowering pack
amounts. The Week pack should normally fund at least three hides, but v1 only
enforces the one-hide minimum.

## Deployment and Arcade registration

The constructor order is:

```text
(owner, arcade_registry, usdc_token, strk_token, roz_token)
```

All five addresses must be nonzero. The three token addresses must be
different. The constructor stores the default issue amounts and minimum hide
stake, but deliberately leaves both pack IDs unconfigured because Arcade
assigns them during registration.

Use this deployment sequence:

1. Confirm the network's official Arcade registry, USDC, STRK, and ROZ
   addresses. Confirm ROZ uses 18 decimals.
2. Build and test this repository, then declare and deploy
   `TreasureGameStarterpack` with the constructor arguments above.
3. Fund the deployed contract with enough of all three tokens for the planned
   sales window. It needs no token allowance because it uses direct ERC-20
   transfers from its own inventory.
4. Register Welcome in Arcade at $9.99 with `reissuable = false`, using the
   deployed implementation address.
5. Register Week in Arcade at $29.99 with `reissuable = true`, using the same
   implementation address.
6. Record the two `u32` IDs returned by Arcade and call
   `set_pack_ids(welcome_id, week_id)` as owner. Issuance reverts until this
   step is complete.
7. Read back `get_pack_ids`, `pack_amounts`, `get_token_addresses`,
   `get_min_hide_stake_usdc`, and `get_arcade_registry`.
8. Issue test purchases to fresh recipient addresses and reconcile all three
   contract and recipient balances before enabling public sales.

Record the implementation class hash, contract address, deployment
transaction, deployment block, Arcade registry, token addresses, pack IDs,
and initial inventory in the release log.

## Owner operations

The owner can call:

- `set_pack_amounts(pack_id, usdc, strk, roz)` to change future issues.
- `set_min_hide_stake_usdc(amount)` to change the pack-only safety floor.
- `set_pack_ids(welcome_id, week_id)` after registration or re-registration.
- `set_token_addresses(usdc, strk, roz)` to change all payout tokens
  atomically.
- `set_arcade_registry(address)` if Cartridge replaces the registry.
- `withdraw_unsold_tokens(token, to, amount)` to recover inventory.
- the embedded OpenZeppelin ownership functions to transfer or renounce
  ownership.

All amount arguments must be nonzero. Pack IDs and token addresses must be
pairwise distinct where applicable. Configuration updates emit events,
including the caller, so operational monitoring can alert on unexpected
changes.

Changing token addresses does not migrate inventory held in the old token
contracts. Fund the new tokens before enabling issues and recover obsolete
inventory explicitly with `withdraw_unsold_tokens`. That withdrawal can make
future issuance fail, so reconcile the remaining Welcome and Week obligation
before withdrawing.

Because owner actions can redirect or remove inventory, use a dedicated
operational wallet, verify every address on a second device, and transfer
ownership to the intended long-lived administrator after deployment. Do not
renounce ownership while mutable amounts, registry migration, or inventory
recovery may still be needed.

## Issuance behavior and errors

`on_issue` checks all three balances before transferring anything. If any
inventory is short, it reverts with `INSUFFICIENT_INVENTORY`; Starknet's
transaction atomicity also rolls back the Welcome-issued marker and any prior
token calls. A token whose `transfer` returns false is treated as insufficient
inventory.

Expected operational errors include:

| Error | Meaning |
| --- | --- |
| `UNKNOWN_PACK` | IDs are not configured or the supplied ID is neither current pack ID. |
| `WELCOME_ALREADY_ISSUED` | This recipient has previously received Welcome. |
| `WELCOME_QUANTITY_NOT_ONE` | Welcome quantity is not exactly one. |
| `INSUFFICIENT_INVENTORY` | At least one transfer cannot be covered or returned false. |
| `ZERO_AMOUNT` | A configured amount, Week quantity, minimum, or withdrawal is zero. |
| `WELCOME_USDC_BELOW_STAKE` | Proposed Welcome USDC is below the pack safety floor. |
| `WEEK_USDC_BELOW_STAKE` | Proposed Week USDC is below the pack safety floor. |
| `MIN_STAKE_ABOVE_WELCOME_USDC` | Proposed safety floor exceeds current Welcome USDC. |
| `MIN_STAKE_ABOVE_WEEK_USDC` | Proposed safety floor exceeds current Week USDC. |
| `NOT_OWNER` | A non-owner called an administrative function. |
| `NOT_ARCADE` | A caller other than the configured Arcade registry called `on_issue`. |

The contract intentionally contains no hop logic, paymaster predicate,
hide/find implementation, or treasury `transferFrom` flow. There is no hop
paymaster in v1: recipients pay transaction gas in STRK. The STRK included in
a pack becomes the recipient's balance only after issuance and does not
retroactively pay for the Arcade purchase transaction.

## Events

Monitor `PackIssued` for the exact totals delivered per issue and
`WelcomeIssued` for the permanent recipient flag. Administrative events are
`PackAmountsUpdated`, `MinHideStakeUpdated`, `TokenAddressesUpdated`,
`PackIdsUpdated`, `ArcadeRegistryUpdated`, and `UnsoldTokensWithdrawn`.
OpenZeppelin ownership transfer events are included in the same contract ABI.

## Files

- `src/starterpack.cairo` — interfaces and production implementation.
- `src/lib.cairo` — exports the starter-pack module.
- `Scarb.toml` — keeps the large game and starter-pack integration suites in
  separate compiler targets and declares their required test artifacts.
- `tests/test_starterpack.cairo` — issuance, authorization, units,
  inventory, and safety-floor regression tests.
- `docs/PACKS.md` — this deployment and operations runbook.
- `README.md` — project-level entry point and build inventory.
