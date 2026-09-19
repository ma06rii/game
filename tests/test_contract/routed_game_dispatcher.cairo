// Test-only compatibility dispatchers: they exercise the real routed ABI
// while keeping each behavior assertion readable in its original typed form.
use starknet::{ClassHash, ContractAddress};
use project_name::NextRoundParams;
use project_name::{IRoutedGameDispatcher, IRoutedGameDispatcherTrait, IRoutedGameSafeDispatcher, IRoutedGameSafeDispatcherTrait};

#[derive(Copy, Drop)]
pub struct RoutedGameDispatcher {
    pub contract_address: ContractAddress,
}

#[derive(Copy, Drop)]
pub struct RoutedGameSafeDispatcher {
    pub contract_address: ContractAddress,
}

pub trait RoutedGameDispatcherTrait {
    fn start_next_round(self: @RoutedGameDispatcher, params: NextRoundParams) -> bool;
    fn expire_round(self: @RoutedGameDispatcher, expectedRound: u256) -> bool;
    fn hide_treasure(self: @RoutedGameDispatcher) -> bool;
    fn hide_treasure_bulk(self: @RoutedGameDispatcher, bulkAmount: u256, merkleProof: Array<felt252>, leafIndex: u32) -> bool;
    fn validate_treasure_coordinates(self: @RoutedGameDispatcher, finderGamerWalletAddress: ContractAddress, hiderGamerWalletAddress: ContractAddress, leaf: u256, proof: Array<u256>, checkHopCount: u256, checkTimestamp: u64) -> bool;
    fn finder_player_move_position(self: @RoutedGameDispatcher, direction: u128) -> (u128, u128);
    fn get_finder_player_position(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> (u128, u128);
    fn get_minimum_allowance_fee(self: @RoutedGameDispatcher) -> u256;
    fn claim_reward(self: @RoutedGameDispatcher, gameWeek: u256) -> bool;
    fn claim_reward_tokens(self: @RoutedGameDispatcher) -> bool;
    fn claim_reward_token_for_week(self: @RoutedGameDispatcher, gameWeek: u256) -> bool;
    fn get_reward_token_pending(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress) -> u256;
    fn get_total_reward_token_pending(self: @RoutedGameDispatcher) -> u256;
    fn get_reward_token_missed(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress) -> u256;
    fn get_total_reward_token_missed(self: @RoutedGameDispatcher) -> u256;
    fn claim_missed_reward_token(self: @RoutedGameDispatcher) -> u256;
    fn get_reward_token_claimed(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> bool;
    fn get_reward_claimed(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> bool;
    fn get_claimable_weeks(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress, fromWeek: u256, toWeek: u256) -> Array<u256>;
    fn get_reward_token_due(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> (u256, u256, u256);
    fn update_vrf_provider(self: @RoutedGameDispatcher, vrfProviderAddress: ContractAddress) -> bool;
    fn update_game_token(self: @RoutedGameDispatcher, gameTokenAddress: ContractAddress) -> bool;
    fn update_game_reward_token(self: @RoutedGameDispatcher, rewardTokenAddress: ContractAddress) -> bool;
    fn get_contract_addresses(self: @RoutedGameDispatcher) -> (ContractAddress, ContractAddress, ContractAddress);
    fn get_reward_rates(self: @RoutedGameDispatcher) -> (u256, u256, u256, u256, u256);
    fn get_below_threshold_rates(self: @RoutedGameDispatcher) -> (u256, u256, u256, u256);
    fn get_new_wallet_rates(self: @RoutedGameDispatcher) -> (u256, u256, u256, u256);
    fn get_hop_limits(self: @RoutedGameDispatcher) -> (u256, u256, u256, u256);
    fn get_soft_caps(self: @RoutedGameDispatcher) -> (u256, u256, u256, u256);
    fn get_gate_thresholds(self: @RoutedGameDispatcher) -> (u256, u256);
    fn get_hide_settings(self: @RoutedGameDispatcher) -> (u256, u256, u256, u256, u256);
    fn set_whitelist_merkle_root(self: @RoutedGameDispatcher, newRoot: felt252) -> bool;
    fn get_whitelist_merkle_root(self: @RoutedGameDispatcher) -> felt252;
    fn get_whitelist_caps(self: @RoutedGameDispatcher) -> (u256, u256, u256);
    fn set_params(self: @RoutedGameDispatcher, keys: Array<felt252>, values: Array<u256>) -> bool;
    fn update_price_band(self: @RoutedGameDispatcher, bandKind: u8, bandIndex: u8, upTo: u256, num: u256, den: u256) -> bool;
    fn get_price_band(self: @RoutedGameDispatcher, bandKind: u8, bandIndex: u8) -> (u256, u256, u256);
    fn get_player_daily_state(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress) -> (u256, u256, u256, u256, u256);
    fn get_player_lifetime_spend(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress) -> u256;
    fn get_free_hops_remaining(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress) -> u256;
    fn finder_player_generate_position(self: @RoutedGameDispatcher) -> bool;
    fn withdraw_token_balance(self: @RoutedGameDispatcher, tokenAddress: ContractAddress, receiver: ContractAddress) -> ();
    fn get_sweepable_balance(self: @RoutedGameDispatcher, tokenAddress: ContractAddress) -> u256;
    fn get_game_week(self: @RoutedGameDispatcher) -> u256;
    fn get_round_status(self: @RoutedGameDispatcher) -> (u256, u8, u64, u64, u64, u256, u256, u64);
    fn get_next_round_totals(self: @RoutedGameDispatcher) -> (u256, u256);
    fn get_min_treasures_to_start(self: @RoutedGameDispatcher) -> u256;
    fn get_round_keeper(self: @RoutedGameDispatcher) -> ContractAddress;
    fn update_round_keeper(self: @RoutedGameDispatcher, keeper: ContractAddress) -> bool;
    fn get_game_week_treasure_total(self: @RoutedGameDispatcher, gameWeek: u256) -> u256;
    fn get_game_grid_size(self: @RoutedGameDispatcher, gameWeek: u256) -> (u128, u128);
    fn get_hider_player_fee(self: @RoutedGameDispatcher) -> u256;
    fn get_claim_share_amounts(self: @RoutedGameDispatcher, gameWeek: u256, gamerWalletAddress: ContractAddress) -> u256;
    fn get_player_reward_due(self: @RoutedGameDispatcher, gameWeek: u256, gamerWalletAddress: ContractAddress) -> u256;
    fn pause(self: @RoutedGameDispatcher) -> ();
    fn unpause(self: @RoutedGameDispatcher) -> ();
    fn is_paused(self: @RoutedGameDispatcher) -> bool;
    fn propose_upgrade(self: @RoutedGameDispatcher, new_class_hash: ClassHash) -> ();
    fn execute_upgrade(self: @RoutedGameDispatcher) -> ();
    fn execute_upgrade_and_migrate(self: @RoutedGameDispatcher, selector: felt252, calldata: Span<felt252>) -> Span<felt252>;
    fn cancel_upgrade(self: @RoutedGameDispatcher) -> ();
    fn get_pending_upgrade(self: @RoutedGameDispatcher) -> (ClassHash, u64);
    fn get_upgrade_delay(self: @RoutedGameDispatcher) -> u64;
    fn propose_upgrade_delay(self: @RoutedGameDispatcher, new_delay: u64) -> ();
    fn set_upgrade_delay(self: @RoutedGameDispatcher, new_delay: u64) -> ();
    fn cancel_upgrade_delay_change(self: @RoutedGameDispatcher) -> ();
    fn get_pending_upgrade_delay(self: @RoutedGameDispatcher) -> (bool, u64, u64);
    fn propose_vrf_provider_update(self: @RoutedGameDispatcher, vrf_provider_address: ContractAddress) -> ();
    fn propose_game_token_update(self: @RoutedGameDispatcher, game_token_address: ContractAddress) -> ();
    fn propose_game_reward_token_update(self: @RoutedGameDispatcher, reward_token_address: ContractAddress) -> ();
    fn propose_admin_update(self: @RoutedGameDispatcher, new_admin: ContractAddress) -> ();
    fn propose_token_withdrawal(self: @RoutedGameDispatcher, token_address: ContractAddress, receiver: ContractAddress) -> ();
    fn propose_full_token_withdrawal(self: @RoutedGameDispatcher, token_address: ContractAddress, receiver: ContractAddress) -> ();
    fn cancel_admin_action(self: @RoutedGameDispatcher) -> ();
    fn get_pending_admin_action(self: @RoutedGameDispatcher) -> (felt252, felt252, u64);
    fn set_admin(self: @RoutedGameDispatcher, new_admin: ContractAddress) -> ();
    fn get_admin(self: @RoutedGameDispatcher) -> ContractAddress;
    fn migrate_v2(self: @RoutedGameDispatcher) -> bool;
    fn get_upgrade_initialized_version(self: @RoutedGameDispatcher) -> u256;
}

pub trait RoutedGameSafeDispatcherTrait {
    fn start_next_round(self: @RoutedGameSafeDispatcher, params: NextRoundParams) -> Result<bool, Array<felt252>>;
    fn expire_round(self: @RoutedGameSafeDispatcher, expectedRound: u256) -> Result<bool, Array<felt252>>;
    fn hide_treasure(self: @RoutedGameSafeDispatcher) -> Result<bool, Array<felt252>>;
    fn hide_treasure_bulk(self: @RoutedGameSafeDispatcher, bulkAmount: u256, merkleProof: Array<felt252>, leafIndex: u32) -> Result<bool, Array<felt252>>;
    fn validate_treasure_coordinates(self: @RoutedGameSafeDispatcher, finderGamerWalletAddress: ContractAddress, hiderGamerWalletAddress: ContractAddress, leaf: u256, proof: Array<u256>, checkHopCount: u256, checkTimestamp: u64) -> Result<bool, Array<felt252>>;
    fn finder_player_move_position(self: @RoutedGameSafeDispatcher, direction: u128) -> Result<(u128, u128), Array<felt252>>;
    fn get_finder_player_position(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> Result<(u128, u128), Array<felt252>>;
    fn get_minimum_allowance_fee(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>>;
    fn claim_reward(self: @RoutedGameSafeDispatcher, gameWeek: u256) -> Result<bool, Array<felt252>>;
    fn claim_reward_tokens(self: @RoutedGameSafeDispatcher) -> Result<bool, Array<felt252>>;
    fn claim_reward_token_for_week(self: @RoutedGameSafeDispatcher, gameWeek: u256) -> Result<bool, Array<felt252>>;
    fn get_reward_token_pending(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress) -> Result<u256, Array<felt252>>;
    fn get_total_reward_token_pending(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>>;
    fn get_reward_token_missed(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress) -> Result<u256, Array<felt252>>;
    fn get_total_reward_token_missed(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>>;
    fn claim_missed_reward_token(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>>;
    fn get_reward_token_claimed(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> Result<bool, Array<felt252>>;
    fn get_reward_claimed(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> Result<bool, Array<felt252>>;
    fn get_claimable_weeks(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress, fromWeek: u256, toWeek: u256) -> Result<Array<u256>, Array<felt252>>;
    fn get_reward_token_due(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> Result<(u256, u256, u256), Array<felt252>>;
    fn update_vrf_provider(self: @RoutedGameSafeDispatcher, vrfProviderAddress: ContractAddress) -> Result<bool, Array<felt252>>;
    fn update_game_token(self: @RoutedGameSafeDispatcher, gameTokenAddress: ContractAddress) -> Result<bool, Array<felt252>>;
    fn update_game_reward_token(self: @RoutedGameSafeDispatcher, rewardTokenAddress: ContractAddress) -> Result<bool, Array<felt252>>;
    fn get_contract_addresses(self: @RoutedGameSafeDispatcher) -> Result<(ContractAddress, ContractAddress, ContractAddress), Array<felt252>>;
    fn get_reward_rates(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256, u256, u256, u256), Array<felt252>>;
    fn get_below_threshold_rates(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256, u256, u256), Array<felt252>>;
    fn get_new_wallet_rates(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256, u256, u256), Array<felt252>>;
    fn get_hop_limits(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256, u256, u256), Array<felt252>>;
    fn get_soft_caps(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256, u256, u256), Array<felt252>>;
    fn get_gate_thresholds(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256), Array<felt252>>;
    fn get_hide_settings(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256, u256, u256, u256), Array<felt252>>;
    fn set_whitelist_merkle_root(self: @RoutedGameSafeDispatcher, newRoot: felt252) -> Result<bool, Array<felt252>>;
    fn get_whitelist_merkle_root(self: @RoutedGameSafeDispatcher) -> Result<felt252, Array<felt252>>;
    fn get_whitelist_caps(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256, u256), Array<felt252>>;
    fn set_params(self: @RoutedGameSafeDispatcher, keys: Array<felt252>, values: Array<u256>) -> Result<bool, Array<felt252>>;
    fn update_price_band(self: @RoutedGameSafeDispatcher, bandKind: u8, bandIndex: u8, upTo: u256, num: u256, den: u256) -> Result<bool, Array<felt252>>;
    fn get_price_band(self: @RoutedGameSafeDispatcher, bandKind: u8, bandIndex: u8) -> Result<(u256, u256, u256), Array<felt252>>;
    fn get_player_daily_state(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress) -> Result<(u256, u256, u256, u256, u256), Array<felt252>>;
    fn get_player_lifetime_spend(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress) -> Result<u256, Array<felt252>>;
    fn get_free_hops_remaining(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress) -> Result<u256, Array<felt252>>;
    fn finder_player_generate_position(self: @RoutedGameSafeDispatcher) -> Result<bool, Array<felt252>>;
    fn withdraw_token_balance(self: @RoutedGameSafeDispatcher, tokenAddress: ContractAddress, receiver: ContractAddress) -> Result<(), Array<felt252>>;
    fn get_sweepable_balance(self: @RoutedGameSafeDispatcher, tokenAddress: ContractAddress) -> Result<u256, Array<felt252>>;
    fn get_game_week(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>>;
    fn get_round_status(self: @RoutedGameSafeDispatcher) -> Result<(u256, u8, u64, u64, u64, u256, u256, u64), Array<felt252>>;
    fn get_next_round_totals(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256), Array<felt252>>;
    fn get_min_treasures_to_start(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>>;
    fn get_round_keeper(self: @RoutedGameSafeDispatcher) -> Result<ContractAddress, Array<felt252>>;
    fn update_round_keeper(self: @RoutedGameSafeDispatcher, keeper: ContractAddress) -> Result<bool, Array<felt252>>;
    fn get_game_week_treasure_total(self: @RoutedGameSafeDispatcher, gameWeek: u256) -> Result<u256, Array<felt252>>;
    fn get_game_grid_size(self: @RoutedGameSafeDispatcher, gameWeek: u256) -> Result<(u128, u128), Array<felt252>>;
    fn get_hider_player_fee(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>>;
    fn get_claim_share_amounts(self: @RoutedGameSafeDispatcher, gameWeek: u256, gamerWalletAddress: ContractAddress) -> Result<u256, Array<felt252>>;
    fn get_player_reward_due(self: @RoutedGameSafeDispatcher, gameWeek: u256, gamerWalletAddress: ContractAddress) -> Result<u256, Array<felt252>>;
    fn pause(self: @RoutedGameSafeDispatcher) -> Result<(), Array<felt252>>;
    fn unpause(self: @RoutedGameSafeDispatcher) -> Result<(), Array<felt252>>;
    fn is_paused(self: @RoutedGameSafeDispatcher) -> Result<bool, Array<felt252>>;
    fn propose_upgrade(self: @RoutedGameSafeDispatcher, new_class_hash: ClassHash) -> Result<(), Array<felt252>>;
    fn execute_upgrade(self: @RoutedGameSafeDispatcher) -> Result<(), Array<felt252>>;
    fn execute_upgrade_and_migrate(self: @RoutedGameSafeDispatcher, selector: felt252, calldata: Span<felt252>) -> Result<Span<felt252>, Array<felt252>>;
    fn cancel_upgrade(self: @RoutedGameSafeDispatcher) -> Result<(), Array<felt252>>;
    fn get_pending_upgrade(self: @RoutedGameSafeDispatcher) -> Result<(ClassHash, u64), Array<felt252>>;
    fn get_upgrade_delay(self: @RoutedGameSafeDispatcher) -> Result<u64, Array<felt252>>;
    fn propose_upgrade_delay(self: @RoutedGameSafeDispatcher, new_delay: u64) -> Result<(), Array<felt252>>;
    fn set_upgrade_delay(self: @RoutedGameSafeDispatcher, new_delay: u64) -> Result<(), Array<felt252>>;
    fn cancel_upgrade_delay_change(self: @RoutedGameSafeDispatcher) -> Result<(), Array<felt252>>;
    fn get_pending_upgrade_delay(self: @RoutedGameSafeDispatcher) -> Result<(bool, u64, u64), Array<felt252>>;
    fn propose_vrf_provider_update(self: @RoutedGameSafeDispatcher, vrf_provider_address: ContractAddress) -> Result<(), Array<felt252>>;
    fn propose_game_token_update(self: @RoutedGameSafeDispatcher, game_token_address: ContractAddress) -> Result<(), Array<felt252>>;
    fn propose_game_reward_token_update(self: @RoutedGameSafeDispatcher, reward_token_address: ContractAddress) -> Result<(), Array<felt252>>;
    fn propose_admin_update(self: @RoutedGameSafeDispatcher, new_admin: ContractAddress) -> Result<(), Array<felt252>>;
    fn propose_token_withdrawal(self: @RoutedGameSafeDispatcher, token_address: ContractAddress, receiver: ContractAddress) -> Result<(), Array<felt252>>;
    fn propose_full_token_withdrawal(self: @RoutedGameSafeDispatcher, token_address: ContractAddress, receiver: ContractAddress) -> Result<(), Array<felt252>>;
    fn cancel_admin_action(self: @RoutedGameSafeDispatcher) -> Result<(), Array<felt252>>;
    fn get_pending_admin_action(self: @RoutedGameSafeDispatcher) -> Result<(felt252, felt252, u64), Array<felt252>>;
    fn set_admin(self: @RoutedGameSafeDispatcher, new_admin: ContractAddress) -> Result<(), Array<felt252>>;
    fn get_admin(self: @RoutedGameSafeDispatcher) -> Result<ContractAddress, Array<felt252>>;
    fn migrate_v2(self: @RoutedGameSafeDispatcher) -> Result<bool, Array<felt252>>;
    fn get_upgrade_initialized_version(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>>;
}

impl RoutedGameDispatcherImpl of RoutedGameDispatcherTrait {
    fn start_next_round(self: @RoutedGameDispatcher, params: NextRoundParams) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@params, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(0, selector!("start_next_round"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn expire_round(self: @RoutedGameDispatcher, expectedRound: u256) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@expectedRound, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(0, selector!("expire_round"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn hide_treasure(self: @RoutedGameDispatcher) -> bool {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(2, selector!("hide_treasure"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn hide_treasure_bulk(self: @RoutedGameDispatcher, bulkAmount: u256, merkleProof: Array<felt252>, leafIndex: u32) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@bulkAmount, ref args);
        Serde::serialize(@merkleProof, ref args);
        Serde::serialize(@leafIndex, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(2, selector!("hide_treasure_bulk"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn validate_treasure_coordinates(self: @RoutedGameDispatcher, finderGamerWalletAddress: ContractAddress, hiderGamerWalletAddress: ContractAddress, leaf: u256, proof: Array<u256>, checkHopCount: u256, checkTimestamp: u64) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@finderGamerWalletAddress, ref args);
        Serde::serialize(@hiderGamerWalletAddress, ref args);
        Serde::serialize(@leaf, ref args);
        Serde::serialize(@proof, ref args);
        Serde::serialize(@checkHopCount, ref args);
        Serde::serialize(@checkTimestamp, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(4, selector!("validate_treasure_coordinates"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn finder_player_move_position(self: @RoutedGameDispatcher, direction: u128) -> (u128, u128) {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@direction, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(5, selector!("finder_player_move_position"), args.span());
        Serde::<(u128, u128)>::deserialize(ref response).unwrap()
    }

    fn get_finder_player_position(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> (u128, u128) {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        Serde::serialize(@gameWeek, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(6, selector!("get_finder_player_position"), args.span());
        Serde::<(u128, u128)>::deserialize(ref response).unwrap()
    }

    fn get_minimum_allowance_fee(self: @RoutedGameDispatcher) -> u256 {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(6, selector!("get_minimum_allowance_fee"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn claim_reward(self: @RoutedGameDispatcher, gameWeek: u256) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gameWeek, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(7, selector!("claim_reward"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn claim_reward_tokens(self: @RoutedGameDispatcher) -> bool {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(8, selector!("claim_reward_tokens"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn claim_reward_token_for_week(self: @RoutedGameDispatcher, gameWeek: u256) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gameWeek, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(8, selector!("claim_reward_token_for_week"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn get_reward_token_pending(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress) -> u256 {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(8, selector!("get_reward_token_pending"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn get_total_reward_token_pending(self: @RoutedGameDispatcher) -> u256 {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(8, selector!("get_total_reward_token_pending"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn get_reward_token_missed(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress) -> u256 {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(8, selector!("get_reward_token_missed"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn get_total_reward_token_missed(self: @RoutedGameDispatcher) -> u256 {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(8, selector!("get_total_reward_token_missed"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn claim_missed_reward_token(self: @RoutedGameDispatcher) -> u256 {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(8, selector!("claim_missed_reward_token"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn get_reward_token_claimed(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        Serde::serialize(@gameWeek, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(8, selector!("get_reward_token_claimed"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn get_reward_claimed(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        Serde::serialize(@gameWeek, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(7, selector!("get_reward_claimed"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn get_claimable_weeks(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress, fromWeek: u256, toWeek: u256) -> Array<u256> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        Serde::serialize(@fromWeek, ref args);
        Serde::serialize(@toWeek, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(7, selector!("get_claimable_weeks"), args.span());
        Serde::<Array<u256>>::deserialize(ref response).unwrap()
    }

    fn get_reward_token_due(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> (u256, u256, u256) {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        Serde::serialize(@gameWeek, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(8, selector!("get_reward_token_due"), args.span());
        Serde::<(u256, u256, u256)>::deserialize(ref response).unwrap()
    }

    fn update_vrf_provider(self: @RoutedGameDispatcher, vrfProviderAddress: ContractAddress) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@vrfProviderAddress, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(11, selector!("update_vrf_provider"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn update_game_token(self: @RoutedGameDispatcher, gameTokenAddress: ContractAddress) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gameTokenAddress, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(11, selector!("update_game_token"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn update_game_reward_token(self: @RoutedGameDispatcher, rewardTokenAddress: ContractAddress) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@rewardTokenAddress, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(11, selector!("update_game_reward_token"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn get_contract_addresses(self: @RoutedGameDispatcher) -> (ContractAddress, ContractAddress, ContractAddress) {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(11, selector!("get_contract_addresses"), args.span());
        Serde::<(ContractAddress, ContractAddress, ContractAddress)>::deserialize(ref response).unwrap()
    }

    fn get_reward_rates(self: @RoutedGameDispatcher) -> (u256, u256, u256, u256, u256) {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(10, selector!("get_reward_rates"), args.span());
        Serde::<(u256, u256, u256, u256, u256)>::deserialize(ref response).unwrap()
    }

    fn get_below_threshold_rates(self: @RoutedGameDispatcher) -> (u256, u256, u256, u256) {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(10, selector!("get_below_threshold_rates"), args.span());
        Serde::<(u256, u256, u256, u256)>::deserialize(ref response).unwrap()
    }

    fn get_new_wallet_rates(self: @RoutedGameDispatcher) -> (u256, u256, u256, u256) {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(10, selector!("get_new_wallet_rates"), args.span());
        Serde::<(u256, u256, u256, u256)>::deserialize(ref response).unwrap()
    }

    fn get_hop_limits(self: @RoutedGameDispatcher) -> (u256, u256, u256, u256) {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(10, selector!("get_hop_limits"), args.span());
        Serde::<(u256, u256, u256, u256)>::deserialize(ref response).unwrap()
    }

    fn get_soft_caps(self: @RoutedGameDispatcher) -> (u256, u256, u256, u256) {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(10, selector!("get_soft_caps"), args.span());
        Serde::<(u256, u256, u256, u256)>::deserialize(ref response).unwrap()
    }

    fn get_gate_thresholds(self: @RoutedGameDispatcher) -> (u256, u256) {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(10, selector!("get_gate_thresholds"), args.span());
        Serde::<(u256, u256)>::deserialize(ref response).unwrap()
    }

    fn get_hide_settings(self: @RoutedGameDispatcher) -> (u256, u256, u256, u256, u256) {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(3, selector!("get_hide_settings"), args.span());
        Serde::<(u256, u256, u256, u256, u256)>::deserialize(ref response).unwrap()
    }

    fn set_whitelist_merkle_root(self: @RoutedGameDispatcher, newRoot: felt252) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@newRoot, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(3, selector!("set_whitelist_merkle_root"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn get_whitelist_merkle_root(self: @RoutedGameDispatcher) -> felt252 {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(3, selector!("get_whitelist_merkle_root"), args.span());
        Serde::<felt252>::deserialize(ref response).unwrap()
    }

    fn get_whitelist_caps(self: @RoutedGameDispatcher) -> (u256, u256, u256) {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(3, selector!("get_whitelist_caps"), args.span());
        Serde::<(u256, u256, u256)>::deserialize(ref response).unwrap()
    }

    fn set_params(self: @RoutedGameDispatcher, keys: Array<felt252>, values: Array<u256>) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@keys, ref args);
        Serde::serialize(@values, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(9, selector!("set_params"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn update_price_band(self: @RoutedGameDispatcher, bandKind: u8, bandIndex: u8, upTo: u256, num: u256, den: u256) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@bandKind, ref args);
        Serde::serialize(@bandIndex, ref args);
        Serde::serialize(@upTo, ref args);
        Serde::serialize(@num, ref args);
        Serde::serialize(@den, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(9, selector!("update_price_band"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn get_price_band(self: @RoutedGameDispatcher, bandKind: u8, bandIndex: u8) -> (u256, u256, u256) {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@bandKind, ref args);
        Serde::serialize(@bandIndex, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(10, selector!("get_price_band"), args.span());
        Serde::<(u256, u256, u256)>::deserialize(ref response).unwrap()
    }

    fn get_player_daily_state(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress) -> (u256, u256, u256, u256, u256) {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(6, selector!("get_player_daily_state"), args.span());
        Serde::<(u256, u256, u256, u256, u256)>::deserialize(ref response).unwrap()
    }

    fn get_player_lifetime_spend(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress) -> u256 {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(6, selector!("get_player_lifetime_spend"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn get_free_hops_remaining(self: @RoutedGameDispatcher, gamerWalletAddress: ContractAddress) -> u256 {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(6, selector!("get_free_hops_remaining"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn finder_player_generate_position(self: @RoutedGameDispatcher) -> bool {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(5, selector!("finder_player_generate_position"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn withdraw_token_balance(self: @RoutedGameDispatcher, tokenAddress: ContractAddress, receiver: ContractAddress) -> () {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@tokenAddress, ref args);
        Serde::serialize(@receiver, ref args);
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(11, selector!("withdraw_token_balance"), args.span());
    }

    fn get_sweepable_balance(self: @RoutedGameDispatcher, tokenAddress: ContractAddress) -> u256 {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@tokenAddress, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(11, selector!("get_sweepable_balance"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn get_game_week(self: @RoutedGameDispatcher) -> u256 {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(1, selector!("get_game_week"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn get_round_status(self: @RoutedGameDispatcher) -> (u256, u8, u64, u64, u64, u256, u256, u64) {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(1, selector!("get_round_status"), args.span());
        Serde::<(u256, u8, u64, u64, u64, u256, u256, u64)>::deserialize(ref response).unwrap()
    }

    fn get_next_round_totals(self: @RoutedGameDispatcher) -> (u256, u256) {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(1, selector!("get_next_round_totals"), args.span());
        Serde::<(u256, u256)>::deserialize(ref response).unwrap()
    }

    fn get_min_treasures_to_start(self: @RoutedGameDispatcher) -> u256 {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(1, selector!("get_min_treasures_to_start"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn get_round_keeper(self: @RoutedGameDispatcher) -> ContractAddress {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(1, selector!("get_round_keeper"), args.span());
        Serde::<ContractAddress>::deserialize(ref response).unwrap()
    }

    fn update_round_keeper(self: @RoutedGameDispatcher, keeper: ContractAddress) -> bool {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@keeper, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(1, selector!("update_round_keeper"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn get_game_week_treasure_total(self: @RoutedGameDispatcher, gameWeek: u256) -> u256 {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gameWeek, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(1, selector!("get_game_week_treasure_total"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn get_game_grid_size(self: @RoutedGameDispatcher, gameWeek: u256) -> (u128, u128) {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gameWeek, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(1, selector!("get_game_grid_size"), args.span());
        Serde::<(u128, u128)>::deserialize(ref response).unwrap()
    }

    fn get_hider_player_fee(self: @RoutedGameDispatcher) -> u256 {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(3, selector!("get_hider_player_fee"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn get_claim_share_amounts(self: @RoutedGameDispatcher, gameWeek: u256, gamerWalletAddress: ContractAddress) -> u256 {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gameWeek, ref args);
        Serde::serialize(@gamerWalletAddress, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(7, selector!("get_claim_share_amounts"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn get_player_reward_due(self: @RoutedGameDispatcher, gameWeek: u256, gamerWalletAddress: ContractAddress) -> u256 {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gameWeek, ref args);
        Serde::serialize(@gamerWalletAddress, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(7, selector!("get_player_reward_due"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }

    fn pause(self: @RoutedGameDispatcher) -> () {
        let mut args: Array<felt252> = array![];
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("pause"), args.span());
    }

    fn unpause(self: @RoutedGameDispatcher) -> () {
        let mut args: Array<felt252> = array![];
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("unpause"), args.span());
    }

    fn is_paused(self: @RoutedGameDispatcher) -> bool {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("is_paused"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn propose_upgrade(self: @RoutedGameDispatcher, new_class_hash: ClassHash) -> () {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@new_class_hash, ref args);
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("propose_upgrade"), args.span());
    }

    fn execute_upgrade(self: @RoutedGameDispatcher) -> () {
        let mut args: Array<felt252> = array![];
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("execute_upgrade"), args.span());
    }

    fn execute_upgrade_and_migrate(self: @RoutedGameDispatcher, selector: felt252, calldata: Span<felt252>) -> Span<felt252> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@selector, ref args);
        Serde::serialize(@calldata, ref args);
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("execute_upgrade_and_migrate"), args.span());
        Serde::<Span<felt252>>::deserialize(ref response).unwrap()
    }

    fn cancel_upgrade(self: @RoutedGameDispatcher) -> () {
        let mut args: Array<felt252> = array![];
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("cancel_upgrade"), args.span());
    }

    fn get_pending_upgrade(self: @RoutedGameDispatcher) -> (ClassHash, u64) {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("get_pending_upgrade"), args.span());
        Serde::<(ClassHash, u64)>::deserialize(ref response).unwrap()
    }

    fn get_upgrade_delay(self: @RoutedGameDispatcher) -> u64 {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("get_upgrade_delay"), args.span());
        Serde::<u64>::deserialize(ref response).unwrap()
    }

    fn propose_upgrade_delay(self: @RoutedGameDispatcher, new_delay: u64) -> () {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@new_delay, ref args);
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("propose_upgrade_delay"), args.span());
    }

    fn set_upgrade_delay(self: @RoutedGameDispatcher, new_delay: u64) -> () {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@new_delay, ref args);
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("set_upgrade_delay"), args.span());
    }

    fn cancel_upgrade_delay_change(self: @RoutedGameDispatcher) -> () {
        let mut args: Array<felt252> = array![];
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("cancel_upgrade_delay_change"), args.span());
    }

    fn get_pending_upgrade_delay(self: @RoutedGameDispatcher) -> (bool, u64, u64) {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("get_pending_upgrade_delay"), args.span());
        Serde::<(bool, u64, u64)>::deserialize(ref response).unwrap()
    }

    fn propose_vrf_provider_update(self: @RoutedGameDispatcher, vrf_provider_address: ContractAddress) -> () {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@vrf_provider_address, ref args);
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(13, selector!("propose_vrf_provider_update"), args.span());
    }

    fn propose_game_token_update(self: @RoutedGameDispatcher, game_token_address: ContractAddress) -> () {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@game_token_address, ref args);
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(13, selector!("propose_game_token_update"), args.span());
    }

    fn propose_game_reward_token_update(self: @RoutedGameDispatcher, reward_token_address: ContractAddress) -> () {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@reward_token_address, ref args);
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(13, selector!("propose_game_reward_token_update"), args.span());
    }

    fn propose_admin_update(self: @RoutedGameDispatcher, new_admin: ContractAddress) -> () {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@new_admin, ref args);
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(13, selector!("propose_admin_update"), args.span());
    }

    fn propose_token_withdrawal(self: @RoutedGameDispatcher, token_address: ContractAddress, receiver: ContractAddress) -> () {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@token_address, ref args);
        Serde::serialize(@receiver, ref args);
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(13, selector!("propose_token_withdrawal"), args.span());
    }

    fn propose_full_token_withdrawal(self: @RoutedGameDispatcher, token_address: ContractAddress, receiver: ContractAddress) -> () {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@token_address, ref args);
        Serde::serialize(@receiver, ref args);
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(13, selector!("propose_full_token_withdrawal"), args.span());
    }

    fn cancel_admin_action(self: @RoutedGameDispatcher) -> () {
        let mut args: Array<felt252> = array![];
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(13, selector!("cancel_admin_action"), args.span());
    }

    fn get_pending_admin_action(self: @RoutedGameDispatcher) -> (felt252, felt252, u64) {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(13, selector!("get_pending_admin_action"), args.span());
        Serde::<(felt252, felt252, u64)>::deserialize(ref response).unwrap()
    }

    fn set_admin(self: @RoutedGameDispatcher, new_admin: ContractAddress) -> () {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@new_admin, ref args);
        IRoutedGameDispatcher { contract_address: *self.contract_address }.route(13, selector!("set_admin"), args.span());
    }

    fn get_admin(self: @RoutedGameDispatcher) -> ContractAddress {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(13, selector!("get_admin"), args.span());
        Serde::<ContractAddress>::deserialize(ref response).unwrap()
    }

    fn migrate_v2(self: @RoutedGameDispatcher) -> bool {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("migrate_v2"), args.span());
        Serde::<bool>::deserialize(ref response).unwrap()
    }

    fn get_upgrade_initialized_version(self: @RoutedGameDispatcher) -> u256 {
        let mut args: Array<felt252> = array![];
        let mut response = IRoutedGameDispatcher { contract_address: *self.contract_address }.route(12, selector!("get_upgrade_initialized_version"), args.span());
        Serde::<u256>::deserialize(ref response).unwrap()
    }
}

impl RoutedGameSafeDispatcherImpl of RoutedGameSafeDispatcherTrait {
    fn start_next_round(self: @RoutedGameSafeDispatcher, params: NextRoundParams) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@params, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(0, selector!("start_next_round"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn expire_round(self: @RoutedGameSafeDispatcher, expectedRound: u256) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@expectedRound, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(0, selector!("expire_round"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn hide_treasure(self: @RoutedGameSafeDispatcher) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(2, selector!("hide_treasure"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn hide_treasure_bulk(self: @RoutedGameSafeDispatcher, bulkAmount: u256, merkleProof: Array<felt252>, leafIndex: u32) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@bulkAmount, ref args);
        Serde::serialize(@merkleProof, ref args);
        Serde::serialize(@leafIndex, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(2, selector!("hide_treasure_bulk"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn validate_treasure_coordinates(self: @RoutedGameSafeDispatcher, finderGamerWalletAddress: ContractAddress, hiderGamerWalletAddress: ContractAddress, leaf: u256, proof: Array<u256>, checkHopCount: u256, checkTimestamp: u64) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@finderGamerWalletAddress, ref args);
        Serde::serialize(@hiderGamerWalletAddress, ref args);
        Serde::serialize(@leaf, ref args);
        Serde::serialize(@proof, ref args);
        Serde::serialize(@checkHopCount, ref args);
        Serde::serialize(@checkTimestamp, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(4, selector!("validate_treasure_coordinates"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn finder_player_move_position(self: @RoutedGameSafeDispatcher, direction: u128) -> Result<(u128, u128), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@direction, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(5, selector!("finder_player_move_position"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u128, u128)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_finder_player_position(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> Result<(u128, u128), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        Serde::serialize(@gameWeek, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(6, selector!("get_finder_player_position"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u128, u128)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_minimum_allowance_fee(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(6, selector!("get_minimum_allowance_fee"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn claim_reward(self: @RoutedGameSafeDispatcher, gameWeek: u256) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gameWeek, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(7, selector!("claim_reward"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn claim_reward_tokens(self: @RoutedGameSafeDispatcher) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(8, selector!("claim_reward_tokens"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn claim_reward_token_for_week(self: @RoutedGameSafeDispatcher, gameWeek: u256) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gameWeek, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(8, selector!("claim_reward_token_for_week"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_reward_token_pending(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(8, selector!("get_reward_token_pending"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_total_reward_token_pending(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(8, selector!("get_total_reward_token_pending"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_reward_token_missed(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(8, selector!("get_reward_token_missed"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_total_reward_token_missed(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(8, selector!("get_total_reward_token_missed"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn claim_missed_reward_token(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(8, selector!("claim_missed_reward_token"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_reward_token_claimed(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        Serde::serialize(@gameWeek, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(8, selector!("get_reward_token_claimed"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_reward_claimed(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        Serde::serialize(@gameWeek, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(7, selector!("get_reward_claimed"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_claimable_weeks(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress, fromWeek: u256, toWeek: u256) -> Result<Array<u256>, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        Serde::serialize(@fromWeek, ref args);
        Serde::serialize(@toWeek, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(7, selector!("get_claimable_weeks"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<Array<u256>>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_reward_token_due(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress, gameWeek: u256) -> Result<(u256, u256, u256), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        Serde::serialize(@gameWeek, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(8, selector!("get_reward_token_due"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u256, u256, u256)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn update_vrf_provider(self: @RoutedGameSafeDispatcher, vrfProviderAddress: ContractAddress) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@vrfProviderAddress, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(11, selector!("update_vrf_provider"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn update_game_token(self: @RoutedGameSafeDispatcher, gameTokenAddress: ContractAddress) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gameTokenAddress, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(11, selector!("update_game_token"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn update_game_reward_token(self: @RoutedGameSafeDispatcher, rewardTokenAddress: ContractAddress) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@rewardTokenAddress, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(11, selector!("update_game_reward_token"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_contract_addresses(self: @RoutedGameSafeDispatcher) -> Result<(ContractAddress, ContractAddress, ContractAddress), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(11, selector!("get_contract_addresses"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(ContractAddress, ContractAddress, ContractAddress)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_reward_rates(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256, u256, u256, u256), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(10, selector!("get_reward_rates"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u256, u256, u256, u256, u256)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_below_threshold_rates(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256, u256, u256), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(10, selector!("get_below_threshold_rates"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u256, u256, u256, u256)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_new_wallet_rates(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256, u256, u256), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(10, selector!("get_new_wallet_rates"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u256, u256, u256, u256)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_hop_limits(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256, u256, u256), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(10, selector!("get_hop_limits"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u256, u256, u256, u256)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_soft_caps(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256, u256, u256), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(10, selector!("get_soft_caps"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u256, u256, u256, u256)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_gate_thresholds(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(10, selector!("get_gate_thresholds"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u256, u256)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_hide_settings(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256, u256, u256, u256), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(3, selector!("get_hide_settings"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u256, u256, u256, u256, u256)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn set_whitelist_merkle_root(self: @RoutedGameSafeDispatcher, newRoot: felt252) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@newRoot, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(3, selector!("set_whitelist_merkle_root"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_whitelist_merkle_root(self: @RoutedGameSafeDispatcher) -> Result<felt252, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(3, selector!("get_whitelist_merkle_root"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<felt252>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_whitelist_caps(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256, u256), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(3, selector!("get_whitelist_caps"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u256, u256, u256)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn set_params(self: @RoutedGameSafeDispatcher, keys: Array<felt252>, values: Array<u256>) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@keys, ref args);
        Serde::serialize(@values, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(9, selector!("set_params"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn update_price_band(self: @RoutedGameSafeDispatcher, bandKind: u8, bandIndex: u8, upTo: u256, num: u256, den: u256) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@bandKind, ref args);
        Serde::serialize(@bandIndex, ref args);
        Serde::serialize(@upTo, ref args);
        Serde::serialize(@num, ref args);
        Serde::serialize(@den, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(9, selector!("update_price_band"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_price_band(self: @RoutedGameSafeDispatcher, bandKind: u8, bandIndex: u8) -> Result<(u256, u256, u256), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@bandKind, ref args);
        Serde::serialize(@bandIndex, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(10, selector!("get_price_band"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u256, u256, u256)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_player_daily_state(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress) -> Result<(u256, u256, u256, u256, u256), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(6, selector!("get_player_daily_state"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u256, u256, u256, u256, u256)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_player_lifetime_spend(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(6, selector!("get_player_lifetime_spend"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_free_hops_remaining(self: @RoutedGameSafeDispatcher, gamerWalletAddress: ContractAddress) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gamerWalletAddress, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(6, selector!("get_free_hops_remaining"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn finder_player_generate_position(self: @RoutedGameSafeDispatcher) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(5, selector!("finder_player_generate_position"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn withdraw_token_balance(self: @RoutedGameSafeDispatcher, tokenAddress: ContractAddress, receiver: ContractAddress) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@tokenAddress, ref args);
        Serde::serialize(@receiver, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(11, selector!("withdraw_token_balance"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_sweepable_balance(self: @RoutedGameSafeDispatcher, tokenAddress: ContractAddress) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@tokenAddress, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(11, selector!("get_sweepable_balance"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_game_week(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(1, selector!("get_game_week"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_round_status(self: @RoutedGameSafeDispatcher) -> Result<(u256, u8, u64, u64, u64, u256, u256, u64), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(1, selector!("get_round_status"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u256, u8, u64, u64, u64, u256, u256, u64)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_next_round_totals(self: @RoutedGameSafeDispatcher) -> Result<(u256, u256), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(1, selector!("get_next_round_totals"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u256, u256)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_min_treasures_to_start(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(1, selector!("get_min_treasures_to_start"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_round_keeper(self: @RoutedGameSafeDispatcher) -> Result<ContractAddress, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(1, selector!("get_round_keeper"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<ContractAddress>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn update_round_keeper(self: @RoutedGameSafeDispatcher, keeper: ContractAddress) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@keeper, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(1, selector!("update_round_keeper"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_game_week_treasure_total(self: @RoutedGameSafeDispatcher, gameWeek: u256) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gameWeek, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(1, selector!("get_game_week_treasure_total"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_game_grid_size(self: @RoutedGameSafeDispatcher, gameWeek: u256) -> Result<(u128, u128), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gameWeek, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(1, selector!("get_game_grid_size"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(u128, u128)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_hider_player_fee(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(3, selector!("get_hider_player_fee"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_claim_share_amounts(self: @RoutedGameSafeDispatcher, gameWeek: u256, gamerWalletAddress: ContractAddress) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gameWeek, ref args);
        Serde::serialize(@gamerWalletAddress, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(7, selector!("get_claim_share_amounts"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_player_reward_due(self: @RoutedGameSafeDispatcher, gameWeek: u256, gamerWalletAddress: ContractAddress) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@gameWeek, ref args);
        Serde::serialize(@gamerWalletAddress, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(7, selector!("get_player_reward_due"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn pause(self: @RoutedGameSafeDispatcher) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("pause"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn unpause(self: @RoutedGameSafeDispatcher) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("unpause"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn is_paused(self: @RoutedGameSafeDispatcher) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("is_paused"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn propose_upgrade(self: @RoutedGameSafeDispatcher, new_class_hash: ClassHash) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@new_class_hash, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("propose_upgrade"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn execute_upgrade(self: @RoutedGameSafeDispatcher) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("execute_upgrade"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn execute_upgrade_and_migrate(self: @RoutedGameSafeDispatcher, selector: felt252, calldata: Span<felt252>) -> Result<Span<felt252>, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@selector, ref args);
        Serde::serialize(@calldata, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("execute_upgrade_and_migrate"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<Span<felt252>>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn cancel_upgrade(self: @RoutedGameSafeDispatcher) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("cancel_upgrade"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_pending_upgrade(self: @RoutedGameSafeDispatcher) -> Result<(ClassHash, u64), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("get_pending_upgrade"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(ClassHash, u64)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_upgrade_delay(self: @RoutedGameSafeDispatcher) -> Result<u64, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("get_upgrade_delay"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u64>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn propose_upgrade_delay(self: @RoutedGameSafeDispatcher, new_delay: u64) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@new_delay, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("propose_upgrade_delay"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn set_upgrade_delay(self: @RoutedGameSafeDispatcher, new_delay: u64) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@new_delay, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("set_upgrade_delay"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn cancel_upgrade_delay_change(self: @RoutedGameSafeDispatcher) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("cancel_upgrade_delay_change"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_pending_upgrade_delay(self: @RoutedGameSafeDispatcher) -> Result<(bool, u64, u64), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("get_pending_upgrade_delay"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(bool, u64, u64)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn propose_vrf_provider_update(self: @RoutedGameSafeDispatcher, vrf_provider_address: ContractAddress) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@vrf_provider_address, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(13, selector!("propose_vrf_provider_update"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn propose_game_token_update(self: @RoutedGameSafeDispatcher, game_token_address: ContractAddress) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@game_token_address, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(13, selector!("propose_game_token_update"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn propose_game_reward_token_update(self: @RoutedGameSafeDispatcher, reward_token_address: ContractAddress) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@reward_token_address, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(13, selector!("propose_game_reward_token_update"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn propose_admin_update(self: @RoutedGameSafeDispatcher, new_admin: ContractAddress) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@new_admin, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(13, selector!("propose_admin_update"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn propose_token_withdrawal(self: @RoutedGameSafeDispatcher, token_address: ContractAddress, receiver: ContractAddress) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@token_address, ref args);
        Serde::serialize(@receiver, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(13, selector!("propose_token_withdrawal"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn propose_full_token_withdrawal(self: @RoutedGameSafeDispatcher, token_address: ContractAddress, receiver: ContractAddress) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@token_address, ref args);
        Serde::serialize(@receiver, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(13, selector!("propose_full_token_withdrawal"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn cancel_admin_action(self: @RoutedGameSafeDispatcher) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(13, selector!("cancel_admin_action"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_pending_admin_action(self: @RoutedGameSafeDispatcher) -> Result<(felt252, felt252, u64), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(13, selector!("get_pending_admin_action"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<(felt252, felt252, u64)>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn set_admin(self: @RoutedGameSafeDispatcher, new_admin: ContractAddress) -> Result<(), Array<felt252>> {
        let mut args: Array<felt252> = array![];
        Serde::serialize(@new_admin, ref args);
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(13, selector!("set_admin"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_admin(self: @RoutedGameSafeDispatcher) -> Result<ContractAddress, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(13, selector!("get_admin"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<ContractAddress>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn migrate_v2(self: @RoutedGameSafeDispatcher) -> Result<bool, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("migrate_v2"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<bool>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }

    fn get_upgrade_initialized_version(self: @RoutedGameSafeDispatcher) -> Result<u256, Array<felt252>> {
        let mut args: Array<felt252> = array![];
        let dispatcher = IRoutedGameSafeDispatcher { contract_address: *self.contract_address };
        match dispatcher.route(12, selector!("get_upgrade_initialized_version"), args.span()) {
            Result::Ok(data) => {
                let mut response = data;
                Result::Ok(Serde::<u256>::deserialize(ref response).unwrap())
            },
            Result::Err(reason) => Result::Err(reason),
        }
    }
}
