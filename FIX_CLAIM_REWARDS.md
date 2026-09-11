
     Deploy the USDC game contract - fixing the -32603 Internal error

     What the error means

     sncast --account=account_braavos declare --contract-name=HelloStarknet --network=sepolia
     Error: Unknown RPC error: JSON-RPC error: code=-32603, message="Internal error"

     -32603 is the JSON-RPC catch-all for "the server blew up". It carries no
     Starknet-specific meaning - it is not about your balance, your account, or
     your contract. It means the node failed to process the request and had nothing
     better to say.

     Root cause: an RPC spec version mismatch. sncast 0.62.1 targets Starknet
     JSON-RPC 0.10.0. The public provider behind --network sepolia is on an
     older spec, and starknet_estimateFee for a declare of this size fails on it.

     Confirmed by differential test, same command, same contract, three endpoints:

     ┌──────────────────────────────────────────────┬─────────┬────────────────────────────────────────────┐
     │                   Endpoint                   │  Spec   │                   Result                   │
     ├──────────────────────────────────────────────┼─────────┼────────────────────────────────────────────┤
     │ --network sepolia (public default)           │ (older) │ -32603 Internal error                      │
     ├────────────────────────────────────────────────────────────────────────┤
     │                                 03 Internal error + explicit [WARNING]
     │
     │ api.cartridge.gg/.../rpc/v0_9   ompatible version 0.9.0. Expected
     │
     │                                 ion: 0.10.0
     │
     ├────────────────────────────────────────────────────────────────────────
     ┤
     │ starknet-sepolia.g.alchemy.com/.ess: Dry run completed. Overall Fee:
     │
     │                                 4845 STRK
     │
     └────────────────────────────────────────────────────────────────────────
     ┘

     Two supporting details:

     - sncast's own help text warns abo network with a
     public provider. Note that this ops or other
     unexpected behavior."
     - The class is now 550 KB of Sierror a free
     public endpoint to estimate over. sion problem.

     - sncast's own help text warns abo network with a
     public provider. Note that this ops or other
     unexpected behavior."
     - The class is now 550 KB of Sierror a free
     public endpoint to estimate over. sion problem.

     Budget is not a constraint any morgainst a
     balance of 169.50 STRK; even sncas) leaves
     ~107 STRK of headroom. The earlierance" failure is
     resolved by the top-up.

     Prior work already complete

     The contract changes are done, bui

     - src/lib.cairo - configurable gamecimal USDC,
     ETH-flavoured identifiers renamed.
     (vrfProviderAddress, gameTokenAddr
     - [Frontend USDC migration notes](https://github.com/ma06rii/game_frontend/blob/bug/fixapp/USDC_MIGRATION_FRONTEND.md)

     Only deployment and the post-deplo

     ---
     Step 1 - Declare against a spec-0.

     Drop --network and pass --url expl

     sncast --account=account_braavos d
       --contract-name=HelloStarknet \
       --url https://starknet-sepolia.g/rpc/v0_10/ffSkS9OBRrEUykmSI4ETP

     Add --dry-run first if you want topending.

     Note this is the same Alchemy key tend's
     READ_PROVIDER_URL - which is a sepentually, but
     it is the 0.10 endpoint you alread

     Consider adding a snfoundry.toml sommand
     argument you can forget:

     [sncast.default]
     url = "https://starknet-sepolia.g.rpc/v0_10/..."
     account = "account_braavos"

     Record the class hash it prints. Nlease profile
     for declare (visible in its outputt match anything
     computed from target/dev.

     Step 2 - Deploy with BOTH construc

     sncast --account=account_braavos d
       --class-hash <new class hash fro
       --constructor-calldata \
           0x01baad38bde8d3d60eebab5b969a30388bd \
           0x0512feAc6339Ff7889822cb5aA4feeD8343 \
       --url https://starknet-sepolia.g/rpc/v0_10/ffSkS9OBRrEUykmSI4ETP

     Order is (vrfProviderAddress, gameprovider, not
     Cartridge's. The previous deploy pand needed a
     follow-up update_vrf_provider to cecisely so that
     mistake is visible immediately.

     Step 3 - Sweep the old contract be

     0x01ad64b0557cb573f078d7a573bb3552b26 holds
     0.003 ETH in already-collected feehe old name:

     sncast --account=account_braavos i
       --contract-address 0x01ad64b0557ea7e1d182151ee5ab5691b26 \
       --function withdraw_ETH_Balance
       --calldata <your address> \
       --url <the 0.10 url>

     Player positions and claim shares redeploy - there
     is no migration path and none is p

     Step 4 - Regenerate the frontend a

     frontend-address-update.patch and point at the
     old game contract and pre-date thehey need
     regenerating against the new addre carries
     get_game_token / update_game_tokenen_balance).

     Then hand over USDC_MIGRATION_FRON itself - note
     its two hard breakages (the USD orhe
     minimumAllowance 1e12 divergence) sibly wrong.

     ---
     Verification

     Run all reads against the 0.10 end

     1. get_vrf_provider() -> 0x1baad38
     2. get_game_token() -> 0x0512feac.
     3. get_generate_position_fee() -> () ->
     5000000, get_minimum_allowance_fee-looking
     number here means the wrong class
     4. get_game_week() -> expect 0 on reads this
     from the contract (Middle.vue:258)o action
     is needed - just know which week y
     5. Fund a player with USDC from Cist 7000000.
     6. Spawn: expect SUCCEEDED, and thll by exactly
     1000000.
     7. hide_treasure: balance falls by

     Note for future commands

     Every sncast call in this project rl (or a
     snfoundry.toml). --network sepoliaor anything
     that requires fee estimation over

     "/plan open" to edit this plan in

❯ study my project and assess what neede claim functionality working

Let me study the claim path — contrac search.

● Explore(Map frontend claim reward flo
Backgrounded agent (↓ to manage ·

  Read 1 file, ran 2 shell commands

Now let me check whether claim has ev-chain.

  Ran 1 shell command

On-chain evidence confirms claim has check one more thing — the separatereward token contract. Read 1 file, ran 2 shell commands I have the contract picture. Here's tout direction. Claim is currently unreachable, and agates on assert(gameWeek < currentGameWeek), but shares are cred ┌───────────────────────┬──────────── │                       │ new contrac ├───────────────────────┼──────────── │ get_game_week()       │ 0 ├───────────────────────┼──────────── │ shares exist for week │ 1 (one hide ├───────────────────────┼──────────── │ need week ≥           │ 2 └───────────────────────┴──────────── So on both deployments every share siclaimable. start_new_game is the only thing that advances the week, it's owust be called twice after a hide before that hide is claimable.

Three more findings:

- Historical claims get repriced. _ca50) reads currentHiderFee — today's fee
— not the fee from the week being claerwrites all fees on every rollover, a
$5 hide could pay out at whatever theain_game[week] already stores the
per-week hiderFee, so the fix needs n
- The old contract's week-1 hider cou0000 where a count belongs — a past
start_new_game was passed the treasur-count slot. Eight positional u256 args
with no validation.
- The GTR "token rewards due" the UI ameTokenReward appears in exactly three
places — declaration, constructor, getransfer, of the game token only. And
0x0788929e… returns "Contract not fou

● User declined to answer questions
· Advancing the game week is the peks roll over? (Add
`advance_game_week()` (Recommendedgame manually / Time-based automatic
rollover)
· `_calculateRewardDue` values his hider fee rather than the fee in force
during the claimed week. Fix it? (commended) / Leave as-is)
· The UI shows a GTR 'token rewardard` never pays, and the reward
contract isn't deployed on Sepolia / handled off-chain / It should be
paid on-chain / Out of scope — foc
· How deep should this go? (ContraRecommended) / Contract + a
claimed_rewards getter and other r, no code yet)

● Agent "Map frontend claim reward flow

The frontend agent landed with a find the frontend has no claim
implementation at all — claim_reward e button is a literal :disabled="true"
with no @click handler. It also shows a new game contract I haven't seen.
Let me verify that before we talk.

  Ran 1 shell command

Good news on state — the USDC contracrectly wired:

┌───────────────────────┬─────────────────────────────┐
│                       │                             │
├───────────────────────┼─────────────────────────────┤
│ get_game_token        │ USDC ✓                      │
├───────────────────────┼─────────────────────────────┤
│ get_vrf_provider      │ mock ✓                      │
├───────────────────────┼─────────────────────────────┤
│ fees                  │ 5000000 / 1decimal values ✓ │
├───────────────────────┼─────────────────────────────┤
│ contract USDC balance │ 11,800,000  pay claims      │
├───────────────────────┼─────────────────────────────┤
│ get_game_week         │ 0                           │
└───────────────────────┴─────────────────────────────┘

So the contract is fine. Claim is blod that has no claim code at all.

I've noted your answer on rollover (kefore I reformulate the rest — one
thing that answer surfaces: because stHiderFee on every rollover, and
_calculateRewardDue reads the currentweek's, manual rollover makes that
repricing bug live rather than theoreal_reward_shares_for_hiders[newWeek],
which is what corrupted week 1 on the

● User answered Claude's questions:
· What would you like to clarify bweek rollover mechanics, Which contract
fixes are actually needed

Let me get the concrete numbers for y

  Ran 1 shell command

Here's exactly what you asked about.

  Ran 1 shell command

A. Week rollover mechanics

Your contract right now: currentGameWlready happened — they credited
claim_share_amounts[(week 1, player)]because claim_reward(W) requires W <
currentGameWeek, and nothing is < 0.

start_new_game writes exactly six thi

┌─────────────────────────────────────────────────┬────────────────────┐
│                        Writes      alue         │        Note        │
├─────────────────────────────────────────────────┼────────────────────┤
│ currentGameWeek                     + 1         │ the only way it    │
│                                                 │ moves              │
├─────────────────────────────────────────────────┼────────────────────┤
│ currentFinderFee / currentHiderFee s            │ global — not       │
│ currentSpawnNewPositionFee                      │ per-week           │
├─────────────────────────────────────────────────┼────────────────────┤
│ main_game[newWeek]                 inderFee,    │                    │
│                                    )            │                    │
├───────────────────────────────────────────────────────┼──────────────────────┼────────────────────┤
│ main_game_grid_size[newWeek]       gridY)       │                    │
├─────────────────────────────────────────────────┼────────────────────┤
│ total_reward_shares_for_hiders[newW             │ overwrites,        │
│                                                 │ doesn't add        │
├─────────────────────────────────────────────────┼────────────────────┤
│ game_totals[newWeek]                            │                    │
└─────────────────────────────────────────────────┴────────────────────┘

It does not touch claim_share_amountsm actually pays on. So a rollover can't
destroy anyone's entitlement. Two tra

1. total_reward_shares_for_hiders[newrrently holds 2, accrued from those
hides. Rolling 0→1 must pass 2 back iwrong argument here is precisely what
left 4500000000000000 in the old cont
2. The fee arguments are global. _calHiderFee, so passing anything other
than 5000000 reprices every unclaimed

To unblock the two existing shares yoso two calls: 0→1 passing
totalHidersPrev = 2, then 1→2 passing_for_hiders[2] reads at that moment (0
now, +1 per hide while you sit at weeys 4,987,167 per share; the contract's
11,800,000 covers both claims with $1

Side effect: positions are per-week,  after each rollover. That's by design.

B. Which contract fixes are actually

Headline: none of them. Claim works tre's the honest split:

┌───────────────────────────────────────────────────────────────────────┐
│                     Issue                     Effect                  │
│                                               │  claim?  │                                         │
├───────────────────────────────────────────────────────────────────────┤
│                                    n't tell claimed from unclaimed —  │
│ No claimed_rewards getter           showing the amount, button        │
│                                    ts 'Reward already claimed'        │
├───────────────────────────────────────────────────────────────────────┤
│ Fee repricing (currentHiderFee not risk, because manual rollover      │
│                                    s fees every time                  │
├───────────────────────────────────────────────────────────────────────┤
│ validate_treasure_coordinates readsbites when validating a past week; │
│  currentGameWeek not the gameWeek aer shares need a backend anyway    │
├───────────────────────────────────────────────────────────────────────┤
│ GTR never transferred              ows a GTR figure claim_reward      │
│                                     pays                              │
├───────────────────────────────────────────────────────────────────────┤
│ _calculateRewardDue underflow (asseat current values                  │
│ landowner fee)                                                        │
└───────────────────────────────────────────────────────────────────────┘
