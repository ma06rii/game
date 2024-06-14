use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait};
use project_name::IHelloStarknetSafeDispatcher;
use project_name::IHelloStarknetSafeDispatcherTrait;
use project_name::IHelloStarknetDispatcher;
use project_name::IHelloStarknetDispatcherTrait;
use starknet::{
    get_caller_address, class_hash::class_hash_const, contract_address_const, get_contract_address
};

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[test]
fn test_verify() {
    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    #[feature("safe_dispatcher")]
    let result = safe_dispatcher
        .verify(
            0xbc19a39ffdeb3ff487a290fd65626b9592fe3fb625937ab468940c4c58966849,
            0x03e48ef2868eb9039abb12f13e6d4aa79059381a8d3d10c9b5b344d41fad189f,
            array![
                0x4dfa50b1d7dd9d841c1d5e20c75ed801f483f1e837d255bc36716bd371ba52ac,
                0x61a3acbba2a8ef1be4bf74714ddc2cf18e6dceef124978add3db7e34137eaaf2
            ]
        )
        .unwrap();

    assert(@result == @true, 'Not verified');
}

#[test]
fn test_createNewGame() {
    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    #[feature("safe_dispatcher")]
    let result = safe_dispatcher
        ._createNewGame(
            0x97a59a28d105842c91d0c411fe8992d4ed39c700bc44467d30589a2679d9b9cc,
            100,
            10,
            5,
            5,
            1,
            1000,
            0
        )
        .unwrap();

    assert(result == true, 'Game not created');
}

#[test]
fn pass_test_validateTreasureCoordinates() {
    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    let address1: ContractAddress = contract_address_const::<
        0x0651ac246f230feee9127b11ec3568a90d78bc2b7c954a2a4f5655f435e9da73
    >();
    let address2: ContractAddress = contract_address_const::<
        0x069a4214bb1e4ba496b9d7fd1f24932ac10d3be952e1cdfca8b309ad9c5a4571
    >();
    let address3: ContractAddress = contract_address_const::<
        0x07e3a6104a5022a7e768e973ce2f1db8203be67c2f34dab637742c56b7ee7de6
    >();

    #[feature("safe_dispatcher")]
    safe_dispatcher._rewardGamer(address1, 0).unwrap();

    #[feature("safe_dispatcher")]
    safe_dispatcher._rewardGamer(address2, 0).unwrap();

    #[feature("safe_dispatcher")]
    safe_dispatcher._rewardGamer(address3, 0).unwrap();

    let finderAddress: ContractAddress = contract_address_const::<
        0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
    >();

    let hiderAddress: ContractAddress = contract_address_const::<
        0x069a4214bb1e4ba496b9d7fd1f24932ac10d3be952e1cdfca8b309ad9c5a4571
    >();

    #[feature("safe_dispatcher")]
    let result = safe_dispatcher
        ._validateTreasureCoordinates(
            finderAddress,
            hiderAddress,
            0,
            0x03e48ef2868eb9039abb12f13e6d4aa79059381a8d3d10c9b5b344d41fad189f,
            array![
                0x4dfa50b1d7dd9d841c1d5e20c75ed801f483f1e837d255bc36716bd371ba52ac,
                0x61a3acbba2a8ef1be4bf74714ddc2cf18e6dceef124978add3db7e34137eaaf2
            ]
        )
        .unwrap();

    assert(result == true, 'Not verified');
}

#[test]
fn fail_test_validateTreasureCoordinates() {
    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    let address1: ContractAddress = contract_address_const::<
        0x0651ac246f230feee9127b11ec3568a90d78bc2b7c954a2a4f5655f435e9da73
    >();
    let address2: ContractAddress = contract_address_const::<
        0x069a4214bb1e4ba496b9d7fd1f24932ac10d3be952e1cdfca8b309ad9c5a4571
    >();
    let address3: ContractAddress = contract_address_const::<
        0x07e3a6104a5022a7e768e973ce2f1db8203be67c2f34dab637742c56b7ee7de6
    >();

    #[feature("safe_dispatcher")]
    safe_dispatcher._rewardGamer(address1, 0).unwrap();

    #[feature("safe_dispatcher")]
    safe_dispatcher._rewardGamer(address2, 0).unwrap();

    #[feature("safe_dispatcher")]
    safe_dispatcher._rewardGamer(address3, 0).unwrap();

    let finderAddress: ContractAddress = contract_address_const::<
        0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
    >();

    let hiderAddress: ContractAddress = contract_address_const::<
        0x069a4214bb1e4ba496b9d7fd1f24932ac10d3be952e1cdfca8b309ad9c5a4571
    >();

    #[feature("safe_dispatcher")]
    let result = safe_dispatcher
        ._validateTreasureCoordinates(
            finderAddress,
            hiderAddress,
            0,
            0x03e48ef2868eb9039abb12f13e6d4aa79059381a8d3d10c9b5b344d41fad189d,
            array![
                0x4dfa50b1d7dd9d841c1d5e20c75ed801f483f1e837d255bc36716bd371ba52ac,
                0x61a3acbba2a8ef1be4bf74714ddc2cf18e6dceef124978add3db7e34137eaaf2
            ]
        )
        .unwrap();

    assert(result == false, 'passes verification');
}


#[test]
fn test_getFinderPlayerPosition() {
    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    let address: ContractAddress = contract_address_const::<
        0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
    >();

    #[feature("safe_dispatcher")]
    safe_dispatcher._spawnNewPosition(address, 3, 3, 1).unwrap();

    #[feature("safe_dispatcher")]
    let getFinderPlayerPosition_result = safe_dispatcher
        ._getFinderPlayerPosition(address, 1)
        .unwrap();

    assert(getFinderPlayerPosition_result == (3, 3), 'No position');
}


#[test]
fn test_finderPlayerMovePosition() {
    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    let address: ContractAddress = contract_address_const::<
        0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
    >();

    #[feature("safe_dispatcher")]
    safe_dispatcher._spawnNewPosition(address, 3, 3, 0).unwrap();

    #[feature("safe_dispatcher")]
    let finderPlayerMovePosition_result = safe_dispatcher
        ._finderPlayerMovePosition(1, 1, address, 0)
        .unwrap();

    assert(finderPlayerMovePosition_result == (4, 4), 'No position');
}

#[test]
fn test_playerRewardDue() {
    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    let address1: ContractAddress = contract_address_const::<
        0x0651ac246f230feee9127b11ec3568a90d78bc2b7c954a2a4f5655f435e9da73
    >();
    let address2: ContractAddress = contract_address_const::<
        0x069a4214bb1e4ba496b9d7fd1f24932ac10d3be952e1cdfca8b309ad9c5a4571
    >();
    let address3: ContractAddress = contract_address_const::<
        0x07e3a6104a5022a7e768e973ce2f1db8203be67c2f34dab637742c56b7ee7de6
    >();

    #[feature("safe_dispatcher")]
    safe_dispatcher._rewardGamer(address1, 0).unwrap();

    #[feature("safe_dispatcher")]
    safe_dispatcher._rewardGamer(address2, 0).unwrap();

    #[feature("safe_dispatcher")]
    safe_dispatcher._rewardGamer(address3, 0).unwrap();

    #[feature("safe_dispatcher")]
    let playerRewardDue_result = safe_dispatcher._playerRewardDue(address1, 0).unwrap();

    //PlayerRewardToPay + GasFeeReservation + GameMasterFee == HiderFee 
    assert(
        (playerRewardDue_result + 10000000000000 + 2500000000000) == 35000000000000,
        'Reward value not correct'
    );
}

#[test]
fn test_playerRewardDue_afterFinderPlayerFindsTreasure() {
    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    let address1: ContractAddress = contract_address_const::<
        0x0651ac246f230feee9127b11ec3568a90d78bc2b7c954a2a4f5655f435e9da73
    >();
    let address2: ContractAddress = contract_address_const::<
        0x069a4214bb1e4ba496b9d7fd1f24932ac10d3be952e1cdfca8b309ad9c5a4571
    >();
    let address3: ContractAddress = contract_address_const::<
        0x07e3a6104a5022a7e768e973ce2f1db8203be67c2f34dab637742c56b7ee7de6
    >();

    #[feature("safe_dispatcher")]
    safe_dispatcher._rewardGamer(address1, 0).unwrap();

    #[feature("safe_dispatcher")]
    safe_dispatcher._rewardGamer(address2, 0).unwrap();

    #[feature("safe_dispatcher")]
    safe_dispatcher._rewardGamer(address3, 0).unwrap();

    let finderAddress: ContractAddress = contract_address_const::<
        0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
    >();

    let hiderAddress: ContractAddress = contract_address_const::<
        0x069a4214bb1e4ba496b9d7fd1f24932ac10d3be952e1cdfca8b309ad9c5a4571
    >();

    #[feature("safe_dispatcher")]
    safe_dispatcher
        ._validateTreasureCoordinates(
            finderAddress,
            hiderAddress,
            0,
            0x03e48ef2868eb9039abb12f13e6d4aa79059381a8d3d10c9b5b344d41fad189f,
            array![
                0x4dfa50b1d7dd9d841c1d5e20c75ed801f483f1e837d255bc36716bd371ba52ac,
                0x61a3acbba2a8ef1be4bf74714ddc2cf18e6dceef124978add3db7e34137eaaf2
            ]
        )
        .unwrap();

    #[feature("safe_dispatcher")]
    let finderAddress_playerRewardDue_result = safe_dispatcher
        ._playerRewardDue(finderAddress, 0)
        .unwrap();

    //finder player should be due 1 share of the reward
    assert(
        (finderAddress_playerRewardDue_result + 10000000000000 + 2500000000000) == 35000000000000,
        'Reward value not correct'
    );

    #[feature("safe_dispatcher")]
    let hiderAddress_playerRewardDue_result = safe_dispatcher
        ._playerRewardDue(hiderAddress, 0)
        .unwrap();

    //finder player should be due 1 share of the reward
    assert(hiderAddress_playerRewardDue_result == 0, 'Reward value should be zero');
}

#[test]
#[should_panic]
fn test_calculateRewardDue_0() {
    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    #[feature("safe_dispatcher")]
    let calculateRewardDue_result = safe_dispatcher._calculateRewardDue(0).unwrap();

    //finder player should be due 1 share of the reward
    assert(calculateRewardDue_result == 0, 'Reward value should be zero');
}


#[test]
fn test_calculateRewardDue_2() {
    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    #[feature("safe_dispatcher")]
    let calculateRewardDue_result = safe_dispatcher._calculateRewardDue(2).unwrap();

    //finder player should be due 1 share of the reward
    assert(
        (calculateRewardDue_result + 10000000000000 + 2500000000000) == (35000000000000 * 2),
        'Reward value should be zero'
    );
}

#[test]
fn test_spawnNewPosition() {
    //should spwan a position in the game and check that the player is at that position.

    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    let address1: ContractAddress = contract_address_const::<
        0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
    >();

    #[feature("safe_dispatcher")]
    safe_dispatcher._spawnNewPosition(address1, 5, 5, 0).unwrap();

    #[feature("safe_dispatcher")]
    let getFinderPlayerPosition_result = safe_dispatcher
        ._getFinderPlayerPosition(address1, 0)
        .unwrap();

    assert(getFinderPlayerPosition_result == (5, 5), 'Position not recorded');
}

#[test]
#[should_panic]
fn test_spawnNewPosition_twice() {
    //should spawn a poistion for a player and try again to spawn a new position; but should fail as the player already has a position.

    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    let address1: ContractAddress = contract_address_const::<
        0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
    >();

    #[feature("safe_dispatcher")]
    safe_dispatcher._spawnNewPosition(address1, 5, 5, 0).unwrap();

    #[feature("safe_dispatcher")]
    safe_dispatcher._getFinderPlayerPosition(address1, 0).unwrap();

    #[feature("safe_dispatcher")]
    safe_dispatcher._spawnNewPosition(address1, 5, 5, 0).unwrap();
}
