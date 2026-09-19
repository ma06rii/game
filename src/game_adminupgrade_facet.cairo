// Stateless logic facet. Its entrypoints run in the game address's context
// through the game's allowlisted library-call router.
use starknet::{ClassHash, ContractAddress};
use crate::NextRoundParams;

#[starknet::interface]
pub trait IGameAdminUpgradeFacet<TContractState> {
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn is_paused(self: @TContractState) -> bool;
    fn propose_upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn execute_upgrade(ref self: TContractState);
    fn execute_upgrade_and_migrate(
        ref self: TContractState, selector: felt252, calldata: Span<felt252>,
    ) -> Span<felt252>;
    fn cancel_upgrade(ref self: TContractState);
    fn get_pending_upgrade(self: @TContractState) -> (ClassHash, u64);
    fn get_upgrade_delay(self: @TContractState) -> u64;
    fn propose_upgrade_delay(ref self: TContractState, new_delay: u64);
    fn set_upgrade_delay(ref self: TContractState, new_delay: u64);
    fn cancel_upgrade_delay_change(ref self: TContractState);
    fn get_pending_upgrade_delay(self: @TContractState) -> (bool, u64, u64);
    fn migrate_v2(ref self: TContractState) -> bool;
    fn get_upgrade_initialized_version(self: @TContractState) -> u256;
}

#[starknet::contract]
pub mod GameAdminUpgradeFacet {
    use starknet::{ClassHash, ContractAddress};
    use crate::{AdminGameLogic, NextRoundParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FacetImpl of super::IGameAdminUpgradeFacet<ContractState> {
        fn pause(ref self: ContractState) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_pause()
        }

        fn unpause(ref self: ContractState) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_unpause()
        }

        fn is_paused(self: @ContractState) -> bool {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_is_paused()
        }

        fn propose_upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_propose_upgrade(new_class_hash)
        }

        fn execute_upgrade(ref self: ContractState) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_execute_upgrade()
        }

        fn execute_upgrade_and_migrate(
        ref self: ContractState, selector: felt252, calldata: Span<felt252>,
    ) -> Span<felt252> {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_execute_upgrade_and_migrate(selector, calldata)
        }

        fn cancel_upgrade(ref self: ContractState) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_cancel_upgrade()
        }

        fn get_pending_upgrade(self: @ContractState) -> (ClassHash, u64) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_pending_upgrade()
        }

        fn get_upgrade_delay(self: @ContractState) -> u64 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_upgrade_delay()
        }

        fn propose_upgrade_delay(ref self: ContractState, new_delay: u64) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_propose_upgrade_delay(new_delay)
        }

        fn set_upgrade_delay(ref self: ContractState, new_delay: u64) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_set_upgrade_delay(new_delay)
        }

        fn cancel_upgrade_delay_change(ref self: ContractState) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_cancel_upgrade_delay_change()
        }

        fn get_pending_upgrade_delay(self: @ContractState) -> (bool, u64, u64) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_pending_upgrade_delay()
        }

        fn migrate_v2(ref self: ContractState) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_migrate_v2()
        }

        fn get_upgrade_initialized_version(self: @ContractState) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_upgrade_initialized_version()
        }
    }
}
