# Realm of Zee game contracts

Cairo contracts for the Realm of Zee Starknet treasure hunt. This repository
defines the authoritative round state, player actions, USDC accounting, ROZ
rewards, priority-hider Merkle root, and lifecycle events consumed by the
off-chain services.

```text
Player transaction -> game contract -> Starknet event -> Apibara indexer
                                            |                 |
                                            |                 v
                                    contract state      AWS ingestion API
                                                              |
                                                              v
                                                   DynamoDB + Pusher + keeper
```

The other application repositories are:

- `game_frontend`: Vue player interface and wallet sessions.
- `new_apibara_indexers`: Starknet event delivery and block checkpoints.
- `new_roz_aws`: APIs, DynamoDB, leaderboards, notifications, and round keeper.

## Current shared-dev deployment

This is the canonical public snapshot for the current Sepolia deployment. Keep
[`new_addresses.txt`](new_addresses.txt) and this table synchronized whenever
the contract is replaced; other repositories should obtain their live values
from Doppler or deployment outputs instead of copying a second snapshot.

| Item | Value |
| --- | --- |
| Game contract | `0x01aff92bfd50b4953f8b53a95dee15065e89c44e1d98ab4f27d57b6587f1472b` |
| Game class hash | `0x051de976192a752b2938d5efa71cace4cf97df4045baa9ad51dd3939d4e0aafb` |
| Deployment block | `14484189` |
| Sepolia USDC | `0x0512feac6339ff7889822cb5aa2a86c848e9d392bb0e3e237c008674feed8343` |
| ROZ reward token | `0x03a5c8760ed42b8d916f2a37e55335c38979e9ec91c963d0be351e2c285d445b` |
| Test VRF provider | `0x01baad38bde8d3d60eebab5b96f72a297d52e6d1386bc3d4ec5344d9a30388bd` |
| Legacy owner | `0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833` |
| Live hop limits | participation `28`, round reward cap `40`, USDC-free/day `20`, free spawns/day `1` |

The test VRF provider is Sepolia-only. Do not deploy or configure it on
mainnet. Operational balances and historical deployments are documented in
[`ROZ_DEPLOYMENT_AND_FUNDING.md`](ROZ_DEPLOYMENT_AND_FUNDING.md).

The first 20 hops of each UTC day waive the USDC game fee; players still pay
gas in STRK. A future paymaster campaign is a separate limit and may sponsor at
most 20 hops, or fewer (for example 15).

## Prerequisites

The currently tested toolchain is:

- Scarb and Cairo `2.20.0`.
- Starknet Foundry (`snforge` and `sncast`) `0.62.1`.
- A funded Starknet account configured in `sncast` for network deployment.

The manifest pins the matching Cairo, OpenZeppelin, and `snforge_std`
dependencies. Confirm your installation before working on the contract:

```bash
scarb --version
snforge --version
sncast --version
sncast account list
```

No environment file is required for local compilation or tests. RPC URLs and
account credentials used for deployment must stay in the `sncast` account
configuration or the operator's environment; never commit private keys or RPC
API keys.

## Build and test

From this repository:

```bash
scarb build
snforge test
```

Both commands must pass before declaring a class. The principal sources are:

```text
src/lib.cairo                  game contract
src/game_reward_token.cairo    ROZ ERC-20 contract
src/mock_erc20.cairo           test-only token
src/mock_vrf_provider.cairo    Sepolia/test-only VRF provider
tests/test_contract.cairo       contract and regression tests
```

`mock_erc20` and `mock_vrf_provider` are testing components; they are not
production dependencies.

Upgrade, role, pause, migration, and emergency procedures are documented in
[`docs/UPGRADES_AND_PAUSE.md`](docs/UPGRADES_AND_PAUSE.md). Read that runbook
before deploying or declaring a replacement class.

The build's `target/dev/project_name_HelloStarknet.contract_class.json` contains
the current source ABI in its `abi` field. Static ABI copies are no longer
checked in; the frontend fetches the deployed class ABI from Starknet.

The source no longer includes the old Pragma callback API:
`receive_random_words`, `update_seed_modulo_divisor`, and the getter/setter
pairs for callback fee, publish delay, and number of words. Spawning uses
`consume_random(Source::Nonce(caller))` synchronously. This source cleanup
does not change the deployment recorded above; a future deployment must follow
the coordinated deployment procedure.

Historical VRF context remains in [VRF_SPAWN_FIX_CONTEXT.md](VRF_SPAWN_FIX_CONTEXT.md)
and [VRF_SPAWN_FIX_PLAN.md](VRF_SPAWN_FIX_PLAN.md). The single retained copy of the
[frontend USDC migration notes](https://github.com/ma06rii/game_frontend/blob/bug/fixapp/USDC_MIGRATION_FRONTEND.md)
lives in the frontend repository. Historical notes may describe files and APIs
that have since been removed; use this README for current operations.

## Round and treasure model

- Round `0` is the one intentionally empty bootstrap round.
- Hides made during round `N` are staged for round `N + 1`.
- `hide_treasure` and `hide_treasure_bulk` are available while the current
  round is `OPEN` or `ENDING`.
- Movement, spawning, and finding are available only while a round is `OPEN`
  and before its scheduled end.
- Live player functions derive the current round internally and do not accept a
  caller-supplied round ID.
- `expire_round(expectedRound)` and `start_next_round(params)` are keeper-only.
  Stale expiry jobs safely do nothing.
- Every round after bootstrap requires at least two staged treasures. If the
  threshold is not met, the current round remains `ENDING` and hides remain
  open until normal automation can start the next round.
- `start_next_round` validates the supplied staged count and value against
  contract state, increments the round internally, and never overwrites live
  hider-share totals.
- Early ending is allowed only for a non-empty round whose active treasures are
  all found and whose timing rules allow it. A newly opened empty round is not
  auto-ended.

Each opened round snapshots its stake, hide fees, tiered hop fees, spawn fee,
grid, coordinate root, duration, minimum duration, blackout, and end buffer.
The AWS keeper supplies the next configuration, but the contract enforces the
fee ceilings, timing relationships, staged facts, and minimum count.

USDC gameplay amounts use 6 decimals. ROZ rewards use 18 decimals. Hider claim
values are snapshotted when charged, so later fee changes cannot reprice an old
claim.

## Events and indexer selectors

Five gameplay events form the off-chain interface:

| Event | Consumer |
| --- | --- |
| `TreasureHidden` | Stages coordinates and updates hider leaderboards. Single and bulk calls emit this unified event. |
| `CheckForTreasure` | Lets the keeper validate the player's current position and hop count. |
| `TreasureFound` | Records canonical finds and hop deltas used for map-density control. |
| `RoundStarted` | Records official fees, timing, grid, active count, and schedules expiry. |
| `RoundEnded` | Records the reason and found/surviving counts, cancels expiry, and schedules buffered rollover. |

Derive selectors from event names after every ABI change; do not copy old keys:

```bash
sncast utils selector TreasureHidden
sncast utils selector CheckForTreasure
sncast utils selector TreasureFound
sncast utils selector RoundStarted
sncast utils selector RoundEnded
```

The resulting values belong in the `roz-apibara` Doppler project alongside the
new contract address and deployment block. All four indexer trackers must be
coordinated with that same deployment before the services restart.

Governance additionally emits OpenZeppelin `Paused`, `Unpaused`, `Upgraded`,
`RoleGranted`, and `RoleRevoked` events plus local proposal, cancellation,
execution, delay, admin-handoff, and migration events. Operational monitoring
should alert on every one of them.

## Safe Sepolia deployment

The current shared-dev address predates upgradeability. Moving to this class
requires one final coordinated deployment and consumer repoint. Once deployed,
future classes can use delayed Starknet `replace_class_syscall` upgrades while
keeping the same address and storage. This is not an Ethereum proxy. Follow the
complete [upgrade and pause runbook](docs/UPGRADES_AND_PAUSE.md), and inspect
outstanding claims on any address being retired.

Set public addresses and the keeper address in your shell. The keeper must be
the account used by the deployed AWS lifecycle functions:

```bash
export VRF_PROVIDER_ADDRESS=0x...
export GAME_TOKEN_ADDRESS=0x...
export REWARD_TOKEN_ADDRESS=0x...
export ROUND_KEEPER_ADDRESS=0x...
export ADMIN_ADDRESS=0x...
export PAUSER_ADDRESS=0x...
export UPGRADE_DELAY=100 # Sepolia rehearsal; mainnet must be >= 259200
export STARKNET_RPC_URL=https://...
```

Build, test, declare, and deploy:

```bash
scarb build
snforge test

sncast --account account_braavos --wait declare \
  --contract-name HelloStarknet \
  --url "$STARKNET_RPC_URL"

export CLASS_HASH=0x... # class hash printed by declare

sncast --account account_braavos --wait deploy \
  --class-hash "$CLASS_HASH" \
  --arguments "$VRF_PROVIDER_ADDRESS,$GAME_TOKEN_ADDRESS,$REWARD_TOKEN_ADDRESS,$ROUND_KEEPER_ADDRESS,$ADMIN_ADDRESS,$PAUSER_ADDRESS,$UPGRADE_DELAY" \
  --url "$STARKNET_RPC_URL"
```

Constructor order is exactly `(vrfProvider, gameToken, rewardToken,
roundKeeper, admin, pauser, upgradeDelay)`. The historical hardcoded owner is
used only for Ownable bootstrap, then ownership is transferred to `admin` in
the constructor. The admin and pauser must be nonzero and distinct. Mainnet
rejects an upgrade delay below 259200 seconds (three days); testnets may use
zero explicitly.

Record the returned contract address, transaction hash, accepted deployment
block, and class hash. Verify the deployment before repointing anything:

```bash
export GAME_CONTRACT_ADDRESS=0x...

sncast call --contract-address "$GAME_CONTRACT_ADDRESS" --function owner --url "$STARKNET_RPC_URL"
sncast call --contract-address "$GAME_CONTRACT_ADDRESS" --function get_admin --url "$STARKNET_RPC_URL"
sncast call --contract-address "$GAME_CONTRACT_ADDRESS" --function get_upgrade_delay --url "$STARKNET_RPC_URL"
sncast call --contract-address "$GAME_CONTRACT_ADDRESS" --function is_paused --url "$STARKNET_RPC_URL"
sncast call --contract-address "$GAME_CONTRACT_ADDRESS" --function get_game_token --url "$STARKNET_RPC_URL"
sncast call --contract-address "$GAME_CONTRACT_ADDRESS" --function get_game_reward_token --url "$STARKNET_RPC_URL"
sncast call --contract-address "$GAME_CONTRACT_ADDRESS" --function get_vrf_provider --url "$STARKNET_RPC_URL"
sncast call --contract-address "$GAME_CONTRACT_ADDRESS" --function get_round_keeper --url "$STARKNET_RPC_URL"
sncast call --contract-address "$GAME_CONTRACT_ADDRESS" --function get_game_week --url "$STARKNET_RPC_URL"
sncast call --contract-address "$GAME_CONTRACT_ADDRESS" --function get_min_treasures_to_start --url "$STARKNET_RPC_URL"
```

Expected initial state is round `0`, minimum staged treasures `2`, not paused,
and all configured addresses returned unchanged. Verify role membership with
`has_role`: admin has the default-admin, admin, and upgrade selectors; pauser
has only the pause selector.

## Coordinated deployment checklist

Complete this sequence for the final coordinated deployment, or for any later
decision to replace the address instead of upgrading it in place:

1. Settle or deliberately preserve old-contract player claims and record its
   balances.
2. Deploy and verify the new contract; record address, class hash, transaction,
   and deployment block.
3. Update this README and `new_addresses.txt`, then derive all five selectors.
4. In Doppler project `roz-game`, update `CONTRACT_ADDRESS` and
   `CONTRACT_DEPLOYMENT_BLOCK`; deploy the AWS stack and record its public and
   protected ingestion outputs.
5. In Doppler project `roz-apibara`, update the contract, selectors, four
   protected webhook URLs, and the same AWS/indexer bearer token. Stop the
   indexers before resetting all four environment-specific trackers to the new
   deployment block, then restart them.
6. Update the frontend's game address, public API URL, Pusher browser key and
   cluster, and Cartridge policies. Never expose an ingestion URL or bearer
   token to the browser.
7. Confirm `RoundStarted(0)` reached `GameRounds`, hide at least two treasures,
   and let the normal expiry/buffer workflow open round `1`. Do not call
   `start_next_round` manually.
8. Fund the new game contract with ROZ only after the intended tranche and
   recipient have been reviewed. A zero ROZ balance skips/accrues reward credit
   without blocking USDC gameplay.

## Priority bulk hiding

The contract stores a single ordered Poseidon Merkle root. The leaf is the raw
caller address, so another wallet cannot reuse a member's proof. The AWS
operator workflow rebuilds the complete tree, stores root-bound proofs, and
calls the admin-only `set_whitelist_merkle_root` entrypoint. A root of `0x0`
means there are no priority hiders.

Use the AWS repository's `manage-bulk-hide-whitelist.sh`; do not hand-build
proofs or update the root independently, because doing so would leave the
frontend proof service without the matching membership records.

## Operational cautions

- Never put private keys, bearer tokens, MFA codes, or provider API keys in this
  repository.
- Do not treat `new_addresses.txt` as permission to redeploy or repoint other
  services; it is a record of the last coordinated deployment.
- Do not reset indexer trackers during an ordinary restart.
- Do not pass round IDs into live player calls or bypass keeper automation.
- In-place class upgrades preserve storage; replacement-address deployments do
  not migrate balances, claims, whitelist membership, or round state.
