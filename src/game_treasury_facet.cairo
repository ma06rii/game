// Stateless logic facet. Its entrypoints run in the game address's context
// through the game's allowlisted library-call router.
use starknet::{ClassHash, ContractAddress};
use crate::NextRoundParams;

#[starknet::interface]
pub trait IGameTreasuryFacet<TContractState> {
    fn withdraw_token_balance(
        ref self: TContractState, tokenAddress: ContractAddress, receiver: ContractAddress,
    );
    fn get_sweepable_balance(self: @TContractState, tokenAddress: ContractAddress) -> u256;
    fn update_vrf_provider(ref self: TContractState, vrfProviderAddress: ContractAddress) -> bool;
    fn update_game_token(ref self: TContractState, gameTokenAddress: ContractAddress) -> bool;
    fn update_game_reward_token(
        ref self: TContractState, rewardTokenAddress: ContractAddress,
    ) -> bool;
    fn get_contract_addresses(
        self: @TContractState,
    ) -> (ContractAddress, ContractAddress, ContractAddress);
}

#[starknet::contract]
pub mod GameTreasuryFacet {
    use starknet::{ClassHash, ContractAddress};
    use crate::{MainGameLogic, NextRoundParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FacetImpl of super::IGameTreasuryFacet<ContractState> {
        fn withdraw_token_balance(
        ref self: ContractState, tokenAddress: ContractAddress, receiver: ContractAddress,
    ) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_withdraw_token_balance(tokenAddress, receiver)
        }

        fn get_sweepable_balance(self: @ContractState, tokenAddress: ContractAddress) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_sweepable_balance(tokenAddress)
        }

        fn update_vrf_provider(ref self: ContractState, vrfProviderAddress: ContractAddress) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_update_vrf_provider(vrfProviderAddress)
        }

        fn update_game_token(ref self: ContractState, gameTokenAddress: ContractAddress) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_update_game_token(gameTokenAddress)
        }

        fn update_game_reward_token(
        ref self: ContractState, rewardTokenAddress: ContractAddress,
    ) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_update_game_reward_token(rewardTokenAddress)
        }

        fn get_contract_addresses(
        self: @ContractState,
    ) -> (ContractAddress, ContractAddress, ContractAddress) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_contract_addresses()
        }
    }
}
