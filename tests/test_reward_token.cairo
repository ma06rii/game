use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::{ContractAddress, contract_address_const};

const INITIAL_SUPPLY: u256 = 5000000000000000000000000000;

#[test]
fn reward_token_metadata_matches_zee_bucks_branding() {
    let recipient: ContractAddress = contract_address_const::<0x1001>();
    let owner: ContractAddress = contract_address_const::<0x510>();
    let contract = declare("ROZToken").unwrap().contract_class();

    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(recipient.into());
    calldata.append(owner.into());
    let (address, _) = contract.deploy(@calldata).unwrap();

    let token = ERC20ABIDispatcher { contract_address: address };
    assert(token.name() == "Zee Bucks", 'wrong token name');
    assert(token.symbol() == "RZBX", 'wrong token symbol');
    assert(token.decimals() == 18, 'wrong token decimals');
    assert(token.balance_of(recipient) == INITIAL_SUPPLY, 'wrong initial supply');
}
