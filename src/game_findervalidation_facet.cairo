// Stateless logic facet. Its entrypoints run in the game address's context
// through the game's allowlisted library-call router.
use starknet::{ClassHash, ContractAddress};
use crate::NextRoundParams;

#[starknet::interface]
pub trait IGameFinderValidationFacet<TContractState> {
    fn validate_treasure_coordinates(
        ref self: TContractState,
        finderGamerWalletAddress: ContractAddress,
        hiderGamerWalletAddress: ContractAddress,
        leaf: u256,
        proof: Array<u256>,
        checkHopCount: u256,
        checkTimestamp: u64,
    ) -> bool;
}

#[starknet::contract]
pub mod GameFinderValidationFacet {
    use starknet::{ClassHash, ContractAddress};
    use crate::{MainGameLogic, NextRoundParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FacetImpl of super::IGameFinderValidationFacet<ContractState> {
        fn validate_treasure_coordinates(
        ref self: ContractState,
        finderGamerWalletAddress: ContractAddress,
        hiderGamerWalletAddress: ContractAddress,
        leaf: u256,
        proof: Array<u256>,
        checkHopCount: u256,
        checkTimestamp: u64,
    ) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_validate_treasure_coordinates(finderGamerWalletAddress, hiderGamerWalletAddress, leaf, proof, checkHopCount, checkTimestamp)
        }
    }
}
