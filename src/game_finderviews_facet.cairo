// Stateless logic facet. Its entrypoints run in the game address's context
// through the game's allowlisted library-call router.
use starknet::{ClassHash, ContractAddress};
use crate::NextRoundParams;

#[starknet::interface]
pub trait IGameFinderViewsFacet<TContractState> {
    fn get_finder_player_position(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> (u128, u128);
    fn get_free_hops_remaining(self: @TContractState, gamerWalletAddress: ContractAddress) -> u256;
    fn get_player_daily_state(
        self: @TContractState, gamerWalletAddress: ContractAddress,
    ) -> (u256, u256, u256, u256, u256);
    fn get_player_lifetime_spend(
        self: @TContractState, gamerWalletAddress: ContractAddress,
    ) -> u256;
    fn get_minimum_allowance_fee(self: @TContractState) -> u256;
}

#[starknet::contract]
pub mod GameFinderViewsFacet {
    use starknet::{ClassHash, ContractAddress};
    use crate::{MainGameLogic, NextRoundParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FacetImpl of super::IGameFinderViewsFacet<ContractState> {
        fn get_finder_player_position(
        self: @ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> (u128, u128) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_finder_player_position(gamerWalletAddress, gameWeek)
        }

        fn get_free_hops_remaining(self: @ContractState, gamerWalletAddress: ContractAddress) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_free_hops_remaining(gamerWalletAddress)
        }

        fn get_player_daily_state(
        self: @ContractState, gamerWalletAddress: ContractAddress,
    ) -> (u256, u256, u256, u256, u256) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_player_daily_state(gamerWalletAddress)
        }

        fn get_player_lifetime_spend(
        self: @ContractState, gamerWalletAddress: ContractAddress,
    ) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_player_lifetime_spend(gamerWalletAddress)
        }

        fn get_minimum_allowance_fee(self: @ContractState) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_minimum_allowance_fee()
        }
    }
}
