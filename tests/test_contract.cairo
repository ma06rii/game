// DeclareResultTrait is what exposes contract_class() on the DeclareResult that
// declare() returns from snforge_std v0.62 onward.
use core::hash::HashStateTrait;
use core::num::traits::zero::Zero;
use core::poseidon::PoseidonTrait;
use openzeppelin::access::accesscontrol::interface::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use project_name::mock_erc20::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};
use project_name::{
    IGameAdministrationDispatcher, IGameAdministrationDispatcherTrait,
    IGameAdministrationSafeDispatcher, IGameAdministrationSafeDispatcherTrait,
    IHelloStarknetDispatcher, IHelloStarknetDispatcherTrait, IHelloStarknetSafeDispatcher,
    IHelloStarknetSafeDispatcherTrait, NextRoundParams,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyTrait, EventsFilterTrait, declare,
    get_class_hash, spy_events, start_cheat_block_timestamp, start_cheat_caller_address,
    stop_cheat_caller_address, store,
};
use starknet::{ContractAddress, contract_address_const};

fn admin_address() -> ContractAddress {
    contract_address_const::<0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833>()
}

fn pauser_address() -> ContractAddress {
    contract_address_const::<0x515e>()
}

// The game contract's constructor takes the VRF provider, game token, ROZ
// reward token, round keeper, admin, pauser, and upgrade delay. This minimal
// harness uses production-shaped addresses plus distinct admin/pauser wallets;
// token-moving tests use deploy_wired below instead.
fn deploy_contract(name: ByteArray) -> ContractAddress {
    // declare() returns a DeclareResult from snforge_std v0.62 onward, so the
    // ContractClass has to be taken out of it before deploy() can be called.
    // Under the old v0.24 API declare() returned the class directly.
    let contract = declare(name).unwrap().contract_class();

    let vrfProviderAddress: ContractAddress = contract_address_const::<
        0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f,
    >();

    // USDC on Sepolia - 6 decimals, which is what the fee constants assume.
    let gameTokenAddress: ContractAddress = contract_address_const::<
        0x0512feac6339ff7889822cb5aa2a86c848e9d392bb0e3e237c008674feed8343,
    >();

    // The ROZ reward token, deliberately left UNSET here.
    //
    // Zero is the honest pre-configuration state - the game contract is
    // deployed before any reward token is wired up - and it exercises the
    // documented behaviour that matters most: _accrueRewardToken skips the
    // credit and emits RewardTokenAccrualSkipped rather than reverting, so
    // hiding, moving and spawning all still work with no reward token at all.
    //
    // A non-zero address pointing at a contract that is not deployed would
    // NOT behave this way: balance_of would revert and take the whole gameplay
    // action with it. See the note on _accrueRewardToken.
    let rewardTokenAddress: ContractAddress = contract_address_const::<0>();

    let mut constructorCalldata = ArrayTrait::<felt252>::new();
    constructorCalldata.append(vrfProviderAddress.into());
    constructorCalldata.append(gameTokenAddress.into());
    constructorCalldata.append(rewardTokenAddress.into());
    constructorCalldata
        .append(
            contract_address_const::<
                0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833,
            >()
                .into(),
        );
    constructorCalldata
        .append(
            contract_address_const::<
                0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833,
            >()
                .into(),
        );
    constructorCalldata.append(contract_address_const::<0x515e>().into());
    constructorCalldata.append(100);

    let (contract_address, _) = contract.deploy(@constructorCalldata).unwrap();
    contract_address
}

// Spawn, then hop - the two steps in the order the contract requires.
//
// This previously called finder_player_move_position on a player who had never
// spawned, so it always failed on the contract's own 'gamer does not have
// coordinates' rule. It could not have got that far in any case: deploy_contract
// wires neither a VRF provider nor a deployed game token, so the spawn it never
// made would have reverted too.
//
// The comment on the original also described a second behaviour it never
// exercised - that spawning twice should be refused - so that is asserted here
// as well.
#[test]
#[feature("safe_dispatcher")]
fn test_spawn_then_hop_and_reject_duplicate_spawn() {
    let player: ContractAddress = contract_address_const::<0xc0ffee>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address: game };

    let gameWeek = dispatcher.get_game_week();

    // 1. Spawn. The position comes from MockVrfProvider, so it is random but
    //    always on the board.
    start_cheat_caller_address(game, player);
    dispatcher.finder_player_generate_position();
    stop_cheat_caller_address(game);

    let (spawnX, spawnY) = dispatcher.get_finder_player_position(player, gameWeek);
    assert(spawnX != 0, 'spawn should set x');
    assert(spawnY != 0, 'spawn should set y');

    // 2. Spawning again must be refused - the player is already on the board.
    start_cheat_caller_address(game, player);
    let secondSpawn = safe_dispatcher.finder_player_generate_position();
    stop_cheat_caller_address(game);

    assert(secondSpawn.is_err(), 'second spawn must be refused');

    // 3. Now the hop works, because the player holds coordinates.
    start_cheat_caller_address(game, player);
    hop_safely(game, player);
    stop_cheat_caller_address(game);

    let (afterX, afterY) = dispatcher.get_finder_player_position(player, gameWeek);

    // hop_safely moves along x, so y is untouched and x has shifted by one.
    assert(afterY == spawnY, 'hop should not move y');
    assert(afterX != spawnX, 'hop should move x');
}

// ---------------------------------------------------------------------------
// ROZ reward settings (section 7)
// ---------------------------------------------------------------------------
//
// These exercise the parts of the plan that can be checked without moving
// tokens. Anything that charges a fee needs a deployed ERC-20 and an approval,
// which this harness does not set up - so the behavioural tests in section 7
// (5e, 5e-v, 5g, 17a-iii) still need a mock token before they can run.

// Every value the constructor is supposed to write, read back through the
// getters. This is the cheapest possible guard against a typo in a literal -
// getting hopRewardBelowThreshold wrong by a factor of ten would be invisible
// until a farm showed up.
#[test]
fn test_reward_settings_defaults() {
    let contract_address = deploy_contract("HelloStarknet");
    // These values no longer come from the constructor - the class does not
    // set its own defaults any more. Run the documented post-deploy sequence,
    // so this test now proves the RUNBOOK produces them.
    initialise_game_settings(contract_address);
    let dispatcher = IHelloStarknetDispatcher { contract_address };

    // Full rates, raw 18-decimal ROZ.
    let (hide, hideSurvived, find, participation, perHop) = dispatcher.get_reward_rates();
    assert(hide == 30000000000000000000, 'hide != 30');
    assert(hideSurvived == 50000000000000000000, 'hideSurvived != 50');
    assert(find == 110000000000000000000, 'find != 110');
    assert(participation == 18000000000000000000, 'participation != 18');
    assert(perHop == 1000000000000000000, 'perHop != 1');

    // Below the daily spend threshold. The participation bonus is WITHDRAWN
    // here, not reduced - zero is the intended value, not a missing one.
    let (belowHop, belowPart, belowHide, belowSurv) = dispatcher.get_below_threshold_rates();
    assert(belowHop == 150000000000000000, 'belowHop != 0.15');
    assert(belowPart == 0, 'belowPart != 0');
    assert(belowHide == 4500000000000000000, 'belowHide != 4.5');
    assert(belowSurv == 7500000000000000000, 'belowSurv != 7.5');

    // New wallet, under $3 of lifetime spend.
    let (newHop, newPart, newHide, newSurv) = dispatcher.get_new_wallet_rates();
    assert(newHop == 500000000000000000, 'newHop != 0.5');
    assert(newPart == 9000000000000000000, 'newPart != 9');
    assert(newHide == 15000000000000000000, 'newHide != 15');
    assert(newSurv == 25000000000000000000, 'newSurv != 25');
}

// The two orderings the design rests on, and the gate thresholds.
#[test]
fn test_hop_limits_and_gate_thresholds() {
    let contract_address = deploy_contract("HelloStarknet");
    // These values no longer come from the constructor - the class does not
    // set its own defaults any more. Run the documented post-deploy sequence,
    // so this test now proves the RUNBOOK produces them.
    initialise_game_settings(contract_address);
    let dispatcher = IHelloStarknetDispatcher { contract_address };

    let (participationMin, roundCap, freeHops, freeSpawns) = dispatcher.get_hop_limits();
    assert(participationMin == 28, 'participationMin != 28');
    assert(roundCap == 40, 'roundCap != 40');
    assert(freeHops == 20, 'freeHops != 20');
    assert(freeSpawns == 1, 'freeSpawns != 1');

    // The ordering that stops the 18-ROZ bonus being had for nothing.
    assert(freeHops < participationMin, 'free hops >= participation');
    assert(participationMin <= roundCap, 'participation > round cap');

    let (dailyThreshold, lifetimeThreshold) = dispatcher.get_gate_thresholds();
    assert(dailyThreshold == 600000, 'daily != 0.60');
    assert(lifetimeThreshold == 3000000, 'lifetime != 3.00');
}

// THE INVARIANT. Three hides at the base fee must land a wallet exactly on the
// daily spend threshold, and it is the FEE TIER that carries it - not the daily
// cap, which is 10 and has no part in clearing the gate.
#[test]
fn test_hide_settings_and_gate_invariant() {
    let contract_address = deploy_contract("HelloStarknet");
    // These values no longer come from the constructor - the class does not
    // set its own defaults any more. Run the documented post-deploy sequence,
    // so this test now proves the RUNBOOK produces them.
    initialise_game_settings(contract_address);
    let dispatcher = IHelloStarknetDispatcher { contract_address };

    let (feeBase, feeHigh, tierBoundary, dailyCap, perRound) = dispatcher.get_hide_settings();
    assert(feeBase == 200000, 'feeBase != 0.20');
    assert(feeHigh == 250000, 'feeHigh != 0.25');
    assert(tierBoundary == 3, 'tierBoundary != 3');
    assert(dailyCap == 10, 'dailyCap != 10');
    assert(perRound == 2840, 'perRound != 2840');

    let (dailyThreshold, _) = dispatcher.get_gate_thresholds();

    // 3 * 200000 == 600000
    assert(tierBoundary * feeBase == dailyThreshold, 'gate invariant broken');

    // And explicitly NOT the daily cap: 10 * 200000 is 2000000, which is the
    // relationship it is easy to write by mistake.
    assert(dailyCap * feeBase != dailyThreshold, 'cap must not clear the gate');
}

// The whitelist caps, and the floor they leave ordinary players.
#[test]
fn test_whitelist_caps_leave_a_floor() {
    let contract_address = deploy_contract("HelloStarknet");
    // These values no longer come from the constructor - the class does not
    // set its own defaults any more. Run the documented post-deploy sequence,
    // so this test now proves the RUNBOOK produces them.
    initialise_game_settings(contract_address);
    let dispatcher = IHelloStarknetDispatcher { contract_address };

    let (roundCap, collectiveCap, hourlyCap) = dispatcher.get_whitelist_caps();
    assert(roundCap == 250, 'roundCap != 250');
    assert(collectiveCap == 1200, 'collectiveCap != 1200');
    assert(hourlyCap == 80, 'hourlyCap != 80');

    let (_, _, _, _, perRound) = dispatcher.get_hide_settings();

    // 2,840 - 1,200 = 1,640 slots always available to ordinary players,
    // whatever the list length. Without the collective cap, eleven whitelisted
    // addresses at 250 each would leave only 90.
    assert(perRound - collectiveCap == 1640, 'floor != 1640');
    assert(collectiveCap <= perRound, 'group cap above round cap');

    // No root until the admin publishes one, so nobody is whitelisted yet.
    assert(dispatcher.get_whitelist_merkle_root() == 0, 'root should start unset');
}

// The Daily Volume Multiplier bands. Band 0 covering three treasures is what
// lines up with the fee tier and the gate.
#[test]
fn test_volume_multiplier_bands() {
    let contract_address = deploy_contract("HelloStarknet");
    // These values no longer come from the constructor - the class does not
    // set its own defaults any more. Run the documented post-deploy sequence,
    // so this test now proves the RUNBOOK produces them.
    initialise_game_settings(contract_address);
    let dispatcher = IHelloStarknetDispatcher { contract_address };

    let (limit0, num0, den0) = dispatcher.get_volume_band(0);
    assert(limit0 == 2, 'band0 limit != 2');
    assert(num0 == 1 && den0 == 1, 'band0 != 1.00x');

    let (limit1, num1, den1) = dispatcher.get_volume_band(1);
    assert(limit1 == 4, 'band1 limit != 4');
    assert(num1 == 7 && den1 == 10, 'band1 != 0.70x');

    let (_, num4, den4) = dispatcher.get_volume_band(4);
    assert(num4 == 2 && den4 == 25, 'band4 != 0.08x');

    // The tail, reachable only by a whitelisted address since dailyHideCap
    // stops everybody else at 10.
    let (_, num5, den5) = dispatcher.get_volume_band(5);
    assert(num5 == 3 && den5 == 100, 'band5 != 0.03x');
}

// The soft cap covers hops and participation only. 136 sits just under the
// 136.35 a 160-hop day can reach, so it binds almost nothing - by design.
#[test]
fn test_soft_caps() {
    let contract_address = deploy_contract("HelloStarknet");
    // These values no longer come from the constructor - the class does not
    // set its own defaults any more. Run the documented post-deploy sequence,
    // so this test now proves the RUNBOOK produces them.
    initialise_game_settings(contract_address);
    let dispatcher = IHelloStarknetDispatcher { contract_address };

    let (dailyCap, newWalletCap, num, den) = dispatcher.get_soft_caps();
    assert(dailyCap == 136000000000000000000, 'dailySoftCap != 136');
    assert(newWalletCap == 80000000000000000000, 'newWalletCap != 80');
    assert(num == 1 && den == 5, 'soft cap != 0.2x');
}

// A fresh wallet has the full free hop allowance and no accrued ROZ.
#[test]
fn test_fresh_wallet_state() {
    let contract_address = deploy_contract("HelloStarknet");
    // These values no longer come from the constructor - the class does not
    // set its own defaults any more. Run the documented post-deploy sequence,
    // so this test now proves the RUNBOOK produces them.
    initialise_game_settings(contract_address);
    let dispatcher = IHelloStarknetDispatcher { contract_address };

    let player: ContractAddress = contract_address_const::<0x1234>();

    assert(dispatcher.get_free_hops_remaining(player) == 20, 'free hops != 20');
    assert(dispatcher.get_player_lifetime_spend(player) == 0, 'lifetime spend != 0');
    assert(dispatcher.get_reward_token_pending(player) == 0, 'pending != 0');
    assert(dispatcher.get_total_reward_token_pending() == 0, 'total pending != 0');

    let (hopsToday, rozToday, hidesToday, spendToday, freeUsed) = dispatcher
        .get_player_daily_state(player);
    assert(hopsToday == 0, 'hopsToday != 0');
    assert(rozToday == 0, 'rozToday != 0');
    assert(hidesToday == 0, 'hidesToday != 0');
    assert(spendToday == 0, 'spendToday != 0');
    assert(freeUsed == 0, 'freeUsed != 0');
}

// The reward token is deliberately left unset by this harness, which is the
// state the game contract is deployed in before phase 1 wires ROZ up.
#[test]
fn test_reward_token_starts_unset() {
    let contract_address = deploy_contract("HelloStarknet");
    let dispatcher = IHelloStarknetDispatcher { contract_address };

    let rewardToken = dispatcher.get_game_reward_token();
    assert(rewardToken == contract_address_const::<0>(), 'reward token should be unset');
}

// ---------------------------------------------------------------------------
// Behavioural tests (section 7)
// ---------------------------------------------------------------------------
//
// These need real tokens. Two MockERC20s are deployed - one standing in for the
// game token (USDC) and one for ROZ - the player is funded and approves the
// game contract, and the game contract is funded with ROZ so the coverage rule
// in 4c-i lets rewards accrue.
//
// THEY ALL EXERCISE THE HIDE PATH, not the hop path. Hopping asserts the player
// already holds coordinates, and spawning to get them goes through the VRF
// provider - a much larger harness for no extra coverage of the anti-farm
// arithmetic, which lives in the fee tiers, the rate resolution and the volume
// multiplier. All three are reached through hiding.

const STAKE: u256 = 5000000; // $5.00 hider stake, refundable
const FEE_BASE: u256 = 200000; // $0.20, treasures 1-3 of the day
const FEE_HIGH: u256 = 250000; // $0.25, treasure 4 onward

fn deploy_mock_token(name: ByteArray, symbol: ByteArray) -> ContractAddress {
    let contract = declare("MockERC20").unwrap().contract_class();

    let mut calldata = ArrayTrait::<felt252>::new();
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);

    let (token_address, _) = contract.deploy(@calldata).unwrap();
    token_address
}

// Deploys the game contract with both tokens wired up, funds the player, and
// funds the contract with ROZ. Returns (game, gameToken, rewardToken).
// The ordinary harness: a game funded with plenty of ROZ, so rewards land.
fn deploy_wired(
    player: ContractAddress, playerFunds: u256,
) -> (ContractAddress, ContractAddress, ContractAddress) {
    deploy_wired_with_roz(player, playerFunds, 1000000000000000000000)
}

// The same harness with the ROZ funding chosen by the caller.
//
// Pass 0 to get a contract that cannot pay any reward - the state every
// deployment starts in, and the one the missed-ROZ ledger exists for. Pass a
// deliberately small figure to test a PARTIAL recovery, where the contract can
// cover some of a player's backlog but not all of it.
fn deploy_wired_with_roz(
    player: ContractAddress, playerFunds: u256, rozFunding: u256,
) -> (ContractAddress, ContractAddress, ContractAddress) {
    let gameToken = deploy_mock_token("MockUSDC", "mUSDC");
    let rewardToken = deploy_mock_token("MockROZ", "mROZ");

    let contract = declare("HelloStarknet").unwrap().contract_class();

    // The real Cartridge provider is not deployed in a test environment, so
    // consume_random would revert and take spawning with it. MockVrfProvider
    // implements the same IVrfProvider interface and never reverts, which is
    // the whole reason it exists - see src/mock_vrf_provider.cairo.
    let vrfClass = declare("MockVrfProvider").unwrap().contract_class();
    let (vrfProviderAddress, _) = vrfClass.deploy(@ArrayTrait::<felt252>::new()).unwrap();

    let mut constructorCalldata = ArrayTrait::<felt252>::new();
    constructorCalldata.append(vrfProviderAddress.into());
    constructorCalldata.append(gameToken.into());
    constructorCalldata.append(rewardToken.into());
    constructorCalldata
        .append(
            contract_address_const::<
                0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833,
            >()
                .into(),
        );
    constructorCalldata
        .append(
            contract_address_const::<
                0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833,
            >()
                .into(),
        );
    constructorCalldata.append(contract_address_const::<0x515e>().into());
    constructorCalldata.append(100);

    let (game, _) = contract.deploy(@constructorCalldata).unwrap();

    // Fund the player and let the game contract spend on their behalf.
    IMockERC20Dispatcher { contract_address: gameToken }.mint(player, playerFunds);

    start_cheat_caller_address(gameToken, player);
    ERC20ABIDispatcher { contract_address: gameToken }.approve(game, playerFunds);
    stop_cheat_caller_address(gameToken);

    // Fund the game with ROZ. Without this the coverage rule refuses every
    // credit and rewards silently read back as zero - which would make these
    // tests pass for the wrong reason.
    if (rozFunding > 0) {
        IMockERC20Dispatcher { contract_address: rewardToken }.mint(game, rozFunding);
    }

    // The class no longer sets its own defaults - see the constructor comment
    // in lib.cairo. Run the documented post-deploy sequence so every test below
    // starts from the same state the old _initialiseRewardSettings produced.
    initialise_game_settings(game);

    (game, gameToken, rewardToken)
}

// The post-deploy initialisation sequence, exactly as
// ROZ_DEPLOYMENT_AND_FUNDING.md specifies it for a real deployment. Keeping the
// tests on the same path as the runbook means a mistake in the runbook shows up
// here as a failing test rather than on mainnet.
//
// The values are the ones _initialiseRewardSettings used to write, so every
// assertion in this file keeps its original meaning.
//
// THREE ORDERING RULES, all enforced by asserts in the setters:
//
//   1. update_gate_thresholds BEFORE update_hide_settings
//      - the latter asserts feeTierBoundary * feeBase == dailySpendThreshold.
//   2. update_hide_settings BEFORE update_whitelist_caps
//      - the latter asserts collectiveCap <= maxTreasuresPerRound.
//   3. unpause LAST, and as the pauser - the contract deploys paused so that a
//      half-initialised game cannot be played.
fn initialise_game_settings(game: ContractAddress) {
    let admin: ContractAddress = contract_address_const::<
        0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833,
    >();
    let pauser: ContractAddress = contract_address_const::<0x515e>();

    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, admin);

    // ALL THIRTY-FIVE SCALAR SETTINGS IN ONE BATCH. set_params validates the
    // whole configuration after applying it, so on a freshly deployed contract -
    // where every setting is zero - the first batch has to carry all of them.
    // Splitting this into two calls fails 'free hops >= participation' on the
    // first, which is the behaviour that stops a half-configured game running.
    dispatcher
        .set_params(
            array![
                // Full rates, raw 18-decimal ROZ.
                'rewardHide', 'rewardHideSurvived', 'rewardFind', 'rewardParticipation',
                'rewardPerHop',
                // Below the daily spend threshold. Absolute values, never multipliers.
                'hopRewardBelowThreshold', 'participationBelowThreshold',
                'rewardHideBelowThreshold', 'hideSurvivedBelowThreshold',
                // New wallet, under $3 of lifetime spend.
                'hopRewardNewWallet', 'participationNewWallet', 'rewardHideNewWallet',
                'rewardHideSurvivedNewWallet',
                // Limits and allowances. Free hops stay strictly below the minimum.
                'participationMinimumHops', 'hopRewardCap', 'dailyFreeHops',
                'dailyFreeSpawns',
                // Soft caps.
                'dailySoftCapRoz', 'newWalletSoftCapRoz', 'softCapMultiplierNum',
                'softCapMultiplierDen',
                // The Lightweight Gate.
                'dailySpendThreshold', 'lifetimeSpendThreshold',
                // Hiding.
                'hideFeeBase', 'hideFeeHigh', 'hideFeeTierBoundary', 'dailyHideCap',
                'maxTreasuresPerRound',
                // Whitelist.
                'whitelistRoundCap', 'whitelistCollectiveCap', 'whitelistHourlyCap',
                // Per-transaction fees.
                'gasFeeReservation', 'gameMasterFee', 'gameLandownerFee',
                'minimumAllowance',
            ],
            array![
                30000000000000000000, // rewardHide                       30
                50000000000000000000, // rewardHideSurvived               50
                110000000000000000000, // rewardFind                      110
                18000000000000000000, // rewardParticipation              18
                1000000000000000000, // rewardPerHop                      1
                150000000000000000, // hopRewardBelowThreshold            0.15
                0, // participationBelowThreshold                         withdrawn
                4500000000000000000, // rewardHideBelowThreshold          4.5
                7500000000000000000, // hideSurvivedBelowThreshold        7.5
                500000000000000000, // hopRewardNewWallet                 0.5
                9000000000000000000, // participationNewWallet            9
                15000000000000000000, // rewardHideNewWallet              15
                25000000000000000000, // rewardHideSurvivedNewWallet      25
                28, // participationMinimumHops
                40, // hopRewardCap                                       per ROUND
                20, // dailyFreeHops                                      below 28
                1, // dailyFreeSpawns
                136000000000000000000, // dailySoftCapRoz                 136
                80000000000000000000, // newWalletSoftCapRoz              80
                1, // softCapMultiplierNum                                0.2x
                5, // softCapMultiplierDen
                600000, // dailySpendThreshold                            $0.60
                3000000, // lifetimeSpendThreshold                        $3.00
                200000, // hideFeeBase                                    $0.20
                250000, // hideFeeHigh                                    $0.25
                3, // hideFeeTierBoundary          3 x 200000 == 600000
                10, // dailyHideCap
                2840, // maxTreasuresPerRound
                250, // whitelistRoundCap
                1200, // whitelistCollectiveCap     leaves 1,640 for others
                80, // whitelistHourlyCap
                3333, // gasFeeReservation                               $0.0033
                8333, // gameMasterFee                                   $0.0083
                1167, // gameLandownerFee                                $0.0012
                7000000, // minimumAllowance                             $7.00
            ],
        );

    // Progressive hop prices. Band 3 is open-ended.
    dispatcher.update_hop_price_band(0, 25, 5000); // $0.005
    dispatcher.update_hop_price_band(1, 45, 10000); // $0.010
    dispatcher.update_hop_price_band(2, 65, 20000); // $0.020
    dispatcher.update_hop_price_band(3, 0xffffffffffffffffffffffffffffffff, 40000); // $0.040

    // The Daily Volume Multiplier. Band 5 is the open-ended tail.
    dispatcher.update_volume_band(0, 2, 1, 1); // 1.00x
    dispatcher.update_volume_band(1, 4, 7, 10); // 0.70x
    dispatcher.update_volume_band(2, 6, 2, 5); // 0.40x
    dispatcher.update_volume_band(3, 8, 1, 5); // 0.20x
    dispatcher.update_volume_band(4, 10, 2, 25); // 0.08x
    dispatcher.update_volume_band(5, 0xffffffffffffffffffffffffffffffff, 3, 100); // 0.03x

    stop_cheat_caller_address(game);

    // The whitelist merkle root is deliberately left at zero. Storage is
    // zero-initialised, so no write is needed, and a zero root means every
    // proof fails - nobody whitelisted, which is the correct starting state.

    // Unpause last, and only as the pauser: PAUSE_ROLE is deliberately not
    // held by the admin.
    start_cheat_caller_address(game, pauser);
    IGameAdministrationDispatcher { contract_address: game }.unpause();
    stop_cheat_caller_address(game);
}

// TEST 5e - THE HIGHEST-VALUE ASSERTION IN THE SUITE.
//
// A hide moves $5.20: a $5.00 stake and a $0.20 fee. Only the FEE is spend.
// The stake is refundable, so counting it would let a farmer clear the $3
// lifetime gate for the $0.2128 a surviving hide really costs - 14x cheaper -
// and both gate measures would be void.
//
// Assert the NUMBER, not merely that it is non-zero: 15600000 would mean the
// stake is counting.
#[test]
fn test_hide_fee_is_spend_but_stake_is_not() {
    let player: ContractAddress = contract_address_const::<0x1111>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    dispatcher.hide_treasure();
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    let (_, _, hidesToday, spendToday, _) = dispatcher.get_player_daily_state(player);

    assert(hidesToday == 3, 'should have hidden 3');

    // 3 x $0.20 of fee. NOT 15600000, which would include the $15 of stake.
    assert(spendToday == 600000, 'spend must be fees only');
    assert(dispatcher.get_player_lifetime_spend(player) == 600000, 'lifetime must be fees only');
}

// TEST 5e continued - three hides land the wallet EXACTLY on the gate.
//
// hideFeeTierBoundary (3) x hideFeeBase (200000) == dailySpendThreshold
// (600000). This is the calibration the setter assertion protects, verified
// end to end rather than by reading the settings back.
#[test]
fn test_three_hides_land_exactly_on_the_gate() {
    let player: ContractAddress = contract_address_const::<0x2222>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    let (dailyThreshold, _) = dispatcher.get_gate_thresholds();

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    dispatcher.hide_treasure();
    let (_, _, _, spendAfterTwo, _) = dispatcher.get_player_daily_state(player);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    let (_, _, _, spendAfterThree, _) = dispatcher.get_player_daily_state(player);

    assert(spendAfterTwo < dailyThreshold, 'two hides must be below');
    assert(spendAfterThree == dailyThreshold, 'three hides must land exact');
}

// TEST 5g - rates resolve to the LOWEST applicable value, never a product.
//
// A fresh wallet is BOTH new (lifetime under $3) and below the daily threshold,
// so the two reduced rates disagree and one must win outright.
//
// For the first hide of such a wallet:
//     correct:                4.5e18   the lower of 15 and 4.5
//     wrong, new-wallet only: 15e18
//     wrong, multiplied:      2.25e18  (30 x 0.5 x 0.15)
//
// This is the hide line rather than the hop line, but it is the SAME
// _resolveGatedRate function - hopping needs a spawned position and the VRF
// provider to reach.
#[test]
fn test_rates_resolve_to_lowest_and_never_multiply() {
    let player: ContractAddress = contract_address_const::<0x3333>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    let pending = dispatcher.get_reward_token_pending(player);

    assert(pending == 4500000000000000000, 'must be 4.5, the lowest');
    assert(pending != 15000000000000000000, 'must not be new-wallet only');
    assert(pending != 2250000000000000000, 'must not be multiplied');
}

// TEST 5e-v - A BULK OF N IS EXACTLY N SINGLE HIDES.
//
// This is the assertion that closes the hide loop. The Daily Volume Multiplier
// is keyed to the daily treasure count rather than to how many treasures are in
// the transaction, precisely so that splitting or combining calls gains
// nothing. If bulk were cheaper a farmer would batch; if it were dearer they
// would split. Neither may be worth doing.
#[test]
fn test_bulk_hide_equals_the_same_number_of_single_hides() {
    let singleHider: ContractAddress = contract_address_const::<0x4444>();
    let (gameA, _, _) = deploy_wired(singleHider, 200000000);
    let dispatcherA = IHelloStarknetDispatcher { contract_address: gameA };

    // Ten separate single hides.
    start_cheat_caller_address(gameA, singleHider);
    let mut placed: u32 = 0;
    loop {
        if (placed == 10) {
            break;
        }
        dispatcherA.hide_treasure();
        placed = placed + 1;
    }
    stop_cheat_caller_address(gameA);

    let singlePending = dispatcherA.get_reward_token_pending(singleHider);
    let (_, _, _, singleSpend, _) = dispatcherA.get_player_daily_state(singleHider);

    // A fresh contract, and one bulk call of ten.
    let bulkHider: ContractAddress = contract_address_const::<0x5555>();
    let (gameB, _, _) = deploy_wired(bulkHider, 200000000);
    let dispatcherB = IHelloStarknetDispatcher { contract_address: gameB };

    let emptyProof: Array<felt252> = ArrayTrait::new();

    start_cheat_caller_address(gameB, bulkHider);
    dispatcherB.hide_treasure_bulk(STAKE * 10, emptyProof, 0);
    stop_cheat_caller_address(gameB);

    let bulkPending = dispatcherB.get_reward_token_pending(bulkHider);
    let (_, _, bulkHides, bulkSpend, _) = dispatcherB.get_player_daily_state(bulkHider);

    assert(bulkHides == 10, 'bulk should place 10');
    assert(bulkPending == singlePending, 'bulk ROZ must equal singles');
    assert(bulkSpend == singleSpend, 'bulk spend must equal singles');

    // And the fee tier really did step up: 3 x $0.20 + 7 x $0.25.
    assert(singleSpend == (FEE_BASE * 3) + (FEE_HIGH * 7), 'fee tier wrong');
}

// TEST 5e-vi - THE HIDE EVENT REPORTS THE STAKE AND THE FEE SEPARATELY.
//
// The event used to carry ONE field called hiderFee, and it held a different
// quantity on each path - the refundable STAKE on a single hide, the retained
// FEE on a bulk one. An indexer summing that field added stakes to fees and got
// a meaningless total. TreasureHidden now carries both, named for what they are,
// and this test is what stops the two ever being confused again.
//
// The event is read RAW rather than through EventSpyAssertionsTrait, because the
// HelloStarknet module is not pub and its event types cannot be imported here.
// The wire layout being asserted is:
//
//   keys = [selector, user, gameWeek.low, gameWeek.high]
//   data = [hiderStake.low,      hiderStake.high,
//           totalFeeCharged.low, totalFeeCharged.high,
//           treasureCount.low,   treasureCount.high]
//
// Every figure here is below 2^128, so each .high limb is zero.
#[test]
fn test_hide_event_separates_the_stake_from_the_fee() {
    let hider: ContractAddress = contract_address_const::<0x6666>();
    let (game, _, _) = deploy_wired(hider, 200000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    let emptyProof: Array<felt252> = ArrayTrait::new();

    let mut spy = spy_events();

    start_cheat_caller_address(game, hider);
    dispatcher.hide_treasure_bulk(STAKE * 10, emptyProof, 0);
    stop_cheat_caller_address(game);

    // A hide also emits reward events, so pick out the hide event by selector.
    let events = spy.get_events().emitted_by(game);

    let mut found: u32 = 0;
    let mut hiderStake: u256 = 0;
    let mut totalFeeCharged: u256 = 0;
    let mut treasureCount: u256 = 0;
    let mut emittedGameWeek: u256 = 0;

    let mut i: u32 = 0;
    loop {
        if (i == events.events.len()) {
            break;
        }

        let (_, event) = events.events.at(i);

        if (*event.keys.at(0) == selector!("TreasureHidden")) {
            assert(event.keys.len() == 4, 'hide event key layout');
            assert(event.data.len() == 6, 'hide event data layout');
            found = found + 1;
            emittedGameWeek =
                u256 {
                    low: (*event.keys.at(2)).try_into().unwrap(),
                    high: (*event.keys.at(3)).try_into().unwrap(),
                };
            hiderStake =
                u256 {
                    low: (*event.data.at(0)).try_into().unwrap(),
                    high: (*event.data.at(1)).try_into().unwrap(),
                };
            totalFeeCharged =
                u256 {
                    low: (*event.data.at(2)).try_into().unwrap(),
                    high: (*event.data.at(3)).try_into().unwrap(),
                };
            treasureCount =
                u256 {
                    low: (*event.data.at(4)).try_into().unwrap(),
                    high: (*event.data.at(5)).try_into().unwrap(),
                };
        }

        i = i + 1;
    }

    // ONE event for the whole call, not one for each of the ten treasures.
    assert(found == 1, 'one hide event for a bulk');
    assert(emittedGameWeek == 1, 'event week wrong');

    // The count travels in the event, so a single hide and a bulk no longer
    // need two different event shapes to tell them apart.
    assert(treasureCount == 10, 'event count must be 10');

    // The stake is the aggregate, and it divides exactly - the stake rate does
    // not tier.
    assert(hiderStake == STAKE * 10, 'event stake wrong');

    // The fee is the aggregate of the tiers actually charged: 3 x $0.20 then
    // 7 x $0.25. It does NOT divide by the count.
    assert(totalFeeCharged == (FEE_BASE * 3) + (FEE_HIGH * 7), 'event fee wrong');

    // The two fields carry different money. This is the defect itself: if one
    // ever equals the other, the stake has leaked into the fee field again.
    assert(hiderStake != totalFeeCharged, 'stake must not be the fee');

    // Only the fee reaches the spend counters - never the stake (2.6 rule 1).
    let (_, _, _, spend, _) = dispatcher.get_player_daily_state(hider);
    assert(totalFeeCharged == spend, 'event fee must equal spend');
}

// TEST 5e-vii - A SINGLE HIDE EMITS THE SAME EVENT SHAPE, WITH A COUNT OF ONE.
//
// The single and bulk paths used to emit different events. They are one event
// now, so the equivalence 5e-v proves in STORAGE has to hold on the LOG too.
#[test]
fn test_single_hide_emits_the_same_event_with_count_one() {
    let hider: ContractAddress = contract_address_const::<0x7777>();
    let (game, _, _) = deploy_wired(hider, 200000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    let mut spy = spy_events();

    start_cheat_caller_address(game, hider);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    let events = spy.get_events().emitted_by(game);

    let mut found: u32 = 0;
    let mut hiderStake: u256 = 0;
    let mut totalFeeCharged: u256 = 0;
    let mut treasureCount: u256 = 0;
    let mut emittedGameWeek: u256 = 0;

    let mut i: u32 = 0;
    loop {
        if (i == events.events.len()) {
            break;
        }

        let (_, event) = events.events.at(i);

        if (*event.keys.at(0) == selector!("TreasureHidden")) {
            assert(event.keys.len() == 4, 'hide event key layout');
            assert(event.data.len() == 6, 'hide event data layout');
            found = found + 1;
            emittedGameWeek =
                u256 {
                    low: (*event.keys.at(2)).try_into().unwrap(),
                    high: (*event.keys.at(3)).try_into().unwrap(),
                };
            hiderStake =
                u256 {
                    low: (*event.data.at(0)).try_into().unwrap(),
                    high: (*event.data.at(1)).try_into().unwrap(),
                };
            totalFeeCharged =
                u256 {
                    low: (*event.data.at(2)).try_into().unwrap(),
                    high: (*event.data.at(3)).try_into().unwrap(),
                };
            treasureCount =
                u256 {
                    low: (*event.data.at(4)).try_into().unwrap(),
                    high: (*event.data.at(5)).try_into().unwrap(),
                };
        }

        i = i + 1;
    }

    assert(found == 1, 'one hide event for a single');
    assert(emittedGameWeek == 1, 'event week wrong');
    assert(treasureCount == 1, 'event count must be 1');

    // The first treasure of the day, so the base tier - and the stake is the
    // single-treasure stake, which is the value the old event carried under the
    // name hiderFee.
    assert(hiderStake == STAKE, 'single stake wrong');
    assert(totalFeeCharged == FEE_BASE, 'single fee wrong');
    assert(hiderStake != totalFeeCharged, 'stake must not be the fee');
}

// The Daily Volume Multiplier, measured one treasure at a time.
//
// COMPARE LIKE WITH LIKE. The first two treasures of a fresh wallet are cheap
// for a different reason - the wallet is still below the daily spend threshold,
// so they pay 4.5 rather than 15. The curve itself only becomes visible from
// treasure 3 onward, once the gate has been crossed and the wallet is on the
// flat new-wallet rate of 15. Comparing treasure 10 against treasure 1 measures
// the gate, not the curve, and gets the wrong answer:
//
//   ten treasures earn 64.2 ROZ, which is MORE than ten first-treasures (45),
//   because the first treasure is unusually cheap rather than unusually dear.
//
// So this walks the marginal reward instead, which is what the curve actually
// governs:
//
//   treasure 3  band 1.00x  ->  15.0
//   treasure 4  band 0.70x  ->  10.5
//   treasure 10 band 0.08x  ->   1.2
#[test]
fn test_volume_multiplier_reduces_later_treasures() {
    let player: ContractAddress = contract_address_const::<0x6666>();
    let (game, _, _) = deploy_wired(player, 200000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);

    // Treasures 1 and 2 - below the gate, so 4.5 each.
    dispatcher.hide_treasure();
    dispatcher.hide_treasure();
    let afterTwo = dispatcher.get_reward_token_pending(player);
    assert(afterTwo == 9000000000000000000, 'first two should be 4.5 each');

    // Treasure 3 crosses the gate and sits in the 1.00x band.
    dispatcher.hide_treasure();
    let afterThree = dispatcher.get_reward_token_pending(player);
    let marginalThree = afterThree - afterTwo;
    assert(marginalThree == 15000000000000000000, 'treasure 3 should be 15');

    // Treasure 4 is the first in the 0.70x band.
    dispatcher.hide_treasure();
    let afterFour = dispatcher.get_reward_token_pending(player);
    let marginalFour = afterFour - afterThree;
    assert(marginalFour == 10500000000000000000, 'treasure 4 should be 10.5');

    // Walk out to treasure 10, the last an ordinary wallet may place.
    let mut placed: u32 = 4;
    let mut previous = afterFour;
    loop {
        if (placed == 9) {
            break;
        }
        dispatcher.hide_treasure();
        previous = dispatcher.get_reward_token_pending(player);
        placed = placed + 1;
    }

    dispatcher.hide_treasure();
    let afterTen = dispatcher.get_reward_token_pending(player);
    let marginalTen = afterTen - previous;

    stop_cheat_caller_address(game);

    // The 0.08x band.
    assert(marginalTen == 1200000000000000000, 'treasure 10 should be 1.2');

    // THE PROPERTY THAT MATTERS: each later treasure earns strictly less than
    // the one before it, once the gate is out of the way.
    assert(marginalFour < marginalThree, 'curve must fall at band 1');
    assert(marginalTen < marginalFour, 'curve must keep falling');

    // And the whole day comes to 64.2 ROZ, which is the figure the farm
    // economics in 4l-ii are built on.
    assert(afterTen == 64200000000000000000, 'ten hides should total 64.2');
}

// The per-wallet daily cap. An eleventh treasure must be refused.
#[test]
#[feature("safe_dispatcher")]
fn test_daily_hide_cap_stops_the_eleventh() {
    let player: ContractAddress = contract_address_const::<0x7777>();
    let (game, _, _) = deploy_wired(player, 200000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    let safe = IHelloStarknetSafeDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);

    let mut placed: u32 = 0;
    loop {
        if (placed == 10) {
            break;
        }
        dispatcher.hide_treasure();
        placed = placed + 1;
    }

    // The eleventh must revert rather than quietly succeed.
    let eleventh = safe.hide_treasure();

    stop_cheat_caller_address(game);

    assert(eleventh.is_err(), '11th hide must revert');

    let (_, _, hidesToday, _, _) = dispatcher.get_player_daily_state(player);
    assert(hidesToday == 10, 'count must stay at 10');
}

// The cap counts TREASURES, not calls - so a bulk of eleven is refused just as
// eleven single hides would be. Without this a farmer places a whole round's
// worth from one wallet for the gas of a single transaction.
#[test]
#[feature("safe_dispatcher")]
fn test_daily_cap_counts_treasures_not_calls() {
    let player: ContractAddress = contract_address_const::<0x8888>();
    let (game, _, _) = deploy_wired(player, 2000000000);
    let safe = IHelloStarknetSafeDispatcher { contract_address: game };

    let emptyProof: Array<felt252> = ArrayTrait::new();

    start_cheat_caller_address(game, player);
    let oversized = safe.hide_treasure_bulk(STAKE * 11, emptyProof, 0);
    stop_cheat_caller_address(game);

    assert(oversized.is_err(), 'bulk of 11 must revert');
}

// Accrued ROZ can be withdrawn, and the running total is kept honest so the
// sweep in 4j can tell the surplus from what players are owed.
#[test]
fn test_claim_reward_tokens_pays_and_clears() {
    let player: ContractAddress = contract_address_const::<0x9999>();
    let (game, _, rewardToken) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    let owed = dispatcher.get_reward_token_pending(player);
    assert(owed > 0, 'should have accrued');
    assert(dispatcher.get_total_reward_token_pending() == owed, 'total should match');

    start_cheat_caller_address(game, player);
    dispatcher.claim_reward_tokens();
    stop_cheat_caller_address(game);

    assert(dispatcher.get_reward_token_pending(player) == 0, 'pending should clear');
    assert(dispatcher.get_total_reward_token_pending() == 0, 'total should clear');

    let balance = ERC20ABIDispatcher { contract_address: rewardToken }.balance_of(player);
    assert(balance == owed, 'player should hold the ROZ');
}

// ---------------------------------------------------------------------------
// The hop path (2.5, 4l)
// ---------------------------------------------------------------------------
//
// Hopping asserts the player already holds coordinates, so every test below
// spawns first through MockVrfProvider. The spawn itself is free once a day and
// pays no ROZ at all, which the first test checks before moving on.

// Hops once, choosing a direction guaranteed to stay on the board.
//
// Directions are 0 = x-1, 1 = x+1, 2 = y-1, 3 = y+1, and a coordinate may
// never reach 0 or exceed the grid. The spawn point comes from the VRF mock so
// it is not known in advance, which rules out any fixed sequence of moves:
// walking x down toward 1 and then oscillating between 1 and 2 is legal from
// wherever the player happens to land, on any board size.
fn hop_safely(game: ContractAddress, player: ContractAddress) {
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    let gameWeek = dispatcher.get_game_week();
    let (x, _) = dispatcher.get_finder_player_position(player, gameWeek);

    if (x > 1) {
        dispatcher.finder_player_move_position(0);
    } else {
        dispatcher.finder_player_move_position(1);
    }
}

// A spawn puts the player on the board, costs nothing the first time, and earns
// nothing ever.
#[test]
fn test_first_spawn_is_free_and_pays_no_roz() {
    let player: ContractAddress = contract_address_const::<0xb001>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.finder_player_generate_position();
    stop_cheat_caller_address(game);

    let (_, _, _, spendToday, _) = dispatcher.get_player_daily_state(player);

    // The free spawn allowance covered it, so nothing was charged and nothing
    // reached the spend counters.
    assert(spendToday == 0, 'first spawn should be free');

    // A SPAWN PAYS NO ROZ - free or paid, first of the day or fifth. The daily
    // reward and streak bonus that used to hang off spawning are gone with it.
    assert(dispatcher.get_reward_token_pending(player) == 0, 'spawn must pay no ROZ');

    // And the player is now on the board.
    let (x, y) = dispatcher.get_finder_player_position(player, dispatcher.get_game_week());
    assert(x != 0 || y != 0, 'player should have a position');
}

// TEST 5e-i - A FREE HOP EARNS ROZ BUT IS NOT SPEND.
//
// This is the zero-cost sybil surface from 4l-i-a, measured directly. A wallet
// that never pays cannot clear the $0.60 gate, so its hops resolve to
// hopRewardBelowThreshold and it earns 20 x 0.15 = 3 ROZ a day for nothing
// but gas. That 3 ROZ is the figure the 780,822-wallet estimate rests on.
#[test]
fn test_free_hops_earn_but_never_count_as_spend() {
    let player: ContractAddress = contract_address_const::<0xb002>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.finder_player_generate_position();

    assert(dispatcher.get_free_hops_remaining(player) == 20, 'should start with 20');

    // Twenty free hops. Direction 1 and 2 alternate so the player walks
    // back and forth rather than off the edge of the 14x14 board.
    let mut hopped: u32 = 0;
    loop {
        if (hopped == 20) {
            break;
        }
        hop_safely(game, player);
        hopped = hopped + 1;
    }
    stop_cheat_caller_address(game);

    let (hopsToday, _, _, spendToday, freeUsed) = dispatcher.get_player_daily_state(player);

    assert(hopsToday == 20, 'should have hopped 20');
    assert(freeUsed == 20, 'all 20 free hops used');
    assert(dispatcher.get_free_hops_remaining(player) == 0, 'allowance should be spent');

    // NOTHING was charged, so nothing is spend - which is exactly why free play
    // alone can never clear the gate however many hops are taken.
    assert(spendToday == 0, 'free hops are not spend');
    assert(dispatcher.get_player_lifetime_spend(player) == 0, 'free hops not lifetime spend');

    // 20 x 0.15 = 3 ROZ. A free hop earns exactly what a paid hop by the same
    // wallet would - the rate is set by the gate, never by whether the hop was
    // charged for.
    assert(dispatcher.get_reward_token_pending(player) == 3000000000000000000, 'should be 3 ROZ');
}

// TEST 5e-i continued - PARTICIPATION IS LOCKED TWICE OVER for a free player.
//
// The wallet cannot reach 28 hops on a 20-hop allowance, and even if it could
// the bonus is withdrawn below the spend threshold. Either lock alone would be
// enough; keeping both costs nothing.
#[test]
fn test_free_player_cannot_reach_participation() {
    let player: ContractAddress = contract_address_const::<0xb003>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    let (participationMin, _, freeHops, _) = dispatcher.get_hop_limits();

    // The ordering that makes the first lock work.
    assert(freeHops < participationMin, 'free hops must be below 28');

    start_cheat_caller_address(game, player);
    dispatcher.finder_player_generate_position();

    let mut hopped: u32 = 0;
    loop {
        if (hopped == 20) {
            break;
        }
        hop_safely(game, player);
        hopped = hopped + 1;
    }
    stop_cheat_caller_address(game);

    // 3 ROZ and not a unit more. An 18-ROZ participation bonus on top would
    // be immediately visible here.
    assert(dispatcher.get_reward_token_pending(player) == 3000000000000000000, 'no bonus expected');
}

// The 2.5 tier prices, and the fact that a paid hop DOES count as spend.
//
// Hops 1-20 are free. Hop 21 is the first charged one, at the opening tier
// price of $0.005.
#[test]
fn test_paid_hops_charge_the_tier_price_and_count_as_spend() {
    let player: ContractAddress = contract_address_const::<0xb004>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.finder_player_generate_position();

    // Burn the free allowance.
    let mut hopped: u32 = 0;
    loop {
        if (hopped == 20) {
            break;
        }
        hop_safely(game, player);
        hopped = hopped + 1;
    }

    let (_, _, _, spendBefore, _) = dispatcher.get_player_daily_state(player);
    assert(spendBefore == 0, 'free hops cost nothing');

    // Hop 21 - the first paid one.
    hop_safely(game, player);
    stop_cheat_caller_address(game);

    let (hopsToday, _, _, spendAfter, _) = dispatcher.get_player_daily_state(player);

    assert(hopsToday == 21, 'should have hopped 21');

    // The opening tier, $0.005. Band 0 runs to daily hop 25.
    let (bandLimit, bandPrice) = dispatcher.get_hop_price_band(0);
    assert(bandLimit == 25, 'band 0 should end at 25');
    assert(spendAfter == bandPrice, 'hop 21 should cost band 0');
    assert(spendAfter == 5000, 'band 0 should be 0.005');
}

// Lowering the allowance during a UTC day never charges for hops that already
// happened. A player who has used more than the new allowance simply has zero
// free hops remaining, and their next hop is charged normally.
#[test]
fn test_lowering_free_hops_mid_day_is_not_retroactive() {
    let player: ContractAddress = contract_address_const::<0xb014>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    // Model a live day that began under the former 22-hop allowance.
    start_cheat_caller_address(game, admin_address());
    assert(
        dispatcher.set_params(array!['dailyFreeHops'], array![22]),
        'old allowance not set',
    );
    stop_cheat_caller_address(game);

    start_cheat_caller_address(game, player);
    dispatcher.finder_player_generate_position();
    let mut hopped: u32 = 0;
    loop {
        if (hopped == 21) {
            break;
        }
        hop_safely(game, player);
        hopped = hopped + 1;
    }
    stop_cheat_caller_address(game);

    let (_, _, _, spend_before, free_used_before) = dispatcher.get_player_daily_state(player);
    assert(free_used_before == 21, 'expected 21 old free hops');
    assert(spend_before == 0, 'old free hops must remain free');

    // Apply the new live setting. Remaining allowance floors at zero even
    // though the usage counter is greater than the new cap.
    start_cheat_caller_address(game, admin_address());
    assert(
        dispatcher.set_params(array!['dailyFreeHops'], array![20]),
        'new allowance not set',
    );
    stop_cheat_caller_address(game);
    assert(dispatcher.get_free_hops_remaining(player) == 0, 'remaining must floor at zero');
    let (_, _, _, spend_after_update, _) = dispatcher.get_player_daily_state(player);
    assert(spend_after_update == 0, 'update charged old hops');

    start_cheat_caller_address(game, player);
    hop_safely(game, player);
    stop_cheat_caller_address(game);

    let (hops_after, _, _, spend_after_hop, _) = dispatcher.get_player_daily_state(player);
    assert(hops_after == 22, 'next hop should still execute');
    assert(spend_after_hop == 5000, 'next hop should be charged');
}

// The per-ROUND reward cap. Hops past it still MOVE the player - they simply
// earn nothing - because reverting would strand somebody mid-search.
#[test]
fn test_hops_past_the_round_cap_move_but_earn_nothing() {
    let player: ContractAddress = contract_address_const::<0xb005>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    let (_, roundCap, _, _) = dispatcher.get_hop_limits();
    assert(roundCap == 40, 'round cap should be 40');

    start_cheat_caller_address(game, player);
    dispatcher.finder_player_generate_position();

    // Hop exactly to the cap.
    let mut hopped: u32 = 0;
    loop {
        if (hopped == 40) {
            break;
        }
        hop_safely(game, player);
        hopped = hopped + 1;
    }

    let pendingAtCap = dispatcher.get_reward_token_pending(player);

    // Hop 41 - past the cap.
    hop_safely(game, player);
    stop_cheat_caller_address(game);

    let (hopsToday, _, _, _, _) = dispatcher.get_player_daily_state(player);
    let pendingAfterCap = dispatcher.get_reward_token_pending(player);

    // It moved the player...
    assert(hopsToday == 41, 'hop 41 should still happen');

    // ...but earned nothing.
    assert(pendingAfterCap == pendingAtCap, 'hop 41 must earn nothing');
}

// TEST 5d-ii - PARTICIPATION FIRES ON THE FIRST ACTION WHERE BOTH CONDITIONS
// HOLD, not at hop 28 regardless.
//
// A player reaches 28 hops long before $0.60 of spend. If the bonus were
// credited at hop 28 and never looked at again, this player would lose all 18
// ROZ silently and permanently - it pays once a day.
#[test]
fn test_participation_waits_for_both_conditions() {
    let player: ContractAddress = contract_address_const::<0xb006>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.finder_player_generate_position();

    // 28 hops: 20 free, then 8 paid at the opening tiers. Nowhere near $0.60.
    let mut hopped: u32 = 0;
    loop {
        if (hopped == 28) {
            break;
        }
        hop_safely(game, player);
        hopped = hopped + 1;
    }

    let (hopsToday, _, _, spendAt28, _) = dispatcher.get_player_daily_state(player);
    let (dailyThreshold, _) = dispatcher.get_gate_thresholds();

    assert(hopsToday == 28, 'should have hopped 28');
    assert(spendAt28 < dailyThreshold, 'should still be below the gate');

    let pendingAt28 = dispatcher.get_reward_token_pending(player);

    // Now cross the gate by hiding three times - the cheapest route across, and
    // it exercises the two paths meeting.
    dispatcher.hide_treasure();
    dispatcher.hide_treasure();
    dispatcher.hide_treasure();

    // One more hop, now that both conditions hold.
    hop_safely(game, player);
    stop_cheat_caller_address(game);

    let (_, _, _, spendAfter, _) = dispatcher.get_player_daily_state(player);
    assert(spendAfter >= dailyThreshold, 'should be past the gate now');

    let pendingAfter = dispatcher.get_reward_token_pending(player);

    // The jump has to contain the participation bonus. A new wallet gets 9, so
    // the delta is at least that much larger than the hop alone would give.
    let delta = pendingAfter - pendingAt28;
    assert(delta > 9000000000000000000, 'bonus should have fired');
}

// ---------------------------------------------------------------------------
// The bulk-hide whitelist (4m-iii)
// ---------------------------------------------------------------------------
//
// The tree is built HERE IN CAIRO, with the same PoseidonTrait calls
// _verifyWhitelist uses, rather than being generated off-chain and pasted in.
// That makes the proofs correct by construction and keeps the test readable.
//
// WHAT IT DOES NOT COVER: that the JavaScript tooling in 4m-iii produces trees
// compatible with this verifier. That is a cross-language question - same hash,
// same leaf encoding, same index convention - and it needs the real
// starknet-merkle-tree library to answer. Worth doing before the whitelist is
// used in anger.

// One internal node. Must match _verifyWhitelist exactly: Poseidon over the two
// children, left first.
fn poseidon_pair(a: felt252, b: felt252) -> felt252 {
    PoseidonTrait::new().update(a).update(b).finalize()
}

// A four-leaf tree:
//
//              root
//             /    \
//          h01      h23
//         /   \    /   \
//        A     B  C     D
//      idx0  idx1 idx2 idx3
//
// Returns the root. Proofs are assembled by the callers below, which is
// deliberate - writing them out by hand is what checks the index convention.
fn build_tree(a: felt252, b: felt252, c: felt252, d: felt252) -> felt252 {
    let h01 = poseidon_pair(a, b);
    let h23 = poseidon_pair(c, d);
    poseidon_pair(h01, h23)
}

// Give a player game tokens and let the game contract spend them.
fn fund_player(
    gameToken: ContractAddress, game: ContractAddress, player: ContractAddress, amount: u256,
) {
    IMockERC20Dispatcher { contract_address: gameToken }.mint(player, amount);
    start_cheat_caller_address(gameToken, player);
    ERC20ABIDispatcher { contract_address: gameToken }.approve(game, amount);
    stop_cheat_caller_address(gameToken);
}

// A whitelisted address escapes the ordinary daily cap of 10.
#[test]
fn test_whitelisted_address_exceeds_the_daily_cap() {
    let alice: ContractAddress = contract_address_const::<0xa11ce>();
    let (game, gameToken, _) = deploy_wired(alice, 500000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    let bob: ContractAddress = contract_address_const::<0xb0b>();
    let carol: ContractAddress = contract_address_const::<0xca201>();
    let dave: ContractAddress = contract_address_const::<0xda7e>();
    fund_player(gameToken, game, bob, 500000000);

    let root = build_tree(alice.into(), bob.into(), carol.into(), dave.into());

    // Only the admin may publish a root.
    let owner: ContractAddress = contract_address_const::<
        0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833,
    >();
    start_cheat_caller_address(game, owner);
    dispatcher.set_whitelist_merkle_root(root);
    stop_cheat_caller_address(game);

    assert(dispatcher.get_whitelist_merkle_root() == root, 'root should be published');

    // Alice is leaf 0, so her proof is [B, h23] and her index is 0.
    let h23 = poseidon_pair(carol.into(), dave.into());
    let mut aliceProof: Array<felt252> = ArrayTrait::new();
    aliceProof.append(bob.into());
    aliceProof.append(h23);

    // Fifteen treasures - half again the ordinary daily cap, which a
    // non-whitelisted wallet could never place.
    start_cheat_caller_address(game, alice);
    dispatcher.hide_treasure_bulk(STAKE * 15, aliceProof, 0);
    stop_cheat_caller_address(game);

    let (_, _, hidesToday, _, _) = dispatcher.get_player_daily_state(alice);
    assert(hidesToday == 15, 'whitelisted should place 15');
}

// A valid tree, but the WRONG INDEX. The hash still computes, it simply never
// matches the root - so the caller silently drops back to the daily cap. This
// is the likeliest tooling mistake, and its silence is what makes it worth an
// explicit test.
#[test]
#[feature("safe_dispatcher")]
fn test_wrong_leaf_index_falls_back_to_the_daily_cap() {
    let alice: ContractAddress = contract_address_const::<0xa11ce>();
    let (game, _, _) = deploy_wired(alice, 500000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    let safe = IHelloStarknetSafeDispatcher { contract_address: game };

    let bob: ContractAddress = contract_address_const::<0xb0b>();
    let carol: ContractAddress = contract_address_const::<0xca201>();
    let dave: ContractAddress = contract_address_const::<0xda7e>();

    let root = build_tree(alice.into(), bob.into(), carol.into(), dave.into());

    let owner: ContractAddress = contract_address_const::<
        0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833,
    >();
    start_cheat_caller_address(game, owner);
    dispatcher.set_whitelist_merkle_root(root);
    stop_cheat_caller_address(game);

    let h23 = poseidon_pair(carol.into(), dave.into());
    let mut aliceProof: Array<felt252> = ArrayTrait::new();
    aliceProof.append(bob.into());
    aliceProof.append(h23);

    // Alice's correct proof, but claiming index 1 instead of 0. Every step
    // hashes the wrong way round.
    start_cheat_caller_address(game, alice);
    let oversized = safe.hide_treasure_bulk(STAKE * 15, aliceProof, 1);
    stop_cheat_caller_address(game);

    // Refused by the ORDINARY cap, because verification failed and she is being
    // treated as an ordinary wallet.
    assert(oversized.is_err(), 'wrong index must lose whitelist');

    // And she can still place ten, like anybody else.
    let emptyProof: Array<felt252> = ArrayTrait::new();
    start_cheat_caller_address(game, alice);
    dispatcher.hide_treasure_bulk(STAKE * 10, emptyProof, 0);
    stop_cheat_caller_address(game);

    let (_, _, hidesToday, _, _) = dispatcher.get_player_daily_state(alice);
    assert(hidesToday == 10, 'should fall back to 10');
}

// TEST 17a-iii - THE COLLECTIVE CAP, AND THE FLOOR IT LEAVES.
//
// The per-address cap does not compose: without a group bound, enough
// whitelisted addresses at 250 each would take 2,750 of 2,840 and leave 90
// slots for everybody else.
//
// The caps are scaled down here so the group bound can be reached in a few
// calls. The production values (250 / 1,200 / 80) and the 1,640-slot floor they
// leave are checked arithmetically in test_whitelist_caps_leave_a_floor; this
// test is about the MECHANISM, which is identical at any scale.
#[test]
#[feature("safe_dispatcher")]
fn test_whitelist_group_cap_leaves_room_for_ordinary_players() {
    let alice: ContractAddress = contract_address_const::<0xa11ce>();
    let (game, gameToken, _) = deploy_wired(alice, 500000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    let safe = IHelloStarknetSafeDispatcher { contract_address: game };

    let bob: ContractAddress = contract_address_const::<0xb0b>();
    let carol: ContractAddress = contract_address_const::<0xca201>();
    let dave: ContractAddress = contract_address_const::<0xda7e>();

    fund_player(gameToken, game, bob, 500000000);
    fund_player(gameToken, game, carol, 500000000);
    fund_player(gameToken, game, dave, 500000000);

    let root = build_tree(alice.into(), bob.into(), carol.into(), dave.into());

    let owner: ContractAddress = contract_address_const::<
        0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833,
    >();

    // Scaled caps: 20 per address per round, 30 across the group, 20 an hour.
    // The group bound now binds on the SECOND address rather than the fifth.
    start_cheat_caller_address(game, owner);
    dispatcher.set_whitelist_merkle_root(root);
    dispatcher
        .set_params(
            array!['whitelistRoundCap', 'whitelistCollectiveCap', 'whitelistHourlyCap'],
            array![20, 30, 20],
        );
    stop_cheat_caller_address(game);

    let h01 = poseidon_pair(alice.into(), bob.into());
    let h23 = poseidon_pair(carol.into(), dave.into());

    // Alice, leaf 0: proof [B, h23]
    let mut aliceProof: Array<felt252> = ArrayTrait::new();
    aliceProof.append(bob.into());
    aliceProof.append(h23);

    // Bob, leaf 1: proof [A, h23]
    let mut bobProof: Array<felt252> = ArrayTrait::new();
    bobProof.append(alice.into());
    bobProof.append(h23);

    // Carol, leaf 2: proof [D, h01]
    let mut carolProof: Array<felt252> = ArrayTrait::new();
    carolProof.append(dave.into());
    carolProof.append(h01);

    // Alice takes her full 20. Group total is now 20 of 30.
    start_cheat_caller_address(game, alice);
    dispatcher.hide_treasure_bulk(STAKE * 20, aliceProof, 0);
    stop_cheat_caller_address(game);

    // Bob asks for 20 too. His OWN cap would allow it - the group cap is what
    // refuses him, and he must be told so specifically.
    start_cheat_caller_address(game, bob);
    let bobOversized = safe.hide_treasure_bulk(STAKE * 20, bobProof.clone(), 1);
    stop_cheat_caller_address(game);

    assert(bobOversized.is_err(), 'group cap should refuse bob');

    // Bob takes the 10 that remain, bringing the group to exactly 30.
    start_cheat_caller_address(game, bob);
    dispatcher.hide_treasure_bulk(STAKE * 10, bobProof, 1);
    stop_cheat_caller_address(game);

    // Carol is whitelisted and entirely within her own limits, but the group
    // allowance is gone.
    start_cheat_caller_address(game, carol);
    let carolBlocked = safe.hide_treasure_bulk(STAKE * 1, carolProof, 2);
    stop_cheat_caller_address(game);

    assert(carolBlocked.is_err(), 'group cap should refuse carol');

    // THE ASSERTION THE WHOLE CAP EXISTS FOR.
    //
    // The whitelist has taken everything it is allowed. An ordinary player must
    // still be able to hide - the round is nowhere near full, and only the
    // whitelist's own allowance is exhausted.
    let eve: ContractAddress = contract_address_const::<0xe7e>();
    fund_player(gameToken, game, eve, 500000000);

    let emptyProof: Array<felt252> = ArrayTrait::new();

    start_cheat_caller_address(game, eve);
    dispatcher.hide_treasure_bulk(STAKE * 10, emptyProof, 0);
    stop_cheat_caller_address(game);

    let (_, _, eveHides, _, _) = dispatcher.get_player_daily_state(eve);
    assert(eveHides == 10, 'ordinary player must still hide');
}

// The per-address round cap, which binds before the group one.
#[test]
#[feature("safe_dispatcher")]
fn test_whitelist_per_address_round_cap() {
    let alice: ContractAddress = contract_address_const::<0xa11ce>();
    let (game, _, _) = deploy_wired(alice, 500000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    let safe = IHelloStarknetSafeDispatcher { contract_address: game };

    let bob: ContractAddress = contract_address_const::<0xb0b>();
    let carol: ContractAddress = contract_address_const::<0xca201>();
    let dave: ContractAddress = contract_address_const::<0xda7e>();

    let root = build_tree(alice.into(), bob.into(), carol.into(), dave.into());

    let owner: ContractAddress = contract_address_const::<
        0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833,
    >();

    // Her own cap is 12; the group allowance is far larger, so it cannot be
    // what refuses her.
    start_cheat_caller_address(game, owner);
    dispatcher.set_whitelist_merkle_root(root);
    dispatcher
        .set_params(
            array!['whitelistRoundCap', 'whitelistCollectiveCap', 'whitelistHourlyCap'],
            array![12, 500, 100],
        );
    stop_cheat_caller_address(game);

    let h23 = poseidon_pair(carol.into(), dave.into());
    let mut aliceProof: Array<felt252> = ArrayTrait::new();
    aliceProof.append(bob.into());
    aliceProof.append(h23);

    start_cheat_caller_address(game, alice);
    let tooMany = safe.hide_treasure_bulk(STAKE * 13, aliceProof.clone(), 0);
    stop_cheat_caller_address(game);

    assert(tooMany.is_err(), '13 should exceed her 12');

    start_cheat_caller_address(game, alice);
    dispatcher.hide_treasure_bulk(STAKE * 12, aliceProof, 0);
    stop_cheat_caller_address(game);

    let (_, _, hidesToday, _, _) = dispatcher.get_player_daily_state(alice);
    assert(hidesToday == 12, 'should have placed exactly 12');
}

// Only the admin may publish a root. If anyone could, the whitelist would be
// worthless.
#[test]
#[feature("safe_dispatcher")]
fn test_only_admin_publishes_the_root() {
    let alice: ContractAddress = contract_address_const::<0xa11ce>();
    let (game, _, _) = deploy_wired(alice, 100000000);
    let safe = IHelloStarknetSafeDispatcher { contract_address: game };

    start_cheat_caller_address(game, alice);
    let attempt = safe.set_whitelist_merkle_root(0x1234);
    stop_cheat_caller_address(game);

    assert(attempt.is_err(), 'non-admin must not set root');
}

// The sweep must not be able to take ROZ that players have accrued, nor USDC
// they can still claim (4j). Both guards release only the surplus.
#[test]
fn test_sweep_leaves_what_players_are_owed() {
    let player: ContractAddress = contract_address_const::<0xaaaa>();
    let (game, gameToken, rewardToken) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    let owedRoz = dispatcher.get_reward_token_pending(player);
    let heldRoz = ERC20ABIDispatcher { contract_address: rewardToken }.balance_of(game);

    // Everything above the accrued balance, and not a unit more.
    assert(dispatcher.get_sweepable_balance(rewardToken) == heldRoz - owedRoz, 'roz surplus wrong');

    // The net claim is reserved. The $0.20 protocol fee plus the snapshotted
    // per-treasure deductions are immediately surplus.
    let heldUsdc = ERC20ABIDispatcher { contract_address: gameToken }.balance_of(game);
    assert(heldUsdc == STAKE + FEE_BASE, 'contract should hold 5.20');
    assert(
        dispatcher.get_sweepable_balance(gameToken) == FEE_BASE + 12833,
        'fee and deductions sweepable',
    );
}

// ---------------------------------------------------------------------------
// CLAIM DISCOVERY - get_reward_claimed and get_claimable_weeks
// ---------------------------------------------------------------------------

// Open the next round as the keeper.
//
// THE WEEK ARITHMETIC IS THE TRAP IN EVERY TEST BELOW. _hideTreasure credits
// currentGameWeek + 1 ("hide treasure for the week upcoming"), while
// _claimReward requires gameWeek < currentGameWeek. So a hide made at week 0
// lands on week 1, and the week has to reach 2 before it can be claimed -
// this must be called TWICE after a hide, not once.
//
// The fees replay what the constructor deployed with, because the hider fee is
// what a claim is later paid from. The merkle root is a placeholder: nothing on
// the claim path reads it.
//
// Count and value are read back from the contract and passed as assertions.
// start_next_round must never use those inputs to rewrite the live staged slots.
fn round_params(activeCount: u256, hiddenValue: u256, hiderStake: u256) -> NextRoundParams {
    round_params_with_root(activeCount, hiddenValue, hiderStake, 0x1234)
}

fn round_params_with_root(
    activeCount: u256, hiddenValue: u256, hiderStake: u256, merkleRoot: u256,
) -> NextRoundParams {
    NextRoundParams {
        merkle_root: merkleRoot,
        grid_size_x: 14,
        grid_size_y: 14,
        expected_active_treasure_count: activeCount,
        expected_total_hidden_value: hiddenValue,
        hider_stake: hiderStake,
        hide_fee_base: FEE_BASE,
        hide_fee_high: FEE_HIGH,
        hop_price_0: 5000,
        hop_price_1: 10000,
        hop_price_2: 20000,
        hop_price_3: 40000,
        spawn_fee: 1000000,
        round_duration: 21600,
        min_duration: 2700,
        near_end_blackout: 720,
        end_buffer: 180,
    }
}

// Older claim/find fixtures deliberately opened empty or one-treasure rounds.
// Keep their subject player at one share, but stage any missing capacity with a
// separate wallet so every rollover exercises the production minimum.
fn ensure_minimum_staged(game: ContractAddress) {
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    let (stagedCount, _) = dispatcher.get_next_round_totals();
    if (stagedCount >= dispatcher.get_min_treasures_to_start()) {
        return;
    }

    let filler: ContractAddress = contract_address_const::<0xf111e>();
    let missing = dispatcher.get_min_treasures_to_start() - stagedCount;
    let gameToken = dispatcher.get_game_token();
    fund_player(gameToken, game, filler, missing * (STAKE + FEE_HIGH));

    start_cheat_caller_address(game, filler);
    if (missing == 1) {
        dispatcher.hide_treasure();
    } else {
        dispatcher.hide_treasure_bulk(STAKE * missing, array![], 0);
    }
    stop_cheat_caller_address(game);
}

fn advance_round_with_root(game: ContractAddress, merkleRoot: u256) {
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    let keeper = dispatcher.get_round_keeper();
    ensure_minimum_staged(game);
    let (_, _, _, scheduledEndTs, _, _, _, _) = dispatcher.get_round_status();

    start_cheat_block_timestamp(game, scheduledEndTs + 60);
    start_cheat_caller_address(game, keeper);
    dispatcher.expire_round(dispatcher.get_game_week());
    stop_cheat_caller_address(game);

    let (_, _, _, _, endedTs, _, _, endBuffer) = dispatcher.get_round_status();
    let (activeCount, hiddenValue) = dispatcher.get_next_round_totals();
    start_cheat_block_timestamp(game, endedTs + endBuffer);
    start_cheat_caller_address(game, keeper);
    dispatcher
        .start_next_round(round_params_with_root(activeCount, hiddenValue, STAKE, merkleRoot));
    stop_cheat_caller_address(game);
}

fn advance_round_with_hider_fee(game: ContractAddress, hiderFee: u256) {
    let owner: ContractAddress = contract_address_const::<
        0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833,
    >();

    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    ensure_minimum_staged(game);
    let (_, _, _, scheduledEndTs, _, _, _, _) = dispatcher.get_round_status();

    // Expiry runs after the 60-second validation grace. The next round may
    // only open after the on-chain buffer has elapsed.
    start_cheat_block_timestamp(game, scheduledEndTs + 60);
    start_cheat_caller_address(game, owner);
    dispatcher.expire_round(dispatcher.get_game_week());
    stop_cheat_caller_address(game);

    let (_, _, _, _, endedTs, _, _, _) = dispatcher.get_round_status();
    let (activeCount, hiddenValue) = dispatcher.get_next_round_totals();
    start_cheat_block_timestamp(game, endedTs + 180);

    start_cheat_caller_address(game, owner);
    dispatcher.start_next_round(round_params(activeCount, hiddenValue, hiderFee));
    stop_cheat_caller_address(game);
}

fn advance_round(game: ContractAddress) {
    advance_round_with_hider_fee(game, STAKE);
}

// A successful find moves both representations of the treasure share. The
// aggregate count pays the same net USDC stake as before; the typed count is
// what turns the claim-time ROZ leg into the full finder reward.
#[test]
fn test_find_moves_usdc_and_typed_reward_share() {
    let hider: ContractAddress = contract_address_const::<0xa11ce>();
    let finder: ContractAddress = contract_address_const::<0xb0b>();
    let leaf: u256 = 0xfeed;
    let (game, _, _) = deploy_wired(hider, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, hider);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    advance_round_with_root(game, leaf);
    let round = dispatcher.get_game_week();
    let (_, _, startTs, _, _, activeBefore, _, _) = dispatcher.get_round_status();
    assert(round == 1, 'find round should be 1');
    assert(activeBefore == 2, 'expected two treasures');
    assert(dispatcher.get_claim_share_amounts(round, hider) == 1, 'hider aggregate missing');

    let (hiderSharesBefore, finderSharesBefore, survivalBefore) = dispatcher
        .get_reward_token_due(hider, round);
    assert(hiderSharesBefore == 1, 'hider typed share missing');
    assert(finderSharesBefore == 0, 'unexpected finder share');
    assert(survivalBefore > 0, 'survival ROZ missing');

    let keeper = dispatcher.get_round_keeper();
    start_cheat_caller_address(game, keeper);
    let found = dispatcher.validate_treasure_coordinates(finder, hider, leaf, array![], 0, startTs);
    stop_cheat_caller_address(game);
    assert(found, 'treasure should validate');

    assert(dispatcher.get_claim_share_amounts(round, hider) == 0, 'hider aggregate not removed');
    assert(dispatcher.get_claim_share_amounts(round, finder) == 1, 'finder aggregate not credited');

    let (hiderSharesAfter, _, survivalAfter) = dispatcher.get_reward_token_due(hider, round);
    let (_, finderSharesAfter, _) = dispatcher.get_reward_token_due(finder, round);
    assert(hiderSharesAfter == 0, 'hider typed share not removed');
    assert(survivalAfter == 0, 'survival ROZ retained');
    assert(finderSharesAfter == 1, 'finder typed share not credited');

    let (_, _, _, _, _, activeAfter, _, _) = dispatcher.get_round_status();
    assert(activeAfter == 1, 'active count not reduced');

    // Finish round 1 and open round 2 so its reward can be collected.
    advance_round(game);
    start_cheat_caller_address(game, finder);
    dispatcher.claim_reward(round);
    stop_cheat_caller_address(game);
    assert(
        dispatcher.get_reward_token_pending(finder) == 110000000000000000000,
        'finder should receive 110 ROZ',
    );
}

// The deployed class allowed the supplied test wallet to find its own staged
// treasure. That contradicts the reward economics and must fail before any
// coordinate, share or active-count mutation occurs.
#[test]
#[feature("safe_dispatcher")]
fn test_finder_cannot_find_own_treasure() {
    let player: ContractAddress = contract_address_const::<0xcafe>();
    let leaf: u256 = 0xbeef;
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    let safe = IHelloStarknetSafeDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);
    advance_round_with_root(game, leaf);

    let round = dispatcher.get_game_week();
    let (_, _, startTs, _, _, activeBefore, _, _) = dispatcher.get_round_status();
    let aggregateBefore = dispatcher.get_claim_share_amounts(round, player);
    let typedBefore = dispatcher.get_reward_token_due(player, round);

    start_cheat_caller_address(game, dispatcher.get_round_keeper());
    let attempt = safe.validate_treasure_coordinates(player, player, leaf, array![], 0, startTs);
    stop_cheat_caller_address(game);

    assert(attempt.is_err(), 'self-find must revert');
    assert(
        dispatcher.get_claim_share_amounts(round, player) == aggregateBefore, 'aggregate changed',
    );
    assert(dispatcher.get_reward_token_due(player, round) == typedBefore, 'typed shares changed');
    let (_, _, _, _, _, activeAfter, _, _) = dispatcher.get_round_status();
    assert(activeAfter == activeBefore, 'active count changed');
}

// TEST 1 - the flag flips, and it is visible.
//
// get_reward_claimed is the whole point: claimed_rewards was storage-only, so
// before this view nothing outside the contract could tell a settled round from
// an unclaimed one. There is no USDC claim event to index either.
#[test]
fn test_get_reward_claimed_flips_when_the_usdc_is_taken() {
    let player: ContractAddress = contract_address_const::<0xaaaa>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    // Hidden at week 0, so the share lands on week 1.
    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    assert(dispatcher.get_reward_claimed(player, 1) == false, 'not claimed yet');

    // Twice - week 1 needs the counter at 2 before it is finished.
    advance_round(game);
    advance_round(game);

    assert(dispatcher.get_reward_claimed(player, 1) == false, 'still not claimed');

    start_cheat_caller_address(game, player);
    dispatcher.claim_reward(1);
    stop_cheat_caller_address(game);

    assert(dispatcher.get_reward_claimed(player, 1) == true, 'claim must be recorded');
}

// TEST 2 - THE TEST THE FRONTEND DEPENDS ON.
//
// One call has to answer "which rounds can this wallet collect", and the answer
// has to stop including a round the moment it is collected. Without this the
// panel either needs a backend or has to guess.
#[test]
fn test_claimable_weeks_finds_the_round_then_forgets_it() {
    let player: ContractAddress = contract_address_const::<0xbbbb>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    advance_round(game);
    advance_round(game);

    let before = dispatcher.get_claimable_weeks(player, 0, 8);
    assert(before.len() == 1, 'one round to collect');
    assert(*before.at(0) == 1_u256, 'it should be week 1');

    // Every week the view returns must be one claim_reward accepts. If this
    // reverts the view is lying, which is worse than not existing.
    start_cheat_caller_address(game, player);
    dispatcher.claim_reward(*before.at(0));
    stop_cheat_caller_address(game);

    let after = dispatcher.get_claimable_weeks(player, 0, 8);
    assert(after.len() == 0, 'collected round must drop out');
}

// TEST 3 - condition 1 on its own.
//
// A share sitting in the round now under way is not collectable yet. Advance
// only once after the hide and the week is still the current one.
#[test]
fn test_claimable_weeks_excludes_the_unfinished_round() {
    let player: ContractAddress = contract_address_const::<0xcccc>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    // One short of what week 1 needs.
    advance_round(game);

    assert(dispatcher.get_game_week() == 1_u256, 'week should be 1');

    let weeks = dispatcher.get_claimable_weeks(player, 0, 8);
    assert(weeks.len() == 0, 'current round not collectable');
}

// TEST 4 - a wallet that has never played gets an empty list, not a revert.
#[test]
fn test_claimable_weeks_empty_for_a_wallet_with_no_shares() {
    let player: ContractAddress = contract_address_const::<0xdddd>();
    let stranger: ContractAddress = contract_address_const::<0xeeee>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    advance_round(game);
    advance_round(game);

    // The round is collectable - but not by this wallet.
    assert(dispatcher.get_claimable_weeks(player, 0, 8).len() == 1, 'player has one');
    assert(dispatcher.get_claimable_weeks(stranger, 0, 8).len() == 0, 'stranger has none');
}

// A round can no longer be opened with a stake below its deductions. Rejection
// happens before any staged count/value is touched.
#[test]
#[feature("safe_dispatcher")]
fn test_round_rejects_stake_below_deductions_without_losing_staged_totals() {
    let player: ContractAddress = contract_address_const::<0xf00d>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    let safe = IHelloStarknetSafeDispatcher { contract_address: game };
    let keeper = dispatcher.get_round_keeper();

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    let (_, _, _, scheduledEndTs, _, _, _, _) = dispatcher.get_round_status();
    start_cheat_block_timestamp(game, scheduledEndTs + 60);
    start_cheat_caller_address(game, keeper);
    dispatcher.expire_round(0);
    stop_cheat_caller_address(game);

    let (_, _, _, _, endedTs, _, _, _) = dispatcher.get_round_status();
    start_cheat_block_timestamp(game, endedTs + 180);
    start_cheat_caller_address(game, keeper);
    let attempt = safe.start_next_round(round_params(2, STAKE * 2, 1000));
    stop_cheat_caller_address(game);

    assert(attempt.is_err(), 'unsafe stake must fail');
    assert(dispatcher.get_game_week() == 0, 'round must not advance');
    assert(dispatcher.get_next_round_totals() == (2, STAKE * 2), 'staged totals preserved');
}

// Regression for the original rollover defect: the count that gates finds was
// already populated by hides and the retired round-opening call used to overwrite it from an
// argument. The replacement treats count/value inputs as assertions only.
#[test]
fn test_start_next_round_preserves_the_live_staged_count() {
    let player: ContractAddress = contract_address_const::<0xf11d>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    let keeper = dispatcher.get_round_keeper();

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);
    assert(dispatcher.get_next_round_totals() == (2, STAKE * 2), 'hides must stage two');

    let (_, _, _, scheduledEndTs, _, _, _, _) = dispatcher.get_round_status();
    start_cheat_block_timestamp(game, scheduledEndTs + 60);
    start_cheat_caller_address(game, keeper);
    dispatcher.expire_round(0);
    stop_cheat_caller_address(game);

    let (_, stateBefore, _, _, endedTs, _, _, endBuffer) = dispatcher.get_round_status();
    assert(stateBefore == 1_u8, 'round must be ending');
    start_cheat_block_timestamp(game, endedTs + endBuffer);
    start_cheat_caller_address(game, keeper);
    dispatcher.start_next_round(round_params(2, STAKE * 2, STAKE));
    stop_cheat_caller_address(game);

    let (roundId, stateAfter, _, _, _, active, initial, _) = dispatcher.get_round_status();
    assert(roundId == 1_u256, 'round increments');
    assert(stateAfter == 0_u8, 'new round must be open');
    assert(active == 2_u256 && initial == 2_u256, 'active count survives');
    assert(dispatcher.get_total_number_of_hiders(1) == 2, 'find gate count must survive');
}

// Round zero is the only deliberately empty round. Every keeper-opened round
// must contain at least two staged treasures, even when the supplied count and
// value correctly match the contract's zero/one totals.
#[test]
#[feature("safe_dispatcher")]
fn test_start_next_round_rejects_zero_and_one_staged_treasure() {
    let player: ContractAddress = contract_address_const::<0xf12d>();
    let (emptyGame, _, _) = deploy_wired(player, 100000000);
    let empty = IHelloStarknetDispatcher { contract_address: emptyGame };
    let emptySafe = IHelloStarknetSafeDispatcher { contract_address: emptyGame };
    let emptyKeeper = empty.get_round_keeper();
    let (_, _, _, emptyScheduledEnd, _, _, _, _) = empty.get_round_status();

    start_cheat_block_timestamp(emptyGame, emptyScheduledEnd + 60);
    start_cheat_caller_address(emptyGame, emptyKeeper);
    empty.expire_round(0);
    stop_cheat_caller_address(emptyGame);
    let (_, _, _, _, emptyEndedTs, _, _, emptyBuffer) = empty.get_round_status();
    start_cheat_block_timestamp(emptyGame, emptyEndedTs + emptyBuffer);
    start_cheat_caller_address(emptyGame, emptyKeeper);
    let emptyAttempt = emptySafe.start_next_round(round_params(0, 0, STAKE));
    stop_cheat_caller_address(emptyGame);
    assert(emptyAttempt.is_err(), 'zero staged treasures must fail');
    let (emptyRound, emptyState, _, _, _, _, _, _) = empty.get_round_status();
    assert(emptyRound == 0 && emptyState == 1_u8, 'empty game must keep waiting');

    let (oneGame, _, _) = deploy_wired(player, 100000000);
    let one = IHelloStarknetDispatcher { contract_address: oneGame };
    let oneSafe = IHelloStarknetSafeDispatcher { contract_address: oneGame };
    start_cheat_caller_address(oneGame, player);
    one.hide_treasure();
    stop_cheat_caller_address(oneGame);
    let (_, _, _, oneScheduledEnd, _, _, _, _) = one.get_round_status();
    start_cheat_block_timestamp(oneGame, oneScheduledEnd + 60);
    start_cheat_caller_address(oneGame, one.get_round_keeper());
    one.expire_round(0);
    stop_cheat_caller_address(oneGame);
    let (_, _, _, _, oneEndedTs, _, _, oneBuffer) = one.get_round_status();
    start_cheat_block_timestamp(oneGame, oneEndedTs + oneBuffer);
    start_cheat_caller_address(oneGame, one.get_round_keeper());
    let oneAttempt = oneSafe.start_next_round(round_params(1, STAKE, STAKE));
    stop_cheat_caller_address(oneGame);
    assert(oneAttempt.is_err(), 'one staged treasure must fail');
    assert(one.get_next_round_totals() == (1, STAKE), 'one staged treasure was changed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_ending_round_accepts_hides_and_opens_at_exact_minimum() {
    let player: ContractAddress = contract_address_const::<0xf13d>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    let safe = IHelloStarknetSafeDispatcher { contract_address: game };
    let (_, _, _, scheduledEnd, _, _, _, _) = dispatcher.get_round_status();

    start_cheat_block_timestamp(game, scheduledEnd + 60);
    start_cheat_caller_address(game, dispatcher.get_round_keeper());
    dispatcher.expire_round(0);
    stop_cheat_caller_address(game);

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    dispatcher.hide_treasure();
    let movementAttempt = safe.finder_player_move_position(0);
    stop_cheat_caller_address(game);

    assert(movementAttempt.is_err(), 'search open while ending');
    assert(dispatcher.get_min_treasures_to_start() == 2, 'minimum must be two');
    assert(dispatcher.get_next_round_totals() == (2, STAKE * 2), 'ending hides not staged');

    let (_, _, _, _, endedTs, _, _, endBuffer) = dispatcher.get_round_status();
    start_cheat_block_timestamp(game, endedTs + endBuffer);
    start_cheat_caller_address(game, dispatcher.get_round_keeper());
    dispatcher.start_next_round(round_params(2, STAKE * 2, STAKE));
    stop_cheat_caller_address(game);

    let (roundId, state, _, _, _, active, initial, _) = dispatcher.get_round_status();
    assert(roundId == 1 && state == 0_u8, 'round one did not open');
    assert(active == 2 && initial == 2, 'wrong round one count');
}

#[test]
fn test_stale_expiry_cannot_end_the_current_round() {
    let player: ContractAddress = contract_address_const::<0xf22d>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    let keeper = dispatcher.get_round_keeper();
    let (_, _, _, scheduledEndTs, _, _, _, _) = dispatcher.get_round_status();

    start_cheat_block_timestamp(game, scheduledEndTs + 600);
    start_cheat_caller_address(game, keeper);
    let ended = dispatcher.expire_round(99);
    stop_cheat_caller_address(game);

    let (roundId, state, _, _, endedTs, _, _, _) = dispatcher.get_round_status();
    assert(ended == false, 'stale expiry must be a no-op');
    assert(roundId == 0 && state == 0_u8 && endedTs == 0, 'current round must stay open');
}

// TEST 6 - bounds.
//
// A reversed range is a caller error. A range of 256 rounds or more would run
// into the step limit for a call and fail obscurely, so it is refused clearly
// instead.
#[test]
#[feature("safe_dispatcher")]
fn test_claimable_weeks_rejects_bad_ranges() {
    let player: ContractAddress = contract_address_const::<0x1111>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let safe = IHelloStarknetSafeDispatcher { contract_address: game };

    assert(safe.get_claimable_weeks(player, 5, 4).is_err(), 'reversed range must fail');
    assert(safe.get_claimable_weeks(player, 0, 256).is_err(), 'wide range must fail');

    // 255 apart is the widest that is allowed, and must not fail.
    assert(safe.get_claimable_weeks(player, 0, 255).is_ok(), '255 apart is fine');
}

// TEST 7 - week 0, where the clamp would underflow.
//
// Nothing has finished on a fresh contract, so the answer is empty. The view has
// to return before computing currentGameWeek - 1: a u256 cannot go negative and
// the subtraction would panic.
#[test]
fn test_claimable_weeks_empty_before_any_round_finishes() {
    let player: ContractAddress = contract_address_const::<0x2222>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    assert(dispatcher.get_game_week() == 0_u256, 'fresh contract is week 0');

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    let weeks = dispatcher.get_claimable_weeks(player, 0, 8);
    assert(weeks.len() == 0, 'nothing finished yet');
}

// ---------------------------------------------------------------------------
// MISSED ROZ - rewards earned while the contract could not pay for them
// ---------------------------------------------------------------------------

// TEST 1 - THE WHOLE POINT: a skipped reward is written down, not forgotten.
//
// Before the ledger existed, a skip emitted an event and returned. A contract
// cannot read its own logs, so the amount was gone - and unlike the claim leg
// there was nothing left in storage to recalculate it from.
//
// The assertion is deliberately made against a FUNDED twin running the exact
// same action rather than against a hardcoded figure. What the ledger records
// must be precisely what the player would have been credited, and reward rates
// are settings that can change; comparing the two contracts checks the property
// instead of a number that would rot.
#[test]
fn test_a_skipped_reward_is_recorded_not_lost() {
    let player: ContractAddress = contract_address_const::<0x9001>();

    // No ROZ at all - the state every deployment starts in.
    let (poorGame, _, _) = deploy_wired_with_roz(player, 100000000, 0);
    let poor = IHelloStarknetDispatcher { contract_address: poorGame };

    start_cheat_caller_address(poorGame, player);
    poor.hide_treasure();
    stop_cheat_caller_address(poorGame);

    let missed = poor.get_reward_token_missed(player);

    assert(missed > 0, 'the skip must be recorded');
    assert(poor.get_reward_token_pending(player) == 0, 'nothing is payable yet');
    assert(poor.get_total_reward_token_missed() == missed, 'the total must agree');

    // The same hide, on a contract that can pay.
    let (richGame, _, _) = deploy_wired(player, 100000000);
    let rich = IHelloStarknetDispatcher { contract_address: richGame };

    start_cheat_caller_address(richGame, player);
    rich.hide_treasure();
    stop_cheat_caller_address(richGame);

    assert(rich.get_reward_token_pending(player) == missed, 'must record what it would pay');
}

// TEST 2 - the round trip: missed -> pending -> wallet.
#[test]
fn test_missed_roz_converts_and_pays_out_once_funded() {
    let player: ContractAddress = contract_address_const::<0x9002>();
    let (game, _, rewardToken) = deploy_wired_with_roz(player, 100000000, 0);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    let missed = dispatcher.get_reward_token_missed(player);
    assert(missed > 0, 'should have missed something');

    // The tranche arrives as a plain transfer, exactly as real funding does.
    IMockERC20Dispatcher { contract_address: rewardToken }.mint(game, missed * 10);

    start_cheat_caller_address(game, player);
    let converted = dispatcher.claim_missed_reward_token();
    stop_cheat_caller_address(game);

    assert(converted == missed, 'all of it should convert');
    assert(dispatcher.get_reward_token_missed(player) == 0, 'missed must be cleared');
    assert(dispatcher.get_total_reward_token_missed() == 0, 'the total must clear too');
    assert(dispatcher.get_reward_token_pending(player) == missed, 'it must now be payable');

    // And the existing withdrawal path pays it, unchanged.
    start_cheat_caller_address(game, player);
    dispatcher.claim_reward_tokens();
    stop_cheat_caller_address(game);

    let inWallet = ERC20ABIDispatcher { contract_address: rewardToken }.balance_of(player);

    assert(inWallet == missed, 'the player must be paid');
    assert(dispatcher.get_reward_token_pending(player) == 0, 'pending must be cleared');
}

// TEST 3 - PARTIAL CONVERSION, and why it is not all-or-nothing.
//
// If the conversion insisted on covering the whole backlog, a player owed more
// than the contract holds would recover NOTHING - the larger the debt the less
// collectable it would be, which is exactly backwards. Whatever fits must move.
#[test]
fn test_missed_roz_converts_partially_when_funds_are_short() {
    let player: ContractAddress = contract_address_const::<0x9003>();
    let (game, _, rewardToken) = deploy_wired_with_roz(player, 100000000, 0);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    let missed = dispatcher.get_reward_token_missed(player);
    assert(missed > 1, 'need something to split');

    // Deliberately not enough.
    let partialFunding = missed / 2;
    IMockERC20Dispatcher { contract_address: rewardToken }.mint(game, partialFunding);

    start_cheat_caller_address(game, player);
    let converted = dispatcher.claim_missed_reward_token();
    stop_cheat_caller_address(game);

    assert(converted == partialFunding, 'should take exactly what fits');
    assert(dispatcher.get_reward_token_missed(player) == missed - partialFunding, 'rest waits');
    assert(dispatcher.get_reward_token_pending(player) == partialFunding, 'the rest is payable');

    // Top up, and the remainder comes across on a second call.
    IMockERC20Dispatcher { contract_address: rewardToken }.mint(game, missed);

    start_cheat_caller_address(game, player);
    let second = dispatcher.claim_missed_reward_token();
    stop_cheat_caller_address(game);

    assert(second == missed - partialFunding, 'the remainder converts');
    assert(dispatcher.get_reward_token_missed(player) == 0, 'nothing left waiting');
}

// TEST 4 - calling again does not mint a second debt.
//
// This is the failure that would follow from routing the conversion through
// _accrueRewardToken: on a shortfall it records to missed, so a failed recovery
// would ADD to the very balance it was trying to clear.
#[test]
fn test_converting_twice_does_not_double_credit() {
    let player: ContractAddress = contract_address_const::<0x9004>();
    let (game, _, rewardToken) = deploy_wired_with_roz(player, 100000000, 0);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    let missed = dispatcher.get_reward_token_missed(player);
    IMockERC20Dispatcher { contract_address: rewardToken }.mint(game, missed * 10);

    start_cheat_caller_address(game, player);
    let first = dispatcher.claim_missed_reward_token();
    let second = dispatcher.claim_missed_reward_token();
    stop_cheat_caller_address(game);

    assert(first == missed, 'first call takes it all');
    assert(second == 0, 'second call is a no-op');
    assert(dispatcher.get_reward_token_pending(player) == missed, 'pending must not double');
    assert(dispatcher.get_reward_token_missed(player) == 0, 'missed must stay clear');
}

// TEST 5 - the sweep cannot take ROZ that is owed as missed.
//
// Money players have earned is not the owner's to withdraw, whether it is
// already payable (pending) or still waiting on funding (missed).
#[test]
fn test_sweep_reserves_missed_roz() {
    let player: ContractAddress = contract_address_const::<0x9005>();
    let (game, _, rewardToken) = deploy_wired_with_roz(player, 100000000, 0);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    let missed = dispatcher.get_reward_token_missed(player);
    assert(missed > 0, 'need a backlog to reserve');

    // Fund with three times the backlog, so exactly twice it is surplus.
    IMockERC20Dispatcher { contract_address: rewardToken }.mint(game, missed * 3);

    assert(
        dispatcher.get_sweepable_balance(rewardToken) == missed * 2, 'must hold back the missed',
    );

    // Convert it, and the reserved amount simply changes category - still
    // reserved, now as pending.
    start_cheat_caller_address(game, player);
    dispatcher.claim_missed_reward_token();
    stop_cheat_caller_address(game);

    assert(
        dispatcher.get_sweepable_balance(rewardToken) == missed * 2, 'still held back as pending',
    );
}

// TEST 6 - participation is made whole WITHOUT the flag being fixed.
//
// _creditParticipationIfDue writes player_paid_participation BEFORE attempting
// the credit and ignores the result, so on an unfunded contract the day is
// marked paid when nothing was paid - and it is never retried. The ledger
// captures the amount anyway, which is why that call site needs no change.
//
// Guarding the flag as well would be worse: the day would be reattempted on
// every later action, recording the same bonus into missed again and again.
#[test]
fn test_participation_bonus_survives_an_unfunded_contract() {
    let player: ContractAddress = contract_address_const::<0x9006>();
    let (game, _, _) = deploy_wired_with_roz(player, 100000000, 0);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.finder_player_generate_position();

    let mut hopped: u32 = 0;
    loop {
        if (hopped == 28) {
            break;
        }
        hop_safely(game, player);
        hopped = hopped + 1;
    }

    let missedBefore = dispatcher.get_reward_token_missed(player);

    // Crossing the gate is what makes the bonus due.
    dispatcher.hide_treasure();
    dispatcher.hide_treasure();
    dispatcher.hide_treasure();
    hop_safely(game, player);
    stop_cheat_caller_address(game);

    let (_, _, _, spendAfter, _) = dispatcher.get_player_daily_state(player);
    let (dailyThreshold, _) = dispatcher.get_gate_thresholds();
    assert(spendAfter >= dailyThreshold, 'should be past the gate');

    // Same assertion as the funded participation test: the jump has to be
    // bigger than a hop alone, so it must contain the 9 ROZ bonus.
    let delta = dispatcher.get_reward_token_missed(player) - missedBefore;

    assert(delta > 9000000000000000000, 'bonus must be recorded');
    assert(dispatcher.get_reward_token_pending(player) == 0, 'still nothing payable');
}

// TEST 7 - nothing to recover is a normal answer, not an error.
#[test]
fn test_claiming_missed_with_nothing_owed_returns_zero() {
    let player: ContractAddress = contract_address_const::<0x9007>();
    let stranger: ContractAddress = contract_address_const::<0x9008>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, stranger);
    let converted = dispatcher.claim_missed_reward_token();
    stop_cheat_caller_address(game);

    assert(converted == 0, 'nothing to convert');
    assert(dispatcher.get_reward_token_missed(stranger) == 0, 'and none recorded');
}

// ---------------------------------------------------------------------------
// Pause, roles, delayed administration and upgrades
// ---------------------------------------------------------------------------

#[test]
#[feature("safe_dispatcher")]
fn test_pauser_is_separate_from_admin_and_can_be_replaced_by_role_grant() {
    let game = deploy_contract("HelloStarknet");
    let admin = IGameAdministrationDispatcher { contract_address: game };
    let admin_safe = IGameAdministrationSafeDispatcher { contract_address: game };
    let access = IAccessControlDispatcher { contract_address: game };

    // The class deploys PAUSED so a half-initialised game cannot be played, so
    // lift that first - this test is about who may pause, not about the state
    // a deployment starts in.
    start_cheat_caller_address(game, pauser_address());
    admin.unpause();
    stop_cheat_caller_address(game);

    start_cheat_caller_address(game, admin_address());
    let refused = admin_safe.pause();
    stop_cheat_caller_address(game);
    assert(refused.is_err(), 'admin must not begin as pauser');

    start_cheat_caller_address(game, pauser_address());
    admin.pause();
    assert(admin.is_paused(), 'pauser should pause');
    admin.unpause();
    stop_cheat_caller_address(game);

    start_cheat_caller_address(game, admin_address());
    access.grant_role(selector!("PAUSE_ROLE"), admin_address());
    admin.pause();
    assert(admin.is_paused(), 'granted admin should pause');
    admin.unpause();
    stop_cheat_caller_address(game);
}

#[test]
#[feature("safe_dispatcher")]
fn test_pause_freezes_play_but_pending_roz_can_still_be_claimed() {
    let player: ContractAddress = contract_address_const::<0x701>();
    let stranger: ContractAddress = contract_address_const::<0x702>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let gameplay = IHelloStarknetDispatcher { contract_address: game };
    let gameplay_safe = IHelloStarknetSafeDispatcher { contract_address: game };
    let administration = IGameAdministrationDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    gameplay.finder_player_generate_position();
    gameplay.hide_treasure();
    stop_cheat_caller_address(game);
    assert(gameplay.get_reward_token_pending(player) > 0, 'test needs pending ROZ');

    start_cheat_caller_address(game, pauser_address());
    administration.pause();
    stop_cheat_caller_address(game);

    start_cheat_caller_address(game, player);
    assert(gameplay_safe.hide_treasure().is_err(), 'single hide must pause');
    assert(gameplay_safe.hide_treasure_bulk(STAKE, array![], 0).is_err(), 'bulk hide must pause');
    assert(gameplay_safe.finder_player_move_position(3).is_err(), 'hop must pause');
    gameplay.claim_reward_tokens();
    stop_cheat_caller_address(game);
    assert(gameplay.get_reward_token_pending(player) == 0, 'claim must remain live');

    start_cheat_caller_address(game, stranger);
    assert(gameplay_safe.finder_player_generate_position().is_err(), 'spawn must pause');
    stop_cheat_caller_address(game);

    start_cheat_caller_address(game, pauser_address());
    administration.unpause();
    stop_cheat_caller_address(game);

    start_cheat_caller_address(game, player);
    assert(gameplay.hide_treasure(), 'unpause should restore play');
    stop_cheat_caller_address(game);
}

#[test]
fn test_usdc_round_claim_remains_callable_while_paused() {
    let player: ContractAddress = contract_address_const::<0x70a>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let gameplay = IHelloStarknetDispatcher { contract_address: game };
    let administration = IGameAdministrationDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    gameplay.hide_treasure();
    stop_cheat_caller_address(game);
    advance_round(game);
    advance_round(game);

    start_cheat_caller_address(game, pauser_address());
    administration.pause();
    stop_cheat_caller_address(game);
    start_cheat_caller_address(game, player);
    assert(gameplay.claim_reward(1), 'paused USDC claim failed');
    stop_cheat_caller_address(game);
    assert(gameplay.get_reward_claimed(player, 1), 'claim flag not written');
}

#[test]
#[feature("safe_dispatcher")]
fn test_expiry_stays_live_while_paused_but_next_round_waits_for_unpause() {
    let player: ContractAddress = contract_address_const::<0x703>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let gameplay = IHelloStarknetDispatcher { contract_address: game };
    let gameplay_safe = IHelloStarknetSafeDispatcher { contract_address: game };
    let administration = IGameAdministrationDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    gameplay.hide_treasure();
    gameplay.hide_treasure();
    stop_cheat_caller_address(game);

    start_cheat_caller_address(game, pauser_address());
    administration.pause();
    stop_cheat_caller_address(game);

    let keeper = gameplay.get_round_keeper();
    let (_, _, _, scheduled_end, _, _, _, _) = gameplay.get_round_status();
    start_cheat_block_timestamp(game, scheduled_end + 60);
    start_cheat_caller_address(game, keeper);
    assert(gameplay.expire_round(0), 'expiry must remain live');
    let (active_count, hidden_value) = gameplay.get_next_round_totals();
    let blocked = gameplay_safe.start_next_round(round_params(active_count, hidden_value, STAKE));
    stop_cheat_caller_address(game);
    assert(blocked.is_err(), 'round start must pause');

    let (_, _, _, _, ended_at, _, _, end_buffer) = gameplay.get_round_status();
    start_cheat_block_timestamp(game, ended_at + end_buffer);
    start_cheat_caller_address(game, pauser_address());
    administration.unpause();
    stop_cheat_caller_address(game);
    start_cheat_caller_address(game, keeper);
    assert(
        gameplay.start_next_round(round_params(active_count, hidden_value, STAKE)),
        'round start not restored',
    );
    stop_cheat_caller_address(game);
}

#[test]
#[feature("safe_dispatcher")]
fn test_upgrade_delay_cancel_and_execution() {
    let game = deploy_contract("HelloStarknet");
    let administration = IGameAdministrationDispatcher { contract_address: game };
    let administration_safe = IGameAdministrationSafeDispatcher { contract_address: game };
    let replacement = declare("MockVrfProvider").unwrap().contract_class();
    let replacement_hash = *replacement.class_hash;

    start_cheat_caller_address(game, admin_address());
    administration.propose_upgrade(replacement_hash);
    let (pending, _) = administration.get_pending_upgrade();
    assert(pending == replacement_hash, 'wrong pending class');
    assert(administration_safe.execute_upgrade().is_err(), 'upgrade must wait');
    administration.cancel_upgrade();
    let (cancelled, cancelled_eta) = administration.get_pending_upgrade();
    assert(cancelled.is_zero(), 'cancel must clear class');
    assert(cancelled_eta == 0, 'cancel must clear eta');

    administration.propose_upgrade(replacement_hash);
    let (_, second_eta) = administration.get_pending_upgrade();
    start_cheat_block_timestamp(game, second_eta);
    administration.execute_upgrade();
    stop_cheat_caller_address(game);
    assert(get_class_hash(game) == replacement_hash, 'class hash was not replaced');
}

#[test]
#[feature("safe_dispatcher")]
fn test_decreasing_delay_cannot_enable_an_immediate_upgrade() {
    let game = deploy_contract("HelloStarknet");
    let administration = IGameAdministrationDispatcher { contract_address: game };
    let administration_safe = IGameAdministrationSafeDispatcher { contract_address: game };
    let replacement = declare("MockVrfProvider").unwrap().contract_class();
    let replacement_hash = *replacement.class_hash;

    start_cheat_caller_address(game, admin_address());
    administration.propose_upgrade_delay(0);
    assert(administration_safe.set_upgrade_delay(0).is_err(), 'delay decrease must itself wait');
    administration.propose_upgrade(replacement_hash);
    assert(administration_safe.execute_upgrade().is_err(), 'pending keeps original eta');
    let (_, _, delay_eta) = administration.get_pending_upgrade_delay();
    start_cheat_block_timestamp(game, delay_eta);
    administration.set_upgrade_delay(0);
    assert(administration.get_upgrade_delay() == 0, 'delay should decrease after eta');
    stop_cheat_caller_address(game);
}

#[test]
fn test_migration_is_idempotent_and_preserves_live_reward_state() {
    let player: ContractAddress = contract_address_const::<0x704>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let gameplay = IHelloStarknetDispatcher { contract_address: game };
    let administration = IGameAdministrationDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    gameplay.hide_treasure();
    stop_cheat_caller_address(game);
    let pending_before = gameplay.get_reward_token_pending(player);
    let total_pending_before = gameplay.get_total_reward_token_pending();
    let (_, _, _, daily_cap_before, _) = gameplay.get_hide_settings();

    // Emulate the pre-migration value an upgraded address would contain.
    store(game, selector!("upgrade_initialized_version"), array![0, 0].span());
    assert(administration.get_upgrade_initialized_version() == 0, 'version cheat failed');

    start_cheat_caller_address(game, admin_address());
    assert(administration.migrate_v2(), 'first migration should apply');
    assert(!administration.migrate_v2(), 'migration already applied');
    stop_cheat_caller_address(game);

    let (_, _, _, daily_cap_after, _) = gameplay.get_hide_settings();
    assert(daily_cap_after == daily_cap_before, 'migration changed cap');
    assert(
        gameplay.get_reward_token_pending(player) == pending_before, 'migration changed pending',
    );
    assert(
        gameplay.get_total_reward_token_pending() == total_pending_before,
        'migration changed pending total',
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_unauthorized_account_cannot_pause_upgrade_sweep_or_change_tokens() {
    let player: ContractAddress = contract_address_const::<0x705>();
    let attacker: ContractAddress = contract_address_const::<0x706>();
    let (game, game_token, reward_token) = deploy_wired(player, 100000000);
    let gameplay_safe = IHelloStarknetSafeDispatcher { contract_address: game };
    let administration_safe = IGameAdministrationSafeDispatcher { contract_address: game };
    let replacement = declare("MockVrfProvider").unwrap().contract_class();
    let replacement_hash = *replacement.class_hash;

    start_cheat_caller_address(game, attacker);
    assert(administration_safe.pause().is_err(), 'attacker paused');
    assert(
        administration_safe.propose_upgrade(replacement_hash).is_err(), 'attacker proposed upgrade',
    );
    assert(
        administration_safe.propose_game_token_update(reward_token).is_err(),
        'attacker proposed token change',
    );
    assert(gameplay_safe.update_game_token(reward_token).is_err(), 'attacker changed token');
    assert(
        administration_safe.propose_token_withdrawal(game_token, attacker).is_err(),
        'attacker proposed sweep',
    );
    assert(
        gameplay_safe.withdraw_token_balance(game_token, attacker).is_err(), 'attacker swept token',
    );
    stop_cheat_caller_address(game);
}

#[test]
#[feature("safe_dispatcher")]
fn test_full_sweep_requires_pause_for_proposal_and_execution() {
    let player: ContractAddress = contract_address_const::<0x707>();
    let receiver: ContractAddress = contract_address_const::<0x708>();
    let (game, _, reward_token) = deploy_wired(player, 100000000);
    let gameplay = IHelloStarknetDispatcher { contract_address: game };
    let gameplay_safe = IHelloStarknetSafeDispatcher { contract_address: game };
    let administration = IGameAdministrationDispatcher { contract_address: game };
    let administration_safe = IGameAdministrationSafeDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    gameplay.hide_treasure();
    stop_cheat_caller_address(game);
    assert(gameplay.get_reward_token_pending(player) > 0, 'test needs player liability');

    start_cheat_caller_address(game, admin_address());
    assert(
        administration_safe.propose_full_token_withdrawal(reward_token, receiver).is_err(),
        'full proposal needs pause',
    );
    stop_cheat_caller_address(game);

    start_cheat_caller_address(game, pauser_address());
    administration.pause();
    stop_cheat_caller_address(game);
    start_cheat_caller_address(game, admin_address());
    administration.propose_full_token_withdrawal(reward_token, receiver);
    let (_, _, eta) = administration.get_pending_admin_action();
    stop_cheat_caller_address(game);

    start_cheat_caller_address(game, pauser_address());
    administration.unpause();
    stop_cheat_caller_address(game);
    start_cheat_block_timestamp(game, eta);
    start_cheat_caller_address(game, pauser_address());
    administration.pause();
    stop_cheat_caller_address(game);
    start_cheat_caller_address(game, admin_address());
    assert(
        gameplay_safe.withdraw_token_balance(reward_token, receiver).is_err(),
        'unpause must cancel full sweep',
    );
    stop_cheat_caller_address(game);

    start_cheat_caller_address(game, admin_address());
    administration.propose_full_token_withdrawal(reward_token, receiver);
    let (_, _, second_eta) = administration.get_pending_admin_action();
    start_cheat_block_timestamp(game, second_eta);
    gameplay.withdraw_token_balance(reward_token, receiver);
    stop_cheat_caller_address(game);

    assert(
        ERC20ABIDispatcher { contract_address: reward_token }.balance_of(game) == 0,
        'full sweep did not drain',
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_admin_handoff_is_delayed_and_revokes_the_previous_admin() {
    let game = deploy_contract("HelloStarknet");
    // This test proves the handoff by having the new admin write a setting, and
    // set_params validates the WHOLE configuration. On an uninitialised contract
    // every setting is zero, so that write would fail on the invariants rather
    // than on authorisation - which is not what is being tested here.
    initialise_game_settings(game);
    let new_admin: ContractAddress = contract_address_const::<0x709>();
    let gameplay = IHelloStarknetDispatcher { contract_address: game };
    let gameplay_safe = IHelloStarknetSafeDispatcher { contract_address: game };
    let administration = IGameAdministrationDispatcher { contract_address: game };
    let administration_safe = IGameAdministrationSafeDispatcher { contract_address: game };
    let access = IAccessControlDispatcher { contract_address: game };

    start_cheat_caller_address(game, admin_address());
    administration.propose_admin_update(new_admin);
    assert(administration_safe.set_admin(new_admin).is_err(), 'admin handoff must wait');
    let (_, _, eta) = administration.get_pending_admin_action();
    start_cheat_block_timestamp(game, eta);
    administration.set_admin(new_admin);
    stop_cheat_caller_address(game);

    assert(administration.get_admin() == new_admin, 'admin was not changed');
    assert(access.has_role(selector!("ADMIN_ROLE"), new_admin), 'new admin role missing');
    assert(access.has_role(selector!("UPGRADE_ROLE"), new_admin), 'new upgrade role missing');
    assert(!access.has_role(selector!("ADMIN_ROLE"), admin_address()), 'old admin role remained');

    start_cheat_caller_address(game, admin_address());
    assert(
        gameplay_safe.set_params(array!['gasFeeReservation'], array![99]).is_err(),
        'old admin still authorized',
    );
    stop_cheat_caller_address(game);
    start_cheat_caller_address(game, new_admin);
    assert(
        gameplay.set_params(array!['gasFeeReservation'], array![99]),
        'new admin not authorized',
    );
    stop_cheat_caller_address(game);
}
