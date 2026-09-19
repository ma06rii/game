// Stateless logic facet. Its entrypoints run in the game address's context
// through the game's allowlisted library-call router.
use starknet::{ClassHash, ContractAddress};
use crate::NextRoundParams;

#[starknet::interface]
pub trait IGameRoundViewsFacet<TContractState> {
    fn get_game_week(self: @TContractState) -> u256;
    fn get_round_status(self: @TContractState) -> (u256, u8, u64, u64, u64, u256, u256, u64);
    fn get_next_round_totals(self: @TContractState) -> (u256, u256);
    fn get_min_treasures_to_start(self: @TContractState) -> u256;
    fn get_round_keeper(self: @TContractState) -> ContractAddress;
    fn update_round_keeper(ref self: TContractState, keeper: ContractAddress) -> bool;
    fn get_game_week_treasure_total(self: @TContractState, gameWeek: u256) -> u256;
    fn get_game_grid_size(self: @TContractState, gameWeek: u256) -> (u128, u128);
}

#[starknet::contract]
pub mod GameRoundViewsFacet {
    use starknet::{ClassHash, ContractAddress};
    use crate::{MainGameLogic, NextRoundParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FacetImpl of super::IGameRoundViewsFacet<ContractState> {
        fn get_game_week(self: @ContractState) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_game_week()
        }

        fn get_round_status(self: @ContractState) -> (u256, u8, u64, u64, u64, u256, u256, u64) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_round_status()
        }

        fn get_next_round_totals(self: @ContractState) -> (u256, u256) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_next_round_totals()
        }

        fn get_min_treasures_to_start(self: @ContractState) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_min_treasures_to_start()
        }

        fn get_round_keeper(self: @ContractState) -> ContractAddress {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_round_keeper()
        }

        fn update_round_keeper(ref self: ContractState, keeper: ContractAddress) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_update_round_keeper(keeper)
        }

        fn get_game_week_treasure_total(self: @ContractState, gameWeek: u256) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_game_week_treasure_total(gameWeek)
        }

        fn get_game_grid_size(self: @ContractState, gameWeek: u256) -> (u128, u128) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_game_grid_size(gameWeek)
        }
    }
}
