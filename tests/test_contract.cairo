use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait};
use project_name::IHelloStarknetSafeDispatcher;
use project_name::IHelloStarknetSafeDispatcherTrait;
use project_name::IHelloStarknetDispatcher;
use project_name::IHelloStarknetDispatcherTrait;


fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

//#[test]
//fn test_increase_balance() {
//    let contract_address = deploy_contract("HelloStarknet");

//    let dispatcher = IHelloStarknetDispatcher { contract_address };

//    let balance_before = dispatcher.get_balance();
//    assert(balance_before == 0, 'Invalid balance');

//    dispatcher.increase_balance(42);

//    let balance_after = dispatcher.get_balance();
//    assert(balance_after == 42, 'Invalid balance');
//}

// #[test]
// #[feature("safe_dispatcher")]
// fn test_cannot_increase_balance_with_zero_value() {
//     let contract_address = deploy_contract("HelloStarknet");

//     let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//     let balance_before = safe_dispatcher.get_balance().unwrap();
//     assert(balance_before == 0, 'Invalid balance');

//     match safe_dispatcher.increase_balance(0) {
//         Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
//         Result::Err(panic_data) => {
//             assert(*panic_data.at(0) == 'Amount cannot be 0', *panic_data.at(0));
//         }
//     };
// }

#[test]
fn test_verify() {
    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    #[feature("safe_dispatcher")]
    let result = safe_dispatcher
        .verify(
            0x97a59a28d105842c91d0c411fe8992d4ed39c700bc44467d30589a2679d9b9cc,
            0x10bc03ea268bc6eaf309fcda72d7bb87f64df533945211bc2d290c0512ad28d5,
            array![
                0x3055bd13643dc51c272cdb0a5cb115b0974e37ac51c25f1fedcc9eb6fb047e61,
                0xe37588d4469dbdb8667f0289e5f342adb9de1d114bbbe57421b9c67801c2e30d
            ]
        )
        .unwrap();

    assert(@result == @true, 'Not verified');
}


#[test]
fn test_startNewGame() {
    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    #[feature("safe_dispatcher")]
    let result = safe_dispatcher
        .startNewGame(
            0x97a59a28d105842c91d0c411fe8992d4ed39c700bc44467d30589a2679d9b9cc,
            100,
            10,
            5,
            5,
            1,
            1000
        )
        .unwrap();

    println!("result {:?}", result);
// assert(@result == @true, 'Not verified');
}
