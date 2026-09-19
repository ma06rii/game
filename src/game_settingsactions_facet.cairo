// Stateless logic facet. Its entrypoints run in the game address's context
// through the game's allowlisted library-call router.
use starknet::{ClassHash, ContractAddress};
use crate::NextRoundParams;

#[starknet::interface]
pub trait IGameSettingsActionsFacet<TContractState> {
    fn set_params(ref self: TContractState, keys: Array<felt252>, values: Array<u256>) -> bool;
    fn update_price_band(
        ref self: TContractState, bandKind: u8, bandIndex: u8, upTo: u256, num: u256, den: u256,
    ) -> bool;
}

#[starknet::contract]
pub mod GameSettingsActionsFacet {
    use starknet::{ClassHash, ContractAddress};
    use crate::{MainGameLogic, NextRoundParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FacetImpl of super::IGameSettingsActionsFacet<ContractState> {
        fn set_params(ref self: ContractState, keys: Array<felt252>, values: Array<u256>) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_set_params(keys, values)
        }

        fn update_price_band(
        ref self: ContractState, bandKind: u8, bandIndex: u8, upTo: u256, num: u256, den: u256,
    ) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_update_price_band(bandKind, bandIndex, upTo, num, den)
        }
    }
}
