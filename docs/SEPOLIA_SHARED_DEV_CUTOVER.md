# Sepolia shared-dev cutover: routed game

Target game: `0x07088478d5e2464e947186bca33dec61bfd3a84bdf82f76b78f2528bd19b3c86`
at accepted deployment block `15297345`. Its root class is
`0x05c62564e2163b40ed87e846bfb06fd79b11c1fd9a0719a2d4ea91e4022644df`.
The 35 canonical settings and ten price bands were submitted and checked on
2026-09-19. The game remains **paused** until the final activation step.

This procedure replaces the existing shared-dev services. It intentionally
does not move or sweep balances or claims from the old game. For this first
manual test, use Braavos/Argent standard wallets; Cartridge starter packs,
Neon analytics, Zee Bucks (RZBX) funding, and reward claims are not part of the cutover.

## 1. Access and maintenance gate

- Confirm `roz-contract/dev`, `roz-game/dev`, `roz-apibara/dev`, and
  `roz-frontend/dev` resolve with Varlock. If a directory-scoped Doppler CLI
  token fails, repair that scope or run with an authorized `DOPPLER_TOKEN` in
  the environment. Never paste tokens into logs or commit them.
- Confirm the AWS `roz-game-deploy` MFA profile for the normal stack update and
  a separate administrator profile for the one-time data reset. The deploy
  role cannot perform the reset.
- Record all four repository commits, current CloudFormation outputs, table
  counts, and indexer tracker positions. Stop all four legacy indexer
  supervisors and confirm their PIDs have exited. Do not alter their trackers
  while they run.
- Keep old-contract gameplay idle during the maintenance window. Do not change
  the indexer or frontend Doppler target yet.

## 2. Administrator-run backup and reset

From the AWS backend repository, the administrator follows the guarded command
in its README:

```bash
AWS_PROFILE=<administrator-profile> node scripts/reset-dev-game-era.mjs --preview
AWS_PROFILE=<administrator-profile> node scripts/reset-dev-game-era.mjs --apply \
  --archive-dir <new-durable-private-directory> \
  --confirm '390657472661/roz-game/-dev/15297345/0x07088478d5e2464e947186bca33dec61bfd3a84bdf82f76b78f2528bd19b3c86'
```

Review the exact five table names, counts, schedules, and old contract target
before applying. Do not proceed until the command confirms every DynamoDB
backup is `AVAILABLE`, the five tables are empty, the exact old schedules are
gone, and the `RESET#15297345` marker is `COMPLETE`. Save the private archive
and backup ARNs. A failed run leaves round-health automation disabled; inspect
and resume with the same archive instead of starting indexers.

## 3. Deploy the backend and reconnect event delivery

1. In Doppler `roz-game/dev`, set `CONTRACT_ADDRESS` to the target game and
   `CONTRACT_DEPLOYMENT_BLOCK=15297345` together. Keep `NAME_SUFFIX=-dev`,
   Sepolia RPC/network, and the existing shared-dev Pusher and bearer values.
2. In the AWS repository run `npm test`, `sam validate --lint`, and
   `varlock run -- ./scripts/deploy.sh --no-execute-changeset`. Review the
   changeset for resource replacement, especially DynamoDB tables. Then run
   `varlock run -- ./scripts/deploy.sh` and require `UPDATE_COMPLETE`.
3. Record the new `PublicApiBaseUrl`, `HideTreasureUrl`,
   `CheckForTreasureUrl`, `TreasureFoundIngestionUrl`, and
   `RoundLifecycleUrl` CloudFormation outputs. The four ingestion URLs and
   bearer token must never go into the frontend bundle.
4. In Doppler `roz-apibara/dev`, set `SMART_CONTRACT_ADDRESS`,
   `GAME_DEPLOYMENT_BLOCK=15297345`, the five event selectors derived with
   `sncast utils selector` for `TreasureHidden`, `CheckForTreasure`,
   `TreasureFound`, `RoundStarted`, and `RoundEnded`, the four matching AWS
   ingestion URLs, and the same `WEBHOOK_BEARER_TOKEN` as AWS. Preserve the
   correct Sepolia RPC/DNA settings and four distinct tracker filenames.
5. Back up the four old tracker files; run
   `node scripts/init-trackers.mjs --block 15297345 --directory .runtime/trackers`
   in the indexer repository. Update its committed
   `tracker-seeds/starknet-sepolia-dev.json`. Run `pnpm test`,
   `pnpm run typecheck`, configured preflight/build, then start the four
   legacy supervisors. Require healthy trackers and exactly one
   `RoundStarted(0)` delivery producing `GameRounds/CURRENT` and an expiry
   schedule. If the original six-hour deadline has passed, the lifecycle
   handler schedules the missed expiry shortly after replay.

## 4. Local frontend, activation, and manual test

In `roz-frontend/dev`, set `VITE_GAME_CONTRACT_ADDRESS` to the target game,
`VITE_PUBLIC_GAME_API_BASE_URL` to the AWS public `/v0` output,
`PUBLIC_GAME_API_PROXY_TARGET` to that API origin without `/v0`, and the
matching public `VITE_PUSHER_KEY`/`VITE_PUSHER_CLUSTER`. Keep
`VITE_USE_STANDARD_WALLET=true`. Run `pnpm test`, `pnpm env:check -- --online`,
`pnpm build`, then `pnpm dev` locally. Verify the API/proxy and Sepolia wallet
connection.

Only after backend, indexers, and frontend are ready, run from the contract
repository:

```bash
DOPPLER_CONFIG=dev npm exec -- varlock run -- node scripts/initialize-routed-game.mjs --check
DOPPLER_CONFIG=dev npm exec -- varlock run -- node scripts/initialize-routed-game.mjs --unpause
```

Re-enable the recorded RoundHealth EventBridge rule and verify the CloudWatch
alarm is healthy. Use two wallets with Sepolia gas; Hider A needs at least
11 test USDC and should approve about 20 USDC before hiding two treasures.
Once round 1 opens under normal expiry/buffer rules, use a different Finder B
to spawn and find. Check accepted transactions, all four indexer checkpoints,
hidden/found DynamoDB rows, public API/leaderboard updates, and the Pusher
notification. Do not treat an empty round 0 or a still-paused contract as a
successful gameplay test.
