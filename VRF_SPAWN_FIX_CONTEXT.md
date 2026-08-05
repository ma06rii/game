# Handoff context for `VRF_SPAWN_FIX_PLAN.md`

**Read this first, then execute `VRF_SPAWN_FIX_PLAN.md`.** This file explains *why*
that plan exists, what has already been changed, and which traps to avoid. It
assumes you have no prior context.

---

## 1. What this project is

A Vue 3 + Vite treasure-hunt game ("RoZ Game") on **Starknet Sepolia**. Players
connect a wallet, approve the game contract to spend their ETH, spawn onto a
grid, move around hunting treasure, and hide treasure for others.

Important: **this is not a Dojo app.** No Cairo source, no `Scarb.toml`, no
manifests, no `@dojoengine/*` dependencies — this repo holds only contract ABIs
(`src/contracts/`). It talks to contracts directly over RPC and receives events
via Pusher. Any advice that assumes Dojo/Katana/Torii does not apply here.

The game contract's Cairo source lives in a **separate repo the user controls**.
That repo is where most of `VRF_SPAWN_FIX_PLAN.md` gets executed.

Working branch: `bug/fixapp`.

## 2. How we got here

### The original bug
Every transaction failed with:

```
AVNU sponsorship failed: JSON-RPC error 163:
An error occurred (UNKNOWN_ERROR) (data: service not available)
```

### What was investigated and ruled out
- **Error decoding.** Code 163 = `UNKNOWN_ERROR` in the SNIP-29 paymaster spec,
  with a free-form `data` string. `service not available` is AVNU's own
  application-level rejection, not a client bug.
- **AVNU is healthy.** `paymaster_isAvailable` returns `true` on both
  `sepolia.paymaster.avnu.fi` and `starknet.paymaster.avnu.fi`, and the Sepolia
  paymaster lists the game's ETH token as supported.
- **Not a session-policy gap.** `hide_treasure` IS in the session policies and
  failed identically to the out-of-policy `approve`. Policy coverage is irrelevant.
- **Not a missing Cartridge registration.** Cartridge's docs state that on testnet
  the paymaster is *"Automatically enabled, no additional setup required"* and
  needs *"no code changes or configuration"*. Teams/budgets/`slot paymaster create`
  are mainnet-only concerns.
- **Not an SDK version problem.** `@cartridge/controller` was bumped `0.11.3` →
  `0.13.16` (current). The error survived unchanged.

### The answer
**Cartridge support confirmed via Discord that Sepolia is down for Cartridge
Controller.** Their suggested workaround — run your own Katana + Torii — does not
fit this app (see §1) and was rejected as far larger than the alternatives.

### The workaround that was built
A **standard-wallet fallback**: connect Argent/Braavos directly via `get-starknet`
so the player pays their own gas, bypassing Cartridge entirely. This is
**confirmed working** — the wallet picker appears, connection succeeds, and
`hide_treasure` executes successfully on-chain.

### Why a second plan was then needed
`spawn` still fails:

```
argent/multicall-failed, 0x1, 'VrfProvider: not fulfilled', ENTRYPOINT_FAILED
```

Per Cartridge's VRF README, step 4 of the VRF flow is: *"The Cartridge
**Paymaster** wraps the players multicall with a `submit_random` and
`assert_consumed` call."* The randomness proof is injected **by the paymaster** —
the exact component that is down.

So the standard-wallet fallback was always capped at non-VRF calls: `hide_treasure`
works (no randomness), `spawn` cannot (needs `consume_random`). This was a gap in
the original workaround recommendation, discovered only after it shipped.

`VRF_SPAWN_FIX_PLAN.md` exists to break that dependency: deploy a testnet-only
mock VRF provider that fulfils randomness inline, so nothing needs to call
`submit_random`.

## 3. Verified facts (checked on-chain / in source — do not re-derive)

| Fact | Value |
|---|---|
| Network | Starknet Sepolia |
| Game contract | `0x053458482f7d7cd516f89700399a34e7bc62ec94373c46d4cf32d624f017e537` |
| Cartridge VRF provider (same on Sepolia **and** mainnet) | `0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f` |
| ETH token | `0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7` |
| Current game week | `0x1` |
| Test player position | `(0x0, 0x0)` — none, so moves are blocked behind spawn |
| Argent test account | Deployed (class `0x036078...`) — account deployment is NOT the issue |
| Game contract VRF setter | **None.** Address fixed at deploy; owning the contract doesn't help |
| `submit_random` gating | Verifies against `get_vrf_public_key`; only Cartridge holds that key |
| VRF seed derivation | `Source::Nonce(addr)` → `poseidon([nonce, addr, caller, chain_id])` (`vrf_provider_component.cairo:167-191`) |
| `@cartridge/controller` installed | `0.13.16` |

VRF provider interface (from the deployed Sepolia class):

```
request_random(caller: ContractAddress, source: Source)   [view]
submit_random(seed: felt252, proof: Proof)                [external]
consume_random(source: Source) -> felt252                 [external]

Source = enum { Nonce: ContractAddress, Salt: felt252 }
Proof  = struct { gamma: Point, c: felt252, s: felt252, sqrt_ratio_hint: felt252 }
```

## 4. What has already been changed in this repo

**Committed** (`83937b5` and earlier):

- `src/components/utils/standardWallet.js` — **new.** `isStandardWalletMode()`,
  `connectStandardWallet()`, `disconnectStandardWallet()`. Enabled via
  `?wallet=standard` in the URL or `VITE_USE_STANDARD_WALLET=true` in `.env`.
- `src/components/Middle.vue` —
  - `executeAndConfirm(account, calls)` helper replacing all 7 `account.execute`
    call sites. Waits for the receipt and throws on revert.
  - `showTxError()` + a transaction-error modal, replacing silent `console.log`
    swallows.
  - Standard-wallet branches in mount-time connect, disconnect, and a guard around
    `controller.username()`.
- `src/components/utils/controllerPolicies.js` — `propagateSessionErrors: true`;
  the non-canonical `chains` override commented out.
- `package.json` — `@cartridge/controller` `^0.13.16`.

**Uncommitted working-tree changes** (the wallet-picker z-index fix):

- `src/assets/standard-wallet-picker.css` — **new, untracked.** Raises
  get-starknet's picker above the app's overlays.
- `src/main.js` — imports that CSS.
- `src/components/OnboardingWizard.vue` — `isSelectingWallet` ref, `try/finally`
  around the connect, dimmed-overlay class.

**Two bugs fixed along the way, worth knowing about:**
1. `tx.code === "SUCCESS"` was never true — starknet v9's `execute()` returns
   `{ transaction_hash }` with no `code` field, so *successful* transactions were
   being treated as failures and swallowed.
2. `.onboarding-overlay` has `@click.self="handleSkip"`; once the wallet picker
   sat on top, a click dismissing the picker could silently skip the tutorial.
   Fixed with `pointer-events: none` on the dimmed overlay.

Also present: `AVNU_SPONSORSHIP_INVESTIGATION.md` (committed) — the earlier
investigation into the sponsorship failure itself.

## 5. Traps — read before editing

- **Only `Middle.vue` is live.** `Middle1.vue`, `Middle2.vue`, `Middle3.vue`,
  `Middle4.vue` and `Middle.js` are dead legacy variants, unreachable from the
  router (`/` → `HomeView.vue` → `Middle.vue`). They contain near-identical code
  and are the easiest way to waste hours editing the wrong file.
- **`Middle.vue` has a test override** (~line 1172) that force-sets
  `isETHUsageApproved` and `isValidBalance` to `true` under a
  `//for test purposes only` comment. Remove it before judging any test result —
  it bypasses the approval and balance gates entirely.
- **The ETH address is correct.** `0x049d3657...` is the canonical Starknet ETH
  token (verified: `symbol()` → `0x455448`). Automated review has flagged it as a
  typo before. It is not.
- **Do not "fix" `convertFromEthToWei` inconsistently.** `Middle.vue:361` wraps it
  in `Math.floor`; line ~1082 does not. That second one is a real latent bug
  (fractional wei reaching `num.toBigInt`), but it is out of scope for the VRF plan.
- **Duplicate starknet versions.** The app depends on `starknet@^9.2.1` while
  `@cartridge/controller` depends on `starknet@^8.5.2`; the lockfile carries
  several majors. Mostly dormant, but relevant if you hit `instanceof`/type oddities.
- **Security, pre-existing and out of scope:** an Alchemy API key is hardcoded into
  RPC URLs across several files and committed to the repo, so it ships to every
  browser client. Worth rotating separately; do not bundle it into this work.
- **Sandbox note:** in some environments `.env` is masked (bound to `/dev/null`)
  and the global pnpm store is read-only, which makes `pnpm install` fail. If so,
  ask the user to run installs themselves rather than forcing a store switch —
  switching stores triggers a full `node_modules` purge.

## 6. Scope for the new session

**In scope:** everything in `VRF_SPAWN_FIX_PLAN.md` — the mock VRF provider, making
the game contract's VRF address configurable (plus an owner-gated
`update_vrf_provider` setter), redeploying to Sepolia, and updating four address
references in this frontend.

**Out of scope:** rewriting `spawnNewPosition` (the plan is specifically designed
so the frontend multicall does not change), the full self-hosted `vrf-server`
path, the Alchemy key rotation, and the `convertFromEthToWei` inconsistency.

**Do not remove the standard-wallet fallback yet.** It is what makes testing
possible while Cartridge Sepolia is down. When Cartridge recovers, the fallback,
its CSS, and the `?wallet=standard` flag all come out together — and with the
`update_vrf_provider` setter in place, switching back to Cartridge's real VRF
needs no redeploy.

## 7. Open question to confirm with the user

The plan assumes the game contract currently references the VRF provider as a
hardcoded `const`. The user indicated this is the case but had not yet confirmed
it against the Cairo source. Verify before implementing §2 of the plan.
