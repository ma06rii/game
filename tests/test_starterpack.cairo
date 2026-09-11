use core::serde::Serde;
use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use project_name::mock_erc20::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};
use project_name::starterpack::TreasureGameStarterpack::{Event, PackIssued, WelcomeIssued};
use project_name::starterpack::{
    IStarterpackImplementationDispatcher, IStarterpackImplementationDispatcherTrait,
    IStarterpackImplementationSafeDispatcher, IStarterpackImplementationSafeDispatcherTrait,
    ITreasureGameStarterpackDispatcher, ITreasureGameStarterpackDispatcherTrait,
    ITreasureGameStarterpackSafeDispatcher, ITreasureGameStarterpackSafeDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const};

const WELCOME_ID: u32 = 101;
const WEEK_ID: u32 = 202;

const WELCOME_USDC: u256 = 6000000;
const WELCOME_STRK: u256 = 2500000000000000000;
const WELCOME_ROZ: u256 = 1000000000000000000000;
const WEEK_USDC: u256 = 18000000;
const WEEK_STRK: u256 = 6000000000000000000;
const WEEK_ROZ: u256 = 3000000000000000000000;
const MIN_HIDE_STAKE_USDC: u256 = 5000000;

#[derive(Drop, Copy)]
struct StarterpackSetup {
    pack: ContractAddress,
    usdc: ContractAddress,
    strk: ContractAddress,
    roz: ContractAddress,
}

fn owner() -> ContractAddress {
    contract_address_const::<0x510>()
}

fn arcade() -> ContractAddress {
    contract_address_const::<0xa7cade>()
}

fn recipient_one() -> ContractAddress {
    contract_address_const::<0x1001>()
}

fn recipient_two() -> ContractAddress {
    contract_address_const::<0x1002>()
}

fn stranger() -> ContractAddress {
    contract_address_const::<0xbad>()
}

fn deploy_mock_token(name: ByteArray, symbol: ByteArray) -> ContractAddress {
    let contract = declare("MockERC20").unwrap().contract_class();
    let mut calldata = ArrayTrait::<felt252>::new();
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

fn deploy_starterpack(fund_inventory: bool, configure_ids: bool) -> StarterpackSetup {
    let usdc = deploy_mock_token("MockUSDC", "mUSDC");
    let strk = deploy_mock_token("MockSTRK", "mSTRK");
    let roz = deploy_mock_token("MockROZ", "mROZ");

    let contract = declare("TreasureGameStarterpack").unwrap().contract_class();
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(owner().into());
    calldata.append(arcade().into());
    calldata.append(usdc.into());
    calldata.append(strk.into());
    calldata.append(roz.into());
    let (pack, _) = contract.deploy(@calldata).unwrap();

    if configure_ids {
        let administration = ITreasureGameStarterpackDispatcher { contract_address: pack };
        start_cheat_caller_address(pack, owner());
        administration.set_pack_ids(WELCOME_ID, WEEK_ID);
        stop_cheat_caller_address(pack);
    }

    if fund_inventory {
        // Enough for several Welcome packs and high-quantity Week tests.
        IMockERC20Dispatcher { contract_address: usdc }.mint(pack, 1000000000);
        IMockERC20Dispatcher { contract_address: strk }.mint(pack, 1000000000000000000000);
        IMockERC20Dispatcher { contract_address: roz }.mint(pack, 1000000000000000000000000);
    }

    StarterpackSetup { pack, usdc, strk, roz }
}

#[test]
fn test_exact_defaults_and_views() {
    let setup = deploy_starterpack(true, true);
    let administration = ITreasureGameStarterpackDispatcher { contract_address: setup.pack };
    let issuer = IStarterpackImplementationDispatcher { contract_address: setup.pack };

    let (welcome_id, week_id) = administration.get_pack_ids();
    assert(welcome_id == WELCOME_ID, 'wrong Welcome ID');
    assert(week_id == WEEK_ID, 'wrong Week ID');
    assert(administration.are_pack_ids_configured(), 'IDs should be configured');

    let (usdc, strk, roz) = administration.get_token_addresses();
    assert(usdc == setup.usdc, 'wrong USDC token');
    assert(strk == setup.strk, 'wrong STRK token');
    assert(roz == setup.roz, 'wrong ROZ token');
    assert(administration.get_arcade_registry() == arcade(), 'wrong Arcade registry');
    assert(administration.get_min_hide_stake_usdc() == MIN_HIDE_STAKE_USDC, 'wrong minimum stake');

    let (welcome_usdc, welcome_strk, welcome_roz) = administration.pack_amounts(WELCOME_ID);
    assert(welcome_usdc == WELCOME_USDC, 'Welcome USDC units');
    assert(welcome_strk == WELCOME_STRK, 'Welcome STRK units');
    assert(welcome_roz == WELCOME_ROZ, 'Welcome ROZ units');

    let (week_usdc, week_strk, week_roz) = administration.pack_amounts(WEEK_ID);
    assert(week_usdc == WEEK_USDC, 'Week USDC units');
    assert(week_strk == WEEK_STRK, 'Week STRK units');
    assert(week_roz == WEEK_ROZ, 'Week ROZ units');

    match issuer.supply(WELCOME_ID) {
        Option::None => (),
        Option::Some(_) => core::panic_with_felt252('supply must be unlimited'),
    }
    match issuer.supply(999) {
        Option::None => (),
        Option::Some(_) => core::panic_with_felt252('unknown supply not unlimited'),
    };
}

#[test]
#[feature("safe_dispatcher")]
fn test_welcome_issues_once_with_exact_amounts_and_events() {
    let setup = deploy_starterpack(true, true);
    let recipient = recipient_one();
    let issuer = IStarterpackImplementationDispatcher { contract_address: setup.pack };
    let issuer_safe = IStarterpackImplementationSafeDispatcher { contract_address: setup.pack };
    let administration = ITreasureGameStarterpackDispatcher { contract_address: setup.pack };
    let mut spy = spy_events();

    start_cheat_caller_address(setup.pack, arcade());
    issuer.on_issue(recipient, WELCOME_ID, 1);
    stop_cheat_caller_address(setup.pack);

    assert(administration.welcome_issued(recipient), 'Welcome flag not stored');
    assert(
        ERC20ABIDispatcher { contract_address: setup.usdc }.balance_of(recipient) == WELCOME_USDC,
        'wrong Welcome USDC',
    );
    assert(
        ERC20ABIDispatcher { contract_address: setup.strk }.balance_of(recipient) == WELCOME_STRK,
        'wrong Welcome STRK',
    );
    assert(
        ERC20ABIDispatcher { contract_address: setup.roz }.balance_of(recipient) == WELCOME_ROZ,
        'wrong Welcome ROZ',
    );

    spy
        .assert_emitted(
            @array![
                (setup.pack, Event::WelcomeIssued(WelcomeIssued { recipient })),
                (
                    setup.pack,
                    Event::PackIssued(
                        PackIssued {
                            recipient,
                            starterpack_id: WELCOME_ID,
                            quantity: 1,
                            usdc: WELCOME_USDC,
                            strk: WELCOME_STRK,
                            roz: WELCOME_ROZ,
                        },
                    ),
                ),
            ],
        );

    start_cheat_caller_address(setup.pack, arcade());
    let second = issuer_safe.on_issue(recipient, WELCOME_ID, 1);
    stop_cheat_caller_address(setup.pack);
    assert(second.is_err(), 'second Welcome must revert');
}

#[test]
#[feature("safe_dispatcher")]
fn test_week_can_issue_twice_and_multiplies_quantity() {
    let setup = deploy_starterpack(true, true);
    let recipient = recipient_one();
    let issuer = IStarterpackImplementationDispatcher { contract_address: setup.pack };
    let issuer_safe = IStarterpackImplementationSafeDispatcher { contract_address: setup.pack };

    start_cheat_caller_address(setup.pack, arcade());
    issuer.on_issue(recipient, WEEK_ID, 2);
    issuer.on_issue(recipient, WEEK_ID, 1);
    let zero_quantity = issuer_safe.on_issue(recipient, WEEK_ID, 0);
    stop_cheat_caller_address(setup.pack);

    assert(zero_quantity.is_err(), 'zero Week quantity must revert');
    assert(
        ERC20ABIDispatcher { contract_address: setup.usdc }.balance_of(recipient) == WEEK_USDC * 3,
        'wrong Week USDC total',
    );
    assert(
        ERC20ABIDispatcher { contract_address: setup.strk }.balance_of(recipient) == WEEK_STRK * 3,
        'wrong Week STRK total',
    );
    assert(
        ERC20ABIDispatcher { contract_address: setup.roz }.balance_of(recipient) == WEEK_ROZ * 3,
        'wrong Week ROZ total',
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_invalid_quantities_unknown_pack_and_non_arcade_revert() {
    let setup = deploy_starterpack(true, true);
    let issuer_safe = IStarterpackImplementationSafeDispatcher { contract_address: setup.pack };

    start_cheat_caller_address(setup.pack, arcade());
    let welcome_quantity = issuer_safe.on_issue(recipient_one(), WELCOME_ID, 2);
    let unknown = issuer_safe.on_issue(recipient_one(), 999, 1);
    stop_cheat_caller_address(setup.pack);
    assert(welcome_quantity.is_err(), 'Welcome quantity 2 must revert');
    assert(unknown.is_err(), 'unknown pack must revert');

    start_cheat_caller_address(setup.pack, stranger());
    let unauthorized = issuer_safe.on_issue(recipient_one(), WEEK_ID, 1);
    stop_cheat_caller_address(setup.pack);
    assert(unauthorized.is_err(), 'non-Arcade issue must revert');

    let unconfigured = deploy_starterpack(true, false);
    let unconfigured_safe = IStarterpackImplementationSafeDispatcher {
        contract_address: unconfigured.pack,
    };
    start_cheat_caller_address(unconfigured.pack, arcade());
    let before_ids = unconfigured_safe.on_issue(recipient_one(), WELCOME_ID, 1);
    stop_cheat_caller_address(unconfigured.pack);
    assert(before_ids.is_err(), 'issuance before IDs must revert');
}

#[test]
fn test_pack_amount_update_only_changes_future_issues() {
    let setup = deploy_starterpack(true, true);
    let issuer = IStarterpackImplementationDispatcher { contract_address: setup.pack };
    let administration = ITreasureGameStarterpackDispatcher { contract_address: setup.pack };
    let first = recipient_one();
    let second = recipient_two();

    start_cheat_caller_address(setup.pack, arcade());
    issuer.on_issue(first, WELCOME_ID, 1);
    stop_cheat_caller_address(setup.pack);

    let new_usdc: u256 = 8000000;
    let new_strk: u256 = 3000000000000000000;
    let new_roz: u256 = 1200000000000000000000;
    start_cheat_caller_address(setup.pack, owner());
    administration.set_pack_amounts(WELCOME_ID, new_usdc, new_strk, new_roz);
    stop_cheat_caller_address(setup.pack);

    start_cheat_caller_address(setup.pack, arcade());
    issuer.on_issue(second, WELCOME_ID, 1);
    stop_cheat_caller_address(setup.pack);

    let usdc = ERC20ABIDispatcher { contract_address: setup.usdc };
    let strk = ERC20ABIDispatcher { contract_address: setup.strk };
    let roz = ERC20ABIDispatcher { contract_address: setup.roz };
    assert(usdc.balance_of(first) == WELCOME_USDC, 'past USDC was changed');
    assert(strk.balance_of(first) == WELCOME_STRK, 'past STRK was changed');
    assert(roz.balance_of(first) == WELCOME_ROZ, 'past ROZ was changed');
    assert(usdc.balance_of(second) == new_usdc, 'new USDC not used');
    assert(strk.balance_of(second) == new_strk, 'new STRK not used');
    assert(roz.balance_of(second) == new_roz, 'new ROZ not used');
}

#[test]
#[feature("safe_dispatcher")]
fn test_non_owner_cannot_change_configuration_or_withdraw() {
    let setup = deploy_starterpack(true, true);
    let safe = ITreasureGameStarterpackSafeDispatcher { contract_address: setup.pack };

    start_cheat_caller_address(setup.pack, stranger());
    let amounts = safe.set_pack_amounts(WELCOME_ID, 8000000, WELCOME_STRK, WELCOME_ROZ);
    let ids = safe.set_pack_ids(303, 404);
    let tokens = safe.set_token_addresses(setup.usdc, setup.strk, setup.roz);
    let stake = safe.set_min_hide_stake_usdc(4000000);
    let registry = safe.set_arcade_registry(stranger());
    let withdrawal = safe.withdraw_unsold_tokens(setup.usdc, stranger(), 1);
    stop_cheat_caller_address(setup.pack);

    assert(amounts.is_err(), 'non-owner changed amounts');
    assert(ids.is_err(), 'non-owner changed IDs');
    assert(tokens.is_err(), 'non-owner changed tokens');
    assert(stake.is_err(), 'non-owner changed minimum');
    assert(registry.is_err(), 'non-owner changed registry');
    assert(withdrawal.is_err(), 'non-owner withdrew inventory');
}

#[test]
#[feature("safe_dispatcher")]
fn test_minimum_hide_stake_invariants() {
    let setup = deploy_starterpack(true, true);
    let administration = ITreasureGameStarterpackDispatcher { contract_address: setup.pack };
    let safe = ITreasureGameStarterpackSafeDispatcher { contract_address: setup.pack };

    start_cheat_caller_address(setup.pack, owner());
    let below_stake = safe.set_pack_amounts(WELCOME_ID, 4000000, WELCOME_STRK, WELCOME_ROZ);
    let raised_too_soon = safe.set_min_hide_stake_usdc(7000000);
    assert(below_stake.is_err(), 'Welcome below stake must revert');
    assert(raised_too_soon.is_err(), 'high minimum did not revert');

    administration.set_pack_amounts(WELCOME_ID, 8000000, WELCOME_STRK, WELCOME_ROZ);
    administration.set_min_hide_stake_usdc(7000000);
    stop_cheat_caller_address(setup.pack);

    assert(administration.get_min_hide_stake_usdc() == 7000000, 'minimum was not raised');
    let (welcome_usdc, _, _) = administration.pack_amounts(WELCOME_ID);
    assert(welcome_usdc == 8000000, 'Welcome was not raised first');
}

#[test]
#[feature("safe_dispatcher")]
fn test_insufficient_inventory_is_atomic_and_does_not_consume_welcome() {
    let setup = deploy_starterpack(false, true);
    let issuer_safe = IStarterpackImplementationSafeDispatcher { contract_address: setup.pack };
    let administration = ITreasureGameStarterpackDispatcher { contract_address: setup.pack };
    let recipient = recipient_one();

    start_cheat_caller_address(setup.pack, arcade());
    let result = issuer_safe.on_issue(recipient, WELCOME_ID, 1);
    stop_cheat_caller_address(setup.pack);

    assert(result.is_err(), 'empty inventory must revert');
    assert(!administration.welcome_issued(recipient), 'failed issue consumed Welcome');
    assert(
        ERC20ABIDispatcher { contract_address: setup.usdc }.balance_of(recipient) == 0,
        'failed issue transferred USDC',
    );
    assert(
        ERC20ABIDispatcher { contract_address: setup.strk }.balance_of(recipient) == 0,
        'failed issue transferred STRK',
    );
    assert(
        ERC20ABIDispatcher { contract_address: setup.roz }.balance_of(recipient) == 0,
        'failed issue transferred ROZ',
    );
}

#[test]
#[feature("safe_dispatcher")]
fn test_welcome_limit_survives_pack_id_update() {
    let setup = deploy_starterpack(true, true);
    let issuer = IStarterpackImplementationDispatcher { contract_address: setup.pack };
    let issuer_safe = IStarterpackImplementationSafeDispatcher { contract_address: setup.pack };
    let administration = ITreasureGameStarterpackDispatcher { contract_address: setup.pack };
    let recipient = recipient_one();

    start_cheat_caller_address(setup.pack, arcade());
    issuer.on_issue(recipient, WELCOME_ID, 1);
    stop_cheat_caller_address(setup.pack);

    start_cheat_caller_address(setup.pack, owner());
    administration.set_pack_ids(303, 404);
    stop_cheat_caller_address(setup.pack);

    start_cheat_caller_address(setup.pack, arcade());
    let second = issuer_safe.on_issue(recipient, 303, 1);
    stop_cheat_caller_address(setup.pack);
    assert(second.is_err(), 'new ID bypassed Welcome limit');
}

#[test]
fn test_owner_can_withdraw_unsold_inventory_and_change_registry() {
    let setup = deploy_starterpack(true, true);
    let administration = ITreasureGameStarterpackDispatcher { contract_address: setup.pack };
    let receiver = recipient_two();
    let new_registry: ContractAddress = contract_address_const::<0x777>();

    start_cheat_caller_address(setup.pack, owner());
    administration.withdraw_unsold_tokens(setup.usdc, receiver, 1234567);
    administration.set_arcade_registry(new_registry);
    stop_cheat_caller_address(setup.pack);

    assert(
        ERC20ABIDispatcher { contract_address: setup.usdc }.balance_of(receiver) == 1234567,
        'withdrawal did not arrive',
    );
    assert(administration.get_arcade_registry() == new_registry, 'registry was not updated');
}
