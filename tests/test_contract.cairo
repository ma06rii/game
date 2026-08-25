use project_name::{
    IHelloStarknetDispatcher, IHelloStarknetDispatcherTrait, IHelloStarknetSafeDispatcher,
    IHelloStarknetSafeDispatcherTrait,
};
// DeclareResultTrait is what exposes contract_class() on the DeclareResult that
// declare() returns from snforge_std v0.62 onward.
use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;
use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use project_name::mock_erc20::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::class_hash::class_hash_const;
use starknet::{ContractAddress, contract_address_const, get_caller_address, get_contract_address};

// The game contract's constructor takes the VRF provider address, the game token
// address and the ROZ reward token address, so all three have to be serialised
// into the deploy calldata here, IN THAT ORDER. Tests exercise neither
// randomness nor token transfers, so any non-zero addresses would do; the real
// ones are used because they are the meaningful defaults.
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

    let (contract_address, _) = contract.deploy(@constructorCalldata).unwrap();
    contract_address
}

// #[test]
// fn test_verify() {
//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     #[feature("safe_dispatcher")]
//     let result = safe_dispatcher
//         ._verify(
//             0xbc19a39ffdeb3ff487a290fd65626b9592fe3fb625937ab468940c4c58966849,
//             0x03e48ef2868eb9039abb12f13e6d4aa79059381a8d3d10c9b5b344d41fad189f,
//             array![
//                 0x4dfa50b1d7dd9d841c1d5e20c75ed801f483f1e837d255bc36716bd371ba52ac,
//                 0x61a3acbba2a8ef1be4bf74714ddc2cf18e6dceef124978add3db7e34137eaaf2
//             ]
//         )
//         .unwrap();

//     assert(@result == @true, 'Not verified');
// }

// #[test]
// fn test_createNewGame() {
//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     #[feature("safe_dispatcher")]
//     let result = safe_dispatcher
//         ._createNewGame(
//             0xbc19a39ffdeb3ff487a290fd65626b9592fe3fb625937ab468940c4c58966849,
//             75000000000000, //approx $ 0.25 finder fee
//             35000000000000, //approx $ 0.12 hider fee
//             5000000000000000,
//             5,
//             5,
//             3,
//             105000000000000,
//             0
//         )
//         .unwrap();

//     assert(result == true, 'Game not created');
// }

//skip
// #[test]
// fn pass_test_validateTreasureCoordinates() {
//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     let address1: ContractAddress = contract_address_const::<
//         0x0651ac246f230feee9127b11ec3568a90d78bc2b7c954a2a4f5655f435e9da73
//     >();
//     let address2: ContractAddress = contract_address_const::<
//         0x069a4214bb1e4ba496b9d7fd1f24932ac10d3be952e1cdfca8b309ad9c5a4571
//     >();
//     let address3: ContractAddress = contract_address_const::<
//         0x07e3a6104a5022a7e768e973ce2f1db8203be67c2f34dab637742c56b7ee7de6
//     >();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._rewardGamer(address1, 0).unwrap();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._rewardGamer(address2, 0).unwrap();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._rewardGamer(address3, 0).unwrap();

//     let finderAddress: ContractAddress = contract_address_const::<
//         0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
//     >();

//     let hiderAddress: ContractAddress = contract_address_const::<
//         0x069a4214bb1e4ba496b9d7fd1f24932ac10d3be952e1cdfca8b309ad9c5a4571
//     >();

//     #[feature("safe_dispatcher")]
//     let result = safe_dispatcher
//         .ooValidateTreasureCoordinates(
//             finderAddress,
//             hiderAddress,
//             0,
//             0x03e48ef2868eb9039abb12f13e6d4aa79059381a8d3d10c9b5b344d41fad189f,
//             array![
//                 0x4dfa50b1d7dd9d841c1d5e20c75ed801f483f1e837d255bc36716bd371ba52ac,
//                 0x61a3acbba2a8ef1be4bf74714ddc2cf18e6dceef124978add3db7e34137eaaf2
//             ]
//         )
//         .unwrap();

//     assert(result == true, 'Not verified');
// }

//skip
// #[test]
// fn fail_test_validateTreasureCoordinates() {
//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     let address1: ContractAddress = contract_address_const::<
//         0x0651ac246f230feee9127b11ec3568a90d78bc2b7c954a2a4f5655f435e9da73
//     >();
//     let address2: ContractAddress = contract_address_const::<
//         0x069a4214bb1e4ba496b9d7fd1f24932ac10d3be952e1cdfca8b309ad9c5a4571
//     >();
//     let address3: ContractAddress = contract_address_const::<
//         0x07e3a6104a5022a7e768e973ce2f1db8203be67c2f34dab637742c56b7ee7de6
//     >();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._rewardGamer(address1, 0).unwrap();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._rewardGamer(address2, 0).unwrap();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._rewardGamer(address3, 0).unwrap();

//     let finderAddress: ContractAddress = contract_address_const::<
//         0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
//     >();

//     let hiderAddress: ContractAddress = contract_address_const::<
//         0x069a4214bb1e4ba496b9d7fd1f24932ac10d3be952e1cdfca8b309ad9c5a4571
//     >();

//     #[feature("safe_dispatcher")]
//     let result = safe_dispatcher
//         .ooValidateTreasureCoordinates(
//             finderAddress,
//             hiderAddress,
//             0,
//             0x03e48ef2868eb9039abb12f13e6d4aa79059381a8d3d10c9b5b344d41fad189d,
//             array![
//                 0x4dfa50b1d7dd9d841c1d5e20c75ed801f483f1e837d255bc36716bd371ba52ac,
//                 0x61a3acbba2a8ef1be4bf74714ddc2cf18e6dceef124978add3db7e34137eaaf2
//             ]
//         )
//         .unwrap();

//     assert(result == false, 'passes verification');
// }

//skip
// #[test]
// fn test_getFinderPlayerPosition() {
//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     let address: ContractAddress = contract_address_const::<
//         0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
//     >();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._spawnNewPosition(address, 1).unwrap();

//     #[feature("safe_dispatcher")]
//     let getFinderPlayerPosition_result = safe_dispatcher
//         .getFinderPlayerPosition(address, 1)
//         .unwrap();

//     assert(getFinderPlayerPosition_result == (3, 3), 'No position');
// }

//skip
// #[test]
// fn test_finderPlayerMovePosition() {
//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     let address: ContractAddress = contract_address_const::<
//         0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
//     >();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._spawnNewPosition(address, 0).unwrap();

//     #[feature("safe_dispatcher")]
//     let finderPlayerMovePosition_result = safe_dispatcher
//         .finderPlayerMovePosition(1, 1)
//         .unwrap();

//     assert(finderPlayerMovePosition_result == (4, 4), 'No position');
// }

//skip
// #[test]
// fn test_playerRewardDue() {
//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     let address1: ContractAddress = contract_address_const::<
//         0x0651ac246f230feee9127b11ec3568a90d78bc2b7c954a2a4f5655f435e9da73
//     >();
//     let address2: ContractAddress = contract_address_const::<
//         0x069a4214bb1e4ba496b9d7fd1f24932ac10d3be952e1cdfca8b309ad9c5a4571
//     >();
//     let address3: ContractAddress = contract_address_const::<
//         0x07e3a6104a5022a7e768e973ce2f1db8203be67c2f34dab637742c56b7ee7de6
//     >();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._rewardGamer(address1, 0).unwrap();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._rewardGamer(address2, 0).unwrap();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._rewardGamer(address3, 0).unwrap();

//     #[feature("safe_dispatcher")]
//     let playerRewardDue_result = safe_dispatcher._playerRewardDue(address1, 0).unwrap();

//     //PlayerRewardToPay + GasFeeReservation + GameMasterFee == HiderFee
//     assert(
//         (playerRewardDue_result + 10000000000000 + 2500000000000) == 35000000000000,
//         'Reward value not correct'
//     );
// }

//skip
// #[test]
// fn test_playerRewardDue_afterFinderPlayerFindsTreasure() {
//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     let address1: ContractAddress = contract_address_const::<
//         0x0651ac246f230feee9127b11ec3568a90d78bc2b7c954a2a4f5655f435e9da73
//     >();
//     let address2: ContractAddress = contract_address_const::<
//         0x069a4214bb1e4ba496b9d7fd1f24932ac10d3be952e1cdfca8b309ad9c5a4571
//     >();
//     let address3: ContractAddress = contract_address_const::<
//         0x07e3a6104a5022a7e768e973ce2f1db8203be67c2f34dab637742c56b7ee7de6
//     >();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._rewardGamer(address1, 0).unwrap();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._rewardGamer(address2, 0).unwrap();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._rewardGamer(address3, 0).unwrap();

//     let finderAddress: ContractAddress = contract_address_const::<
//         0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
//     >();

//     let hiderAddress: ContractAddress = contract_address_const::<
//         0x069a4214bb1e4ba496b9d7fd1f24932ac10d3be952e1cdfca8b309ad9c5a4571
//     >();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher
//         .ooValidateTreasureCoordinates(
//             finderAddress,
//             hiderAddress,
//             0,
//             0x03e48ef2868eb9039abb12f13e6d4aa79059381a8d3d10c9b5b344d41fad189f,
//             array![
//                 0x4dfa50b1d7dd9d841c1d5e20c75ed801f483f1e837d255bc36716bd371ba52ac,
//                 0x61a3acbba2a8ef1be4bf74714ddc2cf18e6dceef124978add3db7e34137eaaf2
//             ]
//         )
//         .unwrap();

//     #[feature("safe_dispatcher")]
//     let finderAddress_playerRewardDue_result = safe_dispatcher
//         ._playerRewardDue(finderAddress, 0)
//         .unwrap();

//     //finder player should be due 1 share of the reward
//     assert(
//         (finderAddress_playerRewardDue_result + 10000000000000 + 2500000000000) ==
//         35000000000000, 'Reward value not correct'
//     );

//     #[feature("safe_dispatcher")]
//     let hiderAddress_playerRewardDue_result = safe_dispatcher
//         ._playerRewardDue(hiderAddress, 0)
//         .unwrap();

//     //finder player should be due 1 share of the reward
//     assert(hiderAddress_playerRewardDue_result == 0, 'Reward value should be zero');
// }

// #[test]
// #[should_panic]
// fn test_calculateRewardDue_0() {
//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     #[feature("safe_dispatcher")]
//     let calculateRewardDue_result = safe_dispatcher._calculateRewardDue(0).unwrap();

//     //finder player should be due 1 share of the reward
//     assert(calculateRewardDue_result == 0, 'Reward value should be zero');
// }

//skip
// #[test]
// fn test_calculateRewardDue_2() {
//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     #[feature("safe_dispatcher")]
//     let calculateRewardDue_result = safe_dispatcher._calculateRewardDue(2).unwrap();

//     //finder player should be due 1 share of the reward
//     assert(
//         (calculateRewardDue_result + 10000000000000 + 2500000000000) == (35000000000000 * 2),
//         'Reward value should be zero'
//     );
// }

//skip
// #[test]
// fn test_spawnNewPosition() {
//     //should spwan a position in the game and check that the player is at that position.

//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     let address1: ContractAddress = contract_address_const::<
//         0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
//     >();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._spawnNewPosition(address1, 0).unwrap();

//     #[feature("safe_dispatcher")]
//     let getFinderPlayerPosition_result = safe_dispatcher
//         .getFinderPlayerPosition(address1, 0)
//         .unwrap();

//     assert(getFinderPlayerPosition_result == (5, 5), 'Position not recorded');
// }

//skip
// #[test]
// #[should_panic]
// fn test_spawnNewPosition_twice() {
//     //should spawn a poistion for a player and try again to spawn a new position; but should fail
//     as the player already has a position.

//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     let address1: ContractAddress = contract_address_const::<
//         0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
//     >();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._spawnNewPosition(address1, 0).unwrap();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher.getFinderPlayerPosition(address1, 0).unwrap();

//     #[feature("safe_dispatcher")]
//     safe_dispatcher._spawnNewPosition(address1, 0).unwrap();
// }

// #[test]
// fn test_getSeed() {
//     //should spawn a poistion for a player and try again to spawn a new position; but should fail
//     as the player already has a position.

//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     let address1: ContractAddress = contract_address_const::<
//         0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
//     >();

//     #[feature("safe_dispatcher")]
//     let result = safe_dispatcher._getSeed(address1).unwrap();

//     println!("result {:?}", result);
// }

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
fn test_getSeed() {
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
    let dispatcher = IHelloStarknetDispatcher { contract_address };

    let (participationMin, roundCap, freeHops, freeSpawns) = dispatcher.get_hop_limits();
    assert(participationMin == 28, 'participationMin != 28');
    assert(roundCap == 40, 'roundCap != 40');
    assert(freeHops == 22, 'freeHops != 22');
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

    // No root until the owner publishes one, so nobody is whitelisted yet.
    assert(dispatcher.get_whitelist_merkle_root() == 0, 'root should start unset');
}

// The Daily Volume Multiplier bands. Band 0 covering three treasures is what
// lines up with the fee tier and the gate.
#[test]
fn test_volume_multiplier_bands() {
    let contract_address = deploy_contract("HelloStarknet");
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
    let dispatcher = IHelloStarknetDispatcher { contract_address };

    let player: ContractAddress = contract_address_const::<0x1234>();

    assert(dispatcher.get_free_hops_remaining(player) == 22, 'free hops != 22');
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
fn deploy_wired(
    player: ContractAddress, playerFunds: u256,
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

    let (game, _) = contract.deploy(@constructorCalldata).unwrap();

    // Fund the player and let the game contract spend on their behalf.
    IMockERC20Dispatcher { contract_address: gameToken }.mint(player, playerFunds);

    start_cheat_caller_address(gameToken, player);
    ERC20ABIDispatcher { contract_address: gameToken }.approve(game, playerFunds);
    stop_cheat_caller_address(gameToken);

    // Fund the game with ROZ. Without this the coverage rule refuses every
    // credit and rewards silently read back as zero - which would make these
    // tests pass for the wrong reason.
    IMockERC20Dispatcher { contract_address: rewardToken }
        .mint(game, 1000000000000000000000);

    (game, gameToken, rewardToken)
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
// hopRewardBelowThreshold and it earns 22 x 0.15 = 3.3 ROZ a day for nothing
// but gas. That 3.3 is the figure the 709,838-wallet estimate rests on.
#[test]
fn test_free_hops_earn_but_never_count_as_spend() {
    let player: ContractAddress = contract_address_const::<0xb002>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, player);
    dispatcher.finder_player_generate_position();

    assert(dispatcher.get_free_hops_remaining(player) == 22, 'should start with 22');

    // Twenty-two free hops. Direction 1 and 2 alternate so the player walks
    // back and forth rather than off the edge of the 14x14 board.
    let mut hopped: u32 = 0;
    loop {
        if (hopped == 22) {
            break;
        }
        hop_safely(game, player);
        hopped = hopped + 1;
    }
    stop_cheat_caller_address(game);

    let (hopsToday, _, _, spendToday, freeUsed) = dispatcher.get_player_daily_state(player);

    assert(hopsToday == 22, 'should have hopped 22');
    assert(freeUsed == 22, 'all 22 free hops used');
    assert(dispatcher.get_free_hops_remaining(player) == 0, 'allowance should be spent');

    // NOTHING was charged, so nothing is spend - which is exactly why free play
    // alone can never clear the gate however many hops are taken.
    assert(spendToday == 0, 'free hops are not spend');
    assert(dispatcher.get_player_lifetime_spend(player) == 0, 'free hops not lifetime spend');

    // 22 x 0.15 = 3.3 ROZ. A free hop earns exactly what a paid hop by the same
    // wallet would - the rate is set by the gate, never by whether the hop was
    // charged for.
    assert(dispatcher.get_reward_token_pending(player) == 3300000000000000000, 'should be 3.3 ROZ');
}

// TEST 5e-i continued - PARTICIPATION IS LOCKED TWICE OVER for a free player.
//
// The wallet cannot reach 28 hops on a 22-hop allowance, and even if it could
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
        if (hopped == 22) {
            break;
        }
        hop_safely(game, player);
        hopped = hopped + 1;
    }
    stop_cheat_caller_address(game);

    // 3.3 ROZ and not a unit more. An 18-ROZ participation bonus on top would
    // be immediately visible here.
    assert(dispatcher.get_reward_token_pending(player) == 3300000000000000000, 'no bonus expected');
}

// The 2.5 tier prices, and the fact that a paid hop DOES count as spend.
//
// Hops 1-22 are free. Hop 23 is the first charged one, at the opening tier
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
        if (hopped == 22) {
            break;
        }
        hop_safely(game, player);
        hopped = hopped + 1;
    }

    let (_, _, _, spendBefore, _) = dispatcher.get_player_daily_state(player);
    assert(spendBefore == 0, 'free hops cost nothing');

    // Hop 23 - the first paid one.
    hop_safely(game, player);
    stop_cheat_caller_address(game);

    let (hopsToday, _, _, spendAfter, _) = dispatcher.get_player_daily_state(player);

    assert(hopsToday == 23, 'should have hopped 23');

    // The opening tier, $0.005. Band 0 runs to daily hop 25.
    let (bandLimit, bandPrice) = dispatcher.get_hop_price_band(0);
    assert(bandLimit == 25, 'band 0 should end at 25');
    assert(spendAfter == bandPrice, 'hop 23 should cost band 0');
    assert(spendAfter == 5000, 'band 0 should be 0.005');
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

    // 28 hops: 22 free, then 6 paid at the opening tiers. Nowhere near $0.60.
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

    // Only the owner may publish a root.
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
    dispatcher.update_whitelist_caps(20, 30, 20);
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
    dispatcher.update_whitelist_caps(12, 500, 100);
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

// Only the owner may publish a root. If anyone could, the whitelist would be
// worthless.
#[test]
#[feature("safe_dispatcher")]
fn test_only_owner_publishes_the_root() {
    let alice: ContractAddress = contract_address_const::<0xa11ce>();
    let (game, _, _) = deploy_wired(alice, 100000000);
    let safe = IHelloStarknetSafeDispatcher { contract_address: game };

    start_cheat_caller_address(game, alice);
    let attempt = safe.set_whitelist_merkle_root(0x1234);
    stop_cheat_caller_address(game);

    assert(attempt.is_err(), 'non-owner must not set root');
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

    // The $5 stake is still claimable by the hider, so it is not sweepable.
    // Only the $0.20 fee is the house's.
    let heldUsdc = ERC20ABIDispatcher { contract_address: gameToken }.balance_of(game);
    assert(heldUsdc == STAKE + FEE_BASE, 'contract should hold 5.20');
    assert(dispatcher.get_sweepable_balance(gameToken) == FEE_BASE, 'only the fee is sweepable');
}

// ---------------------------------------------------------------------------
// CLAIM DISCOVERY - get_reward_claimed and get_claimable_weeks
// ---------------------------------------------------------------------------

// Open the next round as the owner.
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
// totalNumberOfHidersFromThePreviousWeek is passed as 0 rather than the
// constructor's 3 deliberately. That argument overwrites
// total_reward_shares_for_hiders for the round being opened - a slot hides have
// ALREADY written to, because they credit a week ahead. Zero keeps these tests
// measuring claim discovery rather than that interaction.
fn advance_round_with_hider_fee(game: ContractAddress, hiderFee: u256) {
    let owner: ContractAddress = contract_address_const::<
        0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833,
    >();

    let dispatcher = IHelloStarknetDispatcher { contract_address: game };

    start_cheat_caller_address(game, owner);
    dispatcher
        .start_new_game(
            0x1234, // root - unread by anything on the claim path
            100000, // $0.10 finder fee, as deployed
            hiderFee,
            1000000, // $1.00 spawn fee, as deployed
            14,
            14,
            0, // see the note above
            0,
        );
    stop_cheat_caller_address(game);
}

fn advance_round(game: ContractAddress) {
    advance_round_with_hider_fee(game, STAKE);
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

// TEST 5 - THE REGRESSION _isRewardClaimable EXISTS TO PREVENT.
//
// _calculateRewardDue ASSERTS the hider fee exceeds the three deductions. Reach
// it through _playerRewardDue on a round funded below that line and the call
// reverts - which in a scan would destroy the answer for every other week in
// the range, not just the bad one.
//
// Here week 2 is funded by week 1's hider fee of $0.001, far under the $0.012833
// of deductions. get_player_reward_due(2) therefore reverts, and the scan across
// it must still come back with week 1.
#[test]
#[feature("safe_dispatcher")]
fn test_claimable_weeks_survives_a_round_funded_below_its_fees() {
    let player: ContractAddress = contract_address_const::<0xf00d>();
    let (game, _, _) = deploy_wired(player, 100000000);
    let dispatcher = IHelloStarknetDispatcher { contract_address: game };
    let safe = IHelloStarknetSafeDispatcher { contract_address: game };

    // Week 1 gets a normal share, funded by the constructor's $5.00.
    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    // Open week 1 with a hider fee UNDER the deductions.
    advance_round_with_hider_fee(game, 1000);

    // This hide credits week 2, whose funding week is now that $0.001 round.
    start_cheat_caller_address(game, player);
    dispatcher.hide_treasure();
    stop_cheat_caller_address(game);

    // Carry on so both week 1 and week 2 are finished.
    advance_round(game);
    advance_round(game);

    // The single-week getter reverts on week 2, exactly as documented.
    let probe = safe.get_player_reward_due(2, player);
    assert(probe.is_err(), 'week 2 must revert');

    // The scan spans it anyway, and still reports the round that is good.
    let weeks = dispatcher.get_claimable_weeks(player, 0, 8);
    assert(weeks.len() == 1, 'bad round must not kill scan');
    assert(*weeks.at(0) == 1_u256, 'week 1 survives');
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
