# Sepolia development redeployment runbook

Assessment snapshot: 2026-09-14

This runbook covers the coordinated deployment of the Realm of Zee game
contract, AWS backend, Apibara indexers, and Vue frontend to Starknet Sepolia.
It records the state observed on the assessment date. Recheck balances, fees,
chain state, and deployed infrastructure immediately before making changes.

[README.md](README.md) is the canonical source for deployment guidance, and
`npm run env:check -- game --online` is the mandatory preflight for a future
deployment. The routed multi-class implementation has not passed the full
Sepolia declaration gate; the historical rollout sequence below must not be
executed yet. Read [the game
declaration diagnosis](docs/SEPOLIA_GAME_DECLARATION.md) and [the measured
facet architecture](docs/GAME_FACET_ARCHITECTURE.md), then follow the
[conditional routed-game deployment procedure](docs/SEPOLIA_ROUTED_GAME_DEPLOYMENT.md)
before any fee-bearing transaction.

## Assessment

This historical assessment preceded the multi-class refactor. The current
contract is **not deployment-ready** until the active Sepolia transaction
cap is verified and the coordinated
rollout requires these operational decisions:

1. Choose a real pauser address distinct from the admin.
2. Either reset the existing shared-dev DynamoDB game era or deploy an isolated
   backend stack.
3. Replace the invalid Neon database credential if the consolidated analytics
   indexer is included in testing.

No deployment or repository change other than creating this runbook was made
during the assessment.

### Release repositories at the assessment snapshot

Deploy only from these clean worktrees:

| Component | Commit | Working directory |
| --- | --- | --- |
| Contract | `3a06e43` | `/home/ii/development/personal/game-worktrees/bug-vrf-game` |
| Frontend | `9a4c5e4` | `/home/ii/development/personal/game_frontend-worktrees/bug-fixapp-game_frontend` |
| Indexers | `ecc5dac` | `/home/ii/development/personal/new_apibara_indexers-worktrees/dev` |
| AWS | `b78f180` | `/home/ii/development/personal/new_roz_aws-worktrees/dev` |

The base checkouts, `bug-vrf-game-fork`, and legacy `roz_lambdas` repository are
not the coordinated deployment sources.

## State observed on 2026-09-14

- Contract release size: 81,494 of 81,920 CASM felts.
- Local class hash:
  `0x05e5e6ff232c7ec62d04fea94ba9202123153673e6efcab3ba1460e1fbaca074`.
- Sepolia did not yet have that class declared.
- Declaration dry-run succeeded at approximately 186.1984 STRK.
- `account_braavos` held approximately 4,999.993 STRK.
- The frontend and both Doppler projects still pointed to the old contract
  `0x01aff92bfd50b4953f8b53a95dee15065e89c44e1d98ab4f27d57b6587f1472b`.
- The four legacy indexers were healthy and two blocks behind head.
- The deployed `RoundHealth-dev` Lambda did not have
  `START_NEXT_ROUND_FUNCTION_NAME`, proving the latest AWS commit still needed
  deployment.
- Game-Neon was stopped because `DATABASE_URL` returned PostgreSQL `28P01`,
  invalid password.
- Starterpack deployment variables were unset. Starterpack is not required for
  Argent/Braavos mode.

Update on 2026-09-17: the old game declaration transaction
`0x05d2cef38f9e04d0a47076a6eb6aceb21ce2d1e723ac5d87331e7feb4bd38b27`
is not found and the class is not declared on Sepolia. That artifact was built
with Sierra 1.9.3; Sepolia currently lists 1.9.0. It must not be reused. A
compatible local rebuild is available in `deployment-dev-game`; the old release
SHAs in the table above are historical and must be re-frozen before rollout.
The `game --online` environment preflight passed on this date; the assessment's
earlier missing-pauser warning is historical.

The rebuilt 2.19.0 class hash is
`0x04710d5c3c4401145c06833183c04bd7fb502476bf7e23b2c90de3e079ea456e`.
Its declaration dry-run estimated 5,984,131,520 L2 gas. The attempt with
transaction hash
`0x7f5c4153d6db1b80dbeab0c12e7a2eab3123e637923d3f12dae3b1dfff658c9`
timed out after five minutes and was subsequently not found on two Sepolia
providers; the class was still not declared at `latest`. Do not submit this
class again until its resource estimate is shown to fit the active Sepolia
transaction limit. See [the diagnosis](docs/SEPOLIA_GAME_DECLARATION.md).

### Existing-contract liabilities

Do not sweep or abandon the old contract without a deliberate decision:

| Item | Observed value |
| --- | ---: |
| USDC balance | 140.012833 USDC |
| Immediately sweepable USDC | 25.307992 USDC |
| Reserved USDC liability | approximately 114.704841 USDC |
| Pending ROZ | 0 ROZ |
| Missed ROZ ledger | 274.4 ROZ |
| ROZ balance | 0 ROZ |
| Round state | round 9 `ENDING` |
| Next-round staging | one of two required treasures |

Keep a legacy frontend configuration available if players need to access old
claims. State and liabilities do not migrate to a replacement address.

## Critical backend issue

The current DynamoDB tables cannot simply be reused with the new address.

`functions/RoundLifecycle/index.mjs` only replaces `CURRENT` when the incoming
round number is higher. A new deployment emits `RoundStarted(0)`, while the
current backend already contains round 9, so it would reject the new event as
stale. Existing `ROUND#0` rows, hidden-treasure coordinates, and treasure-found
rows also collide across eras.

Choose one approach:

- **Safest:** create a separate stack/config such as `dev_redeploy`, with a
  unique stack name, `NAME_SUFFIX`, trackers, tables, APIs, and preferably a
  separate Pusher app.
- **Fastest shared-dev replacement:** back up and clear the five era-specific
  tables and old round schedules before replaying the new deployment.

The repository has appropriate reset logic in
`functions/ResetDevState/index.mjs`, but it is not declared in `template.yaml`,
has no safe operator wrapper, and is not covered by the current deploy-compute
policy. That operator path should be implemented before reusing shared dev.

The five tables it is designed to reset are:

- `roz_gamer_leaderboard-dev`
- `roz_gamer_team_leaderboard-dev`
- `roz_hidden_treasure-dev`
- `roz_game_rounds-dev`
- `roz_treasure_found-dev`

It also removes old `expire`, `minimum`, and `start` round schedules. It retains
game configuration, profiles, paymaster state, and whitelist membership.

## Recommended deployment sequence

### 1. Choose roles

For the recommended separated setup, the `roz-contract/dev` Doppler config must
resolve to these values. The listing below is a reference for what each variable
must hold, not a set of commands to run: the deploy is driven entirely through
Varlock, and manually exporting these into your shell is exactly how the wrong
values end up in a constructor. See [README.md](README.md) for the canonical
invocation.

```bash
VRF_PROVIDER_ADDRESS=0x01baad38bde8d3d60eebab5b96f72a297d52e6d1386bc3d4ec5344d9a30388bd
USDC_TOKEN_ADDRESS=0x0512feac6339ff7889822cb5aa2a86c848e9d392bb0e3e237c008674feed8343
ROZ_TOKEN_ADDRESS=0x03a5c8760ed42b8d916f2a37e55335c38979e9ec91c963d0be351e2c285d445b
ROUND_KEEPER_ADDRESS=0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
ADMIN_ADDRESS=0x...
PAUSER_ADDRESS=0x...
UPGRADE_DELAY=100
STARKNET_RPC_URL=https://...
```

`USDC_TOKEN_ADDRESS` is the game token (constructor slot 2) and
`ROZ_TOKEN_ADDRESS` is the reward token (slot 3). These are the names declared
in `.env.schema` and enforced by `scripts/check-contract-env.mjs`; no other
spelling is supplied by Doppler.

Requirements:

- `ADMIN_ADDRESS` and `PAUSER_ADDRESS` must be nonzero and different.
- `ROUND_KEEPER_ADDRESS` must match the account and private key used by the AWS
  deploy-wallet secret.
- For a minimum viable Sepolia rehearsal, the existing Braavos account can be
  both admin and keeper, but the pauser must still differ.
- Use an injected wallet/block explorer for the pauser, or create and fund a
  throwaway Sepolia account.

Official references:

- [Starknet Sepolia deployment and account funding](https://docs.starknet.io/build/quickstart/sepolia)
- [Starknet network and fee-token addresses](https://docs.starknet.io/learn/cheatsheets/chain-info)
- [Circle USDC contract addresses](https://developers.circle.com/stablecoins/usdc-contract-addresses)

### 2. Freeze and record the release

```bash
cd /home/ii/development/personal/game-worktrees/deployment-dev-game

git status --short
git rev-parse HEAD
scarb --release build
npm run contract:artifact-check
snforge test
sncast utils class-hash --contract-name HelloStarknet
```

Record all four repository SHAs together in the release note.

### 3. Stop old event delivery

Stop the four legacy indexer supervisors before changing Doppler or tracker
files. Do not reset trackers while the old workers are running.

Leave the old contract and balances untouched unless the liability plan says
otherwise.

### 4. Declare and deploy

Run the online preflight first. It validates every required variable, confirms
the configured Doppler RPC really is Sepolia, and checks that both sncast
aliases resolve locally to their configured addresses:

```bash
DOPPLER_CONFIG=dev npm run env:check -- game --online
```

As checked on 2026-09-17, the Doppler `STARKNET_RPC_URL` serves RPC
0.10.3-rc.0, but it has not passed a declaration dry-run with this toolchain.
Use `--network sepolia` below until a dedicated URL passes a dry-run. The
online preflight checks the Doppler RPC, not the provider selected by
`--network`. A pending transaction may not be visible to another provider.
For the old unsplit game class, the dry-run measured about 5.4 times the
published mainnet per-transaction limit. The routed root's read-only Sepolia
dry-run estimated 1,054,092,480 L2 gas; all 14 facet dry-runs also completed.
**Stop after local checks until the architecture document's
deployment gate is met.**

Every `sncast` transaction call below runs inside `varlock run -- bash -c '...'`.
Both halves matter. Varlock injects the Doppler values, and the single-quoted `bash -c`
defers `$VAR` expansion into the child process. Writing
`varlock run -- sncast --arguments "$ADMIN_ADDRESS"` does not work: the outer
shell expands the variable before Varlock ever runs, so sncast receives an empty
string and the constructor silently takes a zero address.

```bash
DOPPLER_CONFIG=dev npm exec -- varlock run -- bash -c '
  sncast --account "$SNCAST_ACCOUNT" declare \
    --contract-name HelloStarknet \
    --network sepolia \
    --dry-run --detailed
'
```

The [routed-game operator procedure](docs/SEPOLIA_ROUTED_GAME_DEPLOYMENT.md)
contains conditional paid commands, but the stop gate above remains in force.
The game constructor now has an eighth argument: a 14-hash facet array. Every
facet must be declared and verified first, and the array must be supplied in
the exact order specified by [the architecture document](docs/GAME_FACET_ARCHITECTURE.md).
The old seven-argument command would deploy an invalid or unusable game.

`deploy --class-hash` does not declare a missing class. Wait for the declare
transaction to reach `ACCEPTED_ON_L2`, then compare its reported hash with the local
`sncast utils class-hash --contract-name HelloStarknet` result. If they
differ, stop and inspect the build before deploying. If waiting times out,
check transaction status, nonce, and class existence before retrying. Do not
retry a failed deployment until declaration is confirmed on Sepolia.

`GAME_CLASS_HASH` is a shell variable rather than a Doppler secret. A future
script will also need distinct variables for the facet hashes; none should be
copied from a prior build without checking the generated artifact.

Official Starknet Foundry references:

- [Deploying contracts](https://foundry-rs.github.io/starknet-foundry/starknet/deploy.html)
- [Dry runs](https://foundry-rs.github.io/starknet-foundry/starknet/dry-run.html)

Record:

- Class hash
- Declaration transaction
- Contract address
- Deployment transaction
- Accepted deployment block

### 5. Initialize while paused

The constructor deliberately pauses the routed contract. First follow the
[routed deployment runbook](docs/SEPOLIA_ROUTED_GAME_DEPLOYMENT.md) to verify
the deployed root, all 14 facet hashes, and paused state. The historical direct
`set_params`, `update_price_band`, `get_contract_addresses`, `is_paused`, and
`unpause` commands in `ROZ_DEPLOYMENT_AND_FUNDING.md` are **not valid for this
ABI**. A route-aware initialization procedure must submit the canonical
35-value settings batch and ten price bands, read them back, and then unpause
from the distinct pauser account. Keep the contract paused until this is
implemented and the backend, indexers, and frontend are ready.

### 6. Prepare AWS

For shared dev:

```bash
doppler secrets set \
  CONTRACT_ADDRESS="$GAME" \
  CONTRACT_DEPLOYMENT_BLOCK="$DEPLOYMENT_BLOCK" \
  PUBLIC_APP_ORIGIN=http://localhost:5173 \
  --project roz-game \
  --config dev
```

Then:

```bash
cd /home/ii/development/personal/new_roz_aws-worktrees/dev

npm test
sam validate --lint
DOPPLER_CONFIG=dev varlock run -- \
  ./scripts/deploy.sh --no-execute-changeset
```

Review the changeset carefully. Deploy interactively so MFA can be entered:

```bash
DOPPLER_CONFIG=dev varlock run -- ./scripts/deploy.sh
```

If reusing shared dev, run the backed-up era reset after the AWS deployment and
before restarting indexers.

For an isolated environment, use a separate Doppler config, stack name, suffix,
and Pusher app:

```bash
DOPPLER_CONFIG=dev_redeploy varlock run -- \
  ./scripts/deploy.sh --stack-name roz-game-redeploy
```

After deployment, record `PublicApiBaseUrl` and the four protected ingestion
outputs.

### 7. Reconfigure Apibara

Update the selected `roz-apibara` Doppler config with:

- `SMART_CONTRACT_ADDRESS`
- `GAME_DEPLOYMENT_BLOCK`
- Five event selectors
- Four AWS ingestion URLs
- The bearer token matching AWS exactly
- Environment-specific tracker filenames

The selector values remain unchanged because the event names did not change,
but derive and verify them again:

```bash
sncast utils selector TreasureHidden
sncast utils selector CheckForTreasure
sncast utils selector TreasureFound
sncast utils selector RoundStarted
sncast utils selector RoundEnded
```

Initialize trackers at the inclusive deployment block:

```bash
cd /home/ii/development/personal/new_apibara_indexers-worktrees/dev

node scripts/init-trackers.mjs \
  --block "$DEPLOYMENT_BLOCK" \
  --directory .runtime/trackers

pnpm test
pnpm run typecheck
DOPPLER_CONFIG=dev varlock run -- pnpm run build
DOPPLER_CONFIG=dev varlock run -- pnpm run preflight
```

Restart the four legacy supervisors and verify:

```bash
DOPPLER_CONFIG=dev varlock run -- pnpm run health
```

For game-Neon:

1. Create or repair a direct, non-pooler Neon credential.
2. Prefer a fresh development database/branch so the old persisted Apibara
   cursor cannot override `GAME_DEPLOYMENT_BLOCK`.
3. Run migrations.
4. Run the online preflight.
5. Start the game-Neon supervisor.

```bash
DOPPLER_CONFIG=dev varlock run -- pnpm run db:migrate
DOPPLER_CONFIG=dev varlock run -- \
  node scripts/check-indexer-readiness.mjs --indexer game-neon --online
./restart_treasure_game_neon_service.sh dev
```

### 8. Configure the frontend

For a local Argent/Braavos test, create or update `.env.local` in the frontend
worktree:

```dotenv
VITE_GAME_CONTRACT_ADDRESS=0x...
VITE_USE_STANDARD_WALLET=true
VITE_PUBLIC_GAME_API_BASE_URL=/game-api/v0
PUBLIC_GAME_API_PROXY_TARGET=https://NEW_PUBLIC_API_ORIGIN
VITE_PUSHER_KEY=...
VITE_PUSHER_CLUSTER=eu
VITE_BULK_HIDE_ENABLED=false
```

Then restart Vite:

```bash
cd /home/ii/development/personal/game_frontend-worktrees/bug-fixapp-game_frontend
pnpm test
pnpm build
pnpm dev
```

The frontend fetches the deployed root ABI through `getClassAt()`, but the
routed build also needs its generated facet ABI manifest copied from
`integrations/routed-game-manifest.json` into the frontend's
`src/components/utils/routed-game-manifest.json` and AWS's
`functions/routed-game-manifest.json`. The same configured game address drives
the Cartridge session policies; review its broader `route` permission.

For a canonical shared-dev cutover, also update:

- `src/components/utils/contractAddresses.js`
- The contract deployment documentation
- `new_addresses.txt`
- `tracker-seeds/starknet-sepolia-dev.json`

### 9. Verify paused behavior, then unpause

Before unpausing:

- Connect Argent or Braavos on Sepolia.
- Confirm reads load from the new address.
- Confirm **Approve Spend Limit** still submits successfully.
- Confirm movement, spawn, and hide are visibly paused.
- Confirm claims remain available.

Then invoke `unpause()` from the distinct pauser wallet. The call reverts unless
all 35 settings and all 10 bands are complete.

## Manual end-to-end test

Use two wallets:

- **Hider A:** at least 11 USDC plus STRK; approve about $20 and hide two
  treasures.
- **Finder B:** STRK plus some USDC. It must not be the hider because players
  cannot find their own treasures.

Verify:

1. Approval, hide events, tracker advancement, AWS hidden rows, and hider
   leaderboard.
2. `GameRounds/CURRENT` is round 0 and an expiry schedule exists.
3. After round 1 opens, spawn Finder B and move.
4. A find produces `CheckForTreasure`, keeper validation, `TreasureFound`, a
   Pusher notification, and leaderboard changes.
5. Pause mid-round and verify gameplay stops while claims remain usable.
6. Unpause and confirm the five-minute `RoundHealth` recovery can resume an
   eligible rollover.
7. Stage two treasures for round 2, finish round 1, let round 2 open, then test
   USDC and ROZ claims.

## Timing warning

The constructor hardcodes the empty bootstrap round to six hours. It cannot be
ended early because it contains no treasures.

- With the current class, movement testing begins roughly six hours plus the
  three-minute buffer after deployment.
- A complete claim-cycle test takes at least another configured minimum round
  duration.
- To make the Sepolia rehearsal faster, change the bootstrap duration before
  declaring. Current validation allows a minimum of one hour. That change
  creates a different class hash and requires rebuilding, retesting, and
  repeating the declaration dry-run.

## Cleanup needed before a public test

- Rotate or restrict the exposed Alchemy key committed in
  `contractAddresses.js`, `standardWallet.js`, and historical documentation.
- Keep the contract README deployment checks aligned with the deployed ABI
  and paused initial state.
- Correct frontend documentation that says Sepolia ETH is required; the current
  transaction flow uses STRK.
- Keep starterpack/Controller disabled until its contract, Arcade IDs,
  inventory, and Neon variables are genuinely configured.
