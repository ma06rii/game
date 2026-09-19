// Stateless logic facet. Its entrypoints run in the game address's context
// through the game's allowlisted library-call router.
use starknet::{ClassHash, ContractAddress};
use crate::NextRoundParams;

#[starknet::interface]
pub trait IGameRozClaimsFacet<TContractState> {
    fn claim_reward_tokens(ref self: TContractState) -> bool;
    fn claim_reward_token_for_week(ref self: TContractState, gameWeek: u256) -> bool;
    fn get_reward_token_pending(self: @TContractState, gamerWalletAddress: ContractAddress) -> u256;
    fn get_total_reward_token_pending(self: @TContractState) -> u256;
    fn get_reward_token_missed(self: @TContractState, gamerWalletAddress: ContractAddress) -> u256;
    fn get_total_reward_token_missed(self: @TContractState) -> u256;
    fn claim_missed_reward_token(ref self: TContractState) -> u256;
    fn get_reward_token_claimed(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    fn get_reward_token_due(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> (u256, u256, u256);
}

#[starknet::contract]
pub mod GameRozClaimsFacet {
    use starknet::{ClassHash, ContractAddress};
    use crate::{MainGameLogic, NextRoundParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FacetImpl of super::IGameRozClaimsFacet<ContractState> {
        fn claim_reward_tokens(ref self: ContractState) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_claim_reward_tokens()
        }

        fn claim_reward_token_for_week(ref self: ContractState, gameWeek: u256) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_claim_reward_token_for_week(gameWeek)
        }

        fn get_reward_token_pending(self: @ContractState, gamerWalletAddress: ContractAddress) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_reward_token_pending(gamerWalletAddress)
        }

        fn get_total_reward_token_pending(self: @ContractState) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_total_reward_token_pending()
        }

        fn get_reward_token_missed(self: @ContractState, gamerWalletAddress: ContractAddress) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_reward_token_missed(gamerWalletAddress)
        }

        fn get_total_reward_token_missed(self: @ContractState) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_total_reward_token_missed()
        }

        fn claim_missed_reward_token(ref self: ContractState) -> u256 {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_claim_missed_reward_token()
        }

        fn get_reward_token_claimed(
        self: @ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_reward_token_claimed(gamerWalletAddress, gameWeek)
        }

        fn get_reward_token_due(
        self: @ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> (u256, u256, u256) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_reward_token_due(gamerWalletAddress, gameWeek)
        }
    }
}
