# HelloStarknet upgrades and pause

This document is the operator runbook for the upgradeable `HelloStarknet`
class. It covers the first coordinated deployment, emergency pause, delayed
administration, future class replacement, migration, and recovery.

## Architecture

Starknet upgrades do not use an Ethereum-style proxy. `HelloStarknet` calls
`replace_class_syscall` through OpenZeppelin's `UpgradeableComponent`. The
contract address and storage remain in place while Starknet changes the class
hash that supplies its code.

The currently published game address predates this mechanism and cannot call
`replace_class_syscall`. Introducing this class therefore requires one final
coordinated deployment and repointing of the frontend, keeper, and indexers.
Every class deployed from this version onward can be upgraded in place. A full
redeploy remains an emergency alternative, but it does not migrate state.

An upgrade never reruns the constructor. Any new storage field reads as zero
until a migration initializes it. The new class must preserve the old ABI for
existing entrypoints and must never reinterpret old storage.

## Roles and wallet separation

Roles are `felt252` selectors (`selector!("ROLE_NAME")`).

| Role | Authority | Recommended holder |
| --- | --- | --- |
| `PAUSE_ROLE` | Immediate `pause` and `unpause` only | A second wallet/device kept ready for incident response |
| `ADMIN_ROLE` | Parameters, keeper, pauser membership, delayed token/provider changes, delayed sweeps, and delayed admin handoff | Ready or Braavos on a dedicated phone |
| `UPGRADE_ROLE` | Propose, execute, and cancel upgrades; migrate; manage the upgrade delay | The same dedicated admin wallet in v1 |
| `DEFAULT_ADMIN_ROLE` | Role administration boundary | The v1 admin; moved only by delayed `set_admin` |

The pauser is deliberately not an upgrader. The admin is deliberately not a
pauser at deployment, although the admin may later grant itself `PAUSE_ROLE`.
Do not describe multiple accounts controlled by one person as a multisig. This
v1 setup is for one operator with separated devices. The development machine
must never hold the admin seed.

Direct `grant_role`, `revoke_role`, and `renounce_role` are limited to
`PAUSE_ROLE`. The three core roles move together only through the delayed
`set_admin` handoff, preventing a direct AccessControl call from bypassing the
delay.

Do not use Ownable's direct `transfer_ownership` as an administrative handoff.
Game authority comes from AccessControl, so that call changes only the legacy
`owner()` value and would make operational tooling disagree with the roles.
Always use the delayed `propose_admin_update` / `set_admin` path, which moves
the core roles and ownership together.

## Constructor and first deployment

The constructor signature changed from four arguments to seven, in this exact
order:

```text
(
  vrfProviderAddress,
  gameTokenAddress,
  rewardTokenAddress,
  roundKeeperAddress,
  adminAddress,
  pauserAddress,
  upgradeDelay
)
```

`adminAddress` and `pauserAddress` must be nonzero and distinct. The historical
hardcoded owner is still used to bootstrap the unchanged Ownable substorage,
then ownership is transferred inside the constructor to `adminAddress`.
`adminAddress` receives `DEFAULT_ADMIN_ROLE`, `ADMIN_ROLE`, and `UPGRADE_ROLE`;
`pauserAddress` receives only `PAUSE_ROLE`.

On Starknet mainnet (`SN_MAIN`) the constructor rejects an `upgradeDelay`
below 259200 seconds (three days). Sepolia and local tests may explicitly use
zero, although a nonzero testnet delay gives a more realistic rehearsal.

First-deployment checklist:

1. Build and run the complete test suite.
2. Confirm the admin address is a dedicated Ready/Braavos wallet and the
   pauser is a second device.
3. Confirm the keeper is the AWS lifecycle signer, not the admin wallet.
4. Declare the class and independently record its class hash.
5. Deploy with all seven constructor arguments. Use at least `259200` for a
   mainnet-capable deployment.
6. Read `owner`, `get_admin`, `get_upgrade_delay`, `is_paused`, token/provider
   getters, and `get_round_keeper` back from the deployed address.
7. Check `has_role` for all four assignments and confirm the pauser does not
   have `UPGRADE_ROLE`.
8. Record address, class hash, deployment transaction, and deployment block.
9. Repoint the frontend, keeper, and all indexers as one coordinated change.
10. Run the round-zero smoke test before funding production balances.

Example deployment shape:

```bash
sncast --account account_braavos --wait deploy \
  --class-hash "$CLASS_HASH" \
  --arguments "$VRF_PROVIDER_ADDRESS,$GAME_TOKEN_ADDRESS,$REWARD_TOKEN_ADDRESS,$ROUND_KEEPER_ADDRESS,$ADMIN_ADDRESS,$PAUSER_ADDRESS,$UPGRADE_DELAY" \
  --url "$STARKNET_RPC_URL"
```

## Upgrade runbook

Use the following sequence for every in-place upgrade:

1. Review the new class and storage diff. Existing storage must be byte-for-byte
   unchanged and all new fields appended at the end.
2. Write an idempotent migration that initializes only fields introduced by
   that version. Never call `_initialiseRewardSettings` wholesale against a
   live contract.
3. Test upgrade, migration, state preservation, pause behavior, claims, and
   rollback/replacement behavior locally.
4. Declare the new class.
5. Call `propose_upgrade(new_class_hash)` from `UPGRADE_ROLE`.
6. Read `get_pending_upgrade()` and publish the class hash, proposal
   transaction, ETA, source revision, audit/review notes, and migration
   calldata during the delay.
7. Before execution, confirm the published hash equals the pending hash and
   re-run the state/liability checks.
8. At or after the ETA call either `execute_upgrade()` or
   `execute_upgrade_and_migrate(selector!("migrate_vN"), calldata)`.
9. Verify the address now reports the declared class hash, the migration
   version advanced, all invariants hold, and representative reads and claims
   still work.

Use `cancel_upgrade()` if the hash, review, or operating conditions are wrong.
Only one class hash may be pending at once.

`execute_upgrade_and_migrate` follows Starknet's replace-class semantics: the
new class is used for later calls in the same transaction, including the
self-call to the migration selector. It does not replace the code already
executing in the remainder of the current function. If the migration self-call
reverts, the entire transaction, including class replacement, reverts.

Increasing `upgrade_delay` is immediate. Decreasing it requires
`propose_upgrade_delay(new_delay)`, waiting the old delay, and then calling
`set_upgrade_delay(new_delay)`. A pending upgrade retains the ETA calculated
when it was proposed, so decreasing the configured delay cannot accelerate it.
Mainnet always enforces a minimum of three days.

## Migration checklist

- Append new fields after every existing field and substorage. Never rename,
  reorder, delete, or insert storage in the middle.
- Remember that the constructor does not run on upgrade.
- Give each migration a monotonically increasing stored version or boolean.
- Return without writing if that version is already applied.
- Initialize only fields introduced by that version.
- Do not clear or rewrite round state, share maps, `reward_token_pending`,
  `reward_token_missed`, `total_reward_token_pending`,
  `total_reward_token_missed`, or `total_usdc_claimable`.
- Preserve the hide-fee invariant:
  `hideFeeTierBoundary * hideFeeBase == dailySpendThreshold`.
- Snapshot the important values before execution and compare them afterward.

`migrate_v2` in this class only records its version after checking the
hide-fee invariant. Fresh deployments already have version 2. It intentionally
does not replay constructor reward settings.

## Pause behavior

Pause is immediate and has no timelock.

| Reverts while paused | Remains callable while paused |
| --- | --- |
| `hide_treasure` | `claim_reward` |
| `hide_treasure_bulk` | `claim_reward_tokens` |
| `finder_player_move_position` | `claim_reward_token_for_week` |
| `finder_player_generate_position` | `claim_missed_reward_token` |
| `start_next_round` | `expire_round` |
|  | `validate_treasure_coordinates` |
|  | every view, pause/unpause, role administration, delayed administration, and upgrades |

The pause freezes new play, not money already owed. It has no v1 mode that can
pause claims. Expiry stays available so a live round can close, and coordinate
validation stays available so already-checked finds can settle.

Incident procedure:

1. From the pauser device call `pause()` and verify `is_paused() == true`.
2. Record the transaction and announce what is being investigated.
3. Let expiry, validation, and claims continue.
4. Cancel any suspicious pending upgrade or admin action from the appropriate
   role.
5. Fix and verify the issue. Call `unpause()` only from `PAUSE_ROLE` after the
   safety check is complete.

## Delayed sensitive administration and sweeps

The game has one shared pending queue for dangerous admin actions. A second
action cannot overwrite the first. Propose the exact operation, wait
`upgrade_delay`, then call its existing execution entrypoint:

| Proposal | Execution |
| --- | --- |
| `propose_vrf_provider_update(address)` | `update_vrf_provider(address)` |
| `propose_game_token_update(address)` | `update_game_token(address)` |
| `propose_game_reward_token_update(address)` | `update_game_reward_token(address)` |
| `propose_admin_update(address)` | `set_admin(address)` |
| `propose_token_withdrawal(token, receiver)` | `withdraw_token_balance(token, receiver)` |
| `propose_full_token_withdrawal(token, receiver)` | `withdraw_token_balance(token, receiver)` |

The arguments are hashed into the proposal. Execution with different arguments
reverts. `cancel_admin_action()` clears the queue.

A normal token withdrawal remains liability-safe. For ROZ it reserves
`total_reward_token_pending + total_reward_token_missed`; for the game token it
reserves `total_usdc_claimable`, exactly as before. A full withdrawal ignores
those reserves only during one uninterrupted paused window, and it still waits
the full upgrade delay. Calling `unpause` cancels a pending full withdrawal, so
re-pausing requires a fresh proposal and a fresh delay. This is a last-resort
recovery tool: using it can make player claims insolvent and must be publicly
documented.

Changing the reward-token address does not convert pending or missed balances.
Those amounts retain the denomination in which they were earned. Settle and
fund liabilities deliberately before a token change. Changing the game token
likewise does not rescale its 6-decimal USDC-oriented parameters.

Other rate, cap, keeper, and whitelist setters are immediate `ADMIN_ROLE`
operations. They can change live behavior and should be simulated and reviewed
even though they do not use the delayed queue.

## Moving administration to a multisig or timelock

No game redeployment is needed. Deploy and test the OpenZeppelin Multisig or
Timelock contract, then:

1. Call `propose_admin_update(multisig_or_timelock)` from the current admin.
2. Publish the target address and wait the current upgrade delay.
3. Call `set_admin(multisig_or_timelock)`.
4. Verify the target holds `DEFAULT_ADMIN_ROLE`, `ADMIN_ROLE`, and
   `UPGRADE_ROLE`, the previous admin holds none of them, and Ownable `owner()`
   equals the target.
5. Execute a harmless administrative rehearsal through the new controller.

The `PAUSE_ROLE` is not moved by `set_admin`; keep or separately rotate the
incident-response wallet with `grant_role`/`revoke_role`.

## Files implementing this change

- `src/lib.cairo` — components, storage, roles, delay queues, pause guards,
  migration, ABI, and events.
- `tests/test_contract.cairo` — constructor updates plus pause, claim, role,
  upgrade, migration, delay, sweep, and authorization tests.
- `docs/UPGRADES_AND_PAUSE.md` — this runbook.
- `README.md` — current deployment summary and link to this runbook.

`Scarb.toml` is unchanged. Its existing OpenZeppelin v2.0.0 root dependency
already re-exports the access-control, introspection, security, and upgrades
components used here.
