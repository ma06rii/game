// Stateless logic facet. Its entrypoints run in the game address's context
// through the game's allowlisted library-call router.
use starknet::{ClassHash, ContractAddress};
use crate::NextRoundParams;

#[starknet::interface]
pub trait IGameFinderActionsFacet<TContractState> {
    fn finder_player_move_position(ref self: TContractState, direction: u128) -> (u128, u128);
    fn finder_player_generate_position(ref self: TContractState) -> bool;
}

#[starknet::contract]
pub mod GameFinderActionsFacet {
    use starknet::{ClassHash, ContractAddress};
    use crate::{MainGameLogic, NextRoundParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FacetImpl of super::IGameFinderActionsFacet<ContractState> {
        fn finder_player_move_position(ref self: ContractState, direction: u128) -> (u128, u128) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_finder_player_move_position(direction)
        }

        fn finder_player_generate_position(ref self: ContractState) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_finder_player_generate_position()
        }
    }
}
