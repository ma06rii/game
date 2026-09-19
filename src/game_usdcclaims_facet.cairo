// Stateless logic facet. Its entrypoints run in the game address's context
// through the game's allowlisted library-call router.
use starknet::{ClassHash, ContractAddress};
use crate::NextRoundParams;

#[starknet::interface]
pub trait IGameUsdcClaimsFacet<TContractState> {
    fn claim_reward(ref self: TContractState, gameWeek: u256) -> bool;
    fn get_reward_claimed(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    fn get_claimable_weeks(
        self: @TContractState, gamerWalletAddress: ContractAddress, fromWeek: u256, toWeek: u256,
    ) -> Array<u256>;
    fn get_claim_share_amounts(
        self: @TContractState, gameWeek: u256, gamerWalletAddress: ContractAddress,
    ) -> u256;
    fn get_player_reward_due(
        self: @TContractState, gameWeek: u256, gamerWalletAddress: ContractAddress,
    ) -> u256;
}

#[starknet::contract]
pub mod GameUsdcClaimsFacet {
    use starknet::{ClassHash, ContractAddress};
    use crate::{MainGameLogic, NextRoundParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FacetImpl of super::IGameUsdcClaimsFacet<ContractState> {
        fn claim_reward(ref self: ContractState, gameWeek: u256) -> bool {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_claim_reward(gameWeek)
        }

        fn get_reward_claimed(
        self: @ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_reward_claimed(gamerWalletAddress, gameWeek)
        }

        fn get_claimable_weeks(
        self: @ContractState, gamerWalletAddress: ContractAddress, fromWeek: u256, toWeek: u256,
    ) -> Array<u256> {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_claimable_weeks(gamerWalletAddress, fromWeek, toWeek)
        }

        fn get_claim_share_amounts(
        self: @ContractState, gameWeek: u256, gamerWalletAddress: ContractAddress,
    ) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_claim_share_amounts(gameWeek, gamerWalletAddress)
        }

        fn get_player_reward_due(
        self: @ContractState, gameWeek: u256, gamerWalletAddress: ContractAddress,
    ) -> u256 {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_player_reward_due(gameWeek, gamerWalletAddress)
        }
    }
}
