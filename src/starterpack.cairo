// Cartridge Arcade starter-pack implementation for Realm of Zee.
//
// Arcade collects the purchase price before calling on_issue. This contract
// only distributes inventory that has already been transferred to it. Pack
// prices are therefore configured in Arcade, not in this storage.

use starknet::ContractAddress;

/// Cartridge's IStarterpackImplementation ABI. Keep these selectors and
/// parameter orders identical to the Arcade registry interface.
#[starknet::interface]
pub trait IStarterpackImplementation<TContractState> {
    fn on_issue(
        ref self: TContractState, recipient: ContractAddress, starterpack_id: u32, quantity: u32,
    );
    fn supply(self: @TContractState, starterpack_id: u32) -> Option<u32>;
}

/// Realm of Zee configuration and inventory API for the implementation.
#[starknet::interface]
pub trait ITreasureGameStarterpack<TContractState> {
    fn set_pack_amounts(
        ref self: TContractState, starterpack_id: u32, usdc: u256, strk: u256, roz: u256,
    );
    fn set_pack_ids(ref self: TContractState, welcome_id: u32, week_id: u32);
    fn set_token_addresses(
        ref self: TContractState,
        usdc: ContractAddress,
        strk: ContractAddress,
        roz: ContractAddress,
    );
    fn set_min_hide_stake_usdc(ref self: TContractState, amount: u256);
    fn set_arcade_registry(ref self: TContractState, arcade_registry: ContractAddress);
    fn withdraw_unsold_tokens(
        ref self: TContractState, token: ContractAddress, to: ContractAddress, amount: u256,
    );

    fn welcome_issued(self: @TContractState, recipient: ContractAddress) -> bool;
    fn pack_amounts(self: @TContractState, starterpack_id: u32) -> (u256, u256, u256);
    fn get_token_addresses(
        self: @TContractState,
    ) -> (ContractAddress, ContractAddress, ContractAddress);
    fn get_pack_ids(self: @TContractState) -> (u32, u32);
    fn are_pack_ids_configured(self: @TContractState) -> bool;
    fn get_min_hide_stake_usdc(self: @TContractState) -> u256;
    fn get_arcade_registry(self: @TContractState) -> ContractAddress;
}

pub mod errors {
    pub const UNKNOWN_PACK: felt252 = 'UNKNOWN_PACK';
    pub const WELCOME_ALREADY_ISSUED: felt252 = 'WELCOME_ALREADY_ISSUED';
    pub const WELCOME_QUANTITY_NOT_ONE: felt252 = 'WELCOME_QUANTITY_NOT_ONE';
    pub const INSUFFICIENT_INVENTORY: felt252 = 'INSUFFICIENT_INVENTORY';
    pub const ZERO_AMOUNT: felt252 = 'ZERO_AMOUNT';
    pub const WELCOME_USDC_BELOW_STAKE: felt252 = 'WELCOME_USDC_BELOW_STAKE';
    pub const WEEK_USDC_BELOW_STAKE: felt252 = 'WEEK_USDC_BELOW_STAKE';
    pub const MIN_STAKE_ABOVE_WELCOME_USDC: felt252 = 'MIN_STAKE_ABOVE_WELCOME_USDC';
    pub const MIN_STAKE_ABOVE_WEEK_USDC: felt252 = 'MIN_STAKE_ABOVE_WEEK_USDC';
    pub const NOT_OWNER: felt252 = 'NOT_OWNER';
    pub const NOT_ARCADE: felt252 = 'NOT_ARCADE';
    pub const ZERO_ADDRESS: felt252 = 'ZERO_ADDRESS';
    pub const PACK_IDS_MUST_DIFFER: felt252 = 'PACK_IDS_MUST_DIFFER';
    pub const TOKEN_ADDRESSES_MUST_DIFFER: felt252 = 'TOKEN_ADDRESSES_MUST_DIFFER';
}

#[starknet::contract]
pub mod TreasureGameStarterpack {
    use core::num::traits::Zero;
    use core::panic_with_felt252;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use super::{IStarterpackImplementation, ITreasureGameStarterpack, errors};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Defaults are written to storage by the constructor. Issuance always
    // reads storage, so an owner update affects only subsequent purchases.
    const DEFAULT_WELCOME_USDC: u256 = 6000000;
    const DEFAULT_WELCOME_STRK: u256 = 2500000000000000000;
    const DEFAULT_WELCOME_ROZ: u256 = 1000000000000000000000;
    const DEFAULT_WEEK_USDC: u256 = 18000000;
    const DEFAULT_WEEK_STRK: u256 = 6000000000000000000;
    const DEFAULT_WEEK_ROZ: u256 = 3000000000000000000000;
    const DEFAULT_MIN_HIDE_STAKE_USDC: u256 = 5000000;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        arcade_registry: ContractAddress,
        usdc_token: ContractAddress,
        strk_token: ContractAddress,
        roz_token: ContractAddress,
        welcome_id: u32,
        week_id: u32,
        pack_ids_configured: bool,
        welcome_usdc: u256,
        welcome_strk: u256,
        welcome_roz: u256,
        week_usdc: u256,
        week_strk: u256,
        week_roz: u256,
        min_hide_stake_usdc: u256,
        // Keyed only by recipient, deliberately not by pack ID. Updating the
        // Arcade ID can never make a second Welcome issuable to one wallet.
        welcome_issued: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PackIssued: PackIssued,
        WelcomeIssued: WelcomeIssued,
        PackAmountsUpdated: PackAmountsUpdated,
        MinHideStakeUpdated: MinHideStakeUpdated,
        TokenAddressesUpdated: TokenAddressesUpdated,
        PackIdsUpdated: PackIdsUpdated,
        ArcadeRegistryUpdated: ArcadeRegistryUpdated,
        UnsoldTokensWithdrawn: UnsoldTokensWithdrawn,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PackIssued {
        #[key]
        pub recipient: ContractAddress,
        #[key]
        pub starterpack_id: u32,
        pub quantity: u32,
        pub usdc: u256,
        pub strk: u256,
        pub roz: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WelcomeIssued {
        #[key]
        pub recipient: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PackAmountsUpdated {
        #[key]
        pub pack_id: u32,
        pub usdc: u256,
        pub strk: u256,
        pub roz: u256,
        #[key]
        pub caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MinHideStakeUpdated {
        pub old_amount: u256,
        pub new_amount: u256,
        #[key]
        pub caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenAddressesUpdated {
        pub old_usdc: ContractAddress,
        pub old_strk: ContractAddress,
        pub old_roz: ContractAddress,
        pub new_usdc: ContractAddress,
        pub new_strk: ContractAddress,
        pub new_roz: ContractAddress,
        #[key]
        pub caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PackIdsUpdated {
        pub old_welcome_id: u32,
        pub old_week_id: u32,
        pub new_welcome_id: u32,
        pub new_week_id: u32,
        #[key]
        pub caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ArcadeRegistryUpdated {
        pub old_registry: ContractAddress,
        pub new_registry: ContractAddress,
        #[key]
        pub caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct UnsoldTokensWithdrawn {
        #[key]
        pub token: ContractAddress,
        #[key]
        pub to: ContractAddress,
        pub amount: u256,
        pub caller: ContractAddress,
    }

    /// Deploy before registering the two Arcade packs. Once Arcade returns the
    /// numeric IDs, the owner completes setup with set_pack_ids.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        arcade_registry: ContractAddress,
        usdc_token: ContractAddress,
        strk_token: ContractAddress,
        roz_token: ContractAddress,
    ) {
        assert(!owner.is_zero(), errors::ZERO_ADDRESS);
        assert(!arcade_registry.is_zero(), errors::ZERO_ADDRESS);
        self._assert_token_addresses(usdc_token, strk_token, roz_token);

        self.ownable.initializer(owner);
        self.arcade_registry.write(arcade_registry);
        self.usdc_token.write(usdc_token);
        self.strk_token.write(strk_token);
        self.roz_token.write(roz_token);

        self.welcome_usdc.write(DEFAULT_WELCOME_USDC);
        self.welcome_strk.write(DEFAULT_WELCOME_STRK);
        self.welcome_roz.write(DEFAULT_WELCOME_ROZ);
        self.week_usdc.write(DEFAULT_WEEK_USDC);
        self.week_strk.write(DEFAULT_WEEK_STRK);
        self.week_roz.write(DEFAULT_WEEK_ROZ);
        self.min_hide_stake_usdc.write(DEFAULT_MIN_HIDE_STAKE_USDC);
    }

    #[abi(embed_v0)]
    impl StarterpackImplementationImpl of IStarterpackImplementation<ContractState> {
        /// Called by Arcade after payment has been collected. It never charges
        /// recipient and rejects direct calls from every other address.
        fn on_issue(
            ref self: ContractState, recipient: ContractAddress, starterpack_id: u32, quantity: u32,
        ) {
            self._assert_arcade();
            assert(!recipient.is_zero(), errors::ZERO_ADDRESS);
            assert(self.pack_ids_configured.read(), errors::UNKNOWN_PACK);

            let welcome_id = self.welcome_id.read();
            let week_id = self.week_id.read();

            if starterpack_id == welcome_id {
                assert(quantity == 1, errors::WELCOME_QUANTITY_NOT_ONE);
                assert(!self.welcome_issued.read(recipient), errors::WELCOME_ALREADY_ISSUED);

                let usdc = self.welcome_usdc.read();
                let strk = self.welcome_strk.read();
                let roz = self.welcome_roz.read();
                self._assert_inventory(usdc, strk, roz);

                // Effects precede interactions. Any failed token call reverts
                // this write together with every preceding transfer.
                self.welcome_issued.write(recipient, true);
                self._transfer_pack(recipient, usdc, strk, roz);

                self.emit(Event::WelcomeIssued(WelcomeIssued { recipient }));
                self
                    .emit(
                        Event::PackIssued(
                            PackIssued { recipient, starterpack_id, quantity, usdc, strk, roz },
                        ),
                    );
            } else if starterpack_id == week_id {
                assert(quantity != 0, errors::ZERO_AMOUNT);

                let multiplier: u256 = quantity.into();
                let usdc = self.week_usdc.read() * multiplier;
                let strk = self.week_strk.read() * multiplier;
                let roz = self.week_roz.read() * multiplier;
                self._assert_inventory(usdc, strk, roz);
                self._transfer_pack(recipient, usdc, strk, roz);

                self
                    .emit(
                        Event::PackIssued(
                            PackIssued { recipient, starterpack_id, quantity, usdc, strk, roz },
                        ),
                    );
            } else {
                panic_with_felt252(errors::UNKNOWN_PACK);
            }
        }

        /// Both packs are inventory-backed but have no registry supply ceiling.
        fn supply(self: @ContractState, starterpack_id: u32) -> Option<u32> {
            let _unused_id = starterpack_id;
            Option::None
        }
    }

    #[abi(embed_v0)]
    impl StarterpackAdministrationImpl of ITreasureGameStarterpack<ContractState> {
        /// Update one logical pack. Existing recipients are never topped up;
        /// on_issue reads these values only for the next successful issuance.
        fn set_pack_amounts(
            ref self: ContractState, starterpack_id: u32, usdc: u256, strk: u256, roz: u256,
        ) {
            self._assert_owner();
            assert(usdc != 0 && strk != 0 && roz != 0, errors::ZERO_AMOUNT);
            assert(self.pack_ids_configured.read(), errors::UNKNOWN_PACK);

            if starterpack_id == self.welcome_id.read() {
                assert(usdc >= self.min_hide_stake_usdc.read(), errors::WELCOME_USDC_BELOW_STAKE);
                self.welcome_usdc.write(usdc);
                self.welcome_strk.write(strk);
                self.welcome_roz.write(roz);
            } else if starterpack_id == self.week_id.read() {
                assert(usdc >= self.min_hide_stake_usdc.read(), errors::WEEK_USDC_BELOW_STAKE);
                self.week_usdc.write(usdc);
                self.week_strk.write(strk);
                self.week_roz.write(roz);
            } else {
                panic_with_felt252(errors::UNKNOWN_PACK);
            }

            self
                .emit(
                    Event::PackAmountsUpdated(
                        PackAmountsUpdated {
                            pack_id: starterpack_id, usdc, strk, roz, caller: get_caller_address(),
                        },
                    ),
                );
        }

        /// Set the IDs returned by Arcade registration. IDs may be updated if
        /// packs are re-registered, but they must always identify two packs.
        fn set_pack_ids(ref self: ContractState, welcome_id: u32, week_id: u32) {
            self._assert_owner();
            assert(welcome_id != week_id, errors::PACK_IDS_MUST_DIFFER);

            let old_welcome_id = self.welcome_id.read();
            let old_week_id = self.week_id.read();
            self.welcome_id.write(welcome_id);
            self.week_id.write(week_id);
            self.pack_ids_configured.write(true);

            self
                .emit(
                    Event::PackIdsUpdated(
                        PackIdsUpdated {
                            old_welcome_id,
                            old_week_id,
                            new_welcome_id: welcome_id,
                            new_week_id: week_id,
                            caller: get_caller_address(),
                        },
                    ),
                );
        }

        /// Change all payout token contracts atomically. Inventory left at an
        /// old token address remains recoverable with withdraw_unsold_tokens.
        fn set_token_addresses(
            ref self: ContractState,
            usdc: ContractAddress,
            strk: ContractAddress,
            roz: ContractAddress,
        ) {
            self._assert_owner();
            self._assert_token_addresses(usdc, strk, roz);

            let old_usdc = self.usdc_token.read();
            let old_strk = self.strk_token.read();
            let old_roz = self.roz_token.read();
            self.usdc_token.write(usdc);
            self.strk_token.write(strk);
            self.roz_token.write(roz);

            self
                .emit(
                    Event::TokenAddressesUpdated(
                        TokenAddressesUpdated {
                            old_usdc,
                            old_strk,
                            old_roz,
                            new_usdc: usdc,
                            new_strk: strk,
                            new_roz: roz,
                            caller: get_caller_address(),
                        },
                    ),
                );
        }

        /// Safety floor for pack USDC only. This does not update the game's
        /// hide stake; operations must change the two settings together.
        fn set_min_hide_stake_usdc(ref self: ContractState, amount: u256) {
            self._assert_owner();
            assert(amount != 0, errors::ZERO_AMOUNT);
            assert(amount <= self.welcome_usdc.read(), errors::MIN_STAKE_ABOVE_WELCOME_USDC);
            assert(amount <= self.week_usdc.read(), errors::MIN_STAKE_ABOVE_WEEK_USDC);

            let old_amount = self.min_hide_stake_usdc.read();
            self.min_hide_stake_usdc.write(amount);
            self
                .emit(
                    Event::MinHideStakeUpdated(
                        MinHideStakeUpdated {
                            old_amount, new_amount: amount, caller: get_caller_address(),
                        },
                    ),
                );
        }

        /// Update the only address allowed to issue packs. This is the
        /// migration joint if Cartridge deploys a replacement registry.
        fn set_arcade_registry(ref self: ContractState, arcade_registry: ContractAddress) {
            self._assert_owner();
            assert(!arcade_registry.is_zero(), errors::ZERO_ADDRESS);

            let old_registry = self.arcade_registry.read();
            self.arcade_registry.write(arcade_registry);
            self
                .emit(
                    Event::ArcadeRegistryUpdated(
                        ArcadeRegistryUpdated {
                            old_registry,
                            new_registry: arcade_registry,
                            caller: get_caller_address(),
                        },
                    ),
                );
        }

        /// Withdraw inventory that is not intended for future pack issues.
        /// The owner is responsible for retaining enough of all three assets.
        fn withdraw_unsold_tokens(
            ref self: ContractState, token: ContractAddress, to: ContractAddress, amount: u256,
        ) {
            self._assert_owner();
            assert(!token.is_zero() && !to.is_zero(), errors::ZERO_ADDRESS);
            assert(amount != 0, errors::ZERO_AMOUNT);

            let dispatcher = ERC20ABIDispatcher { contract_address: token };
            assert(
                dispatcher.balance_of(get_contract_address()) >= amount,
                errors::INSUFFICIENT_INVENTORY,
            );
            assert(dispatcher.transfer(to, amount), errors::INSUFFICIENT_INVENTORY);
            self
                .emit(
                    Event::UnsoldTokensWithdrawn(
                        UnsoldTokensWithdrawn { token, to, amount, caller: get_caller_address() },
                    ),
                );
        }

        fn welcome_issued(self: @ContractState, recipient: ContractAddress) -> bool {
            self.welcome_issued.read(recipient)
        }

        fn pack_amounts(self: @ContractState, starterpack_id: u32) -> (u256, u256, u256) {
            assert(self.pack_ids_configured.read(), errors::UNKNOWN_PACK);
            if starterpack_id == self.welcome_id.read() {
                (self.welcome_usdc.read(), self.welcome_strk.read(), self.welcome_roz.read())
            } else if starterpack_id == self.week_id.read() {
                (self.week_usdc.read(), self.week_strk.read(), self.week_roz.read())
            } else {
                panic_with_felt252(errors::UNKNOWN_PACK);
            }
        }

        fn get_token_addresses(
            self: @ContractState,
        ) -> (ContractAddress, ContractAddress, ContractAddress) {
            (self.usdc_token.read(), self.strk_token.read(), self.roz_token.read())
        }

        fn get_pack_ids(self: @ContractState) -> (u32, u32) {
            (self.welcome_id.read(), self.week_id.read())
        }

        fn are_pack_ids_configured(self: @ContractState) -> bool {
            self.pack_ids_configured.read()
        }

        fn get_min_hide_stake_usdc(self: @ContractState) -> u256 {
            self.min_hide_stake_usdc.read()
        }

        fn get_arcade_registry(self: @ContractState) -> ContractAddress {
            self.arcade_registry.read()
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn _assert_owner(self: @ContractState) {
            assert(get_caller_address() == self.ownable.Ownable_owner.read(), errors::NOT_OWNER);
        }

        fn _assert_arcade(self: @ContractState) {
            assert(get_caller_address() == self.arcade_registry.read(), errors::NOT_ARCADE);
        }

        fn _assert_token_addresses(
            self: @ContractState,
            usdc: ContractAddress,
            strk: ContractAddress,
            roz: ContractAddress,
        ) {
            assert(!usdc.is_zero() && !strk.is_zero() && !roz.is_zero(), errors::ZERO_ADDRESS);
            assert(usdc != strk && usdc != roz && strk != roz, errors::TOKEN_ADDRESSES_MUST_DIFFER);
        }

        fn _assert_inventory(self: @ContractState, usdc: u256, strk: u256, roz: u256) {
            let held_by = get_contract_address();
            let usdc_token = ERC20ABIDispatcher { contract_address: self.usdc_token.read() };
            let strk_token = ERC20ABIDispatcher { contract_address: self.strk_token.read() };
            let roz_token = ERC20ABIDispatcher { contract_address: self.roz_token.read() };

            assert(usdc_token.balance_of(held_by) >= usdc, errors::INSUFFICIENT_INVENTORY);
            assert(strk_token.balance_of(held_by) >= strk, errors::INSUFFICIENT_INVENTORY);
            assert(roz_token.balance_of(held_by) >= roz, errors::INSUFFICIENT_INVENTORY);
        }

        fn _transfer_pack(
            ref self: ContractState, recipient: ContractAddress, usdc: u256, strk: u256, roz: u256,
        ) {
            let usdc_token = ERC20ABIDispatcher { contract_address: self.usdc_token.read() };
            let strk_token = ERC20ABIDispatcher { contract_address: self.strk_token.read() };
            let roz_token = ERC20ABIDispatcher { contract_address: self.roz_token.read() };

            assert(usdc_token.transfer(recipient, usdc), errors::INSUFFICIENT_INVENTORY);
            assert(strk_token.transfer(recipient, strk), errors::INSUFFICIENT_INVENTORY);
            assert(roz_token.transfer(recipient, roz), errors::INSUFFICIENT_INVENTORY);
        }
    }
}
