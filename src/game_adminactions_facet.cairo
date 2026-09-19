// Stateless logic facet. Its entrypoints run in the game address's context
// through the game's allowlisted library-call router.
use starknet::{ClassHash, ContractAddress};
use crate::NextRoundParams;

#[starknet::interface]
pub trait IGameAdminActionsFacet<TContractState> {
    fn propose_vrf_provider_update(ref self: TContractState, vrf_provider_address: ContractAddress);
    fn propose_game_token_update(ref self: TContractState, game_token_address: ContractAddress);
    fn propose_game_reward_token_update(
        ref self: TContractState, reward_token_address: ContractAddress,
    );
    fn propose_admin_update(ref self: TContractState, new_admin: ContractAddress);
    fn propose_token_withdrawal(
        ref self: TContractState, token_address: ContractAddress, receiver: ContractAddress,
    );
    fn propose_full_token_withdrawal(
        ref self: TContractState, token_address: ContractAddress, receiver: ContractAddress,
    );
    fn cancel_admin_action(ref self: TContractState);
    fn get_pending_admin_action(self: @TContractState) -> (felt252, felt252, u64);
    fn set_admin(ref self: TContractState, new_admin: ContractAddress);
    fn get_admin(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
pub mod GameAdminActionsFacet {
    use starknet::{ClassHash, ContractAddress};
    use crate::{AdminGameLogic, NextRoundParams};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FacetImpl of super::IGameAdminActionsFacet<ContractState> {
        fn propose_vrf_provider_update(ref self: ContractState, vrf_provider_address: ContractAddress) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_propose_vrf_provider_update(vrf_provider_address)
        }

        fn propose_game_token_update(ref self: ContractState, game_token_address: ContractAddress) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_propose_game_token_update(game_token_address)
        }

        fn propose_game_reward_token_update(
        ref self: ContractState, reward_token_address: ContractAddress,
    ) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_propose_game_reward_token_update(reward_token_address)
        }

        fn propose_admin_update(ref self: ContractState, new_admin: ContractAddress) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_propose_admin_update(new_admin)
        }

        fn propose_token_withdrawal(
        ref self: ContractState, token_address: ContractAddress, receiver: ContractAddress,
    ) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_propose_token_withdrawal(token_address, receiver)
        }

        fn propose_full_token_withdrawal(
        ref self: ContractState, token_address: ContractAddress, receiver: ContractAddress,
    ) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_propose_full_token_withdrawal(token_address, receiver)
        }

        fn cancel_admin_action(ref self: ContractState) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_cancel_admin_action()
        }

        fn get_pending_admin_action(self: @ContractState) -> (felt252, felt252, u64) {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_pending_admin_action()
        }

        fn set_admin(ref self: ContractState, new_admin: ContractAddress) {
            let mut game = crate::HelloStarknet::game_contract_state();
            game.logic_set_admin(new_admin)
        }

        fn get_admin(self: @ContractState) -> ContractAddress {
            let game = crate::HelloStarknet::game_contract_state();
            game.logic_get_admin()
        }
    }
}
