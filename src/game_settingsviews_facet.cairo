// Stateless logic facet. Its entrypoints run in the game address's context
// through the game's allowlisted library-call router.
use starknet::{ClassHash, ContractAddress};
use crate::NextRoundParams;

#[starknet::interface]
pub trait IGameSettingsViewsFacet<TContractState> {
    fn get_reward_rates(self: @TContractState) -> (u256, u256, u256, u256, u256);
    fn get_below_threshold_rates(self: @TContractState) -> (u256, u256, u256, u256);
    fn get_new_wallet_rates(self: @TContractState) -> (u256, u256, u256, u256);
    fn get_hop_limits(self: @TContractState) -> (u256, u256, u256, u256);
    fn get_soft_caps(self: @TContractState) -> (u256, u256, u256, u256);
    fn get_gate_thresholds(self: @TContractState) -> (u256, u256);
    fn get_price_band(self: @TContractState, bandKind: u8, bandIndex: u8) -> (u256, u256, u256);
}

#[starknet::contract]
pub mod GameSettingsViewsFacet {
    use starknet::{ClassHash, ContractAddress};
    use crate::{MainGameLogic, NextRoundParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FacetImpl of super::IGameSettingsViewsFacet<ContractState> {
        fn get_reward_rates(self: @ContractState) -> (u256, u256, u256, u256, u256) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_reward_rates()
        }

        fn get_below_threshold_rates(self: @ContractState) -> (u256, u256, u256, u256) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_below_threshold_rates()
        }

        fn get_new_wallet_rates(self: @ContractState) -> (u256, u256, u256, u256) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_new_wallet_rates()
        }

        fn get_hop_limits(self: @ContractState) -> (u256, u256, u256, u256) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_hop_limits()
        }

        fn get_soft_caps(self: @ContractState) -> (u256, u256, u256, u256) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_soft_caps()
        }

        fn get_gate_thresholds(self: @ContractState) -> (u256, u256) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_gate_thresholds()
        }

        fn get_price_band(self: @ContractState, bandKind: u8, bandIndex: u8) -> (u256, u256, u256) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_price_band(bandKind, bandIndex)
        }
    }
}
