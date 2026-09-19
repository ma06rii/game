# Game declaration on Sepolia: compatibility and resource limits

This is the decision record for declaring `HelloStarknet` from the
`deployment-dev-game` worktree. It separates compiler compatibility, class
size, and transaction-resource limits; they are different failure modes.
No fee-bearing declaration or deployment is performed by the repository checks.
The original single-class artifact and its hash below are historical. The
current worktree contains a measured [routed multi-class implementation](GAME_FACET_ARCHITECTURE.md)
that has not passed the full Sepolia declaration gate; do not apply the old seven-argument deployment
instructions to it. Use the [conditional routed-game deployment
procedure](SEPOLIA_ROUTED_GAME_DEPLOYMENT.md) after the gate is met.

## What the previous error means

On 2026-09-17, transaction
`0x05d2cef38f9e04d0a47076a6eb6aceb21ce2d1e723ac5d87331e7feb4bd38b27`
was not found by the configured Sepolia RPC, and class
`0x05e5e6ff232c7ec62d04fea94ba9202123153673e6efcab3ba1460e1fbaca074`
was not declared at `latest`. The original `sncast declare` command did **not**
use `--wait`. Its `Success: Declaration completed` output therefore established
submission, not `ACCEPTED_ON_L2`. A block explorer's “transaction has not been
found” message does not identify a compiler or class-size rejection. Pending
transactions may be visible only on the submitting node, and transactions that
cannot be included can be evicted from the mempool. See the
[transaction lifecycle](https://docs.starknet.io/learn/protocol/transactions)
and [sncast wait behavior](https://foundry-rs.github.io/starknet-foundry/appendix/sncast/common.html).

There is a separate, concrete compatibility risk. The old release artifact was
compiled with Scarb/Cairo 2.20.0 and has Sierra header `1.9.3`. Starknet's
[chain information](https://docs.starknet.io/learn/cheatsheets/chain-info)
currently lists Sepolia at Sierra `1.9.0`, supporting Cairo through `2.19.0`.
The old artifact's CASM contains 81,494 felts and its Sierra JSON is 3,552,940
bytes—below the published 81,920-felt and 4,089,446-byte limits. Thus the
lookup error does not prove a size problem. The old class hash must not be
reused after a compatible rebuild; class hashes are tied to the compiled code.

After the machine's RAM increase, the Scarb 2.19 release build and all 74
Cairo tests passed. The new game class hash is
`0x04710d5c3c4401145c06833183c04bd7fb502476bf7e23b2c90de3e079ea456e`.
The `--wait declare` attempt printed transaction
`0x7f5c4153d6db1b80dbeab0c12e7a2eab3123e637923d3f12dae3b1dfff658c9`
twice, but each invocation timed out after 300 seconds. Subsequent reads from
the configured Sepolia RPC and a public sncast Sepolia provider could not find
the transaction; the class was absent at `latest`, and the configured RPC still
reported deployer nonce 557. This establishes that the attempt was **not
confirmed**, but neither provider exposed a rejection reason. A fresh
declaration dry-run estimated **5,984,131,520 L2 gas** and
about **187.78 STRK**. The new class still has 63,430 Sierra program felts and
81,494 CASM felts. Local RAM and disk do not change those onchain resources.

The [published mainnet transaction limit](https://docs.starknet.io/learn/cheatsheets/chain-info)
is 1.1 billion L2 gas; its block limit is 6 billion. The dry-run is about
5.4 times the published per-transaction limit and nearly fills a block. The
documentation labels these limits *mainnet*, so treat the corresponding
Sepolia limit as needing confirmation from the actual transaction result or
network operator. This resource estimate is a strong reason not to keep
blindly resubmitting the same large class; it is not an observed Sepolia
rejection code.

**Current stop condition:** do not submit this exact class again while its
estimated L2 gas exceeds the active per-transaction limit or that limit is
unknown. A longer `--wait` timeout will not make an over-limit transaction
includable. Obtain an explicit Sepolia limit/rejection diagnosis, or redesign
and measure smaller independent classes before another fee-bearing attempt.

## Compatibility and declaration checkpoint

1. Use the versions pinned in `.tool-versions` and `Scarb.toml`: Scarb/Cairo
   2.19.0, Sierra 1.9.0, and Starknet Foundry 0.62.1. From this worktree run
   `scarb --release build`, `npm run contract:artifact-check`, and `snforge test`.
   The artifact check reads the generated Sierra header and class sizes; it
   deliberately rejects a stale 2.20 artifact. Rebuild and remeasure after
   any source or toolchain change.
2. Run `DOPPLER_CONFIG=dev npm run env:check -- game --online`. Get the **new**
   hash with `sncast utils class-hash --contract-name HelloStarknet`. Run the
   declaration dry-run shown in the README, record its fee and L2-gas estimate,
   and compare them with the current Sepolia network limits. The current 2.19
   estimate above is already unusually large; do not submit it again without
   resolving its inclusion risk.
3. All 15 read-only dry-runs completed under the published *mainnet* cap,
   but do not submit until the active Sepolia limit is verified. Once every
   class is proven to fit the active network, the release
   procedure must declare and confirm each facet before deploying the game.
   Record each class and transaction hash; do not deploy until every declaration
   is `ACCEPTED_ON_L2` and `starknet_getClass` finds each hash at `latest`.
4. After a timeout, do **not** immediately submit another declaration. Check
   status, class existence, and the deployer's latest nonce with the read-only
   helper below. `not found on this node` is not proof of a network-wide
   rejection while the transaction may still be pending.

```bash
DOPPLER_CONFIG=dev npm exec -- varlock run -- \
  node scripts/check-declaration.mjs 0xCLASS_HASH 0xDECLARE_TX_HASH
```

The helper checks that the configured RPC is Sepolia and never prints its URL.
The Doppler URL was serving RPC `0.10.3-rc.0` on 2026-09-17, but has not
passed a declaration dry-run with the pinned toolchain. Until it does, the
README uses `--network sepolia` for transaction submission. That flag can
choose different free providers on separate invocations, so the helper's
pending-transaction answer may differ from the submitting provider. Use the
accepted class at `latest` as the decisive checkpoint.

An RPC parse error, unsupported Sierra version, insufficient fee bound, or
transient missing transaction must be fixed on its own terms. The current
routed implementation has an eighth constructor argument and cannot use the
old deployment command. Its root and all 14 facets have code-only floors below
the published *mainnet* transaction cap, but that does not prove Sepolia
includability; see the [measurements](GAME_FACET_ARCHITECTURE.md).

## Why one reward-logic class is not enough

Do **not** split solely by moving functions into a Cairo source module or a
component: those compile into the same contract class. The declaration fee
[charges 40,000 L2 gas per Sierra program felt and per CASM bytecode felt](https://docs.starknet.io/learn/protocol/fees).
The game has 144,924 such felts, so **code publication alone** has a
5,796,960,000-L2-gas floor before ABI and other costs. At a 1.1-billion limit,
each declared class would need fewer than 27,500 combined code felts even
before overhead. Merely extracting the reward subsystem into one class would
leave the outer game far above that threshold. Six perfectly balanced classes
is the mathematical minimum if total code did not grow; real dispatch wrappers
and duplicated types likely require more. This is an inference from the
published fee schedule and current artifact, not a measured multi-class build.

The routed implementation uses [Cairo library calls](https://www.starknet.io/cairo-book/ch102-03-executing-code-from-another-class.html)
to keep one stateful game address, with typed logic executed in the game's
storage context. The old 79-method root ABI is replaced by one `route` method;
frontend and AWS adapters are updated accordingly. See the
[architecture document](GAME_FACET_ARCHITECTURE.md) for measured budgets and
the remaining onchain verification gate. Do not deploy the old two-class proposal.
