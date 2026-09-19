// Stateless logic facet. Its entrypoints run in the game address's context
// through the game's allowlisted library-call router.
use starknet::{ClassHash, ContractAddress};
use crate::NextRoundParams;

#[starknet::interface]
pub trait IGameHideViewsFacet<TContractState> {
    fn get_hider_player_fee(self: @TContractState) -> u256;
    fn set_whitelist_merkle_root(ref self: TContractState, newRoot: felt252) -> bool;
    fn get_whitelist_merkle_root(self: @TContractState) -> felt252;
    fn get_whitelist_caps(self: @TContractState) -> (u256, u256, u256);
    fn get_hide_settings(self: @TContractState) -> (u256, u256, u256, u256, u256);
}

#[starknet::contract]
pub mod GameHideViewsFacet {
    use starknet::{ClassHash, ContractAddress};
    use crate::{MainGameLogic, NextRoundParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FacetImpl of super::IGameHideViewsFacet<ContractState> {
        fn get_hider_player_fee(self: @ContractState) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_hider_player_fee()
        }

        fn set_whitelist_merkle_root(ref self: ContractState, newRoot: felt252) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_set_whitelist_merkle_root(newRoot)
        }

        fn get_whitelist_merkle_root(self: @ContractState) -> felt252 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_whitelist_merkle_root()
        }

        fn get_whitelist_caps(self: @ContractState) -> (u256, u256, u256) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_whitelist_caps()
        }

        fn get_hide_settings(self: @ContractState) -> (u256, u256, u256, u256, u256) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_hide_settings()
        }
    }
}
