# Deploy the routed game contract to Starknet Sepolia

Operator procedure for the `deployment-dev-game` worktree. Last reviewed
2026-09-18. This deploys a **paused contract**, not a playable game or a
frontend/backend cutover. Nothing in this document has been submitted onchain
by the repository validation checks.

The current game is **15 classes**: 14 facet classes are declared, then the
`HelloStarknet` root class is declared and deployed. The facets are not deployed
as separate contracts. The root constructor takes the seven environment values
shown below plus an eighth argument, an array of exactly 14 facet class hashes
in the documented order. The old seven-argument deployment command is invalid.
See [the architecture and measured class sizes](GAME_FACET_ARCHITECTURE.md).

## Stop gate before paying for any declaration

The root's 2026-09-17 Sepolia dry-run consumed **1,054,092,480 L2 gas**. The
[published 1.1-billion per-transaction limit](https://docs.starknet.io/learn/cheatsheets/chain-info)
is explicitly a **mainnet** limit; this project has not confirmed the active
Sepolia limit. A dry-run's consumed gas is also not necessarily the transaction's
signed maximum L2 gas bound. The 15 dry-run fee estimates totalled about
**288.45 testnet STRK** on that date, not a current price.

Before step 3, re-run the dry-runs; establish the active Sepolia limit and
supported Sierra version from an authoritative current source or the selected
provider; inspect the fee estimate and proposed resource bound for every
class, especially the root; and verify sufficient Sepolia STRK. **If any of
these cannot be established, stop.** Do not assume that more machine RAM, a
longer `--wait`, or a successful fee estimate proves the transaction can be
included. If the root cannot fit, do not pay to declare the facets first.

## 1. Freeze and validate this release

Run from the contract worktree. Record the source revision and all local
changes; the worktree is currently uncommitted. Do not edit or rebuild with a
different compiler after recording class hashes without repeating this process.
The signer remains in the local `sncast` account store, not in Doppler.

```bash
cd /home/ii/development/personal/game-worktrees/deployment-dev-game

git status --short
git rev-parse HEAD
scarb --release build
npm run contract:artifact-check
npm test
snforge test
DOPPLER_CONFIG=dev npm run env:check -- game --online
sncast --account account_braavos balance --token strk --network sepolia
```

`env:check` validates the Doppler values, the Sepolia RPC chain ID, and the
deployer and pauser account aliases. Transactions below use `--network
sepolia`, which may select a different public provider from the Doppler RPC;
the online preflight does **not** prove that provider accepts declarations.

## 2. Dry-run all 15 declarations

```bash
SNCAST_ACCOUNT=account_braavos bash scripts/dry-run-routed-classes.sh
```

This helper sends no transactions. Review each L2 gas and fee estimate. If a
class is already declared, `sncast` cannot estimate another declaration of
that same hash; the helper compares it to the local release artifact, checks
the class at Sepolia `latest` using the Doppler RPC, prints its hash, and
continues without a new fee estimate. A failed or inconsistent RPC check stops
the helper; reconcile provider lag rather than redeclaring blindly. The
existing command still works, but an already-declared class requires working
Doppler/Varlock access for that check. The helper uses Bash to display estimates;
`rg` is not required. Missing estimate fields and other dry-run failures are
fatal.
Re-run after any source, compiler, account, or provider change.
[`sncast --dry-run`](https://foundry-rs.github.io/starknet-foundry/starknet/dry-run.html)
estimates a transaction; it does not reserve capacity or declare a class.

## 3. Declare and verify each facet, one at a time

Keep this Bash array in the **exact** constructor order. Each class is a paid
declaration. Do not submit the next one until the previous class is confirmed
at `latest`.

```bash
FACETS=(
  GameRoundActionsFacet GameRoundViewsFacet
  GameHideActionsFacet GameHideViewsFacet
  GameFinderValidationFacet GameFinderActionsFacet GameFinderViewsFacet
  GameUsdcClaimsFacet GameRozClaimsFacet
  GameSettingsActionsFacet GameSettingsViewsFacet
  GameTreasuryFacet GameAdminUpgradeFacet GameAdminActionsFacet
)
```

For the first class, run the following commands. Then replace `CLASS` with
each next name in `FACETS` and repeat. Copy the actual hash printed by the
local command into `CLASS_HASH`; do not reuse one from a previous build.

```bash
CLASS=GameRoundActionsFacet
sncast utils class-hash --contract-name "$CLASS"
CLASS_HASH=0xLOCAL_CLASS_HASH

DOPPLER_CONFIG=dev npm exec -- varlock run -- \
  node scripts/check-declaration.mjs "$CLASS_HASH"
```

If that check says `Class at latest: declared`, record the matching hash and
skip the paid declaration. Otherwise, **only after the stop gate above is
met**, submit this class:

```bash
sncast --account account_braavos --wait --wait-timeout 600 \
  declare --contract-name "$CLASS" --network sepolia
```

Record the declaration transaction hash from the output, then check both it
and the class. The hash reported by `declare` must equal `CLASS_HASH` and the
helper must say `Class at latest: declared` before continuing.

```bash
DECLARE_TX_HASH=0xTRANSACTION_HASH_FROM_OUTPUT
DOPPLER_CONFIG=dev npm exec -- varlock run -- \
  node scripts/check-declaration.mjs "$CLASS_HASH" "$DECLARE_TX_HASH"
```

If `--wait` times out, **do not declare the same class again yet**. Check the
transaction and the latest class/nonce state, and reconcile provider lag or
an explicit rejection first:

```bash
sncast tx-status "$DECLARE_TX_HASH" --network sepolia
DOPPLER_CONFIG=dev npm exec -- varlock run -- \
  node scripts/check-declaration.mjs "$CLASS_HASH" "$DECLARE_TX_HASH"
```

The original timed-out declaration was for an older, unsplit class. Neither
its transaction hash nor its class hash belongs in this routed deployment.
The [declaration diagnosis](SEPOLIA_GAME_DECLARATION.md) explains the earlier
“transaction not found” message. [`--wait`](https://foundry-rs.github.io/starknet-foundry/appendix/sncast/common.html)
times out locally; a timeout alone does not establish network-wide rejection.

## 4. Declare and verify the root

Only after all 14 facets are confirmed at `latest`, repeat step 3 with
`CLASS=HelloStarknet`. Calculate its local hash, check whether it is already
declared, submit only if needed, and verify its class at `latest` and the
transaction status. **Do not use `--no-abi`: it changes the class hash.**

```bash
CLASS=HelloStarknet
sncast utils class-hash --contract-name "$CLASS"
CLASS_HASH=0xLOCAL_ROOT_CLASS_HASH

DOPPLER_CONFIG=dev npm exec -- varlock run -- \
  node scripts/check-declaration.mjs "$CLASS_HASH"

# Only if the class is not declared and the stop gate is met:
sncast --account account_braavos --wait --wait-timeout 600 \
  declare --contract-name "$CLASS" --network sepolia

# Replace the value with the returned transaction hash:
DECLARE_TX_HASH=0xROOT_DECLARE_TRANSACTION_HASH
DOPPLER_CONFIG=dev npm exec -- varlock run -- \
  node scripts/check-declaration.mjs "$CLASS_HASH" "$DECLARE_TX_HASH"
```

Skip the paid `declare` line if the class was already declared; in that case,
the previously accepted class hash at `latest` is the checkpoint.

## 5. Assemble and recheck the constructor hashes

The deployment script contains the accepted release hashes in the same order
as `FACETS`; review them against your declaration records before using
`--send`. These are class hashes, not facet contract addresses. For the manual
post-deployment checks in step 7, set `FACET_HASHES` and `GAME_CLASS_HASH` in
your current shell from those same recorded hashes. The deployment script also
checks that all 15 classes are declared at `latest` on its selected RPC and
stops if any are missing. The diagnostic helper below does not fail on an
undeclared class unless given `--require-declared`.

```bash
FACET_HASHES=(
  0xROUND_ACTIONS 0xROUND_VIEWS
  0xHIDE_ACTIONS 0xHIDE_VIEWS
  0xFINDER_VALIDATION 0xFINDER_ACTIONS 0xFINDER_VIEWS
  0xUSDC_CLAIMS 0xROZ_CLAIMS
  0xSETTINGS_ACTIONS 0xSETTINGS_VIEWS
  0xTREASURY 0xADMIN_UPGRADE 0xADMIN_ACTIONS
)
GAME_CLASS_HASH=0xHELLO_STARKNET_HASH

for hash in "${FACET_HASHES[@]}" "$GAME_CLASS_HASH"; do
  DOPPLER_CONFIG=dev npm exec -- varlock run -- \
    node scripts/check-declaration.mjs "$hash" --require-declared
done
```

## 6. Dry-run the deployment, then submit it

Run the standalone script from this checkout. It already contains the 15
release hashes, retrieves the other values through Varlock, and supplies the
constructor in this order:
`(vrfProvider, USDC game token, Zee Bucks (RZBX) reward token, roundKeeper, admin, pauser,
upgradeDelay, facetClassHashes)`. The array length `14` is serialized before
the facet hashes. It uses `STARKNET_RPC_URL` from Varlock for both its chain and
class checks and the sncast transaction, and verifies the configured deployer
and pauser accounts. It does not declare a missing class.

```bash
bash scripts/deploy-routed-game.sh
```

Review the result. If it fails, reports unexpected addresses or fees, or
requires resource bounds beyond the confirmed network limit, stop. Once the
dry-run, hashes, and current fee settings have been reviewed, the separate
fee-bearing command is:

```bash
bash scripts/deploy-routed-game.sh --send
```

For a later mainnet release, first declare and independently verify these same
15 classes on mainnet, configure mainnet values and an RPC URL in a dedicated
Doppler config, then use `--network mainnet --doppler-config NAME`. Mainnet
requires an upgrade delay of at least 259200 seconds (three days). First run
without `--send` to estimate; only a separate invocation with `--send`
submits the transaction. The Sepolia-only `npm run env:check` command in step 1
does not validate a mainnet environment; this script runs its own checks.

Record the returned **contract address**, deployment transaction hash, and
accepted block. If this wait times out, check the transaction and deployed
address before attempting another deployment. `sncast deploy` submits through
the Universal Deployer Contract; the instance has a new contract address,
distinct from `GAME_CLASS_HASH`. See the [Foundry deploy reference](https://foundry-rs.github.io/starknet-foundry/appendix/sncast/deploy.html).

## 7. Verify the paused instance at `latest`

Paste the actual address printed by `deploy`. Compare the returned root class
hash to `GAME_CLASS_HASH` and each getter result to the corresponding entry
in `FACET_HASHES`. The direct root ABI has `get_facet_hash`; game/admin methods
such as `is_paused` use `route`.

```bash
GAME_ADDRESS=0xADDRESS_FROM_DEPLOY

sncast get class-hash-at --network sepolia --block-id latest "$GAME_ADDRESS"

for i in "${!FACET_HASHES[@]}"; do
  echo "Facet $i — expected ${FACET_HASHES[$i]}"
  sncast call --network sepolia --block-id latest \
    --contract-address "$GAME_ADDRESS" \
    --function get_facet_hash --calldata "$i"
done

PAUSED_SELECTOR=$(sncast utils selector is_paused | awk '/^Selector:/ {print $2}')
sncast call --network sepolia --block-id latest \
  --contract-address "$GAME_ADDRESS" \
  --function route --calldata 12 "$PAUSED_SELECTOR" 0
```

The final routed response should encode one result (`1`) whose value is true
(`1`): the new contract starts paused. If any hash or pause state differs,
stop before changing any integration address.

## 8. Do not mistake deployment for activation

The new instance has empty gameplay settings and pricing bands. **Do not run
the old direct `set_params`, `update_price_band`, or `unpause` commands in
`RZBX_DEPLOYMENT_AND_FUNDING.md`: those functions are now routed through facet
IDs 9, 9, and 12 respectively, not directly exposed by the root ABI.** Use the
route-aware operator script from the contract repository root:

```bash
DOPPLER_CONFIG=dev npm exec -- varlock run -- node scripts/initialize-routed-game.mjs --check
DOPPLER_CONFIG=dev npm exec -- varlock run -- node scripts/initialize-routed-game.mjs --estimate
DOPPLER_CONFIG=dev npm exec -- varlock run -- node scripts/initialize-routed-game.mjs --send
```

`--send` submits the canonical 35-value settings batch and ten price bands in
order, estimates each transaction before sending, and checks public readback
after acceptance. It leaves the game paused. After the backend, indexers, and
frontend are ready, the distinct pauser runs:

```bash
DOPPLER_CONFIG=dev npm exec -- varlock run -- node scripts/initialize-routed-game.mjs --unpause
```

The script is intentionally pinned to this Sepolia deployment and refuses
other chains or an unexpected root class hash. Three fee-deduction fields do
not have individual public getters; their canonical values are protected by
the accepted first batch and the contract's unpause guard.

To make the game playable, coordinate the new address and matching facet ABI
manifest with AWS, Apibara, and the frontend; settle the old shared-dev game
era or use isolated infrastructure; verify events and balances; then unpause.
The [coordinated redeployment runbook](../SEPOLIA_DEV_REDEPLOYMENT_RUNBOOK.md)
describes the surrounding services, but its historical direct-call
initialization commands must be updated for this routed ABI before use.
