// Stateless logic facet. Its entrypoints run in the game address's context
// through the game's allowlisted library-call router.
use starknet::{ClassHash, ContractAddress};
use crate::NextRoundParams;

#[starknet::interface]
pub trait IGameHideActionsFacet<TContractState> {
    fn hide_treasure(ref self: TContractState) -> bool;
    fn hide_treasure_bulk(
        ref self: TContractState, bulkAmount: u256, merkleProof: Array<felt252>, leafIndex: u32,
    ) -> bool;
}

#[starknet::contract]
pub mod GameHideActionsFacet {
    use starknet::{ClassHash, ContractAddress};
    use crate::{MainGameLogic, NextRoundParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FacetImpl of super::IGameHideActionsFacet<ContractState> {
        fn hide_treasure(ref self: ContractState) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_hide_treasure()
        }

        fn hide_treasure_bulk(
        ref self: ContractState, bulkAmount: u256, merkleProof: Array<felt252>, leafIndex: u32,
    ) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_hide_treasure_bulk(bulkAmount, merkleProof, leafIndex)
        }
    }
}
