// Stateless logic facet. Its entrypoints run in the game address's context
// through the game's allowlisted library-call router.
use starknet::{ClassHash, ContractAddress};
use crate::NextRoundParams;

#[starknet::interface]
pub trait IGameRoundActionsFacet<TContractState> {
    fn start_next_round(ref self: TContractState, params: NextRoundParams) -> bool;
    fn expire_round(ref self: TContractState, expectedRound: u256) -> bool;
}

#[starknet::contract]
pub mod GameRoundActionsFacet {
    use starknet::{ClassHash, ContractAddress};
    use crate::{MainGameLogic, NextRoundParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FacetImpl of super::IGameRoundActionsFacet<ContractState> {
        fn start_next_round(ref self: ContractState, params: NextRoundParams) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_start_next_round(params)
        }

        fn expire_round(ref self: ContractState, expectedRound: u256) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_expire_round(expectedRound)
        }
    }
}
