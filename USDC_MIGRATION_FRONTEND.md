# Frontend work required for the ETH -> USDC migration

The contract side is done and builds clean. This document covers what the
frontend needs, and **it is not an address swap** - two items below are hard
breakages that will show visibly broken UI if skipped.

Target checkout:
`/home/ii/development/personal/game_frontend-worktrees/bug-fixapp-game_frontend`
(branch `bug/fixapp`). Only `Middle.vue` is live - `Middle.js`, `Middle1-4.vue`,
`WelcomeView.vue` (its route is commented out) and `src/contracts2/**` are dead.

```
USDC (Sepolia) = 0x0512feAc6339Ff7889822cb5aA2a86C848e9D392bB0E3E237C008674feeD8343
decimals       = 6          so 1 USDC = 1,000,000 units
NEW_GAME_CONTRACT_ADDRESS = <fill in after redeploy>
```

## What changed on-chain

- Fees are now **6-decimal USDC amounts**, preserving the previous USD values:

  | Getter | Returns | = |
  |---|---|---|
  | `get_finder_player_fee()` | `100000` | $0.10 |
  | `get_hider_player_fee()` | `5000000` | $5.00 |
  | `get_generate_position_fee()` | `1000000` | $1.00 |
  | `get_minimum_allowance_fee()` | `7000000` | $7.00 |
  | `get_game_token_reward()` | `11666667` | $11.6667 |

- New entrypoints: `get_game_token()` / `update_game_token()` (owner-only).
- `withdraw_ETH_Balance` is renamed **`withdraw_token_balance`**. Not called by
  the frontend, but note it if any tooling uses it.
- The constructor now takes two arguments: `(vrfProviderAddress, gameTokenAddress)`.

---

## 1. HARD BREAKAGE - the USD price oracle collapses to `NaN`

`src/stores/counter.js:57` prices the game token through an Ekubo **USDC/ETH**
pool on Starknet mainnet:

```js
const ethPoolPrice = await handler({tokenA:'0x053c9125…', tokenB:'0x049d3657…', decimalsToken0:18, decimalsToken1:6, poolPriceContract});
```

Once the game token *is* USDC there is no USDC/USDC pool. `get_pool_price`
reverts, `getSqrtRatio` swallows the error and returns `undefined`, `getPrice`
yields `NaN`, and **every USD figure in the UI renders `"NaN"`** - wallet balance
(`Middle.vue:1883`), prize pool (`:2432-2435`), and both reward panels
(`:2342-2348`, `:2374-2380`).

**Fix:** pin the game-token price to `1` and delete the lookup. That also lets you
remove:

- `refreshEthUsdPrice` and its `watch` (`Middle.vue:1136-1155`) - a workaround for
  Firefox dropping user activation across the mainnet round-trip. With no
  round-trip, the problem disappears.
- The "Tap approve once more to confirm" cold-cache retry branch
  (`Middle.vue:1163-1176`).

**Do not remove the mainnet `RpcProvider` or `POOL_PRICE_CONTRACT_ADDRESS.`**
`getPoolRewardTokenPrice` (`counter.js:42`) still prices the GTR reward token
against USDC and must keep working.

## 2. HARD BREAKAGE - `minimumAllowance` diverges by 1e12

The frontend never reads the contract's minimum. `Middle.vue:437-462` recomputes
its own threshold:

```js
let ethValue = (Number(import.meta.env.VITE_MINIMUM_APPROVED_USD_SPEND) / ethUsdPrice);
const weiValue = Math.floor(convertFromEthToWei(ethValue));   // x 1e18
let compareApprovedValues = num.toBigInt(String(res)) > num.toBigInt(String(weiValue));
```

The contract now wants `7000000` (6-decimal). This local calculation still
produces an 18-decimal number, so the two disagree by 1e12 and
`isETHUsageApproved` will be wrong in whichever direction the drift falls -
either blocking play permanently or waving through an allowance that then reverts
on-chain with `'token spend approval req'`.

**Recommended fix: read `get_minimum_allowance_fee()` from the game contract and
compare the allowance against it directly.** It is already in the ABI. This
deletes `VITE_MINIMUM_APPROVED_USD_SPEND` *and* the oracle from the approval
path, and keeps the frontend automatically in step with any future
`update_minimum_allowance_fee` call.

Note the committed `.env` sets `VITE_MINIMUM_APPROVED_USD_SPEND=1` while the
contract requires $7 - so this mismatch already exists today and is worth closing
rather than re-tuning.

## 3. Decimals - the 1e18 helpers

Two hardcoded converters:

- `convertFromEthToWei` - `Middle.vue:122` - `multipliedBy(1e18)`
- `convertFromWeiToEth` - `counter.js:113` - `dividedBy(1e18)`

`convertFromWeiToEth` has five live call sites, all of which break by 1e12:
`counter.js:209` (token balance), `:454`/`:455` (prize pool, `gameWeekTVLETH`),
`:475-476` (rewards this round), `:488-489` (rewards next round).

**Already safe, leave alone:** the player's own balance. `Middle.vue:1220` reads
`decimals()` live off the token contract and `counter.js:320` divides by
`10 ** decimals`. This path adapts to USDC by itself.

The cleanest fix is to make both helpers take the decimals from the same live
`gameTokenDecimals` the store already holds, rather than swapping one constant
for another.

**A latent bug fixes itself here:** `handleSpendAmount` (`Middle.vue:1158-1187`)
has no `Math.floor`, so `USD / price * 1e18` can yield a fractional string that
`num.toBigInt` rejects. Once the oracle divide goes and the amount becomes
`USD * 1e6`, the result is always an integer.

## 4. `VITE_REWARD_TOKEN_MULTIPLIER=1400000`

Used at `counter.js:475-476` and `:488-489`:

```js
let myGamerTokenRewardsDue = convertFromWeiToEth(new BigNumber(gameTokenReward.value).multipliedBy(o.value).multipliedBy(import.meta.env.VITE_REWARD_TOKEN_MULTIPLIER));
```

GTR itself stays an 18-decimal token, so the `1e18` divide on that branch remains
correct. But `gameTokenReward` is now a 6-decimal amount, so the multiplier's
scale is off by 1e12 and needs re-deriving (most likely x1e12, or re-quoted
against USDC). The **ETH branch** on the same lines
(`hiderGamerFee.value` through `convertFromWeiToEth`, no multiplier) is what
breaks outright.

## 5. Addresses, ticker and labels

- `Middle.vue:42` `ETH_CONTRACT_ADDRESS` -> the USDC address.
- `Middle.vue:52` `GAME_TOKEN_TICKER = "ETH"` -> `"USDC"`. This covers the six
  template bindings at L1877, L1964, L2089, L2344, L2376, L2433.
- `Middle.vue:38` `SEPOLIA_GAME_CONTRACT_ADDRESS` -> the new game contract.
- `controllerPolicies.js:4-5` -> the new game contract too.

**No token ABI swap is needed.** The token object is built from
`getClassAt(ETH_CONTRACT_ADDRESS)` (`Middle.vue:1206-1219`), so pointing the
constant at USDC pulls USDC's own ABI. The `sepolia_eth_abi.json` import at
`Middle.vue:18` is dead and can be deleted - it is the StarkGate ETH class, not a
generic ERC20.

Hardcoded "ETH" prose still to reword:

| File | Lines |
|---|---|
| `Middle.vue` | L1690, L1722-1724, L1865 (`<!-- ETH Balance -->`), L1869-1873 (Ethereum diamond SVG + `wallet-balance-icon-eth`), L1145, L1170-1171 |
| `OnboardingWizard.vue` | L91, L119, L163, L174, L182 (`0.005 ETH or more`), L199, L407 |

`Middle.vue:1081`'s "Top-Up Wallet" button opens
`https://www.alchemy.com/faucets/starknet-sepolia` - an **ETH** faucet. It needs
to point at a USDC source (Circle's faucet) or players cannot fund themselves.

Store naming is ETH-flavoured throughout (`ethUsdPrice`, `isETHUsageApproved`,
`gamerETHRewardsDue*`, `gameWeekTVLETH`). Cosmetic, but pervasive enough that
renaming during this migration is cheaper than later.

## 6. Optional

`controllerPolicies.js` registers policies for the game contract and the VRF
provider but **not** the token, so `approve` always prompts the user. Adding the
USDC address with an `approve` entrypoint would smooth that - though it only
matters once Cartridge Controller is usable again.

---

## Verification

1. `get_game_token()` on the new contract returns the USDC address.
2. Fund a test player with USDC from Circle's faucet.
3. Approve the game contract for at least **7,000,000** units ($7).
4. Check the UI: wallet balance shows a sensible USDC figure, and **no USD field
   shows `NaN`**.
5. Spawn. The player's USDC balance should drop by exactly **1,000,000** ($1).
6. `hide_treasure` should deduct exactly **5,000,000** ($5).
7. Prize pool and reward panels should show figures ~1e12 larger than expected if
   item 3 was missed - a good canary for a half-done migration.
