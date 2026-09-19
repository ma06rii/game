# Routed game architecture

`HelloStarknet` remains the **one stateful game address**. Fourteen separately
declared facet classes hold the game/admin entrypoints. The root exposes one
`route(facet, selector, calldata)` function instead of the former 79 named
game/admin functions. Its existing OpenZeppelin access-control, Ownable, and
SRC5 interfaces remain directly callable. This is a breaking game ABI change:
clients must use the route adapter and its facet ABI manifest.

The root constructor retains its seven original arguments and adds
`facetClassHashes: Array<ClassHash>` as argument eight. The array must contain
**exactly 14** already-declared class hashes in this order:

| ID | Class | Code floor | Sepolia dry-run L2 gas |
| ---: | --- | ---: | ---: |
| 0 | `GameRoundActionsFacet` | 838,120,000 | 861,512,640 |
| 1 | `GameRoundViewsFacet` | 270,240,000 | 280,094,400 |
| 2 | `GameHideActionsFacet` | 950,800,000 | 975,606,720 |
| 3 | `GameHideViewsFacet` | 167,400,000 | 173,946,560 |
| 4 | `GameFinderValidationFacet` | 696,920,000 | 715,844,800 |
| 5 | `GameFinderActionsFacet` | 927,560,000 | 951,532,480 |
| 6 | `GameFinderViewsFacet` | 165,440,000 | 172,287,680 |
| 7 | `GameUsdcClaimsFacet` | 537,040,000 | 553,119,680 |
| 8 | `GameRozClaimsFacet` | 604,680,000 | 622,989,760 |
| 9 | `GameSettingsActionsFacet` | 919,800,000 | 944,149,440 |
| 10 | `GameSettingsViewsFacet` | 224,480,000 | 233,056,960 |
| 11 | `GameTreasuryFacet` | 408,720,000 | 421,812,160 |
| 12 | `GameAdminUpgradeFacet` | 706,400,000 | 727,839,680 |
| 13 | `GameAdminActionsFacet` | 434,920,000 | 449,067,200 |

The root's code floor is **1,004,040,000 L2 gas**. These are measurements of
the Scarb/Cairo 2.19.0 release artifacts: 40,000 L2 gas times the combined
Sierra and CASM felts. They omit other declaration costs. A read-only
`sncast --dry-run --detailed` of the root on Sepolia estimated **1,054,092,480
L2 gas** (all 14 facet dry-runs also completed), roughly 46 million below the [published *mainnet* per-transaction
limit](https://docs.starknet.io/learn/cheatsheets/chain-info) of 1.1 billion.
That is narrow headroom, not proof that Sepolia will include a declaration;
the active Sepolia limit still needs confirmation. These dry-runs used
`account_braavos` and `--network sepolia` on 2026-09-17. Their fee estimates
sum to roughly **288.45 STRK** across 15 declarations at that moment; prices,
resource bounds, and available testnet balance must be rechecked before any
paid submission.
Every source/compiler change requires fresh measurements. No paid declaration
was submitted for these classes.

## Call path

The generated `integrations/routed-game-manifest.json` maps each old method
name to its facet ID, mutability, and original typed ABI. It is generated from
the 14 release facet ABIs by `node scripts/export-routed-game-manifest.mjs`.
Copy that exact file to the frontend's
`src/components/utils/routed-game-manifest.json` and AWS's
`functions/routed-game-manifest.json` whenever a new game build is released.
Do not hand-edit the copies or reuse a manifest from a different class build.

For example, a call to `get_game_week()` becomes:

```text
game.route(1, selector("get_game_week"), [])
```

At the ABI/RPC level the route calldata is `[facet, selector, old_calldata_len,
...old_calldata]`. Its return is `[result_len, ...old_result]`. Clients use
the old facet ABI to serialize the old arguments and decode the result. The
router rejects IDs outside `0..13`, reads the class hash from the root's
storage, and makes a [Cairo library call](https://www.starknet.io/cairo-book/ch102-03-executing-code-from-another-class.html).
Library execution uses the root's storage and event address, and preserves
the original caller. Thus game state, token balances, and indexed game events
still belong to the one root address. Facets are **declared classes**, not
separate deployed contracts.

The large game logic remains once in `MainGameLogicImpl` and
`AdminGameLogicImpl` in `src/lib.cairo`; facets contain thin entrypoints.
`game_contract_state()` supplies the typed root storage marker during library
execution. The test-only `RoutedGameDispatcher` adapter in
`tests/test_contract/routed_game_dispatcher.cairo` sends test calls through
the actual router, so the existing game tests exercise the new path rather
than bypassing it.

## Security and compatibility

- The route ID is a dispatch choice, **not an authorization grant**. The
  original caller reaches the facet, where privileged methods still enforce
  their existing role/owner checks. Any selector present on a facet can be
  requested; review each facet's public ABI before deployment.
- The root stores the facet hashes only during construction. There is no
  facet-hash setter. An upgrade to the root class does not automatically
  replace its stored facet hashes; that would require a separately reviewed
  migration design.
- A wrong constructor ordering makes methods call the wrong class and revert.
  Verify `get_facet_hash(id)` for all 14 IDs against the accepted declarations.
- The frontend detects `route` in the **live** ABI and uses typed read / raw
  transaction adapters. This leaves the legacy deployed game usable until the
  address changes. AWS handlers do the same. Cartridge policy grants the
  single `route` selector, which is broader than per-method session policies;
  onchain authorization remains the final guard. Review that tradeoff before
  enabling Cartridge against the new address.
- Event source addresses and selectors should be checked with a deployed
  canary before repointing Apibara. The library-call design predicts the root
  event address, but local tests cannot prove production indexer behavior.

## Local verification and deployment gate

```bash
scarb --release build
npm run contract:artifact-check
node scripts/export-routed-game-manifest.mjs
snforge test
SNCAST_ACCOUNT=account_braavos bash scripts/dry-run-routed-classes.sh
```

The final command is read-only and stops at the first provider/dry-run error;
set the account alias to the intended deployer. The release build, artifact
check, all 75 Cairo tests, and all 15 read-only class dry-runs passed. The
frontend and AWS adapter tests also pass in their repositories. Before a
fee-bearing Sepolia declaration, rerun the estimates after any build or
provider change, and verify the active Sepolia per-transaction limit and
Sierra version. The dry-run's **consumed** L2 gas is not necessarily the
signed maximum L2 resource bound of a later paid transaction. Before
declaring the near-cap root, inspect the proposed bound and fee settings; if
necessary, use [`sncast declare --l2-gas`](https://foundry-rs.github.io/starknet-foundry/appendix/sncast/declare.html)
with a bound above fresh measured consumption but within the confirmed
network limit. Do not guess a bound or simply extend `--wait`.
Only then declare each facet, wait for `ACCEPTED_ON_L2`, verify each class at
`latest`, declare the root, and deploy with the exact 14-hash array. Re-run
consumer tests, deploy the matching frontend/AWS versions, verify indexed
events, and unpause only after the coordinated rollout is ready. See the
[conditional Sepolia deployment procedure](SEPOLIA_ROUTED_GAME_DEPLOYMENT.md),
[declaration diagnosis](SEPOLIA_GAME_DECLARATION.md), and
[redeployment runbook](../SEPOLIA_DEV_REDEPLOYMENT_RUNBOOK.md).
