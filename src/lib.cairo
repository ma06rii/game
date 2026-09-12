// A testnet-only stand-in for Cartridge's VRF provider, deployed while their
// Sepolia service is unavailable. It is a separate contract, never called from
// this file, and never deployed to mainnet. See src/mock_vrf_provider.cairo for
// the full explanation.

// The ROZ reward token - a fixed-supply ERC20 with no mint function, deployed
// on its own before the game contract. Declaring it here is what puts it in the
// build; without this line the file is never compiled and its class is never
// produced. The game contract never calls into it by module path: it holds the
// token's ADDRESS in storage and talks to it through the ERC20 dispatcher, so
// the two can be deployed and upgraded independently.
mod game_reward_token;

// A test-only ERC-20 with an unrestricted mint, used to stand in for both the
// game token and the reward token in the test suite. It is never called from
// this file and must never be deployed to mainnet - see src/mock_erc20.cairo.
//
// Public only so the test crate can reach its dispatcher to mint.
pub mod mock_erc20;
mod mock_vrf_provider;

// Cartridge Arcade calls this separate implementation contract after it has
// collected payment for a registered starter pack. The contract distributes
// pre-funded USDC, STRK and ROZ; it never charges the buyer itself.
pub mod starterpack;
use starknet::{ClassHash, ContractAddress};

#[derive(Drop, Copy, Clone, Serde)]
pub struct NextRoundParams {
    pub merkle_root: u256,
    pub grid_size_x: u128,
    pub grid_size_y: u128,
    pub expected_active_treasure_count: u256,
    pub expected_total_hidden_value: u256,
    pub hider_stake: u256,
    pub hide_fee_base: u256,
    pub hide_fee_high: u256,
    pub hop_price_0: u256,
    pub hop_price_1: u256,
    pub hop_price_2: u256,
    pub hop_price_3: u256,
    pub spawn_fee: u256,
    pub round_duration: u64,
    pub min_duration: u64,
    pub near_end_blackout: u64,
    pub end_buffer: u64,
}

// Define the VRF Provider interface (as you provided)
// Implemented by Cartridge's real provider, and - so the two can be swapped by
// address alone - by MockVrfProvider in src/mock_vrf_provider.cairo.
#[starknet::interface]
pub trait IVrfProvider<TContractState> {
    fn request_random(self: @TContractState, caller: ContractAddress, source: Source);
    fn consume_random(ref self: TContractState, source: Source) -> felt252;
}

// Define the Source enum (as you provided)
#[derive(Drop, Copy, Clone, Serde)]
pub enum Source {
    Nonce: ContractAddress,
    Salt: felt252,
}

#[starknet::interface]
pub trait IHelloStarknet<TContractState> {
    fn start_next_round(ref self: TContractState, params: NextRoundParams) -> bool;
    fn expire_round(ref self: TContractState, expectedRound: u256) -> bool;
    fn hide_treasure(ref self: TContractState) -> bool;
    fn hide_treasure_bulk(
        ref self: TContractState, bulkAmount: u256, merkleProof: Array<felt252>, leafIndex: u32,
    ) -> bool;
    fn validate_treasure_coordinates(
        ref self: TContractState,
        finderGamerWalletAddress: ContractAddress,
        hiderGamerWalletAddress: ContractAddress,
        leaf: u256,
        proof: Array<u256>,
        checkHopCount: u256,
        checkTimestamp: u64,
    ) -> bool;
    fn finder_player_move_position(ref self: TContractState, direction: u128) -> (u128, u128);
    fn get_finder_player_position(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> (u128, u128);
    fn get_minimum_allowance_fee(self: @TContractState) -> u256;
    fn claim_reward(ref self: TContractState, gameWeek: u256) -> bool;
    // The ROZ claim leg (4g, 4h, 4i)
    fn claim_reward_tokens(ref self: TContractState) -> bool;
    fn claim_reward_token_for_week(ref self: TContractState, gameWeek: u256) -> bool;
    fn get_reward_token_pending(self: @TContractState, gamerWalletAddress: ContractAddress) -> u256;
    fn get_total_reward_token_pending(self: @TContractState) -> u256;
    // ROZ earned while the contract could not pay for it, and the call that
    // turns it back into a withdrawable balance once it can.
    fn get_reward_token_missed(self: @TContractState, gamerWalletAddress: ContractAddress) -> u256;
    fn get_total_reward_token_missed(self: @TContractState) -> u256;
    fn claim_missed_reward_token(ref self: TContractState) -> u256;
    fn get_reward_token_claimed(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    // The USDC counterparts of the two entries above. Claim discovery is
    // impossible without them - see the comments on the implementations.
    fn get_reward_claimed(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    fn get_claimable_weeks(
        self: @TContractState, gamerWalletAddress: ContractAddress, fromWeek: u256, toWeek: u256,
    ) -> Array<u256>;
    fn get_reward_token_due(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> (u256, u256, u256);
    fn update_vrf_provider(ref self: TContractState, vrfProviderAddress: ContractAddress) -> bool;
    fn update_game_token(ref self: TContractState, gameTokenAddress: ContractAddress) -> bool;
    // ROZ reward token - address and rates (4a, 4b)
    fn update_game_reward_token(
        ref self: TContractState, rewardTokenAddress: ContractAddress,
    ) -> bool;
    fn get_contract_addresses(
        self: @TContractState,
    ) -> (ContractAddress, ContractAddress, ContractAddress);
    fn get_reward_rates(self: @TContractState) -> (u256, u256, u256, u256, u256);
    fn get_below_threshold_rates(self: @TContractState) -> (u256, u256, u256, u256);
    fn get_new_wallet_rates(self: @TContractState) -> (u256, u256, u256, u256);
    // Limits and allowances (2.2, 2.3)
    fn get_hop_limits(self: @TContractState) -> (u256, u256, u256, u256);
    fn get_soft_caps(self: @TContractState) -> (u256, u256, u256, u256);
    // The Lightweight Gate (2.6) and hiding (2.3). These four move together -
    // see the invariant asserted in update_hide_settings.
    fn get_gate_thresholds(self: @TContractState) -> (u256, u256);
    fn get_hide_settings(self: @TContractState) -> (u256, u256, u256, u256, u256);
    // The bulk-hide whitelist (4m-iii)
    fn set_whitelist_merkle_root(ref self: TContractState, newRoot: felt252) -> bool;
    fn get_whitelist_merkle_root(self: @TContractState) -> felt252;
    fn get_whitelist_caps(self: @TContractState) -> (u256, u256, u256);
    // Admin-settable schedules, one band at a time (2.3, 2.5)
    // Thirty-five scalar settings through ONE entrypoint. Twelve separate
    // setters used to do this, and their compiler-generated wrappers alone cost
    // 7,922 casm felts against the 81,920 Starknet allows a whole class. The
    // batch is applied and then validated as a whole - see the implementation.
    fn set_params(ref self: TContractState, keys: Array<felt252>, values: Array<u256>) -> bool;

    // bandKind 0 updates a hop band (num is the price; den must be zero).
    // bandKind 1 updates a volume band (num/den is the multiplier).
    fn update_price_band(
        ref self: TContractState, bandKind: u8, bandIndex: u8, upTo: u256, num: u256, den: u256,
    ) -> bool;
    // Returns (limit, num, den). Hop bands use price as num and zero as den.
    fn get_price_band(self: @TContractState, bandKind: u8, bandIndex: u8) -> (u256, u256, u256);
    // Per-player state, so a deploy can be inspected without a block explorer
    fn get_player_daily_state(
        self: @TContractState, gamerWalletAddress: ContractAddress,
    ) -> (u256, u256, u256, u256, u256);
    fn get_player_lifetime_spend(
        self: @TContractState, gamerWalletAddress: ContractAddress,
    ) -> u256;
    fn get_free_hops_remaining(self: @TContractState, gamerWalletAddress: ContractAddress) -> u256;
    fn finder_player_generate_position(ref self: TContractState) -> bool;
    fn withdraw_token_balance(
        ref self: TContractState, tokenAddress: ContractAddress, receiver: ContractAddress,
    );
    fn get_sweepable_balance(self: @TContractState, tokenAddress: ContractAddress) -> u256;
    fn get_game_week(self: @TContractState) -> u256;
    fn get_round_status(self: @TContractState) -> (u256, u8, u64, u64, u64, u256, u256, u64);
    fn get_next_round_totals(self: @TContractState) -> (u256, u256);
    fn get_min_treasures_to_start(self: @TContractState) -> u256;
    fn get_round_keeper(self: @TContractState) -> ContractAddress;
    fn update_round_keeper(ref self: TContractState, keeper: ContractAddress) -> bool;
    fn get_game_week_treasure_total(self: @TContractState, gameWeek: u256) -> u256;
    fn get_game_grid_size(self: @TContractState, gameWeek: u256) -> (u128, u128);
    fn get_hider_player_fee(self: @TContractState) -> u256;
    fn get_claim_share_amounts(
        self: @TContractState, gameWeek: u256, gamerWalletAddress: ContractAddress,
    ) -> u256;
    fn get_player_reward_due(
        self: @TContractState, gameWeek: u256, gamerWalletAddress: ContractAddress,
    ) -> u256;
}

// Upgrade, pause and delayed administration live in a separate interface so
// the already-large game interface keeps every existing selector unchanged.
#[starknet::interface]
pub trait IGameAdministration<TContractState> {
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn is_paused(self: @TContractState) -> bool;
    fn propose_upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn execute_upgrade(ref self: TContractState);
    fn execute_upgrade_and_migrate(
        ref self: TContractState, selector: felt252, calldata: Span<felt252>,
    ) -> Span<felt252>;
    fn cancel_upgrade(ref self: TContractState);
    fn get_pending_upgrade(self: @TContractState) -> (ClassHash, u64);
    fn get_upgrade_delay(self: @TContractState) -> u64;
    fn propose_upgrade_delay(ref self: TContractState, new_delay: u64);
    fn set_upgrade_delay(ref self: TContractState, new_delay: u64);
    fn cancel_upgrade_delay_change(ref self: TContractState);
    fn get_pending_upgrade_delay(self: @TContractState) -> (bool, u64, u64);
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
    fn migrate_v2(ref self: TContractState) -> bool;
    fn get_upgrade_initialized_version(self: @TContractState) -> u256;
}

trait InternalFunctionsTrait<TContractState> {
    fn _receive_random_words_2(
        ref self: TContractState, requester_address: ContractAddress, random_words: felt252,
    );
    fn _checkForTreasure(
        ref self: TContractState,
        gamerWalletAddress: ContractAddress,
        xCoordinate: u128,
        yCoordinate: u128,
        gameWeek: u256,
    ) -> bool;
    fn _verify(self: @TContractState, _root: u256, _leaf: u256, _proof: Array<u256>) -> bool;
    fn _keccak256(self: @TContractState, a: u256, b: u256) -> u256;
    fn _createNewGame(ref self: TContractState, params: NextRoundParams, gameWeek: u256) -> bool;
    fn _validateNextRoundParams(self: @TContractState, params: NextRoundParams);
    fn _assertRoundAcceptsActions(self: @TContractState);
    fn _assertHidingAllowed(self: @TContractState);
    fn _endRound(ref self: TContractState, reason: u8) -> bool;
    fn _hideTreasure(
        ref self: TContractState,
        caller: ContractAddress,
        treasureCount: u256,
        merkleProof: Array<felt252>,
        leafIndex: u32,
    ) -> bool;
    fn _transfer_token_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
    fn _rewardGamer(
        ref self: TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    fn _removeGamerReward(
        ref self: TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    fn _spawnNewPosition(
        ref self: TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    fn _updatePlayerPosition(
        ref self: TContractState,
        xCoordinate: u128,
        yCoordinate: u128,
        gamerWalletAddress: ContractAddress,
        gameWeek: u256,
    );
    fn _finderPlayerMovePosition(
        ref self: TContractState,
        direction: felt252,
        gamerWalletAddress: ContractAddress,
        gameWeek: u256,
    ) -> (u128, u128);
    fn _playerRewardDue(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> u256;
    fn _calculateRewardDue(self: @TContractState, claimShareCount: u256, gameWeek: u256) -> u256;
    fn _isRewardClaimable(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    fn _recordMissedRewardToken(
        ref self: TContractState, gamerWalletAddress: ContractAddress, amount: u256,
    );
    fn _claimReward(
        ref self: TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    fn _transfer_token(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn _request_randomness_from_vrf_provider(
        ref self: TContractState, caller: ContractAddress,
    ) -> bool;
    fn _assert_admin(self: @TContractState);
    fn _assert_admin_or_default(self: @TContractState);
    fn _assert_admin_or_upgrader(self: @TContractState);
    fn _assert_valid_upgrade_delay(self: @TContractState, delay: u64);
    fn _admin_action_hash(
        self: @TContractState, action: felt252, first: felt252, second: felt252,
    ) -> felt252;
    fn _schedule_admin_action(
        ref self: TContractState, action: felt252, action_hash: felt252, require_paused: bool,
    );
    fn _consume_admin_action(
        ref self: TContractState, action: felt252, action_hash: felt252, require_paused: bool,
    );
    fn _clear_admin_action(ref self: TContractState);
}

#[starknet::contract]
mod HelloStarknet {
    use core::array::ArrayTrait;
    use core::hash::HashStateTrait;
    use core::integer::{BoundedInt, u128_byte_reverse};
    use core::num::traits::zero::Zero;
    use core::option::OptionTrait;
    // Poseidon is the hash the off-chain merkle tooling uses for the bulk-hide
    // whitelist. The two MUST agree - a Pedersen tree would produce proofs that
    // never verify here, and the failure is silent (the caller simply falls back
    // to the ordinary daily cap). See _verifyWhitelist.
    use core::poseidon::{PoseidonTrait, poseidon_hash_span};
    use core::serde::Serde;
    use core::traits::{Into, TryInto};
    use openzeppelin::access::accesscontrol::interface::IAccessControl;
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::{
        ClassHash, ContractAddress, SyscallResultTrait, contract_address_const, get_block_timestamp,
        get_caller_address, get_contract_address, get_tx_info, syscalls,
    };
    use super::{
        IGameAdministration, IVrfProviderDispatcher, IVrfProviderDispatcherTrait, NextRoundParams,
        Source,
    };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    const PAUSE_ROLE: felt252 = selector!("PAUSE_ROLE");
    const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");
    const UPGRADE_ROLE: felt252 = selector!("UPGRADE_ROLE");
    const MAINNET_MIN_UPGRADE_DELAY: u64 = 259200;
    const MIGRATION_VERSION: u256 = 2;
    const ACTION_VRF_PROVIDER: felt252 = selector!("ACTION_VRF_PROVIDER");
    const ACTION_GAME_TOKEN: felt252 = selector!("ACTION_GAME_TOKEN");
    const ACTION_REWARD_TOKEN: felt252 = selector!("ACTION_REWARD_TOKEN");
    const ACTION_SET_ADMIN: felt252 = selector!("ACTION_SET_ADMIN");
    const ACTION_SAFE_SWEEP: felt252 = selector!("ACTION_SAFE_SWEEP");
    const ACTION_FULL_SWEEP: felt252 = selector!("ACTION_FULL_SWEEP");

    const ROUND_OPEN: u8 = 0;
    const ROUND_ENDING: u8 = 1;
    const END_REASON_ALL_FOUND: u8 = 0;
    const END_REASON_TIME_EXPIRED: u8 = 1;
    const VALIDATION_GRACE_SECONDS: u64 = 60;
    const OPEN_ENDED_BAND: u256 = 0xffffffffffffffffffffffffffffffff;
    // Poseidon hash (with the array length) of the canonical 35-key order used
    // by set_params. One comparison proves the initial batch has no omissions,
    // duplicates or unknown keys without carrying a second lookup table.
    const INITIAL_SETTINGS_KEYS_HASH: felt252 =
        0x2fd8f8c89dc0378422bb486a63f213ce2f1f691fbd0cd61e4b05c02de92bcc8;
    // Round zero is created directly by the constructor. Every round opened
    // through start_next_round must contain at least this many real, staged
    // treasures; equality with a zero on-chain count is not sufficient.
    const MIN_TREASURES_TO_START: u256 = 2;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TreasureHidden: TreasureHidden,
        TreasureFound: TreasureFound,
        PlayerPosition: PlayerPosition,
        CheckForTreasure: CheckForTreasure,
        RewardTokenAccrued: RewardTokenAccrued,
        RewardTokenAccrualSkipped: RewardTokenAccrualSkipped,
        RewardTokenClaimed: RewardTokenClaimed,
        RewardTokenMissedRecovered: RewardTokenMissedRecovered,
        RoundStarted: RoundStarted,
        RoundEnded: RoundEnded,
        UpgradeProposed: UpgradeProposed,
        UpgradeCancelled: UpgradeCancelled,
        UpgradeExecuted: UpgradeExecuted,
        UpgradeDelayChangeProposed: UpgradeDelayChangeProposed,
        UpgradeDelayChanged: UpgradeDelayChanged,
        UpgradeDelayChangeCancelled: UpgradeDelayChangeCancelled,
        AdminActionProposed: AdminActionProposed,
        AdminActionCancelled: AdminActionCancelled,
        AdminActionExecuted: AdminActionExecuted,
        AdminChanged: AdminChanged,
        MigrationApplied: MigrationApplied,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct UpgradeProposed {
        class_hash: ClassHash,
        eta: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct UpgradeCancelled {
        class_hash: ClassHash,
    }

    #[derive(Drop, starknet::Event)]
    struct UpgradeExecuted {
        class_hash: ClassHash,
    }

    #[derive(Drop, starknet::Event)]
    struct UpgradeDelayChangeProposed {
        new_delay: u64,
        eta: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct UpgradeDelayChanged {
        old_delay: u64,
        new_delay: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct UpgradeDelayChangeCancelled {
        proposed_delay: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct AdminActionProposed {
        action: felt252,
        action_hash: felt252,
        eta: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct AdminActionCancelled {
        action: felt252,
        action_hash: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct AdminActionExecuted {
        action: felt252,
        action_hash: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct AdminChanged {
        previous_admin: ContractAddress,
        new_admin: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct MigrationApplied {
        version: u256,
    }

    // The feedback signal the off-chain map-scaling controller runs on. Without
    // hopsTaken there is no way to compute the median hops per find, and K has
    // no input to adjust against.
    #[derive(Drop, starknet::Event)]
    struct TreasureFound {
        #[key]
        finder: ContractAddress,
        hider: ContractAddress,
        hopsTaken: u256,
        #[key]
        roundId: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct RoundStarted {
        #[key]
        roundId: u256,
        startTs: u64,
        scheduledEndTs: u64,
        roundDuration: u64,
        minDuration: u64,
        nearEndBlackout: u64,
        endBuffer: u64,
        merkleRoot: u256,
        gridSizeX: u128,
        gridSizeY: u128,
        activeTreasureCount: u256,
        totalHiddenValue: u256,
        hiderStake: u256,
        hideFeeBase: u256,
        hideFeeHigh: u256,
        hopPrice0: u256,
        hopPrice1: u256,
        hopPrice2: u256,
        hopPrice3: u256,
        spawnFee: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct RoundEnded {
        #[key]
        roundId: u256,
        endedTs: u64,
        reason: u8,
        initialTreasureCount: u256,
        treasuresFound: u256,
        treasuresSurvived: u256,
    }

    // Every successful ROZ credit. Amounts are raw 18-decimal ROZ.
    #[derive(Drop, starknet::Event)]
    struct RewardTokenAccrued {
        #[key]
        user: ContractAddress,
        amount: u256,
        //Which action earned it, so an indexer can break rewards down without
        //having to correlate against every other event.
        reason: felt252,
    }

    // Fired instead of RewardTokenAccrued when the contract cannot cover the
    // credit (4c-i). The gameplay action still SUCCEEDS - only the reward is
    // skipped. This event is the only signal that rewards have paused, so
    // monitoring it is how the operator learns the tranche needs topping up.
    #[derive(Drop, starknet::Event)]
    struct RewardTokenAccrualSkipped {
        #[key]
        user: ContractAddress,
        amount: u256,
        reason: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct RewardTokenClaimed {
        #[key]
        user: ContractAddress,
        amount: u256,
    }

    // Fired when a player converts ROZ that was previously skipped into a
    // pending balance they can actually withdraw. `remaining` is what is still
    // waiting on further funding - non-zero means the conversion was PARTIAL
    // because the contract could not cover the whole backlog yet, and calling
    // again after the next top-up will move more.
    #[derive(Drop, starknet::Event)]
    struct RewardTokenMissedRecovered {
        #[key]
        user: ContractAddress,
        amount: u256,
        remaining: u256,
    }

    // Emitted ONCE PER CALL - single or bulk - and never once per treasure.
    // Coordinates are assigned off-chain and the merkle root arrives later
    // through start_next_round, so the backend that places treasures only needs to
    // know HOW MANY were bought; an event per treasure would cost gas for no
    // extra information. treasureCount carries that quantity, and is 1 for a
    // single hide, so one bulk of ten and ten single hides describe themselves
    // IDENTICALLY on the log - the same equivalence the fee and reward paths
    // guarantee in 4m.
    //
    // THE TWO MONEY FIELDS ARE DIFFERENT MONEY. Never add them together:
    //
    //   hiderStake      stakePerTreasure * treasureCount. REFUNDABLE - it is
    //                   owed back to the player if the treasure survives, which
    //                   is why it is credited to total_usdc_claimable and MUST
    //                   NOT reach the spend counters (2.6 rule 1).
    //   totalFeeCharged The sum of the per-treasure fees actually taken. KEPT -
    //                   this is the only part that is revenue, and the only part
    //                   _recordSpend ever sees.
    //
    // The stake dwarfs a single hide fee - it is set by currentHiderFee, which
    // is a whole refundable deposit rather than a charge - so a consumer that
    // sums the two fields gets a stake count with noise, not a fee total.
    //
    // Both fields are AGGREGATES for the call, but they do not divide alike:
    //
    //   hiderStake / treasureCount      IS an exact per-treasure stake. The
    //                                   stake rate does not tier.
    //   totalFeeCharged / treasureCount is NOT a per-treasure fee. One call can
    //                                   straddle hideFeeTierBoundary, so some
    //                                   treasures pay hideFeeBase and the rest
    //                                   hideFeeHigh.
    #[derive(Drop, starknet::Event)]
    struct TreasureHidden {
        #[key]
        user: ContractAddress,
        hiderStake: u256,
        totalFeeCharged: u256,
        treasureCount: u256,
        #[key]
        gameWeek: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct CheckForTreasure {
        #[key]
        user: ContractAddress,
        xCoordinate: u128,
        yCoordinate: u128,
        #[key]
        gameWeek: u256,
        hopCount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct PlayerPosition {
        #[key]
        user: ContractAddress,
        xCoordinate: u128,
        yCoordinate: u128,
        #[key]
        gameWeek: u256,
    }

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl PausableViewImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // Core authority moves only through delayed set_admin. The standard role
    // selectors stay ABI-compatible, but direct mutations are intentionally
    // limited to PAUSE_ROLE so they cannot bypass that handoff delay.
    #[abi(embed_v0)]
    impl RestrictedAccessControlImpl of IAccessControl<ContractState> {
        fn has_role(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
            self.access_control.is_role_effective(role, account)
        }

        fn get_role_admin(self: @ContractState, role: felt252) -> felt252 {
            if role == PAUSE_ROLE {
                ADMIN_ROLE
            } else {
                DEFAULT_ADMIN_ROLE
            }
        }

        fn grant_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            assert(role == PAUSE_ROLE, 'Core roles use set_admin');
            self._assert_admin_or_default();
            assert(account.is_non_zero(), 'Role account is zero');
            self.access_control._grant_role(role, account);
        }

        fn revoke_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            assert(role == PAUSE_ROLE, 'Core roles use set_admin');
            self._assert_admin_or_default();
            self.access_control._revoke_role(role, account);
        }

        fn renounce_role(ref self: ContractState, role: felt252, account: ContractAddress) {
            assert(role == PAUSE_ROLE, 'Core roles use set_admin');
            assert(get_caller_address() == account, 'Can only renounce self');
            self.access_control._revoke_role(role, account);
        }
    }

    #[storage]
    struct Storage {
        //Randomness Request
        //Address of the VRF provider this game asks for random numbers. Set from
        //a constructor argument and changeable afterwards by the admin through
        //update_vrf_provider, so the game can be pointed at Cartridge's real
        //provider or at a testnet mock without redeploying.
        vrf_provider_contract_address: ContractAddress,
        //Game token
        //The ERC-20 that every fee, reward and treasure value in this contract is
        //denominated in. Set from a constructor argument and changeable afterwards
        //by the admin through update_game_token.
        //
        //CRITICAL: every amount below is a RAW token amount, so it is tied to this
        //token's decimals. The contract is currently configured for USDC, which has
        //6 decimals, meaning 1 USDC = 1,000,000. Pointing this at a token with
        //different decimals (ETH has 18) without also rescaling every amount would
        //silently change every fee in the game by orders of magnitude.
        game_token_contract_address: ContractAddress,
        //Fees
        gasFeeReservation: u256,
        gameMasterFee: u256,
        gameLandownerFee: u256,
        //Game
        currentGameWeek: u256,
        round_state: u8,
        round_start_ts: u64,
        round_ended_ts: u64,
        round_duration: u64,
        min_duration: u64,
        near_end_blackout: u64,
        end_buffer: u64,
        active_treasure_count: u256,
        round_initial_active_count: u256,
        round_keeper: ContractAddress,
        currentFinderFee: u256,
        currentHiderFee: u256,
        currentSpawnNewPositionFee: u256,
        //Rewards
        currentGameTokenReward: u256,
        //Main_Game: LegacyMap::<gameWeek, (listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot,
        //finderFee, hiderFee)>
        //
        //CAREFUL - the three values in this tuple do NOT all describe the same week:
        //  root      -> the treasures hidden during the PREVIOUS week, which are the
        //               ones live and findable during THIS week (hence the name)
        //  finderFee -> the rate charged for a move made DURING this week
        //  hiderFee  -> the rate charged to hide DURING this week, which funds the
        //               reward pool of the week AFTER this one
        //
        //So the money backing week K's rewards sits at main_game[K-1].hiderFee, not
        //at main_game[K].hiderFee. See _calculateRewardDue.
        main_game: LegacyMap<u256, (u256, u256, u256)>,
        //Main_Game_Grid_Size: LegacyMap::<gameWeek, (gameGridSizeX, gameGridSizeY)>
        main_game_grid_size: LegacyMap<u256, (u128, u128)>,
        //Game_totals: LegacyMap::<gameWeek, totalHiddenTreasureValue>,
        game_totals: LegacyMap<u256, u256>,
        // The net claim value attached to one share in a target round is
        // snapshotted when the funding round opens, so later configuration
        // changes cannot reprice existing claims.
        round_claim_value_per_share: LegacyMap<u256, u256>,
        //Claim_share_amounts: LegacyMap::<(gameWeek, gamerWalletAddress), totalShareCount>,
        claim_share_amounts: LegacyMap<(u256, ContractAddress), u256>,
        //Claimed_rewards: LegacyMap::<(gameWeek, gamerWalletAddress), treasureClaimed>,
        claimed_rewards: LegacyMap<(u256, ContractAddress), bool>,
        //Total_reward_shares_for_hiders: LegacyMap::<gameWeek, totalNumberOfHiders>
        total_reward_shares_for_hiders: LegacyMap<u256, u256>,
        //Total_reward_shares_for_finders: LegacyMap::<gameWeek, totalNumberOfFinders>
        total_reward_shares_for_finders: LegacyMap<u256, u256>,
        //Player_position: LegacyMap::<(gameWeek, gamerWalletAddress), (xPosition, yPosition)>
        player_position: LegacyMap<(u256, ContractAddress), (u128, u128)>,
        //Found_coordinates: LegacyMap::<(leaf, gameWeek), true>
        found_coordinates: LegacyMap<(u256, u256), bool>,
        minimumAllowance: u256,
        // ------------------------------------------------------------------
        // ROZ reward token - address (4a)
        // ------------------------------------------------------------------
        // The ERC-20 this contract pays gameplay rewards in. Held as an address
        // and reached through the ERC20 dispatcher, exactly like the game token
        // above, so the token can be swapped without a new class.
        //
        // ROZ has 18 decimals. The game token (USDC) has 6. Every ROZ amount
        // below is therefore 1e18-scaled and every USDC amount is 1e6-scaled -
        // mixing the two silently changes a value by a factor of a trillion.
        game_reward_token_contract_address: ContractAddress,
        // ------------------------------------------------------------------
        // ROZ reward rates, at full rate (4b)
        // ------------------------------------------------------------------
        // Raw 18-decimal ROZ. These replace currentGameTokenReward, which held a
        // 6-decimal USD figure only the frontend understood.
        rewardHide: u256, // 30  - paid the moment a hide succeeds
        rewardHideSurvived: u256, // 50  - paid if the treasure is still unfound
        rewardFind: u256, // 110 - the best single action in the game
        rewardParticipation: u256, // 18  - once per DAY, not per round
        rewardPerHop: u256, // 1   - the light drip that rewards exploring
        // ------------------------------------------------------------------
        // The Lightweight Gate - reduced rates (2.6)
        // ------------------------------------------------------------------
        // Absolute values, NOT multipliers. That is deliberate: an earlier
        // multiplier design let three reductions compound to 0.2 x 0.2 x 0.5 =
        // 0.02x, which handed a new light player 2% of rewards on their first
        // day. Absolute rates make that impossible - see _resolveGatedRate.
        hopRewardBelowThreshold: u256, // 0.15
        participationBelowThreshold: u256, // 0 - withdrawn, not reduced
        rewardHideBelowThreshold: u256, // 4.5
        rewardHideSurvivedBelowThreshold: u256, // 7.5
        hopRewardNewWallet: u256, // 0.5
        participationNewWallet: u256, // 9
        rewardHideNewWallet: u256, // 15
        rewardHideSurvivedNewWallet: u256, // 25
        // There is deliberately NO reduced rewardFind. A find needs somebody
        // else's hidden treasure and takes that hider's stake, so it cannot be
        // farmed in a closed loop the way hopping and hiding can. It also caps
        // the hide loop - every find is a farm hide that did not survive.
        // ------------------------------------------------------------------
        // Limits and allowances (2.2, 2.3)
        // ------------------------------------------------------------------
        participationMinimumHops: u256, // 28 - hops needed for the daily bonus
        hopRewardCap: u256, // 40 - rewarded hops per ROUND
        dailyFreeHops: u256, // 20 - deliberately BELOW 28, see below
        dailyFreeSpawns: u256, // 1
        dailySoftCapRoz: u256, // 136 - hops + participation only
        softCapMultiplierNum: u256, // 1 } 0.2x beyond the soft cap
        softCapMultiplierDen: u256, // 5 }
        newWalletSoftCapRoz: u256, // 80 - near inert, ~142 hops to bind
        // dailyFreeHops (20) MUST stay strictly below participationMinimumHops
        // (28), so the 18-ROZ bonus can never be had for free. Since 2.6 the
        // spend threshold is the primary guard and this ordering is defence in
        // depth, but breaking it would reopen a zero-cost route to the bonus.
        // ------------------------------------------------------------------
        // The Lightweight Gate - thresholds (2.6)
        // ------------------------------------------------------------------
        // Both are 6-decimal game-token amounts, NOT ROZ.
        dailySpendThreshold: u256, // 600000  = $0.60, resets daily
        lifetimeSpendThreshold: u256, // 3000000 = $3.00, permanent once passed
        // ------------------------------------------------------------------
        // Hiding - fees and limits (2.3)
        // ------------------------------------------------------------------
        // The fee is a FEE: irrecoverable, and it counts toward both spend
        // counters. currentHiderFee above is a STAKE: refundable, and it must
        // never count. Confusing the two makes the $3 lifetime gate clearable
        // for $0.2128 - 14x cheaper - and voids both gate measures.
        hideFeeBase: u256, // 200000 = $0.20, treasures 1-3 of the day
        hideFeeHigh: u256, // 250000 = $0.25, treasure 4 onward
        hideFeeTierBoundary: u256, // 3 - where the fee steps up
        dailyHideCap: u256, // 10 - treasures per wallet per calendar day
        maxTreasuresPerRound: u256, // 2840 - the round total, everyone
        // INVARIANT, asserted in the setters:
        //     hideFeeTierBoundary * hideFeeBase == dailySpendThreshold
        //     3 * 200000 == 600000
        // The first three hides of a day cost the cheap fee and land a wallet
        // exactly on the spend threshold. It is NOT dailyHideCap * hideFeeBase -
        // the cap is 10, and 10 * 200000 is 2000000. The cap bounds volume and
        // has no part in clearing the gate.
        // ------------------------------------------------------------------
        // The bulk-hide whitelist (4m-iii)
        // ------------------------------------------------------------------
        whitelistRoundCap: u256, // 250  - one whitelisted address, per round
        whitelistCollectiveCap: u256, // 1200 - ALL of them together, per round
        whitelistHourlyCap: u256, // 80   - one address, per rolling hour
        // Only ADMIN_ROLE writes this. Publishing a new root replaces the whole
        // list; there is no incremental add or remove, so the list is always
        // exactly what the published tree says. A leaf is the address as
        // felt252, hashed with Poseidon.
        whitelist_merkle_root: felt252,
        //Whitelist_round_count: LegacyMap::<(gamerWalletAddress, gameWeek), treasuresThisRound>
        whitelist_round_count: LegacyMap<(ContractAddress, u256), u256>,
        //Whitelist_round_total: LegacyMap::<gameWeek, treasuresByAllWhitelistedThisRound>
        //
        //The per-address cap does not compose: eleven addresses at 250 each
        //would take 2,750 of 2,840 and leave 90 for everybody else. This bounds
        //the group, so 1,640 slots always remain for ordinary players.
        whitelist_round_total: LegacyMap<u256, u256>,
        //Whitelist_hour_start: LegacyMap::<gamerWalletAddress, windowOpenedAt>
        whitelist_hour_start: LegacyMap<ContractAddress, u64>,
        //Whitelist_hour_count: LegacyMap::<gamerWalletAddress, treasuresInWindow>
        whitelist_hour_count: LegacyMap<ContractAddress, u256>,
        // ------------------------------------------------------------------
        // Per-round and per-day player counters (4e)
        // ------------------------------------------------------------------
        // Everything keyed by dayIndex or gameWeek self-resets as time moves on,
        // so no cleanup pass is ever needed. player_lifetime_spend is the one
        // deliberate exception - a permanent counter is the whole point of the
        // new-wallet measure.
        //Player_hops: LegacyMap::<(gameWeek, gamerWalletAddress), hopsThisRound>
        player_hops: LegacyMap<(u256, ContractAddress), u256>,
        player_last_find_hops: LegacyMap<(u256, ContractAddress), u256>,
        //Player_hops_today: LegacyMap::<(dayIndex, gamerWalletAddress), hopsToday>
        //
        //Drives the 2.5 price tiers. It MUST be keyed by day and never by round:
        //with per-round tiers a farmer re-enters the cheap band four times a
        //day, and 32 hops in each of four rounds costs $0.34 instead of $3.135.
        player_hops_today: LegacyMap<(u64, ContractAddress), u256>,
        //Player_hop_roz_today: LegacyMap::<(dayIndex, gamerWalletAddress), rozFromHopsToday>
        player_hop_roz_today: LegacyMap<(u64, ContractAddress), u256>,
        //Player_paid_participation: LegacyMap::<(dayIndex, gamerWalletAddress), alreadyPaid>
        player_paid_participation: LegacyMap<(u64, ContractAddress), bool>,
        //Player_free_hops_used: LegacyMap::<(dayIndex, gamerWalletAddress), freeHopsUsedToday>
        player_free_hops_used: LegacyMap<(u64, ContractAddress), u256>,
        //Player_free_spawns_used: LegacyMap::<(dayIndex, gamerWalletAddress), freeSpawnsUsedToday>
        player_free_spawns_used: LegacyMap<(u64, ContractAddress), u256>,
        //Player_hides_today: LegacyMap::<(dayIndex, gamerWalletAddress), treasuresToday>
        //
        //Drives BOTH the 2.3 fee tier and the Daily Volume Multiplier, so it
        //must be read BEFORE the current treasure is counted and written after.
        player_hides_today: LegacyMap<(u64, ContractAddress), u256>,
        //Player_spend_today: LegacyMap::<(dayIndex, gamerWalletAddress), spentToday>
        player_spend_today: LegacyMap<(u64, ContractAddress), u256>,
        //Player_lifetime_spend: LegacyMap::<gamerWalletAddress, spentEver>
        player_lifetime_spend: LegacyMap<ContractAddress, u256>,
        // ------------------------------------------------------------------
        // Reward accrual (4c, 4d)
        // ------------------------------------------------------------------
        //Hider_share_amounts: LegacyMap::<(gameWeek, gamerWalletAddress), survivedHideShares>
        //Finder_share_amounts: LegacyMap::<(gameWeek, gamerWalletAddress), findShares>
        //
        //claim_share_amounts above cannot tell a survived hide from a steal -
        //validate_treasure_coordinates just moves the count from one player to
        //another. Paying 50 for one and 110 for the other needs them separated.
        hider_share_amounts: LegacyMap<(u256, ContractAddress), u256>,
        finder_share_amounts: LegacyMap<(u256, ContractAddress), u256>,
        //Hider_survival_roz: LegacyMap::<(gameWeek, gamerWalletAddress), rozOwedForSurvival>
        //
        //The survival reward RESOLVED AT HIDE TIME. claim_reward credits this
        //stored amount and never re-resolves, because a claim can land days
        //later on a fresh day with that day's spend back at zero - which would
        //hand an honest player 7.5 instead of 50, and let a farmer do the
        //reverse by claiming only on days they had already cleared $0.60.
        hider_survival_roz: LegacyMap<(u256, ContractAddress), u256>,
        //Reward_token_pending: LegacyMap::<gamerWalletAddress, rozOwed>
        //
        //ROZ is ACCRUED here, never transferred per action. If the contract held
        //no ROZ and every action transferred, then hiding, moving and spawning
        //would all revert the moment the balance ran dry - the game would stop.
        //With a pending balance the game continues and only the reward pauses.
        reward_token_pending: LegacyMap<ContractAddress, u256>,
        //Reward_token_claimed: LegacyMap::<(gameWeek, gamerWalletAddress), rozLegSettled>
        //
        //Separate from claimed_rewards so a failed ROZ leg can be retried
        //without letting the USDC be claimed twice. See 4h.
        reward_token_claimed: LegacyMap<(u256, ContractAddress), bool>,
        //The sum of every reward_token_pending balance. Kept so the coverage
        //rule in 4c-i is a single read rather than a walk over every player,
        //and so the sweep in 4j can release only the surplus.
        total_reward_token_pending: u256,
        //Reward_token_missed: LegacyMap::<gamerWalletAddress, rozEarnedButRefused>
        //
        //ROZ that was EARNED and then REFUSED, because the coverage rule could
        //not cover it at the time. This is not an IOU the contract can pay right
        //now - that is reward_token_pending above - it is a record that the
        //reward is still owed once there is ROZ to pay it from.
        //
        //WITHOUT THIS A SKIPPED REWARD IS SIMPLY LOST. The skip emits an event
        //and returns, and a contract cannot read its own logs, so nothing on
        //chain remembers the amount. Only the claim leg escaped that, and not
        //because it has a retry entrypoint: its inputs (hider_survival_roz and
        //finder_share_amounts) stay in storage, so claim_reward_token_for_week
        //recalculates rather than replays. A hide or hop reward cannot be
        //recalculated later - it depended on the gate status, volume band and
        //hop counters AT THAT MOMENT, and backdating rates is forbidden
        //everywhere else in this design. Writing the number down at the time is
        //the only thing that can work.
        //
        //Same token caveat as the pending total below: these amounts are
        //denominated in whatever reward token was configured when they were
        //earned, and update_game_reward_token does not convert them.
        reward_token_missed: LegacyMap<ContractAddress, u256>,
        //The sum of every reward_token_missed balance, for the same reason
        //total_reward_token_pending exists - the sweep in 4j subtracts it, so
        //the admin cannot withdraw the backing for rewards players are still
        //owed but have not converted yet.
        total_reward_token_missed: u256,
        //The sum of every USDC a player can still claim. USDC owed is computed
        //from shares on demand and never totalled, so without this the sweep
        //has nothing to subtract and would strand outstanding claims.
        total_usdc_claimable: u256,
        // ------------------------------------------------------------------
        // Admin-settable schedules, indexed by band (2.3, 2.5)
        // ------------------------------------------------------------------
        //Hop_price_tier_limit: LegacyMap::<bandIndex, upToThisManyHopsToday>
        //Hop_price_tier_price: LegacyMap::<bandIndex, priceInGameTokenUnits>
        hop_price_tier_limit: LegacyMap<u8, u256>,
        hop_price_tier_price: LegacyMap<u8, u256>,
        //Volume_band_limit: LegacyMap::<bandIndex, upToThisManyTreasuresAlreadyToday>
        //Volume_band_num / _den: the multiplier for that band, as a fraction
        //
        //The Daily Volume Multiplier is keyed to the DAILY treasure count, not
        //to how many treasures are in the transaction. Keyed to the
        //transaction, a farmer sidesteps it by sending ten single hides instead
        //of one bulk call of ten. Keyed to the day, a bulk of N is exactly N
        //single hides, so there is nothing to route around.
        volume_band_limit: LegacyMap<u8, u256>,
        volume_band_num: LegacyMap<u8, u256>,
        volume_band_den: LegacyMap<u8, u256>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        // APPEND ONLY. These fields were added in the first upgradeable class;
        // existing game state above must never be reordered or renamed.
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        upgrade_delay: u64,
        pending_class_hash: ClassHash,
        pending_upgrade_eta: u64,
        upgrade_initialized_version: u256,
        admin_address: ContractAddress,
        pending_delay_exists: bool,
        pending_delay_value: u64,
        pending_delay_eta: u64,
        pending_admin_action: felt252,
        pending_admin_action_hash: felt252,
        pending_admin_action_eta: u64,
        // A deployment may only leave its initial paused state after all
        // scalar settings and both complete pricing schedules have been
        // installed. These fields are append-only upgrade-safe state.
        settings_initialized: bool,
        hop_bands_initialized: u8,
        volume_bands_initialized: u8,
    }

    // vrfProviderAddress is the contract this game will ask for random numbers
    // when a player spawns. It is passed in at deploy time rather than hardcoded
    // so that the same class can be deployed against different providers:
    //
    //   mainnet  -> Cartridge's real provider,
    //               0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f
    //               (the same address on Sepolia and on mainnet)
    //   sepolia  -> currently the MockVrfProvider from src/mock_vrf_provider.cairo,
    //               because Cartridge's Sepolia service is down. Switch back with
    //               update_vrf_provider once it recovers - no redeploy needed.
    //
    // gameTokenAddress is the ERC-20 the game charges fees in and pays rewards
    // from. Also passed in at deploy time so the token can be changed without a
    // new class, and changeable afterwards through update_game_token.
    //
    // ALL AMOUNTS BELOW ARE IN THE GAME TOKEN'S SMALLEST UNIT, and the values
    // written here assume USDC's 6 decimals:
    //
    //     1 USDC = 1,000,000 units      so  $1.00 = 1000000
    //                                       $0.10 =  100000
    //
    // If you deploy against a token with different decimals, every one of these
    // literals has to be rescaled to match. (They were previously written for
    // 18-decimal ETH priced at roughly $3,333.)
    //
    // rewardTokenAddress is the ROZ ERC-20 this contract accrues gameplay
    // rewards in. Deployed on its own first (phase 1), so its address is known
    // by the time this class is deployed. It can be changed afterwards through
    // update_game_reward_token, but only as a setup lever: doing it while
    // players hold pending balances strands them, because
    // total_reward_token_pending still counts IOUs denominated in the old token
    // while the coverage check reads the balance of the new one.
    //
    // ROZ HAS 18 DECIMALS AND THE GAME TOKEN HAS 6. Every reward literal below
    // is 1e18-scaled; every fee literal is 1e6-scaled. They are never mixed.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        vrfProviderAddress: ContractAddress,
        gameTokenAddress: ContractAddress,
        rewardTokenAddress: ContractAddress,
        roundKeeperAddress: ContractAddress,
        adminAddress: ContractAddress,
        pauserAddress: ContractAddress,
        upgradeDelay: u64,
    ) {
        assert(adminAddress.is_non_zero(), 'Admin address is zero');
        assert(pauserAddress.is_non_zero(), 'Pauser address is zero');
        assert(adminAddress != pauserAddress, 'Admin must differ from pauser');
        self._assert_valid_upgrade_delay(upgradeDelay);

        // Preserve the historical Ownable storage position, but make the
        // explicit admin the owner too so legacy ownership tooling agrees with
        // AccessControl from the first transaction.
        self.ownable.initializer(adminAddress);
        self.access_control.initializer();
        self.access_control.set_role_admin(PAUSE_ROLE, ADMIN_ROLE);
        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, adminAddress);
        self.access_control._grant_role(ADMIN_ROLE, adminAddress);
        self.access_control._grant_role(UPGRADE_ROLE, adminAddress);
        self.access_control._grant_role(PAUSE_ROLE, pauserAddress);
        self.admin_address.write(adminAddress);
        self.upgrade_delay.write(upgradeDelay);
        self.upgrade_initialized_version.write(MIGRATION_VERSION);

        // Previously hardcoded here. Now supplied by whoever deploys the class,
        // so testnet and mainnet can point at different providers. See the
        // comment above this constructor for the addresses involved.
        self.vrf_provider_contract_address.write(vrfProviderAddress);

        // Likewise supplied at deploy time. Currently USDC on Sepolia,
        // 0x0512feac6339ff7889822cb5aa2a86c848e9d392bb0e3e237c008674feed8343.
        self.game_token_contract_address.write(gameTokenAddress);

        // The ROZ token, deployed in phase 1 and passed in here.
        self.game_reward_token_contract_address.write(rewardTokenAddress);

        // THE REWARD SETTINGS ARE NOT SET HERE. They used to be, in
        // _initialiseRewardSettings - roughly ninety storage writes of
        // constants that ran once and then sat in the class forever, costing
        // 5,329 of the 81,920 casm felts Starknet allows a contract. Removing
        // them is what brings this class under that limit.
        //
        // So a freshly deployed contract has every configurable rate, limit,
        // fee and band at zero, and the admin must set them through set_params
        // and the indexed band entrypoint
        // before the game can be played. See "Post-deploy initialisation" in
        // ROZ_DEPLOYMENT_AND_FUNDING.md for the sequence and the one ordering
        // rule it must obey.
        //
        // To make forgetting that impossible rather than merely unlikely, the
        // contract DEPLOYS PAUSED. Hiding, hopping and start_next_round all
        // assert_not_paused, so nothing can be played until the admin has run
        // the sequence and called unpause. An unset contract would otherwise
        // hand out free hops that earn nothing, which is silent and wrong
        // rather than loud and wrong.
        self.pausable.pause();

        self.round_keeper.write(roundKeeperAddress);

        // Round zero is deliberately empty. It stages the first real set of
        // treasures and never invents hider shares or off-chain coordinates.
        self
            ._createNewGame(
                NextRoundParams {
                    merkle_root: 0,
                    grid_size_x: 14,
                    grid_size_y: 14,
                    expected_active_treasure_count: 0,
                    expected_total_hidden_value: 0,
                    hider_stake: 5000000,
                    hide_fee_base: 200000,
                    hide_fee_high: 250000,
                    hop_price_0: 5000,
                    hop_price_1: 10000,
                    hop_price_2: 20000,
                    hop_price_3: 40000,
                    spawn_fee: 1000000,
                    round_duration: 21600,
                    min_duration: 2700,
                    near_end_blackout: 720,
                    end_buffer: 180,
                },
                0,
            );
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        // #[inline(never)] IS LOAD-BEARING, not a style choice. This is called
        // from nineteen places, and the compiler inlines a body this small by
        // default - which duplicated the whole role check nineteen times and
        // cost roughly 2,500 of the 81,920 casm felts Starknet allows a class.
        // Its two siblings below are large enough that the compiler outlines
        // them on its own, which is why only this one needs the attribute.
        #[inline(never)]
        fn _assert_admin(self: @ContractState) {
            self.access_control.assert_only_role(ADMIN_ROLE);
        }

        // The key-to-storage table behind set_params. One arm per setting, and
        // this is the ONLY place a key maps to a storage field, so a renamed
        // field is a compile error here rather than a silent no-op on chain.
        fn _applyParam(ref self: ContractState, key: felt252, value: u256) {
            if key == 'rewardHide' {
                self.rewardHide.write(value);
            } else if key == 'rewardHideSurvived' {
                self.rewardHideSurvived.write(value);
            } else if key == 'rewardFind' {
                self.rewardFind.write(value);
            } else if key == 'rewardParticipation' {
                self.rewardParticipation.write(value);
            } else if key == 'rewardPerHop' {
                self.rewardPerHop.write(value);
            } else if key == 'hopRewardBelowThreshold' {
                self.hopRewardBelowThreshold.write(value);
            } else if key == 'participationBelowThreshold' {
                self.participationBelowThreshold.write(value);
            } else if key == 'rewardHideBelowThreshold' {
                self.rewardHideBelowThreshold.write(value);
            } else if key == 'hideSurvivedBelowThreshold' { // field name is 32 chars, one over the felt252 limit
                self.rewardHideSurvivedBelowThreshold.write(value);
            } else if key == 'hopRewardNewWallet' {
                self.hopRewardNewWallet.write(value);
            } else if key == 'participationNewWallet' {
                self.participationNewWallet.write(value);
            } else if key == 'rewardHideNewWallet' {
                self.rewardHideNewWallet.write(value);
            } else if key == 'rewardHideSurvivedNewWallet' {
                self.rewardHideSurvivedNewWallet.write(value);
            } else if key == 'participationMinimumHops' {
                self.participationMinimumHops.write(value);
            } else if key == 'hopRewardCap' {
                self.hopRewardCap.write(value);
            } else if key == 'dailyFreeHops' {
                self.dailyFreeHops.write(value);
            } else if key == 'dailyFreeSpawns' {
                self.dailyFreeSpawns.write(value);
            } else if key == 'dailySoftCapRoz' {
                self.dailySoftCapRoz.write(value);
            } else if key == 'softCapMultiplierNum' {
                self.softCapMultiplierNum.write(value);
            } else if key == 'softCapMultiplierDen' {
                self.softCapMultiplierDen.write(value);
            } else if key == 'newWalletSoftCapRoz' {
                self.newWalletSoftCapRoz.write(value);
            } else if key == 'dailySpendThreshold' {
                self.dailySpendThreshold.write(value);
            } else if key == 'lifetimeSpendThreshold' {
                self.lifetimeSpendThreshold.write(value);
            } else if key == 'hideFeeBase' {
                self.hideFeeBase.write(value);
            } else if key == 'hideFeeHigh' {
                self.hideFeeHigh.write(value);
            } else if key == 'hideFeeTierBoundary' {
                self.hideFeeTierBoundary.write(value);
            } else if key == 'dailyHideCap' {
                self.dailyHideCap.write(value);
            } else if key == 'maxTreasuresPerRound' {
                self.maxTreasuresPerRound.write(value);
            } else if key == 'whitelistRoundCap' {
                self.whitelistRoundCap.write(value);
            } else if key == 'whitelistCollectiveCap' {
                self.whitelistCollectiveCap.write(value);
            } else if key == 'whitelistHourlyCap' {
                self.whitelistHourlyCap.write(value);
            } else if key == 'gasFeeReservation' {
                self.gasFeeReservation.write(value);
            } else if key == 'gameMasterFee' {
                self.gameMasterFee.write(value);
            } else if key == 'gameLandownerFee' {
                self.gameLandownerFee.write(value);
            } else if key == 'minimumAllowance' {
                self.minimumAllowance.write(value);
            } else {
                // An unknown key is a typo in a deployment script. Ignoring it
                // silently would leave a setting at zero with nothing to show
                // that anything had gone wrong.
                panic!("unknown parameter key");
            }
        }

        // Every cross-field rule the twelve removed setters used to assert,
        // gathered in one place and checked over the whole configuration once a
        // batch has been applied.
        fn _assertSettingsInvariants(self: @ContractState) {
            // Free hops must run out strictly before the participation bonus
            // becomes reachable, or the bonus costs nothing to earn (2.3).
            assert(
                self.dailyFreeHops.read() < self.participationMinimumHops.read(),
                'free hops >= participation',
            );
            assert(
                self.participationMinimumHops.read() <= self.hopRewardCap.read(),
                'participation > round cap',
            );

            // A zero denominator would divide by zero in the soft cap.
            assert(self.softCapMultiplierDen.read() > 0, 'soft cap den is zero');

            // The gate invariant: the cheap hide tier must land a wallet exactly
            // on the daily spend threshold. 3 x 200000 == 600000.
            assert(
                self.hideFeeTierBoundary.read()
                    * self.hideFeeBase.read() == self.dailySpendThreshold.read(),
                'hide fee gate mismatch',
            );
            assert(self.hideFeeHigh.read() >= self.hideFeeBase.read(), 'high fee below base fee');

            // The whitelist as a group must not be able to take a whole round.
            assert(
                self.whitelistCollectiveCap.read() <= self.maxTreasuresPerRound.read(),
                'group cap above round cap',
            );
        }

        fn _assert_admin_or_default(self: @ContractState) {
            let caller = get_caller_address();
            let is_admin = self.access_control.is_role_effective(ADMIN_ROLE, caller);
            let is_default = self.access_control.is_role_effective(DEFAULT_ADMIN_ROLE, caller);
            assert(is_admin || is_default, 'Caller is not admin');
        }

        fn _assert_admin_or_upgrader(self: @ContractState) {
            let caller = get_caller_address();
            let is_admin = self.access_control.is_role_effective(ADMIN_ROLE, caller);
            let is_upgrader = self.access_control.is_role_effective(UPGRADE_ROLE, caller);
            assert(is_admin || is_upgrader, 'Caller lacks admin role');
        }

        // Testnets may deliberately use zero delay. A class that can run on
        // mainnet must always retain at least a three-day public review window.
        #[inline(never)]
        fn _assert_valid_upgrade_delay(self: @ContractState, delay: u64) {
            if get_tx_info().unbox().chain_id == 'SN_MAIN' {
                assert(delay >= MAINNET_MIN_UPGRADE_DELAY, 'Mainnet delay below 3 days');
            }
        }

        #[inline(never)]
        fn _admin_action_hash(
            self: @ContractState, action: felt252, first: felt252, second: felt252,
        ) -> felt252 {
            poseidon_hash_span(array![action, first, second].span())
        }

        fn _schedule_admin_action(
            ref self: ContractState, action: felt252, action_hash: felt252, require_paused: bool,
        ) {
            self._assert_admin();
            if require_paused {
                self.pausable.assert_paused();
            }
            assert(self.pending_admin_action.read() == 0, 'Admin action already pending');
            let eta = get_block_timestamp() + self.upgrade_delay.read();
            self.pending_admin_action.write(action);
            self.pending_admin_action_hash.write(action_hash);
            self.pending_admin_action_eta.write(eta);
            self.emit(AdminActionProposed { action, action_hash, eta });
        }

        fn _consume_admin_action(
            ref self: ContractState, action: felt252, action_hash: felt252, require_paused: bool,
        ) {
            self._assert_admin();
            if require_paused {
                self.pausable.assert_paused();
            }
            assert(self.pending_admin_action.read() == action, 'Wrong admin action');
            assert(
                self.pending_admin_action_hash.read() == action_hash,
                'Admin action arguments changed',
            );
            assert(
                get_block_timestamp() >= self.pending_admin_action_eta.read(),
                'Admin action delay not elapsed',
            );
            self._clear_admin_action();
            self.emit(AdminActionExecuted { action, action_hash });
        }

        fn _clear_admin_action(ref self: ContractState) {
            self.pending_admin_action.write(0);
            self.pending_admin_action_hash.write(0);
            self.pending_admin_action_eta.write(0);
        }

        // The calendar day, as whole days since the Unix epoch.
        //
        // Every daily counter in this contract is keyed by this value, which is
        // what makes them self-resetting: a new day is simply a new storage key,
        // so nothing has to be cleared and no cleanup pass is ever needed. The
        // day rolls at 00:00 UTC.
        //
        // This is deliberately NOT keyed by round. The 2.5 price tiers in
        // particular must reset daily and never per round - with per-round tiers
        // a farmer re-enters the cheap band four times a day, and 32 hops in
        // each of four rounds costs $0.34 instead of $3.135.
        #[inline(never)]
        fn _currentDayIndex(self: @ContractState) -> u64 {
            return get_block_timestamp() / 86400;
        }

        // ------------------------------------------------------------------
        // The bulk-hide whitelist (4m-iii)
        // ------------------------------------------------------------------
        //
        // Is this caller in the published whitelist tree?
        //
        // A ROOT rather than a mapping, because a mapping costs one storage
        // write per address and one transaction per change; a root is a single
        // felt252 and the list lives off-chain. Adding fifty addresses costs one
        // setter call.
        //
        // FAILING VERIFICATION IS THE NORMAL PATH, not an error. Almost every
        // caller is not whitelisted, passes an empty proof, and simply falls
        // back to the ordinary daily cap.
        fn _verifyWhitelist(
            self: @ContractState, caller: ContractAddress, proof: Array<felt252>, leafIndex: u32,
        ) -> bool {
            let root: felt252 = self.whitelist_merkle_root.read();

            // No root published yet, so nobody is whitelisted. The correct
            // starting state.
            if (root == 0) {
                return false;
            }

            // The leaf is the caller's address as felt252 and nothing more - not
            // the address plus a limit, not a hash of it. The off-chain tooling
            // builds it the same way, and the two must agree exactly or every
            // proof fails.
            let mut computedHash: felt252 = caller.into();
            let mut index: u32 = leafIndex;
            let mut i: u32 = 0;

            loop {
                if (i >= proof.len()) {
                    break;
                }

                let sibling: felt252 = *proof.at(i);

                // The low bit of the index says which side this node sits on.
                // Getting it backwards produces a valid-looking hash that never
                // matches the root, so a genuinely whitelisted caller would
                // silently drop back to the daily cap - which is why the wrong
                // index is the likeliest tooling mistake and the one worth
                // testing for explicitly.
                if (index % 2 == 0) {
                    computedHash = PoseidonTrait::new()
                        .update(computedHash)
                        .update(sibling)
                        .finalize();
                } else {
                    computedHash = PoseidonTrait::new()
                        .update(sibling)
                        .update(computedHash)
                        .finalize();
                }

                index = index / 2;
                i = i + 1;
            }

            return computedHash == root;
        }

        // The three limits a whitelisted address answers to, in place of the
        // ordinary daily cap. Checked personal, then group.
        fn _enforceWhitelistLimits(
            ref self: ContractState, caller: ContractAddress, gameWeek: u256, treasureCount: u256,
        ) {
            // 1. Per address, per round. Stops one whitelisted address taking
            //    the whole round - 250 is 8.8% of 2,840.
            let roundCount: u256 = self.whitelist_round_count.read((caller, gameWeek));

            assert(
                roundCount + treasureCount <= self.whitelistRoundCap.read(), 'whitelist round cap',
            );

            // 2. Per address, per rolling hour. A plain resetting bucket rather
            //    than a true sliding window - cheaper, and adequate: two full
            //    batches CAN land a second apart across a boundary, but the
            //    round cap above still holds and that is what protects the
            //    round. Its job is only to stop an address dumping its whole
            //    round allowance in the opening minutes.
            let now: u64 = get_block_timestamp();
            let mut windowStart: u64 = self.whitelist_hour_start.read(caller);
            let mut windowCount: u256 = self.whitelist_hour_count.read(caller);

            if (now >= windowStart + 3600) {
                windowStart = now;
                windowCount = 0;
            }

            assert(
                windowCount + treasureCount <= self.whitelistHourlyCap.read(),
                'whitelist hourly limit',
            );

            // 3. Across ALL whitelisted addresses, per round. The per-address
            //    cap does not compose: eleven addresses at 250 each would take
            //    2,750 of 2,840 and leave 90 for everybody else. This bounds the
            //    group, so 1,640 slots always remain for ordinary players
            //    whatever the list length. It first binds at five addresses.
            let groupSoFar: u256 = self.whitelist_round_total.read(gameWeek);

            assert(
                groupSoFar + treasureCount <= self.whitelistCollectiveCap.read(),
                'whitelist group cap',
            );

            self.whitelist_round_count.write((caller, gameWeek), roundCount + treasureCount);
            self.whitelist_hour_start.write(caller, windowStart);
            self.whitelist_hour_count.write(caller, windowCount + treasureCount);
            self.whitelist_round_total.write(gameWeek, groupSoFar + treasureCount);
        }

        // The 2.5 tier price for a given hop number OF THE DAY.
        //
        // Progressive pricing: a hop costs more the more a wallet has already
        // hopped today. Light play gets cheaper than the old flat rate and
        // grinding gets dearer, with the crossover around 47 hops a day.
        //
        // The hop number passed in is the DAILY count, never the per-round one.
        // That is the single most important property of this schedule.
        fn _hopPriceForHopNumber(self: @ContractState, hopNumberToday: u256) -> u256 {
            let mut bandIndex: u8 = 0;

            loop {
                // Four bands, 0 through 3, the last open-ended.
                if (bandIndex > 3) {
                    break self.hop_price_tier_price.read(3);
                }

                if (hopNumberToday <= self.hop_price_tier_limit.read(bandIndex)) {
                    break self.hop_price_tier_price.read(bandIndex);
                }

                bandIndex = bandIndex + 1;
            }
        }

        // Add an irrecoverable payment to both spend counters (2.6 rule 1).
        //
        // ONLY MONEY THE PLAYER CANNOT GET BACK REACHES THIS FUNCTION: hop fees,
        // spawn fees, the hide FEE, and the 12,833 units retained on a claim.
        //
        // NEVER the $5 hide stake. The stake is refundable - a surviving hider
        // claims back 4,987,167 of it - so counting it would let a farmer clear
        // the whole $3 lifetime gate for the $0.2128 a surviving hide really
        // costs, 14x cheaper, and both gate measures would be void.
        fn _recordSpend(
            ref self: ContractState, gamerWalletAddress: ContractAddress, amount: u256,
        ) {
            if (amount == 0) {
                return;
            }

            let dayIndex: u64 = self._currentDayIndex();

            let spentToday: u256 = self.player_spend_today.read((dayIndex, gamerWalletAddress));
            self.player_spend_today.write((dayIndex, gamerWalletAddress), spentToday + amount);

            let spentEver: u256 = self.player_lifetime_spend.read(gamerWalletAddress);
            self.player_lifetime_spend.write(gamerWalletAddress, spentEver + amount);
        }

        // Credit the daily participation bonus if this wallet now qualifies.
        //
        // CALLED ON EVERY HOP, and it must be. The bonus needs BOTH conditions
        // to hold - 28 hops today AND dailySpendThreshold spent today - and they
        // are not reached in a fixed order. The modelled typical casual passes
        // hop 28 with only $0.145 spent, so a version that credits at hop 28 and
        // never looks again would deny that player the bonus entirely. It pays
        // once per calendar day, so the miss would be silent and permanent.
        fn _creditParticipationIfDue(ref self: ContractState, gamerWalletAddress: ContractAddress) {
            let dayIndex: u64 = self._currentDayIndex();

            // Once a day, not once a round. At four rounds a day, paying it per
            // round made participation the single biggest contributor to farm
            // yield.
            if (self.player_paid_participation.read((dayIndex, gamerWalletAddress))) {
                return;
            }

            let hopsToday: u256 = self.player_hops_today.read((dayIndex, gamerWalletAddress));

            if (hopsToday < self.participationMinimumHops.read()) {
                return;
            }

            let participationRate: u256 = self
                ._resolveGatedRate(
                    gamerWalletAddress,
                    self.rewardParticipation.read(),
                    self.participationNewWallet.read(),
                    self.participationBelowThreshold.read(),
                );

            // Below the spend threshold the bonus is WITHDRAWN, not reduced -
            // participationBelowThreshold is 0. Leave the flag unset so the
            // player can still earn it later the same day if their spend
            // crosses.
            if (participationRate == 0) {
                return;
            }

            let payableParticipation: u256 = self
                ._applyHopSoftCap(gamerWalletAddress, participationRate);

            self.player_paid_participation.write((dayIndex, gamerWalletAddress), true);

            self._accrueRewardToken(gamerWalletAddress, payableParticipation, 'participation');
        }

        // ------------------------------------------------------------------
        // Rate resolution - the Lightweight Gate (2.6 rule 2, 4f)
        // ------------------------------------------------------------------
        //
        // Resolve one reward line to the rate this wallet actually earns.
        //
        // TWO STATUSES CAN HOLD AT ONCE - a new wallet that has also not yet
        // spent $0.60 today - and their rates disagree. The rule is:
        //
        //     take the LOWEST applicable value, for each line independently.
        //
        // Never the product. An earlier multiplier design let the reductions
        // compound to 0.2 x 0.2 x 0.5 = 0.02x, handing a new light player 2% of
        // rewards on their first day. Taking a minimum makes that impossible by
        // construction: a new wallet below the threshold earns the
        // below-threshold rate, not that rate scaled again by the new-wallet
        // one.
        //
        // WORKED, because it is easy to get wrong. Per hop, for a new wallet
        // that is also below the daily threshold:
        //
        //     correct:               0.15e18   (the lower of 0.5 and 0.15)
        //     wrong, new-wallet only: 0.5e18
        //     wrong, multiplied:     0.075e18  (0.5 x 0.15)
        //
        // Note the correct answer, 0.15, is also what an OLD multiplier scheme
        // produced from 0.5 x 0.3 - so it looks exactly like the bug this design
        // removes. Always compare against the stored setting, never against a
        // remembered figure.
        //
        // This applies NO multiplier. The caller applies the single multiplier
        // its line is entitled to - the soft cap for hops and participation, the
        // Daily Volume Multiplier for hides, and nothing at all for find/steal.
        // No reward line ever receives two.
        fn _resolveGatedRate(
            self: @ContractState,
            gamerWalletAddress: ContractAddress,
            fullRate: u256,
            newWalletRate: u256,
            belowThresholdRate: u256,
        ) -> u256 {
            let dayIndex: u64 = self._currentDayIndex();
            let mut resolvedRate: u256 = fullRate;

            // Step 2 - new-wallet status, until lifetimeSpendThreshold is passed.
            let lifetimeSpend: u256 = self.player_lifetime_spend.read(gamerWalletAddress);

            if (lifetimeSpend < self.lifetimeSpendThreshold.read()) {
                if (newWalletRate < resolvedRate) {
                    resolvedRate = newWalletRate;
                }
            }

            // Step 3 - below the daily spend threshold. Read AFTER the fee for
            // the current action has been added to the counter, which is what
            // makes the action that crosses the threshold itself pay the full
            // rate: the 65th hop, or the third hide of the day.
            let spendToday: u256 = self.player_spend_today.read((dayIndex, gamerWalletAddress));

            if (spendToday < self.dailySpendThreshold.read()) {
                if (belowThresholdRate < resolvedRate) {
                    resolvedRate = belowThresholdRate;
                }
            }

            return resolvedRate;
        }

        // The Daily Volume Multiplier band for the NEXT treasure this wallet
        // creates, given how many it has already created today (2.3).
        //
        // Keyed to the DAILY count, never to how many treasures are in the
        // transaction. That distinction is the whole design: keyed to the
        // transaction, a farmer sidesteps the curve entirely by sending ten
        // single hides instead of one bulk call of ten. Keyed to the day, a bulk
        // of N is arithmetically identical to N single hides, so there is
        // nothing to route around and no reason to prefer either shape.
        //
        // Returns (numerator, denominator). Bands are read in order and the last
        // one is open-ended, so this always returns a usable fraction.
        fn _volumeMultiplier(self: @ContractState, alreadyCreatedToday: u256) -> (u256, u256) {
            let mut bandIndex: u8 = 0;

            loop {
                // Six bands, 0 through 5. The guard is a safety net: the last
                // band is stored open-ended, so the comparison below should
                // always match before the index runs out.
                if (bandIndex > 5) {
                    break (1, 1);
                }

                let bandLimit: u256 = self.volume_band_limit.read(bandIndex);

                if (alreadyCreatedToday <= bandLimit) {
                    let num: u256 = self.volume_band_num.read(bandIndex);
                    let den: u256 = self.volume_band_den.read(bandIndex);

                    // A den of zero means the band was never initialised. Fall
                    // back to full rate rather than dividing by zero - being
                    // generous is the safe direction for a misconfiguration,
                    // because the alternative reverts a player's action.
                    if (den == 0) {
                        break (1, 1);
                    }

                    break (num, den);
                }

                bandIndex = bandIndex + 1;
            }
        }

        // Apply the daily soft cap to a hop or participation credit (2.5).
        //
        // Beyond dailySoftCapRoz the remainder is multiplied down by
        // softCapMultiplier (0.2x). This is the ONLY multiplier hops and
        // participation ever see - they never touch the volume multiplier, which
        // belongs to hides.
        //
        // The cap is set to 136, just under the 137.2 raw ROZ a 160-hop day can
        // reach when four spawns are taken before hopping. In practice it binds
        // only that bought-crossing route. An honest active player reaches
        // about 96.7 and never meets it at all. That is deliberate: it
        // is a backstop against one shape of farm, not a brake on real play.
        fn _applyHopSoftCap(
            ref self: ContractState, gamerWalletAddress: ContractAddress, amount: u256,
        ) -> u256 {
            let dayIndex: u64 = self._currentDayIndex();
            let earnedToday: u256 = self.player_hop_roz_today.read((dayIndex, gamerWalletAddress));

            // New wallets carry a lower cap of their own. Take whichever binds
            // first - the same "lowest applicable value" rule as the rates.
            let mut capForThisWallet: u256 = self.dailySoftCapRoz.read();
            let lifetimeSpend: u256 = self.player_lifetime_spend.read(gamerWalletAddress);

            if (lifetimeSpend < self.lifetimeSpendThreshold.read()) {
                let newWalletCap: u256 = self.newWalletSoftCapRoz.read();
                if (newWalletCap < capForThisWallet) {
                    capForThisWallet = newWalletCap;
                }
            }

            // Entirely under the cap - the common case, and nothing to do.
            if (earnedToday + amount <= capForThisWallet) {
                self
                    .player_hop_roz_today
                    .write((dayIndex, gamerWalletAddress), earnedToday + amount);
                return amount;
            }

            let num: u256 = self.softCapMultiplierNum.read();
            let den: u256 = self.softCapMultiplierDen.read();

            if (den == 0) {
                self
                    .player_hop_roz_today
                    .write((dayIndex, gamerWalletAddress), earnedToday + amount);
                return amount;
            }

            // Already fully past the cap - the whole credit is scaled down.
            if (earnedToday >= capForThisWallet) {
                let scaled: u256 = (amount * num) / den;
                self
                    .player_hop_roz_today
                    .write((dayIndex, gamerWalletAddress), earnedToday + amount);
                return scaled;
            }

            // Straddling the cap. Pay the part below it in full and scale only
            // the remainder, so crossing the line does not retroactively reduce
            // what was already earned under it.
            let underCap: u256 = capForThisWallet - earnedToday;
            let overCap: u256 = amount - underCap;
            let scaledRemainder: u256 = (overCap * num) / den;

            self.player_hop_roz_today.write((dayIndex, gamerWalletAddress), earnedToday + amount);

            return underCap + scaledRemainder;
        }

        // Write down a reward that was earned and then refused.
        //
        // Called from both skip paths in _accrueRewardToken below, which is the
        // single choke point every reward passes through - hide, hop,
        // participation and claim alike. Recording here is what makes all four
        // recoverable without any of them being touched, and it is why a skip
        // stopped meaning "lost".
        //
        // This does NOT make the amount payable. It cannot: the whole reason it
        // was skipped is that the contract could not cover it. It becomes
        // payable when the player calls claim_missed_reward_token after the
        // contract is funded, which is the only place this map is reduced.
        fn _recordMissedRewardToken(
            ref self: ContractState, gamerWalletAddress: ContractAddress, amount: u256,
        ) {
            let missedSoFar: u256 = self.reward_token_missed.read(gamerWalletAddress);

            self.reward_token_missed.write(gamerWalletAddress, missedSoFar + amount);

            let totalMissed: u256 = self.total_reward_token_missed.read();

            self.total_reward_token_missed.write(totalMissed + amount);
        }

        // Credit ROZ to a player's pending balance. NEVER transfers.
        //
        // This is the single most important design decision in the reward
        // system. If every rewarded action transferred ROZ directly, then the
        // moment the contract's balance ran dry, hiding, moving and spawning
        // would all start reverting - the game itself would stop because a
        // REWARD ran out. Accruing to a balance means an unfunded contract still
        // plays perfectly; only the reward pauses, and it resumes the moment
        // somebody tops the contract up.
        //
        // THE COVERAGE RULE (4c-i). A credit is only made if the contract can
        // still honour every pending balance afterwards:
        //
        //     total_reward_token_pending + amount <= ROZ balance of this contract
        //
        // That invariant is what lets claim_reward_tokens be written without any
        // failure path: if the sum of all IOUs never exceeds the balance, a
        // claim can always be paid. When the rule would be broken the credit is
        // SKIPPED, not reverted, and an event is emitted - the caller's gameplay
        // action still succeeds.
        //
        // Returns true if the ROZ landed, false if it was skipped. The five
        // gameplay rewards ignore this and simply come round again next round;
        // only the claim leg in 4h records it, because a claim happens once.
        fn _accrueRewardToken(
            ref self: ContractState,
            gamerWalletAddress: ContractAddress,
            amount: u256,
            reason: felt252,
        ) -> bool {
            // Crediting zero is not an error - it is the normal outcome for a
            // withdrawn participation bonus, or a hide by a wallet whose volume
            // multiplier has rounded its reward away. Take the cheap exit.
            if (amount == 0) {
                return true;
            }

            let rewardTokenAddress: ContractAddress = self
                .game_reward_token_contract_address
                .read();

            // No reward token configured yet. Skip rather than revert, for the
            // same reason as an uncovered credit: gameplay must not depend on
            // reward plumbing being finished.
            if (rewardTokenAddress.is_zero()) {
                self._recordMissedRewardToken(gamerWalletAddress, amount);
                self
                    .emit(
                        Event::RewardTokenAccrualSkipped(
                            RewardTokenAccrualSkipped {
                                user: gamerWalletAddress, amount: amount, reason: reason,
                            },
                        ),
                    );
                return false;
            }

            // Read the live balance rather than tracking a funded budget in
            // storage. A tracked budget drifts from the truth the moment anybody
            // transfers ROZ in directly - which is exactly how funding happens,
            // since the token has no mint and tranches arrive as plain
            // transfers. This costs one external call per rewarded action, and
            // that is the honest price of not being wrong.
            let reward_token_dispatcher = ERC20ABIDispatcher {
                contract_address: rewardTokenAddress,
            };
            let heldBalance: u256 = reward_token_dispatcher.balance_of(get_contract_address());
            let alreadyOwed: u256 = self.total_reward_token_pending.read();

            if (alreadyOwed + amount > heldBalance) {
                self._recordMissedRewardToken(gamerWalletAddress, amount);
                self
                    .emit(
                        Event::RewardTokenAccrualSkipped(
                            RewardTokenAccrualSkipped {
                                user: gamerWalletAddress, amount: amount, reason: reason,
                            },
                        ),
                    );
                return false;
            }

            let currentlyPending: u256 = self.reward_token_pending.read(gamerWalletAddress);

            self.reward_token_pending.write(gamerWalletAddress, currentlyPending + amount);
            self.total_reward_token_pending.write(alreadyOwed + amount);

            self
                .emit(
                    Event::RewardTokenAccrued(
                        RewardTokenAccrued {
                            user: gamerWalletAddress, amount: amount, reason: reason,
                        },
                    ),
                );

            return true;
        }

        fn _receive_random_words_2(
            ref self: ContractState, requester_address: ContractAddress, random_words: felt252,
        ) {
            let gameWeek = self.currentGameWeek.read();

            let random_word_0: felt252 = random_words;

            let random_word_0_AsNumber: u256 = random_word_0.try_into().unwrap();

            let random_word_0_AsNumber_A: u128 = random_word_0_AsNumber.high;
            let random_word_0_AsNumber_B: u128 = random_word_0_AsNumber.low;

            let (maxGridX, maxGridY) = self.main_game_grid_size.read(gameWeek);

            // let reducedNumberXCoordinate: u128 = (random_word_0_AsNumber_A - 1_u128) % maxGridX
            //     + 1_u128;

            // let reducedNumberYCoordinate: u128 = (random_word_0_AsNumber_B - 1_u128) % maxGridY
            //     + 1_u128;

            let reducedNumberXCoordinate: u128 = (random_word_0_AsNumber_A % maxGridX) + 1_u128;

            let reducedNumberYCoordinate: u128 = (random_word_0_AsNumber_B % maxGridY) + 1_u128;

            self
                ._updatePlayerPosition(
                    reducedNumberXCoordinate, reducedNumberYCoordinate, requester_address, gameWeek,
                );
        }

        fn _checkForTreasure(
            ref self: ContractState,
            gamerWalletAddress: ContractAddress,
            xCoordinate: u128,
            yCoordinate: u128,
            gameWeek: u256,
        ) -> bool {
            self
                .emit(
                    CheckForTreasure {
                        user: gamerWalletAddress,
                        xCoordinate: xCoordinate,
                        yCoordinate: yCoordinate,
                        gameWeek: gameWeek,
                        hopCount: self.player_hops.read((gameWeek, gamerWalletAddress)),
                    },
                );

            true
        }

        fn _verify(self: @ContractState, _root: u256, _leaf: u256, _proof: Array<u256>) -> bool {
            let mut computed_hash: u256 = _leaf;
            let proofLength: u32 = _proof.len();

            let mut i: u32 = 0;

            loop {
                // A one-leaf Merkle tree has an empty proof. Comparing the
                // cursor directly also avoids underflowing `proofLength - 1`.
                if i >= proofLength {
                    break;
                }

                let mut proofElement: u256 = *_proof.at(i);

                if (computed_hash <= proofElement) {
                    computed_hash = self._keccak256(computed_hash, proofElement);
                } else {
                    computed_hash = self._keccak256(proofElement, computed_hash);
                }
                i += 1;
            }

            if (computed_hash == _root) {
                true
            } else {
                false
            }
        }

        #[inline(never)]
        fn _keccak256(self: @ContractState, a: u256, b: u256) -> u256 {
            let res: u256 = keccak::keccak_u256s_be_inputs(array![a, b].span());
            //reverse_endianness
            let new_value_2: u256 = u256 {
                low: u128_byte_reverse(res.high), high: u128_byte_reverse(res.low),
            };
            return new_value_2;
        }

        fn _validateNextRoundParams(self: @ContractState, params: NextRoundParams) {
            let claimDeductions: u256 = self.gasFeeReservation.read()
                + self.gameMasterFee.read()
                + self.gameLandownerFee.read();
            assert(params.grid_size_x >= 14 && params.grid_size_x <= 600, 'invalid grid x');
            assert(params.grid_size_y >= 14 && params.grid_size_y <= 600, 'invalid grid y');
            assert(
                params.expected_active_treasure_count <= self.maxTreasuresPerRound.read(),
                'too many active treasures',
            );
            assert(
                params.hider_stake > claimDeductions && params.hider_stake <= 50000000,
                'invalid stake',
            );
            assert(params.hide_fee_base <= 2000000, 'hide base too high');
            assert(params.hide_fee_high <= 2500000, 'hide high too high');
            assert(params.hop_price_0 <= 50000, 'hop price 0 too high');
            assert(params.hop_price_1 <= 100000, 'hop price 1 too high');
            assert(params.hop_price_2 <= 200000, 'hop price 2 too high');
            assert(params.hop_price_3 <= 400000, 'hop price 3 too high');
            assert(params.spawn_fee <= 10000000, 'spawn fee too high');
            assert(
                params.round_duration >= 3600 && params.round_duration <= 86400,
                'invalid round duration',
            );
            assert(params.min_duration < params.round_duration, 'invalid min duration');
            assert(params.near_end_blackout < params.round_duration, 'invalid end blackout');
            assert(
                params.min_duration + params.near_end_blackout < params.round_duration,
                'timing windows overlap',
            );
            assert(params.end_buffer <= 3600, 'end buffer too high');
        }

        fn _assertRoundAcceptsActions(self: @ContractState) {
            self.pausable.assert_not_paused();
            assert(self.round_state.read() == ROUND_OPEN, 'round not open');
            assert(get_block_timestamp() >= self.round_start_ts.read(), 'round not started');
            assert(
                get_block_timestamp() < self.round_start_ts.read() + self.round_duration.read(),
                'round action window closed',
            );
        }

        // Hides fund currentGameWeek + 1 rather than the round being searched.
        // Once a round ends below the next-round minimum, searching stays
        // closed but hiding must remain available or the game can never recover.
        fn _assertHidingAllowed(self: @ContractState) {
            self.pausable.assert_not_paused();
            let state = self.round_state.read();
            assert(state == ROUND_OPEN || state == ROUND_ENDING, 'hiding unavailable');
            assert(get_block_timestamp() >= self.round_start_ts.read(), 'round not started');
        }

        fn _endRound(ref self: ContractState, reason: u8) -> bool {
            if (self.round_state.read() != ROUND_OPEN) {
                return false;
            }

            let endedTs: u64 = get_block_timestamp();
            let initial: u256 = self.round_initial_active_count.read();
            let survived: u256 = self.active_treasure_count.read();
            self.round_state.write(ROUND_ENDING);
            self.round_ended_ts.write(endedTs);
            self
                .emit(
                    Event::RoundEnded(
                        RoundEnded {
                            roundId: self.currentGameWeek.read(),
                            endedTs,
                            reason,
                            initialTreasureCount: initial,
                            treasuresFound: initial - survived,
                            treasuresSurvived: survived,
                        },
                    ),
                );
            true
        }

        fn _createNewGame(
            ref self: ContractState, params: NextRoundParams, gameWeek: u256,
        ) -> bool {
            self._validateNextRoundParams(params);

            let startTs: u64 = get_block_timestamp();
            let deductions: u256 = self.gasFeeReservation.read()
                + self.gameMasterFee.read()
                + self.gameLandownerFee.read();

            self.currentGameWeek.write(gameWeek);
            self.round_state.write(ROUND_OPEN);
            self.round_start_ts.write(startTs);
            self.round_ended_ts.write(0);
            self.round_duration.write(params.round_duration);
            self.min_duration.write(params.min_duration);
            self.near_end_blackout.write(params.near_end_blackout);
            self.end_buffer.write(params.end_buffer);
            self.active_treasure_count.write(params.expected_active_treasure_count);
            self.round_initial_active_count.write(params.expected_active_treasure_count);
            self.currentFinderFee.write(0);
            self.currentHiderFee.write(params.hider_stake);
            self.currentSpawnNewPositionFee.write(params.spawn_fee);

            self.main_game.write(gameWeek, (params.merkle_root, 0, params.hider_stake));
            self.main_game_grid_size.write(gameWeek, (params.grid_size_x, params.grid_size_y));

            // Snapshot next round's claim value while its treasures are funded.
            self.round_claim_value_per_share.write(gameWeek + 1, params.hider_stake - deductions);

            self.hideFeeBase.write(params.hide_fee_base);
            self.hideFeeHigh.write(params.hide_fee_high);
            self.hideFeeTierBoundary.write(3);
            self.dailySpendThreshold.write(params.hide_fee_base * 3);
            self.hop_price_tier_price.write(0, params.hop_price_0);
            self.hop_price_tier_price.write(1, params.hop_price_1);
            self.hop_price_tier_price.write(2, params.hop_price_2);
            self.hop_price_tier_price.write(3, params.hop_price_3);

            self
                .emit(
                    Event::RoundStarted(
                        RoundStarted {
                            roundId: gameWeek,
                            startTs,
                            scheduledEndTs: startTs + params.round_duration,
                            roundDuration: params.round_duration,
                            minDuration: params.min_duration,
                            nearEndBlackout: params.near_end_blackout,
                            endBuffer: params.end_buffer,
                            merkleRoot: params.merkle_root,
                            gridSizeX: params.grid_size_x,
                            gridSizeY: params.grid_size_y,
                            activeTreasureCount: params.expected_active_treasure_count,
                            totalHiddenValue: params.expected_total_hidden_value,
                            hiderStake: params.hider_stake,
                            hideFeeBase: params.hide_fee_base,
                            hideFeeHigh: params.hide_fee_high,
                            hopPrice0: params.hop_price_0,
                            hopPrice1: params.hop_price_1,
                            hopPrice2: params.hop_price_2,
                            hopPrice3: params.hop_price_3,
                            spawnFee: params.spawn_fee,
                        },
                    ),
                );

            return true;
        }

        // Hide one or more treasures. The single and bulk entrypoints both come
        // through here with different treasureCounts, which is what GUARANTEES
        // they are equivalent rather than merely intended to be.
        //
        // That equivalence is load-bearing. The fee tier and the Daily Volume
        // Multiplier are both read from player_hides_today as it advances
        // treasure by treasure inside the loop, so a bulk of N costs and earns
        // exactly what N single hides would. If bulk were cheaper a farmer would
        // batch; if it were dearer they would split. Neither is worth doing.
        fn _hideTreasure(
            ref self: ContractState,
            caller: ContractAddress,
            treasureCount: u256,
            merkleProof: Array<felt252>,
            leafIndex: u32,
        ) -> bool {
            self._assertHidingAllowed();
            assert(treasureCount > 0, 'treasure count is zero');

            let myContract: ContractAddress = get_contract_address();
            let stakePerTreasure: u256 = self.currentHiderFee.read();
            let dayIndex: u64 = self._currentDayIndex();

            //hide treasure for the week upcoming
            let gameWeek = self.currentGameWeek.read() + 1_u256;

            let hidesToday: u256 = self.player_hides_today.read((dayIndex, caller));

            // --- Limits, checked personal first, then group, then global ---
            //
            // The order gives three DIFFERENT errors, and that matters: a
            // whitelisted address that has spent its own allowance must not be
            // told the round is full, and one stopped by the group cap must not
            // think it hit its own limit.
            let isWhitelisted: bool = self._verifyWhitelist(caller, merkleProof, leafIndex);

            if (isWhitelisted) {
                self._enforceWhitelistLimits(caller, gameWeek, treasureCount);
            } else {
                // Counts TREASURES, not calls, so a bulk hide is bounded
                // exactly as the same number of single hides would be.
                assert(hidesToday + treasureCount <= self.dailyHideCap.read(), 'daily hide cap');
            }

            // The only limit that binds the aggregate across every wallet,
            // whitelisted or not. A hard safety bound on the ROUND, and NOT a
            // grid check - the grid for this round does not exist yet, so any
            // read of it would return zero and revert every hide.
            let alreadyHidden: u256 = self.total_reward_shares_for_hiders.read(gameWeek);

            assert(
                alreadyHidden + treasureCount <= self.maxTreasuresPerRound.read(),
                'round treasure cap',
            );

            // --- Take the stake, in one transfer ---
            //
            // THE STAKE IS NOT A FEE. It is returned in full if the treasure
            // survives, less the 12,833 units retained on claim, so it MUST NOT
            // reach the spend counters. Only the per-treasure fee below does.
            let totalStake: u256 = stakePerTreasure * treasureCount;

            let stakeTransferResult: bool = self
                ._transfer_token_from(caller, myContract, totalStake);

            assert(stakeTransferResult == true, 'game token not transferred');

            // Only the snapshotted NET payout is owed to players. The per-share
            // deductions are revenue immediately, so reserving the gross stake
            // here would permanently make them unsweepable.
            let claimValuePerShare: u256 = self.round_claim_value_per_share.read(gameWeek);
            assert(claimValuePerShare > 0, 'claim value not configured');
            let claimableSoFar: u256 = self.total_usdc_claimable.read();
            self.total_usdc_claimable.write(claimableSoFar + claimValuePerShare * treasureCount);

            // --- Per treasure: fee, then reward, in that order ---
            let mut treasuresPlaced: u256 = 0;
            let mut totalFeeCharged: u256 = 0;
            let mut survivalRozAccumulated: u256 = 0;

            loop {
                if (treasuresPlaced == treasureCount) {
                    break;
                }

                // The count BEFORE this treasure. Both the fee tier and the
                // volume band are read from it, so treasure 1 of the day sees 0.
                let alreadyToday: u256 = hidesToday + treasuresPlaced;

                // Fee tier: the cheap fee for the first hideFeeTierBoundary
                // treasures of the day, the higher one after.
                let feeForThisTreasure: u256 = if (alreadyToday < self.hideFeeTierBoundary.read()) {
                    self.hideFeeBase.read()
                } else {
                    self.hideFeeHigh.read()
                };

                let feeTransferResult: bool = self
                    ._transfer_token_from(caller, myContract, feeForThisTreasure);

                assert(feeTransferResult == true, 'hide fee not transferred');

                // CHARGE BEFORE RESOLVING. This is what makes the third hide of
                // a day - the one that takes spend to exactly $0.60 - pay the
                // full 30 rather than 4.5.
                self._recordSpend(caller, feeForThisTreasure);
                totalFeeCharged = totalFeeCharged + feeForThisTreasure;

                // Now the rates, with the spend counter already current.
                let instantRate: u256 = self
                    ._resolveGatedRate(
                        caller,
                        self.rewardHide.read(),
                        self.rewardHideNewWallet.read(),
                        self.rewardHideBelowThreshold.read(),
                    );
                let survivalRate: u256 = self
                    ._resolveGatedRate(
                        caller,
                        self.rewardHideSurvived.read(),
                        self.rewardHideSurvivedNewWallet.read(),
                        self.rewardHideSurvivedBelowThreshold.read(),
                    );

                // The Daily Volume Multiplier is the ONE multiplier a hide
                // receives. Hides never touch the soft cap, which belongs to
                // hops and participation, so no line ever gets two.
                let (volNum, volDen) = self._volumeMultiplier(alreadyToday);

                let payableInstant: u256 = (instantRate * volNum) / volDen;
                let payableSurvival: u256 = (survivalRate * volNum) / volDen;

                self._accrueRewardToken(caller, payableInstant, 'hide');

                // The survival reward is RESOLVED NOW and stored, not resolved
                // at claim time. A claim can land days later on a fresh day with
                // that day's spend back at zero, which would hand an honest
                // player 7.5 instead of 50 - and let a farmer do the reverse by
                // claiming only on days they had already cleared $0.60.
                survivalRozAccumulated = survivalRozAccumulated + payableSurvival;

                treasuresPlaced = treasuresPlaced + 1_u256;
            }

            // --- Book the shares and the stored survival reward ---
            self._rewardHiderShare(caller, gameWeek, treasureCount);

            let survivalOwed: u256 = self.hider_survival_roz.read((gameWeek, caller));
            self
                .hider_survival_roz
                .write((gameWeek, caller), survivalOwed + survivalRozAccumulated);

            self.player_hides_today.write((dayIndex, caller), hidesToday + treasureCount);

            //update the total number of hiders, which is for the next weeeks game
            self.total_reward_shares_for_hiders.write(gameWeek, alreadyHidden + treasureCount);
            self.game_totals.write(gameWeek, self.game_totals.read(gameWeek) + totalStake);

            // ONE event, whether this was a single hide or a bulk of ten. The
            // count goes in the event rather than into a branch, so single and
            // bulk cannot drift apart - they used to emit different shapes, and
            // the field named hiderFee carried the STAKE on one path and the FEE
            // on the other.
            //
            // totalStake and totalFeeCharged are the two different quantities,
            // both aggregated over the call. See the struct for why they must
            // never be summed by a consumer.
            self
                .emit(
                    Event::TreasureHidden(
                        TreasureHidden {
                            user: caller,
                            hiderStake: totalStake,
                            totalFeeCharged: totalFeeCharged,
                            treasureCount: treasureCount,
                            gameWeek: gameWeek,
                        },
                    ),
                );

            true
        }

        fn _finderPlayerMovePosition(
            ref self: ContractState,
            direction: u128,
            gamerWalletAddress: ContractAddress,
            gameWeek: u256,
        ) -> (u128, u128) {
            //get x,y coordinates from player_position mapping
            let (x, y) = self.player_position.read((gameWeek, gamerWalletAddress));

            //check if the gamer has coordinates
            assert(x.is_non_zero(), 'gamer does not have coordinates');
            assert(y.is_non_zero(), 'gamer does not have coordinates');

            //increase or decrease the coordinates in the intended direction
            let mut newX: u128 = 0;
            let mut newY: u128 = 0;

            if (direction == 0_u128) {
                newX = x - 1;
                newY = y;
            }

            if (direction == 1_u128) {
                newX = x + 1;
                newY = y;
            }

            if (direction == 2_u128) {
                newX = x;
                newY = y - 1;
            }

            if (direction == 3_u128) {
                newX = x;
                newY = y + 1;
            }

            //incorrect direction selected by user.
            assert(newY != 0, 'invalid direction selected');
            assert(newX != 0, 'invalid direction selected');

            let (maxGridX, maxGridY) = self.main_game_grid_size.read(gameWeek);

            //do a require check, if the new coordinates is valid for current game
            assert(newX <= maxGridX, 'out of game board range');
            assert(newY <= maxGridY, 'out of game board range');

            //update player position
            self._updatePlayerPosition(newX, newY, gamerWalletAddress, gameWeek);

            return self.player_position.read((gameWeek, gamerWalletAddress));
        }

        fn _rewardGamer(
            ref self: ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
        ) -> bool {
            let currentShareCount = self.claim_share_amounts.read((gameWeek, gamerWalletAddress));

            self
                .claim_share_amounts
                .write((gameWeek, gamerWalletAddress), (currentShareCount + 1_u256));

            true
        }

        // ------------------------------------------------------------------
        // Typed shares (4d)
        // ------------------------------------------------------------------
        //
        // claim_share_amounts above is a single count, and
        // validate_treasure_coordinates just moves one from the hider to the
        // finder. At claim time that makes a survived hide and a steal
        // INDISTINGUISHABLE - they are the same number in the same map. Paying
        // 50 ROZ for one and 110 for the other is impossible without splitting
        // them.
        //
        // So the two maps below are maintained ALONGSIDE claim_share_amounts,
        // never instead of it. The aggregate still drives the USDC claim exactly
        // as it does today; the typed counts drive the ROZ leg only. Keeping the
        // USDC path untouched is deliberate - it is live, it works, and this
        // change must not put it at risk.
        fn _rewardHiderShare(
            ref self: ContractState,
            gamerWalletAddress: ContractAddress,
            gameWeek: u256,
            shareCount: u256,
        ) -> bool {
            let currentAggregate = self.claim_share_amounts.read((gameWeek, gamerWalletAddress));
            self
                .claim_share_amounts
                .write((gameWeek, gamerWalletAddress), currentAggregate + shareCount);

            let currentHiderShares = self.hider_share_amounts.read((gameWeek, gamerWalletAddress));
            self
                .hider_share_amounts
                .write((gameWeek, gamerWalletAddress), currentHiderShares + shareCount);

            true
        }

        // Moves one share from the hider to the finder. Called from
        // validate_treasure_coordinates when a treasure is stolen.
        //
        // The hider's stored survival ROZ is reduced PRO RATA, because
        // hider_survival_roz is one accumulated number and the contract cannot
        // tell which of a player's treasures was the one taken. With hides
        // capped at 10 a day for ordinary wallets the approximation is bounded
        // and small; an exact answer would need a map keyed by rate, which is
        // not obviously worth the storage.
        fn _moveShareToFinder(
            ref self: ContractState,
            hiderWalletAddress: ContractAddress,
            finderWalletAddress: ContractAddress,
            gameWeek: u256,
        ) -> bool {
            let hiderShares = self.hider_share_amounts.read((gameWeek, hiderWalletAddress));
            assert(hiderShares > 0, 'hider has no typed share');

            let survivalOwed = self.hider_survival_roz.read((gameWeek, hiderWalletAddress));
            let perShare = survivalOwed / hiderShares;

            self.hider_share_amounts.write((gameWeek, hiderWalletAddress), hiderShares - 1_u256);
            self.hider_survival_roz.write((gameWeek, hiderWalletAddress), survivalOwed - perShare);

            let finderShares = self.finder_share_amounts.read((gameWeek, finderWalletAddress));
            self.finder_share_amounts.write((gameWeek, finderWalletAddress), finderShares + 1_u256);

            true
        }

        fn _removeGamerReward(
            ref self: ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
        ) -> bool {
            let currentShareCount = self.claim_share_amounts.read((gameWeek, gamerWalletAddress));

            assert(currentShareCount > 0, 'user has no share claims');

            self
                .claim_share_amounts
                .write((gameWeek, gamerWalletAddress), (currentShareCount - 1_u256));

            true
        }

        fn _spawnNewPosition(
            ref self: ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
        ) -> bool {
            assert(
                self.player_position.read((gameWeek, gamerWalletAddress)) == (0, 0),
                'position already on game board',
            );

            let randomnessResult = self._request_randomness_from_vrf_provider(gamerWalletAddress);

            assert(randomnessResult == true, 'random coordinate no generated');

            return true;
        }

        fn _updatePlayerPosition(
            ref self: ContractState,
            xCoordinate: u128,
            yCoordinate: u128,
            gamerWalletAddress: ContractAddress,
            gameWeek: u256,
        ) {
            self.player_position.write((gameWeek, gamerWalletAddress), (xCoordinate, yCoordinate));

            self
                .emit(
                    PlayerPosition {
                        user: gamerWalletAddress,
                        xCoordinate: xCoordinate,
                        yCoordinate: yCoordinate,
                        gameWeek: gameWeek,
                    },
                );

            self._checkForTreasure(gamerWalletAddress, xCoordinate, yCoordinate, gameWeek);
        }

        fn _transfer_token_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            let mut call_data: Array<felt252> = ArrayTrait::new();

            Serde::serialize(@sender, ref call_data);
            Serde::serialize(@recipient, ref call_data);
            Serde::serialize(@amount, ref call_data);

            // Whichever ERC-20 the game is configured to use. Was a hardcoded ETH
            // address; now read from storage so the token can be changed by the
            // owner. `amount` is a raw token amount in that token's decimals.
            let address: ContractAddress = self.game_token_contract_address.read();

            let mut res = syscalls::call_contract_syscall(
                address, selector!("transfer_from"), call_data.span(),
            )
                .unwrap_syscall();

            Serde::<bool>::deserialize(ref res).unwrap()
        }

        fn _transfer_token(
            ref self: ContractState, recipient: ContractAddress, amount: u256,
        ) -> bool {
            let mut call_data: Array<felt252> = ArrayTrait::new();

            Serde::serialize(@recipient, ref call_data);
            Serde::serialize(@amount, ref call_data);

            // See _transfer_token_from above - same configured game token.
            let address: ContractAddress = self.game_token_contract_address.read();

            let mut res = syscalls::call_contract_syscall(
                address, selector!("transfer"), call_data.span(),
            )
                .unwrap_syscall();

            Serde::<bool>::deserialize(ref res).unwrap()
        }

        #[inline(never)]
        fn _playerRewardDue(
            self: @ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
        ) -> u256 {
            let claimShareCount: u256 = self
                .claim_share_amounts
                .read((gameWeek, gamerWalletAddress));

            if (claimShareCount == 0) {
                return 0;
            } else {
                return self._calculateRewardDue(claimShareCount, gameWeek);
            }
        }

        // The three conditions _claimReward asserts, asked as a question
        // instead. Returns true only for a week claim_reward would accept.
        //
        // THIS DELIBERATELY NEVER REVERTS, and that is the entire reason it
        // exists rather than get_claimable_weeks simply calling
        // _playerRewardDue. That path reaches _calculateRewardDue, which
        // ASSERTS the hider fee exceeds the three deductions - so a single
        // unconfigured week in the middle of a scan would revert the whole
        // range and lose the answer for every other week in it. A week whose
        // funding week was never opened has a hider fee of zero and trips
        // exactly that assert.
        //
        // Returning false there is not a white lie: if _calculateRewardDue
        // would revert, claim_reward reverts too, so the week genuinely is
        // not claimable. The caller learns the same thing without losing the
        // rest of the scan.
        //
        // Keep this in step with _claimReward. If an assertion is ever added
        // there, it belongs here as a condition - otherwise this view starts
        // promising weeks the claim will refuse.
        fn _isRewardClaimable(
            self: @ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
        ) -> bool {
            // 1. Only finished rounds. Shares in the round now under way stay
            //    locked until start_next_round moves past it.
            if (gameWeek >= self.currentGameWeek.read()) {
                return false;
            }

            // 2. Not already settled. This is the flag no caller could read
            //    before get_reward_claimed existed.
            if (self.claimed_rewards.read((gameWeek, gamerWalletAddress))) {
                return false;
            }

            // 3. There is something to pay. Held apart from the reward
            //    arithmetic below so a wallet with no shares never reaches the
            //    fee comparison at all.
            let claimShareCount: u256 = self
                .claim_share_amounts
                .read((gameWeek, gamerWalletAddress));

            if (claimShareCount == 0) {
                return false;
            }

            if (self.round_claim_value_per_share.read(gameWeek) == 0) {
                return false;
            }

            // Safe now - the guard above is the only assert on this path.
            let reward: u256 = self._calculateRewardDue(claimShareCount, gameWeek);

            // Mirrors 'No reward available' and 'No infinity reward amount'.
            if (reward == 0 || reward == BoundedInt::max()) {
                return false;
            }

            return true;
        }

        fn _claimReward(
            ref self: ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
        ) -> bool {
            assert(gameWeek < self.currentGameWeek.read(), 'Game week not finished yet');

            assert(
                self.claimed_rewards.read((gameWeek, gamerWalletAddress)) == false,
                'Reward already claimed',
            );

            let reward = self._playerRewardDue(gamerWalletAddress, gameWeek);

            assert(reward != 0, 'No reward available');
            assert(reward != BoundedInt::max(), 'No infinity reward amount');

            let transferTokenResult: bool = self._transfer_token(gamerWalletAddress, reward);

            assert(transferTokenResult == true, 'No game token transferred');

            self.claimed_rewards.write((gameWeek, gamerWalletAddress), true);

            // The USDC has left, so it is no longer owed. Keeping the running
            // total honest is what lets the sweep in 4j release only the
            // surplus rather than money players can still claim.
            let claimableSoFar: u256 = self.total_usdc_claimable.read();

            if (claimableSoFar >= reward) {
                self.total_usdc_claimable.write(claimableSoFar - reward);
            } else {
                self.total_usdc_claimable.write(0);
            }

            // --- The ROZ leg (4g, 4h) ---
            //
            // THE USDC HAS ALREADY BEEN PAID AND THE FLAG ALREADY SET. That
            // ordering is the whole point: a ROZ shortage must never be able to
            // block a USDC claim. This is the behaviour the entire accrual
            // design exists to protect.
            //
            // The ROZ leg is tracked by its own flag so a skipped credit can be
            // retried later through claim_reward_token_for_week, without the
            // USDC becoming claimable a second time.
            self._creditClaimRoz(gamerWalletAddress, gameWeek);

            return true;
        }

        // Credit the ROZ owed for a finished week's shares.
        //
        // Survived hides pay the amount STORED AT HIDE TIME in
        // hider_survival_roz - never a freshly resolved rate. A claim can land
        // days after the hide, on a fresh calendar day with that day's spend
        // back at zero, so re-resolving would pay an honest player 7.5 instead
        // of 50 for claiming on a Monday morning, and would let a farmer do the
        // reverse by claiming only on days they had already cleared $0.60.
        //
        // Finds pay rewardFind at full rate, always. No gate state reduces it.
        fn _creditClaimRoz(
            ref self: ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
        ) -> bool {
            if (self.reward_token_claimed.read((gameWeek, gamerWalletAddress))) {
                return true;
            }

            let survivalRoz: u256 = self.hider_survival_roz.read((gameWeek, gamerWalletAddress));
            let finderShares: u256 = self.finder_share_amounts.read((gameWeek, gamerWalletAddress));
            let findRoz: u256 = finderShares * self.rewardFind.read();

            let totalRoz: u256 = survivalRoz + findRoz;

            if (totalRoz == 0) {
                // Nothing owed. Mark it settled so a retry does not keep
                // looking, and so the getter reports the week as done.
                self.reward_token_claimed.write((gameWeek, gamerWalletAddress), true);
                return true;
            }

            let credited: bool = self._accrueRewardToken(gamerWalletAddress, totalRoz, 'claim');

            // ONLY set the flag if the credit actually landed. If the contract
            // could not cover it the credit was skipped, and leaving the flag
            // clear is what makes the retry in claim_reward_token_for_week
            // possible once the contract is funded again.
            if (credited) {
                self.reward_token_claimed.write((gameWeek, gamerWalletAddress), true);
            }

            return credited;
        }

        // Works out what one player's shares in a finished game week are worth.
        //
        // The gameWeek argument is the week the shares BELONG to - the week the
        // treasure was live and findable - not the week the player is claiming in.
        // A claim always happens at least one week later, because a hider only
        // knows their treasure survived once the week is over.
        //
        // That matters because of when a share is created. hide_treasure charges
        // the fee in force at that moment and credits the share to the NEXT week:
        //
        //   hide during week K-1   ->  charged main_game[K-1].hiderFee
        //                          ->  share credited to week K
        //   week K                 ->  the treasure is live and findable
        //   week K+1 or later      ->  claim_reward(K)
        //
        // So the money backing week K was paid in during week K-1, and week K-1's
        // rate is what this calculation must use. It is the same for finders:
        // validate_treasure_coordinates does not create a share, it moves the
        // hider's existing one, so every share at week K is one hide from week K-1.
        //
        // This previously read the live currentHiderFee. Because start_next_round
        // rewrites that on every rollover, any fee change silently repriced every
        // reward players had not yet claimed - paying them a rate they never
        // agreed to, in either direction.
        fn _calculateRewardDue(
            self: @ContractState, claimShareCount: u256, gameWeek: u256,
        ) -> u256 {
            let claimValuePerShare: u256 = self.round_claim_value_per_share.read(gameWeek);
            assert(claimValuePerShare > 0, 'claim value not configured');
            return claimShareCount * claimValuePerShare;
        }

        // Asks the configured VRF provider for one random number and turns it
        // straight into the player's starting grid position.
        //
        // Which provider answers is decided entirely by the address in storage,
        // set at deploy time and changeable by the admin through
        // update_vrf_provider. Nothing below this line differs between
        // Cartridge's real provider and the testnet MockVrfProvider - they
        // implement the same IVrfProvider trait, so the call is identical and
        // only the behaviour behind it changes:
        //
        //   Cartridge's provider - returns a number that their paymaster proved
        //                          and submitted earlier in this same
        //                          transaction, and REVERTS with
        //                          'VrfProvider: not fulfilled' if it did not.
        //   MockVrfProvider      - generates a number on the spot, so it cannot
        //                          revert for a missing proof. Testnet only.
        //
        fn _request_randomness_from_vrf_provider(
            ref self: ContractState, caller: ContractAddress,
        ) -> bool {
            let randomness_contract_address = self.vrf_provider_contract_address.read();
            let randomness_dispatcher = IVrfProviderDispatcher {
                contract_address: randomness_contract_address,
            };

            // Match the player source used by the frontend VRF request.
            let random_value = randomness_dispatcher.consume_random(Source::Nonce(caller));

            self._receive_random_words_2(caller, random_value);

            return true;
        }
    }

    #[abi(embed_v0)]
    impl GameAdministrationImpl of IGameAdministration<ContractState> {
        // Emergency play freeze. Claims, settlement, expiry and administration
        // deliberately do not depend on this flag.
        fn pause(ref self: ContractState) {
            self.access_control.assert_only_role(PAUSE_ROLE);
            self.pausable.pause();
        }

        fn unpause(ref self: ContractState) {
            self.access_control.assert_only_role(PAUSE_ROLE);
            assert(self.settings_initialized.read(), 'settings not initialized');
            assert(self.hop_bands_initialized.read() == 4, 'hop bands incomplete');
            assert(self.volume_bands_initialized.read() == 6, 'volume bands incomplete');
            // A full sweep is authorized only for one uninterrupted paused
            // window. Unpausing cancels it, so pause -> propose -> unpause ->
            // pause cannot reuse the old ETA.
            if self.pending_admin_action.read() == ACTION_FULL_SWEEP {
                let action_hash = self.pending_admin_action_hash.read();
                self._clear_admin_action();
                self.emit(AdminActionCancelled { action: ACTION_FULL_SWEEP, action_hash });
            }
            self.pausable.unpause();
        }

        fn is_paused(self: @ContractState) -> bool {
            self.pausable.is_paused()
        }

        // Publishing a class hash starts the mandatory review window. It never
        // changes the class by itself, even when a testnet delay is zero.
        fn propose_upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.access_control.assert_only_role(UPGRADE_ROLE);
            assert(new_class_hash.is_non_zero(), 'Class hash is zero');
            assert(self.pending_class_hash.read().is_zero(), 'Upgrade already pending');
            let eta = get_block_timestamp() + self.upgrade_delay.read();
            self.pending_class_hash.write(new_class_hash);
            self.pending_upgrade_eta.write(eta);
            self.emit(UpgradeProposed { class_hash: new_class_hash, eta });
        }

        fn execute_upgrade(ref self: ContractState) {
            self.access_control.assert_only_role(UPGRADE_ROLE);
            let class_hash = self.pending_class_hash.read();
            assert(class_hash.is_non_zero(), 'No pending upgrade');
            assert(
                get_block_timestamp() >= self.pending_upgrade_eta.read(),
                'Upgrade delay not elapsed',
            );
            self.pending_class_hash.write(Zero::zero());
            self.pending_upgrade_eta.write(0);
            self.emit(UpgradeExecuted { class_hash });
            self.upgradeable.upgrade(class_hash);
        }

        // The replacement happens first, then Starknet calls this contract with
        // the supplied selector using the new class in the same transaction.
        fn execute_upgrade_and_migrate(
            ref self: ContractState, selector: felt252, calldata: Span<felt252>,
        ) -> Span<felt252> {
            self.access_control.assert_only_role(UPGRADE_ROLE);
            let class_hash = self.pending_class_hash.read();
            assert(class_hash.is_non_zero(), 'No pending upgrade');
            assert(
                get_block_timestamp() >= self.pending_upgrade_eta.read(),
                'Upgrade delay not elapsed',
            );
            self.pending_class_hash.write(Zero::zero());
            self.pending_upgrade_eta.write(0);
            self.emit(UpgradeExecuted { class_hash });
            self.upgradeable.upgrade_and_call(class_hash, selector, calldata)
        }

        fn cancel_upgrade(ref self: ContractState) {
            self.access_control.assert_only_role(UPGRADE_ROLE);
            let class_hash = self.pending_class_hash.read();
            assert(class_hash.is_non_zero(), 'No pending upgrade');
            self.pending_class_hash.write(Zero::zero());
            self.pending_upgrade_eta.write(0);
            self.emit(UpgradeCancelled { class_hash });
        }

        fn get_pending_upgrade(self: @ContractState) -> (ClassHash, u64) {
            (self.pending_class_hash.read(), self.pending_upgrade_eta.read())
        }

        fn get_upgrade_delay(self: @ContractState) -> u64 {
            self.upgrade_delay.read()
        }

        // A decrease is scheduled against the OLD delay. It cannot be followed
        // by an immediate zero-delay upgrade from the same compromised key.
        fn propose_upgrade_delay(ref self: ContractState, new_delay: u64) {
            self._assert_admin_or_upgrader();
            self._assert_valid_upgrade_delay(new_delay);
            let old_delay = self.upgrade_delay.read();
            assert(new_delay < old_delay, 'Only decreases need proposal');
            assert(!self.pending_delay_exists.read(), 'Delay change already pending');
            let eta = get_block_timestamp() + old_delay;
            self.pending_delay_exists.write(true);
            self.pending_delay_value.write(new_delay);
            self.pending_delay_eta.write(eta);
            self.emit(UpgradeDelayChangeProposed { new_delay, eta });
        }

        fn set_upgrade_delay(ref self: ContractState, new_delay: u64) {
            self._assert_admin_or_upgrader();
            self._assert_valid_upgrade_delay(new_delay);
            let old_delay = self.upgrade_delay.read();
            if new_delay < old_delay {
                assert(self.pending_delay_exists.read(), 'Delay decrease not proposed');
                assert(self.pending_delay_value.read() == new_delay, 'Wrong proposed delay');
                assert(
                    get_block_timestamp() >= self.pending_delay_eta.read(),
                    'Delay change not elapsed',
                );
            }
            self.upgrade_delay.write(new_delay);
            self.pending_delay_exists.write(false);
            self.pending_delay_value.write(0);
            self.pending_delay_eta.write(0);
            self.emit(UpgradeDelayChanged { old_delay, new_delay });
        }

        fn cancel_upgrade_delay_change(ref self: ContractState) {
            self._assert_admin_or_upgrader();
            assert(self.pending_delay_exists.read(), 'No pending delay change');
            let proposed_delay = self.pending_delay_value.read();
            self.pending_delay_exists.write(false);
            self.pending_delay_value.write(0);
            self.pending_delay_eta.write(0);
            self.emit(UpgradeDelayChangeCancelled { proposed_delay });
        }

        fn get_pending_upgrade_delay(self: @ContractState) -> (bool, u64, u64) {
            (
                self.pending_delay_exists.read(),
                self.pending_delay_value.read(),
                self.pending_delay_eta.read(),
            )
        }

        fn propose_vrf_provider_update(
            ref self: ContractState, vrf_provider_address: ContractAddress,
        ) {
            assert(vrf_provider_address.is_non_zero(), 'VRF provider is zero');
            let action_hash = self
                ._admin_action_hash(ACTION_VRF_PROVIDER, vrf_provider_address.into(), 0);
            self._schedule_admin_action(ACTION_VRF_PROVIDER, action_hash, false);
        }

        fn propose_game_token_update(ref self: ContractState, game_token_address: ContractAddress) {
            assert(game_token_address.is_non_zero(), 'Game token is zero');
            let action_hash = self
                ._admin_action_hash(ACTION_GAME_TOKEN, game_token_address.into(), 0);
            self._schedule_admin_action(ACTION_GAME_TOKEN, action_hash, false);
        }

        fn propose_game_reward_token_update(
            ref self: ContractState, reward_token_address: ContractAddress,
        ) {
            assert(reward_token_address.is_non_zero(), 'Reward token is zero');
            let action_hash = self
                ._admin_action_hash(ACTION_REWARD_TOKEN, reward_token_address.into(), 0);
            self._schedule_admin_action(ACTION_REWARD_TOKEN, action_hash, false);
        }

        fn propose_admin_update(ref self: ContractState, new_admin: ContractAddress) {
            assert(new_admin.is_non_zero(), 'Admin address is zero');
            assert(new_admin != self.admin_address.read(), 'Admin is unchanged');
            let action_hash = self._admin_action_hash(ACTION_SET_ADMIN, new_admin.into(), 0);
            self._schedule_admin_action(ACTION_SET_ADMIN, action_hash, false);
        }

        fn propose_token_withdrawal(
            ref self: ContractState, token_address: ContractAddress, receiver: ContractAddress,
        ) {
            assert(token_address.is_non_zero(), 'Token address is zero');
            assert(receiver.is_non_zero(), 'Receiver is zero');
            let action_hash = self
                ._admin_action_hash(ACTION_SAFE_SWEEP, token_address.into(), receiver.into());
            self._schedule_admin_action(ACTION_SAFE_SWEEP, action_hash, false);
        }

        // A full sweep explicitly overrides player-liability reservations and
        // is therefore legal only while paused both now and at execution.
        fn propose_full_token_withdrawal(
            ref self: ContractState, token_address: ContractAddress, receiver: ContractAddress,
        ) {
            assert(token_address.is_non_zero(), 'Token address is zero');
            assert(receiver.is_non_zero(), 'Receiver is zero');
            let action_hash = self
                ._admin_action_hash(ACTION_FULL_SWEEP, token_address.into(), receiver.into());
            self._schedule_admin_action(ACTION_FULL_SWEEP, action_hash, true);
        }

        fn cancel_admin_action(ref self: ContractState) {
            self._assert_admin();
            let action = self.pending_admin_action.read();
            assert(action != 0, 'No pending admin action');
            let action_hash = self.pending_admin_action_hash.read();
            self._clear_admin_action();
            self.emit(AdminActionCancelled { action, action_hash });
        }

        fn get_pending_admin_action(self: @ContractState) -> (felt252, felt252, u64) {
            (
                self.pending_admin_action.read(),
                self.pending_admin_action_hash.read(),
                self.pending_admin_action_eta.read(),
            )
        }

        fn set_admin(ref self: ContractState, new_admin: ContractAddress) {
            assert(new_admin.is_non_zero(), 'Admin address is zero');
            let action_hash = self._admin_action_hash(ACTION_SET_ADMIN, new_admin.into(), 0);
            self._consume_admin_action(ACTION_SET_ADMIN, action_hash, false);
            let previous_admin = self.admin_address.read();
            self.access_control._grant_role(DEFAULT_ADMIN_ROLE, new_admin);
            self.access_control._grant_role(ADMIN_ROLE, new_admin);
            self.access_control._grant_role(UPGRADE_ROLE, new_admin);
            self.admin_address.write(new_admin);
            self.ownable._transfer_ownership(new_admin);
            self.access_control._revoke_role(UPGRADE_ROLE, previous_admin);
            self.access_control._revoke_role(ADMIN_ROLE, previous_admin);
            self.access_control._revoke_role(DEFAULT_ADMIN_ROLE, previous_admin);
            self.emit(AdminChanged { previous_admin, new_admin });
        }

        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin_address.read()
        }

        // This migration is intentionally narrow. Constructor defaults are not
        // replayed because that would overwrite live rates, caps, maps and IOUs.
        fn migrate_v2(ref self: ContractState) -> bool {
            let caller = get_caller_address();
            let via_upgrade_and_call = caller == get_contract_address();
            let is_upgrader = self.access_control.is_role_effective(UPGRADE_ROLE, caller);
            assert(via_upgrade_and_call || is_upgrader, 'Caller is not upgrader');
            if self.upgrade_initialized_version.read() >= MIGRATION_VERSION {
                return false;
            }
            assert(
                self.hideFeeTierBoundary.read()
                    * self.hideFeeBase.read() == self.dailySpendThreshold.read(),
                'Hide fee invariant broken',
            );
            self.upgrade_initialized_version.write(MIGRATION_VERSION);
            self.emit(MigrationApplied { version: MIGRATION_VERSION });
            true
        }

        fn get_upgrade_initialized_version(self: @ContractState) -> u256 {
            self.upgrade_initialized_version.read()
        }
    }

    #[abi(embed_v0)]
    impl HelloStarknetImpl of super::IHelloStarknet<ContractState> {
        fn get_minimum_allowance_fee(self: @ContractState) -> u256 {
            return self.minimumAllowance.read();
        }

        fn get_hider_player_fee(self: @ContractState) -> u256 {
            return self.currentHiderFee.read();
        }

        fn get_game_grid_size(self: @ContractState, gameWeek: u256) -> (u128, u128) {
            return self.main_game_grid_size.read(gameWeek);
        }

        fn get_game_week_treasure_total(self: @ContractState, gameWeek: u256) -> u256 {
            return self.game_totals.read(gameWeek);
        }

        fn get_game_week(self: @ContractState) -> u256 {
            return self.currentGameWeek.read();
        }

        fn get_round_status(self: @ContractState) -> (u256, u8, u64, u64, u64, u256, u256, u64) {
            let startTs: u64 = self.round_start_ts.read();
            return (
                self.currentGameWeek.read(),
                self.round_state.read(),
                startTs,
                startTs + self.round_duration.read(),
                self.round_ended_ts.read(),
                self.active_treasure_count.read(),
                self.round_initial_active_count.read(),
                self.end_buffer.read(),
            );
        }

        fn get_next_round_totals(self: @ContractState) -> (u256, u256) {
            let nextRound: u256 = self.currentGameWeek.read() + 1;
            return (
                self.total_reward_shares_for_hiders.read(nextRound),
                self.game_totals.read(nextRound),
            );
        }

        fn get_min_treasures_to_start(self: @ContractState) -> u256 {
            MIN_TREASURES_TO_START
        }

        fn get_round_keeper(self: @ContractState) -> ContractAddress {
            self.round_keeper.read()
        }

        fn update_round_keeper(ref self: ContractState, keeper: ContractAddress) -> bool {
            self._assert_admin();
            assert(!keeper.is_zero(), 'keeper is zero');
            self.round_keeper.write(keeper);
            true
        }

        fn get_claim_share_amounts(
            self: @ContractState, gameWeek: u256, gamerWalletAddress: ContractAddress,
        ) -> u256 {
            return self.claim_share_amounts.read((gameWeek, gamerWalletAddress));
        }

        // Returns exactly what claim_reward(gameWeek) would pay this player, in
        // the game token's smallest unit. Anyone can call it.
        //
        // Use this rather than working the figure out from get_claim_share_amounts
        // and get_hider_player_fee. Those two cannot reproduce it: the shares must
        // be priced at the PREVIOUS week's hider fee, and the three deductions have
        // to come off once. Going through the same internal path as the claim means
        // the number shown to a player can never disagree with the number they get.
        //
        // Note this mirrors the claim completely, including its assertions - so it
        // reverts with 'Reward is less than fees' in the case where the shares are
        // worth less than the deductions. Treat a revert as "nothing to claim".
        fn get_player_reward_due(
            self: @ContractState, gameWeek: u256, gamerWalletAddress: ContractAddress,
        ) -> u256 {
            return self._playerRewardDue(gamerWalletAddress, gameWeek);
        }

        fn start_next_round(ref self: ContractState, params: NextRoundParams) -> bool {
            self.pausable.assert_not_paused();
            assert(get_caller_address() == self.round_keeper.read(), 'caller is not keeper');
            assert(self.round_state.read() == ROUND_ENDING, 'round not ending');
            assert(
                get_block_timestamp() >= self.round_ended_ts.read() + self.end_buffer.read(),
                'end buffer active',
            );

            let nextRound: u256 = self.currentGameWeek.read() + 1;
            let stagedCount: u256 = self.total_reward_shares_for_hiders.read(nextRound);
            assert(stagedCount >= MIN_TREASURES_TO_START, 'not enough staged treasures');
            assert(params.expected_active_treasure_count == stagedCount, 'active count mismatch');
            assert(
                params.expected_total_hidden_value == self.game_totals.read(nextRound),
                'hidden value mismatch',
            );

            self._createNewGame(params, nextRound)
        }

        fn expire_round(ref self: ContractState, expectedRound: u256) -> bool {
            assert(get_caller_address() == self.round_keeper.read(), 'caller is not keeper');

            // A stale one-time schedule is harmless and must not end whatever
            // round happens to be current when it eventually runs.
            if (expectedRound != self.currentGameWeek.read()
                || self.round_state.read() != ROUND_OPEN) {
                return false;
            }

            let now: u64 = get_block_timestamp();
            let startTs: u64 = self.round_start_ts.read();
            let scheduledEndTs: u64 = startTs + self.round_duration.read();
            let initial: u256 = self.round_initial_active_count.read();

            // Empty bootstrap rounds never end immediately. The active-count
            // path is only valid for a round which actually opened with finds.
            if (initial > 0 && self.active_treasure_count.read() == 0 && now >= startTs
                + self.min_duration.read() && now < scheduledEndTs
                - self.near_end_blackout.read()) {
                return self._endRound(END_REASON_ALL_FOUND);
            }

            // Keep the round OPEN for a short processing grace so a check event
            // emitted before the deadline can still be validated by the keeper.
            if (now >= scheduledEndTs + VALIDATION_GRACE_SECONDS) {
                return self._endRound(END_REASON_TIME_EXPIRED);
            }

            false
        }

        // Hide a single treasure. Costs the $5 stake plus the tiered fee, and is
        // bounded by dailyHideCap for anyone not on the whitelist.
        fn hide_treasure(ref self: ContractState) -> bool {
            let caller = get_caller_address();

            // An empty proof, so _verifyWhitelist returns false and the ordinary
            // daily cap applies. A whitelisted address wanting its higher limits
            // uses hide_treasure_bulk, which takes a proof.
            let emptyProof: Array<felt252> = ArrayTrait::new();

            return self._hideTreasure(caller, 1_u256, emptyProof, 0);
        }

        // Hide several treasures in one transaction.
        //
        // OPEN TO EVERYONE. What differs is how many treasures the caller may
        // create: 10 a day for an ordinary wallet, or 250 a round and 80 an hour
        // for a whitelisted one. Every limit counts TREASURES, not calls, and so
        // do the fee tier and the volume multiplier - which is what makes a bulk
        // of N identical to N single hides and leaves nothing to arbitrage.
        //
        // bulkAmount is the total STAKE, and must be an exact multiple of the
        // hider fee. The per-treasure fees are charged on top.
        fn hide_treasure_bulk(
            ref self: ContractState, bulkAmount: u256, merkleProof: Array<felt252>, leafIndex: u32,
        ) -> bool {
            let caller = get_caller_address();
            let stakePerTreasure: u256 = self.currentHiderFee.read();

            // Whole treasures only. A remainder would be money the contract took
            // without hiding anything for it.
            assert(bulkAmount % stakePerTreasure == 0, 'not a multiple of hider fee');

            let treasureCount: u256 = bulkAmount / stakePerTreasure;

            assert(treasureCount > 0, 'bulk amount too small');

            return self._hideTreasure(caller, treasureCount, merkleProof, leafIndex);
        }

        // One hop. Charges the 2.5 tier price for this wallet's hop number
        // TODAY, then credits ROZ at whatever rate the 2.6 gate resolves to.
        //
        // ORDER MATTERS HERE AND IS THE WHOLE POINT. The fee is charged and the
        // spend counters updated BEFORE the reward rate is read, so the hop that
        // takes a wallet past $0.60 is itself paid at the full rate. Reading the
        // rate first would pay that hop 0.15 and only start paying 1.0 from the
        // next one.
        fn finder_player_move_position( // ref self: ContractState, xDirection: u128, yDirection: u128
            ref self: ContractState, direction: u128,
        ) -> (u128, u128) {
            self._assertRoundAcceptsActions();
            let gamerWalletAddress = get_caller_address();
            let gameWeek = self.currentGameWeek.read();
            let dayIndex: u64 = self._currentDayIndex();
            let myContract: ContractAddress = get_contract_address();

            // --- Count the hop, per day and per round ---
            //
            // The daily count drives the price tiers and the participation
            // test; the round count drives the 40-hop reward cap. They are
            // separate on purpose: the tiers MUST NOT reset at a round boundary,
            // or a farmer re-enters the cheap band four times a day and 128 hops
            // costs $0.34 instead of $3.135.
            let hopsToday: u256 = self.player_hops_today.read((dayIndex, gamerWalletAddress))
                + 1_u256;
            let hopsThisRound: u256 = self.player_hops.read((gameWeek, gamerWalletAddress))
                + 1_u256;

            self.player_hops_today.write((dayIndex, gamerWalletAddress), hopsToday);
            self.player_hops.write((gameWeek, gamerWalletAddress), hopsThisRound);

            // --- Charge for it, unless the free allowance covers it ---
            //
            // A free hop is identical to a paid one in every respect except the
            // charge. It moves the player, it counts toward the 28-hop
            // participation minimum and the 40-hop cap, and it earns ROZ at the
            // same resolved rate. An earlier design made free hops earn nothing,
            // which meant taking the allowance COST an earning player money and
            // the rational move was to avoid the feature entirely.
            let freeHopsUsed: u256 = self
                .player_free_hops_used
                .read((dayIndex, gamerWalletAddress));
            let freeHopAllowance: u256 = self.dailyFreeHops.read();

            if (freeHopsUsed < freeHopAllowance) {
                self
                    .player_free_hops_used
                    .write((dayIndex, gamerWalletAddress), freeHopsUsed + 1_u256);
                // No transfer, and NOTHING is added to the spend counters. A
            // free hop costs the player nothing, so it is not spend - which
            // is why free play alone can never clear the 2.6 gate however
            // many hops are taken.
            } else {
                let hopCost: u256 = self._hopPriceForHopNumber(hopsToday);

                let transferTokenResult: bool = self
                    ._transfer_token_from(gamerWalletAddress, myContract, hopCost);

                assert(transferTokenResult == true, 'game token not transferred');

                self._recordSpend(gamerWalletAddress, hopCost);
            }

            // --- Credit the hop reward, under the per-round cap ---
            //
            // The cap is per ROUND, not per day: 40 rewarded hops in each of
            // four rounds. Hops past it still MOVE the player - they simply earn
            // nothing - because reverting would strand somebody mid-search.
            if (hopsThisRound <= self.hopRewardCap.read()) {
                let hopRate: u256 = self
                    ._resolveGatedRate(
                        gamerWalletAddress,
                        self.rewardPerHop.read(),
                        self.hopRewardNewWallet.read(),
                        self.hopRewardBelowThreshold.read(),
                    );

                // The soft cap is the single multiplier a hop may receive.
                let payableHopReward: u256 = self._applyHopSoftCap(gamerWalletAddress, hopRate);

                self._accrueRewardToken(gamerWalletAddress, payableHopReward, 'hop');
            }

            // --- Participation, tested on BOTH conditions, every hop ---
            self._creditParticipationIfDue(gamerWalletAddress);

            return self._finderPlayerMovePosition(direction, gamerWalletAddress, gameWeek);
        }

        fn get_finder_player_position(
            self: @ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
        ) -> (u128, u128) {
            //get x,y coordinates from player_position mapping
            let (x, y) = self.player_position.read((gameWeek, gamerWalletAddress));

            return (x, y);
        }

        fn validate_treasure_coordinates(
            ref self: ContractState,
            finderGamerWalletAddress: ContractAddress,
            hiderGamerWalletAddress: ContractAddress,
            leaf: u256,
            proof: Array<u256>,
            checkHopCount: u256,
            checkTimestamp: u64,
        ) -> bool {
            assert(get_caller_address() == self.round_keeper.read(), 'caller is not keeper');
            // A find reward is deliberately ungated because it is meant to
            // require somebody else's stake. Letting the same wallet occupy
            // both sides turns the highest reward into a closed farming loop.
            assert(finderGamerWalletAddress != hiderGamerWalletAddress, 'cannot find own treasure');

            let gameWeek: u256 = self.currentGameWeek.read();
            let scheduledEndTs: u64 = self.round_start_ts.read() + self.round_duration.read();
            let now: u64 = get_block_timestamp();
            assert(self.round_state.read() == ROUND_OPEN, 'round not open');
            assert(checkTimestamp <= scheduledEndTs, 'check after round deadline');
            assert(now < scheduledEndTs + VALIDATION_GRACE_SECONDS, 'validation grace elapsed');
            let totalPlayerHops: u256 = self.player_hops.read((gameWeek, finderGamerWalletAddress));
            let previousFindHops: u256 = self
                .player_last_find_hops
                .read((gameWeek, finderGamerWalletAddress));
            assert(checkHopCount <= totalPlayerHops, 'invalid check hop count');
            assert(checkHopCount >= previousFindHops, 'stale check hop count');

            let (root, _, _) = self.main_game.read(self.currentGameWeek.read());

            let result: bool = self._verify(root, leaf, proof);

            if (result == true) {
                //Treasure found
                //record that treasure has been found
                let coordinatesFound = self.found_coordinates.read((leaf, gameWeek));

                assert(coordinatesFound == false, 'coordinates already found');

                //record the leaf representation of coordinates that have been found.
                self.found_coordinates.write((leaf, gameWeek), true);

                //reward the finder gamer
                self._rewardGamer(finderGamerWalletAddress, gameWeek);

                //update the total number of finders, for the current week
                self
                    .total_reward_shares_for_finders
                    .write(
                        gameWeek, (self.total_reward_shares_for_finders.read(gameWeek) + 1_u256),
                    );

                //remove gamer reward
                self._removeGamerReward(hiderGamerWalletAddress, gameWeek);

                // The aggregate calls above move the USDC-backed share. Keep
                // the parallel typed ledgers in step so the hider loses the
                // pro-rata survival ROZ and the finder receives rewardFind at
                // claim time.
                self
                    ._moveShareToFinder(
                        hiderGamerWalletAddress, finderGamerWalletAddress, gameWeek,
                    );

                assert(
                    self.total_reward_shares_for_hiders.read(gameWeek) > 0,
                    'no hiders in current game week',
                );
                assert(self.active_treasure_count.read() > 0, 'no active treasures');

                //update the total number of hiders, for the current week
                self
                    .total_reward_shares_for_hiders
                    .write(gameWeek, (self.total_reward_shares_for_hiders.read(gameWeek) - 1_u256));

                let activeAfterFind: u256 = self.active_treasure_count.read() - 1;
                self.active_treasure_count.write(activeAfterFind);
                self
                    .player_last_find_hops
                    .write((gameWeek, finderGamerWalletAddress), checkHopCount);

                self
                    .emit(
                        Event::TreasureFound(
                            TreasureFound {
                                finder: finderGamerWalletAddress,
                                hider: hiderGamerWalletAddress,
                                hopsTaken: checkHopCount - previousFindHops,
                                roundId: gameWeek,
                            },
                        ),
                    );

                let startTs: u64 = self.round_start_ts.read();
                if (activeAfterFind == 0
                    && self.round_initial_active_count.read() > 0
                    && now >= startTs
                    + self.min_duration.read() && now < scheduledEndTs
                    - self.near_end_blackout.read()) {
                    self._endRound(END_REASON_ALL_FOUND);
                }

                return true;
            } else {
                return false;
            }
        }

        fn finder_player_generate_position(ref self: ContractState) -> bool {
            self._assertRoundAcceptsActions();
            let gamerWalletAddress = get_caller_address();
            let gameWeek = self.currentGameWeek.read();

            let spawnNewPositionCost: u256 = self.currentSpawnNewPositionFee.read();
            let myContract: ContractAddress = get_contract_address();

            // Check that the player has approved this contract to spend enough of
            // the game token on their behalf. This is checked once here rather than
            // per fee, so a player approves a budget up front and can then play
            // several rounds without re-approving.
            let game_token_dispatcher = ERC20ABIDispatcher {
                contract_address: self.game_token_contract_address.read(),
            };
            let allowanceAmount: u256 = game_token_dispatcher
                .allowance(gamerWalletAddress, myContract);

            assert(allowanceAmount >= self.minimumAllowance.read(), 'token spend approval req');

            // The free spawn allowance, one a day by default.
            //
            // A SPAWN PAYS NO ROZ - free or paid, first of the day or fifth. It
            // repositions the rabbit and nothing more. That is why there is no
            // reward branch here at all, and why free and paid spawns are
            // identical apart from the charge. The daily reward and streak bonus
            // that used to hang off spawning are gone with it.
            let dayIndex: u64 = self._currentDayIndex();
            let freeSpawnsUsed: u256 = self
                .player_free_spawns_used
                .read((dayIndex, gamerWalletAddress));

            if (freeSpawnsUsed < self.dailyFreeSpawns.read()) {
                self
                    .player_free_spawns_used
                    .write((dayIndex, gamerWalletAddress), freeSpawnsUsed + 1_u256);
                // Free, so nothing reaches the spend counters.
            } else {
                let transferTokenResult: bool = self
                    ._transfer_token_from(gamerWalletAddress, myContract, spawnNewPositionCost);

                assert(transferTokenResult == true, 'game token not transferred');

                self._recordSpend(gamerWalletAddress, spawnNewPositionCost);
            }

            self
                .player_last_find_hops
                .write(
                    (gameWeek, gamerWalletAddress),
                    self.player_hops.read((gameWeek, gamerWalletAddress)),
                );
            self._spawnNewPosition(gamerWalletAddress, gameWeek);

            return true;
        }

        fn claim_reward(ref self: ContractState, gameWeek: u256) -> bool {
            let gamerWalletAddress = get_caller_address();

            return self._claimReward(gamerWalletAddress, gameWeek);
        }

        // Withdraw accrued ROZ. A SEPARATE entrypoint from claim_reward, not a
        // replacement for it (4g).
        //
        // This can never fail for lack of ROZ, and that is guaranteed by
        // construction rather than by checking: the coverage rule in
        // _accrueRewardToken refuses to create an IOU the contract cannot
        // honour, so if a balance exists here the tokens exist to pay it.
        //
        // A zero balance is a NO-OP, not a revert - somebody polling this
        // should not get a failed transaction for being early.
        fn claim_reward_tokens(ref self: ContractState) -> bool {
            let gamerWalletAddress = get_caller_address();
            let owed: u256 = self.reward_token_pending.read(gamerWalletAddress);

            if (owed == 0) {
                return true;
            }

            let rewardTokenAddress: ContractAddress = self
                .game_reward_token_contract_address
                .read();

            assert(!rewardTokenAddress.is_zero(), 'reward token not configured');

            // Clear BEFORE transferring, so a re-entrant token cannot be paid
            // twice off the same balance.
            self.reward_token_pending.write(gamerWalletAddress, 0);

            let owedTotal: u256 = self.total_reward_token_pending.read();

            if (owedTotal >= owed) {
                self.total_reward_token_pending.write(owedTotal - owed);
            } else {
                self.total_reward_token_pending.write(0);
            }

            let reward_token_dispatcher = ERC20ABIDispatcher {
                contract_address: rewardTokenAddress,
            };

            let transferResult: bool = reward_token_dispatcher.transfer(gamerWalletAddress, owed);

            assert(transferResult == true, 'reward token not transferred');

            self
                .emit(
                    Event::RewardTokenClaimed(
                        RewardTokenClaimed { user: gamerWalletAddress, amount: owed },
                    ),
                );

            return true;
        }

        // Retry the ROZ leg of a past claim (4h).
        //
        // If the contract was unfunded when claim_reward ran, the USDC was still
        // paid but the ROZ credit was skipped and reward_token_claimed left
        // clear. This re-runs just that leg. Without it, a player who claimed
        // during a funding gap would lose their ROZ permanently through no
        // fault of their own.
        //
        // Safe to call repeatedly: once the credit lands the flag is set and
        // every later call is a no-op.
        fn claim_reward_token_for_week(ref self: ContractState, gameWeek: u256) -> bool {
            let gamerWalletAddress = get_caller_address();

            // The USDC leg must have happened first - this only ever retries a
            // leg that was already due.
            assert(
                self.claimed_rewards.read((gameWeek, gamerWalletAddress)),
                'USDC leg not claimed yet',
            );

            return self._creditClaimRoz(gamerWalletAddress, gameWeek);
        }

        // How much ROZ this wallet can withdraw right now.
        fn get_reward_token_pending(
            self: @ContractState, gamerWalletAddress: ContractAddress,
        ) -> u256 {
            return self.reward_token_pending.read(gamerWalletAddress);
        }

        // The sum of every outstanding IOU. Compare against the contract's ROZ
        // balance to see how much headroom the coverage rule has left - when
        // these meet, rewards stop accruing and RewardTokenAccrualSkipped starts
        // firing.
        fn get_total_reward_token_pending(self: @ContractState) -> u256 {
            return self.total_reward_token_pending.read();
        }

        // ROZ this wallet earned while the contract could not pay for it.
        //
        // NOT withdrawable. Call claim_missed_reward_token to move whatever the
        // balance can now cover into the pending balance, then
        // claim_reward_tokens to withdraw it. This is the honest figure for a
        // "waiting on funding" display - before it existed the only source was
        // the RewardTokenAccrualSkipped log, which the contract cannot read and
        // a client has to total up by hand.
        fn get_reward_token_missed(
            self: @ContractState, gamerWalletAddress: ContractAddress,
        ) -> u256 {
            return self.reward_token_missed.read(gamerWalletAddress);
        }

        // The sum of every missed balance. Together with
        // get_total_reward_token_pending this is the full liability: what would
        // have to be funded for every player to be paid everything they have
        // earned.
        fn get_total_reward_token_missed(self: @ContractState) -> u256 {
            return self.total_reward_token_missed.read();
        }

        // Turn previously skipped ROZ into a balance that can be withdrawn.
        //
        // Moves as much as the contract can currently cover out of
        // reward_token_missed and into reward_token_pending. Then
        // claim_reward_tokens pays it out as normal - this deliberately does
        // NOT transfer, so the two steps stay separate and each does one thing.
        //
        // PARTIAL BY DESIGN. It converts min(missed, headroom) rather than
        // insisting on the whole amount. If it were all-or-nothing, a player
        // whose backlog exceeded the free balance would convert nothing at all,
        // forever - the bigger the debt, the less recoverable it would be,
        // which is exactly backwards. Whatever fits moves now; call again after
        // the next top-up for the rest.
        //
        // IT REIMPLEMENTS THE COVERAGE ARITHMETIC INSTEAD OF CALLING
        // _accrueRewardToken, and that is not duplication for its own sake.
        // _accrueRewardToken records to reward_token_missed when it cannot
        // cover a credit - so routing this through it would, on a shortfall,
        // add the amount to missed a SECOND time while the original was still
        // sitting there. The debt would grow every time a player tried to
        // collect it.
        //
        // Safe to call at any time. Nothing missed, or no headroom, returns 0
        // rather than reverting - "there is nothing to move yet" is a normal
        // answer, not an error.
        fn claim_missed_reward_token(ref self: ContractState) -> u256 {
            let gamerWalletAddress: ContractAddress = get_caller_address();

            let missed: u256 = self.reward_token_missed.read(gamerWalletAddress);

            if (missed == 0) {
                return 0;
            }

            let rewardTokenAddress: ContractAddress = self
                .game_reward_token_contract_address
                .read();

            // No token to pay from, so nothing can be covered yet. The record
            // stays exactly as it is.
            if (rewardTokenAddress.is_zero()) {
                return 0;
            }

            // Same live read as the coverage rule in _accrueRewardToken, and for
            // the same reason - a tracked budget drifts the moment somebody
            // transfers ROZ in, which is how funding arrives.
            let reward_token_dispatcher = ERC20ABIDispatcher {
                contract_address: rewardTokenAddress,
            };
            let heldBalance: u256 = reward_token_dispatcher.balance_of(get_contract_address());
            let alreadyOwed: u256 = self.total_reward_token_pending.read();

            // What the contract could promise without breaking the invariant
            // that every pending balance stays payable. Guarded rather than
            // subtracted: a u256 cannot go negative, and being over-committed is
            // simply "no headroom".
            if (heldBalance <= alreadyOwed) {
                return 0;
            }

            let headroom: u256 = heldBalance - alreadyOwed;

            let converting: u256 = if missed > headroom {
                headroom
            } else {
                missed
            };

            self.reward_token_missed.write(gamerWalletAddress, missed - converting);

            let totalMissed: u256 = self.total_reward_token_missed.read();

            self.total_reward_token_missed.write(totalMissed - converting);

            let currentlyPending: u256 = self.reward_token_pending.read(gamerWalletAddress);

            self.reward_token_pending.write(gamerWalletAddress, currentlyPending + converting);
            self.total_reward_token_pending.write(alreadyOwed + converting);

            self
                .emit(
                    Event::RewardTokenMissedRecovered(
                        RewardTokenMissedRecovered {
                            user: gamerWalletAddress,
                            amount: converting,
                            remaining: missed - converting,
                        },
                    ),
                );

            return converting;
        }

        // Whether the ROZ leg of a given week has settled. False after a claim
        // made while the contract was unfunded, which is the signal to call
        // claim_reward_token_for_week.
        fn get_reward_token_claimed(
            self: @ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
        ) -> bool {
            return self.reward_token_claimed.read((gameWeek, gamerWalletAddress));
        }

        // Whether the USDC leg of a given week has been claimed - the exact
        // counterpart of get_reward_token_claimed above.
        //
        // WITHOUT THIS, CLAIM DISCOVERY IS IMPOSSIBLE FROM OUTSIDE. Nothing
        // else exposes claimed_rewards:
        //
        //   - _transfer_token is a raw call_contract_syscall and emits no
        //     event, so a claim leaves no trace for an indexer to find.
        //   - Probing claim_reward with a read-only call does not work
        //     either, because get_caller_address() is 0 in a call - the probe
        //     reports address zero's state, not the player's.
        //   - get_reward_token_claimed is not a usable substitute. It stays
        //     false whenever the ROZ leg was skipped for want of funding,
        //     which is every claim made while the contract holds no ROZ.
        //
        // Note the parameters read (address, week) while the storage key is
        // (week, address). That inversion is the convention every getter here
        // already follows.
        fn get_reward_claimed(
            self: @ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
        ) -> bool {
            return self.claimed_rewards.read((gameWeek, gamerWalletAddress));
        }

        // Every week in fromWeek..=toWeek this wallet can still claim USDC for.
        //
        // One call in place of a probe per round. Each week returned is one
        // claim_reward will accept, because _isRewardClaimable applies all
        // three of its conditions - so a caller can batch the returned weeks
        // into a multicall without checking them again. Amounts come from
        // get_player_reward_due, which is safe on exactly these weeks.
        //
        // Both bounds are INCLUSIVE.
        fn get_claimable_weeks(
            self: @ContractState, gamerWalletAddress: ContractAddress, fromWeek: u256, toWeek: u256,
        ) -> Array<u256> {
            assert(fromWeek <= toWeek, 'bad week range');

            // A view carries no gas meter, but it does have a step limit, and
            // an unbounded range would quietly hit it and fail the call. 256
            // rounds is far beyond any window a caller needs - the frontend
            // reads the most recent handful.
            assert(toWeek - fromWeek < 256, 'week range too wide');

            let mut claimable = ArrayTrait::<u256>::new();

            let currentWeek: u256 = self.currentGameWeek.read();

            // Nothing has finished yet, so nothing can be claimed. Returned
            // early because the clamp below subtracts one from this and a u256
            // cannot go negative - at week 0 that would panic.
            if (currentWeek == 0) {
                return claimable;
            }

            // Condition 1 can never hold above the last finished round, so
            // there is no point walking past it.
            let lastFinishedWeek: u256 = currentWeek - 1;

            let upperBound: u256 = if toWeek > lastFinishedWeek {
                lastFinishedWeek
            } else {
                toWeek
            };

            // The clamp can pull the top below the bottom - asking about
            // future rounds only. That is a legitimate question with an empty
            // answer, not an error.
            if (fromWeek > upperBound) {
                return claimable;
            }

            let mut week: u256 = fromWeek;

            while (week <= upperBound) {
                if (self._isRewardClaimable(gamerWalletAddress, week)) {
                    claimable.append(week);
                }

                week += 1_u256;
            }

            return claimable;
        }

        // The typed share counts behind a week's ROZ, and the survival reward
        // stored at hide time.
        fn get_reward_token_due(
            self: @ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
        ) -> (u256, u256, u256) {
            return (
                self.hider_share_amounts.read((gameWeek, gamerWalletAddress)),
                self.finder_share_amounts.read((gameWeek, gamerWalletAddress)),
                self.hider_survival_roz.read((gameWeek, gamerWalletAddress)),
            );
        }

        // Points the game at a different VRF provider. ADMIN_ROLE only, after
        // the matching proposal has waited the upgrade delay.
        //
        // This is what makes the current Sepolia workaround reversible without a
        // redeploy. The game is presently pointed at the testnet MockVrfProvider
        // (src/mock_vrf_provider.cairo) because Cartridge's Sepolia paymaster is
        // down and their real provider therefore always reverts with
        // 'VrfProvider: not fulfilled'. As soon as that service recovers, one
        // call switches the game straight back to real, verifiable randomness:
        //
        //   update_vrf_provider(
        //       0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f
        //   )
        //
        // A player cannot redirect the game at a provider of their own that
        // returns coordinates they picked; the exact address must have been
        // published through propose_vrf_provider_update first.
        fn update_vrf_provider(
            ref self: ContractState, vrfProviderAddress: ContractAddress,
        ) -> bool {
            let action_hash = self
                ._admin_action_hash(ACTION_VRF_PROVIDER, vrfProviderAddress.into(), 0);
            self._consume_admin_action(ACTION_VRF_PROVIDER, action_hash, false);
            self.vrf_provider_contract_address.write(vrfProviderAddress);
            return true;
        }

        // Reads back whichever provider the game is currently using. Anyone can
        // call this - it is the quickest way to confirm, after a deploy or after
        // update_vrf_provider, that the game is talking to the provider you
        // think it is.
        // Points the game at a different ERC-20 for fees and rewards. This is a
        // delayed ADMIN_ROLE operation.
        //
        // Handle with care - this is a setup and migration lever, not a routine
        // one. Two things go wrong if it is used casually:
        //
        //   1. DECIMALS. Every fee stored in this contract is a raw token amount.
        //      The current values assume 6 decimals (USDC). Switching to an
        //      18-decimal token such as ETH without also calling the update_*_fee
        //      setters would make every fee one-trillionth of its intended value.
        //   2. STRANDED BALANCE. Fees already collected stay in the old token, and
        //      withdraw_token_balance only reaches the currently configured one.
        //      Sweep the old token BEFORE switching.
        //
        // Doing this mid-round also means players who approved a spend budget on
        // the old token have not approved anything on the new one, so their next
        // action reverts on 'token spend approval req' until they re-approve.
        fn update_game_token(ref self: ContractState, gameTokenAddress: ContractAddress) -> bool {
            let action_hash = self
                ._admin_action_hash(ACTION_GAME_TOKEN, gameTokenAddress.into(), 0);
            self._consume_admin_action(ACTION_GAME_TOKEN, action_hash, false);
            self.game_token_contract_address.write(gameTokenAddress);
            return true;
        }

        // Reads back the token the game is currently charging fees in. Anyone can
        // call this; it is the quickest way to confirm a deploy wired up the token
        // you intended.
        // ------------------------------------------------------------------
        // ROZ reward token - address and rates (4a, 4b)
        // ------------------------------------------------------------------

        // A setup lever, not a live one. Changing this while players hold
        // pending ROZ strands them: total_reward_token_pending still counts IOUs
        // denominated in the OLD token, while the coverage check in 4c-i reads
        // the balance of the new one. Treat it exactly like update_game_token.
        fn update_game_reward_token(
            ref self: ContractState, rewardTokenAddress: ContractAddress,
        ) -> bool {
            let action_hash = self
                ._admin_action_hash(ACTION_REWARD_TOKEN, rewardTokenAddress.into(), 0);
            self._consume_admin_action(ACTION_REWARD_TOKEN, action_hash, false);
            self.game_reward_token_contract_address.write(rewardTokenAddress);
            return true;
        }

        // One wrapper returns all immutable-at-deploy wiring. Each address can
        // still be changed only through its delayed administration action.
        fn get_contract_addresses(
            self: @ContractState,
        ) -> (ContractAddress, ContractAddress, ContractAddress) {
            return (
                self.vrf_provider_contract_address.read(),
                self.game_token_contract_address.read(),
                self.game_reward_token_contract_address.read(),
            );
        }

        fn get_reward_rates(self: @ContractState) -> (u256, u256, u256, u256, u256) {
            return (
                self.rewardHide.read(),
                self.rewardHideSurvived.read(),
                self.rewardFind.read(),
                self.rewardParticipation.read(),
                self.rewardPerHop.read(),
            );
        }

        fn get_below_threshold_rates(self: @ContractState) -> (u256, u256, u256, u256) {
            return (
                self.hopRewardBelowThreshold.read(),
                self.participationBelowThreshold.read(),
                self.rewardHideBelowThreshold.read(),
                self.rewardHideSurvivedBelowThreshold.read(),
            );
        }

        fn get_new_wallet_rates(self: @ContractState) -> (u256, u256, u256, u256) {
            return (
                self.hopRewardNewWallet.read(),
                self.participationNewWallet.read(),
                self.rewardHideNewWallet.read(),
                self.rewardHideSurvivedNewWallet.read(),
            );
        }

        fn get_hop_limits(self: @ContractState) -> (u256, u256, u256, u256) {
            return (
                self.participationMinimumHops.read(),
                self.hopRewardCap.read(),
                self.dailyFreeHops.read(),
                self.dailyFreeSpawns.read(),
            );
        }

        // The soft cap covers hops and participation ONLY. Hides take the Daily
        fn get_soft_caps(self: @ContractState) -> (u256, u256, u256, u256) {
            return (
                self.dailySoftCapRoz.read(),
                self.newWalletSoftCapRoz.read(),
                self.softCapMultiplierNum.read(),
                self.softCapMultiplierDen.read(),
            );
        }

        fn get_gate_thresholds(self: @ContractState) -> (u256, u256) {
            return (self.dailySpendThreshold.read(), self.lifetimeSpendThreshold.read());
        }

        fn get_hide_settings(self: @ContractState) -> (u256, u256, u256, u256, u256) {
            return (
                self.hideFeeBase.read(),
                self.hideFeeHigh.read(),
                self.hideFeeTierBoundary.read(),
                self.dailyHideCap.read(),
                self.maxTreasuresPerRound.read(),
            );
        }

        // ------------------------------------------------------------------
        // The bulk-hide whitelist (4m-iii)
        // ------------------------------------------------------------------

        // Publishing a new root replaces the WHOLE list. There is no incremental
        // add or remove, and that is deliberate: the list is always exactly what
        // the published tree says it is.
        //
        // Regenerate the off-chain proof file whenever this changes. Every leaf
        // index shifts when the tree is rebuilt, so a stale proof file silently
        // drops addresses back to the ordinary daily cap.
        fn set_whitelist_merkle_root(ref self: ContractState, newRoot: felt252) -> bool {
            self._assert_admin();
            self.whitelist_merkle_root.write(newRoot);
            return true;
        }

        fn get_whitelist_merkle_root(self: @ContractState) -> felt252 {
            return self.whitelist_merkle_root.read();
        }

        // roundCap bounds ONE whitelisted address; collectiveCap bounds ALL of
        fn get_whitelist_caps(self: @ContractState) -> (u256, u256, u256) {
            return (
                self.whitelistRoundCap.read(),
                self.whitelistCollectiveCap.read(),
                self.whitelistHourlyCap.read(),
            );
        }

        // ------------------------------------------------------------------
        // Admin-settable schedules, one band at a time (2.3, 2.5)
        // ------------------------------------------------------------------

        // Bands are indexed from 0 and read in order, so upToHop must increase
        // with bandIndex. The last band should be left open-ended.
        // ------------------------------------------------------------------
        // set_params - ONE entrypoint for thirty-five scalar settings
        // ------------------------------------------------------------------
        //
        // WHY THIS REPLACED TWELVE SETTERS. Every #[external] function carries a
        // compiler-generated wrapper that deserialises its arguments and
        // serialises its result. Those wrappers were HALF the cost of the old
        // setters - 7,922 casm felts of the 15,457 they occupied - and Starknet
        // allows a class only 81,920 in total. Twelve wrappers became one.
        //
        // Two parallel arrays rather than one array of pairs: Cairo serialises a
        // tuple element by element regardless, and two arrays keep the calldata
        // readable in a block explorer.
        //
        // ATOMICITY IS THE POINT, not a side effect. The batch is applied and
        // THEN validated, so settings that are only legal together - the hide
        // fee tiers and the daily spend threshold, say - move in one transaction
        // without passing through an illegal state. The old per-setter asserts
        // could not express that: update_hide_settings checked itself against a
        // dailySpendThreshold that update_gate_thresholds had already moved, so
        // the two had to be called in a fixed order and could still be left
        // inconsistent if only one of them was called at all.
        //
        // THE CONSEQUENCE, and it is deliberate: the invariants are checked over
        // the WHOLE configuration on every call, not over the fields being
        // written. Changing one setting therefore requires the settings it
        // depends on to be consistent already, or to travel in the same batch.
        // On a freshly deployed contract the FIRST batch must use the exact
        // canonical 35-key order. The Poseidon check below rejects omissions,
        // duplicates and typos before any setting is written. See "Post-deploy
        // initialisation" in ROZ_DEPLOYMENT_AND_FUNDING.md.
        fn set_params(ref self: ContractState, keys: Array<felt252>, values: Array<u256>) -> bool {
            self._assert_admin();

            assert(keys.len() == values.len(), 'keys and values differ');
            assert(keys.len() > 0, 'no parameters given');

            // The first batch is the deployment boundary: it must contain each
            // of the thirty-five recognised settings exactly once. Unknown
            // keys fail in _applyParam and duplicates fail here, so length 35
            // proves the complete key set was supplied. Later admin updates
            // may intentionally change only the fields that travel together.
            let first_batch = !self.settings_initialized.read();
            if first_batch {
                assert(keys.len() == 35, 'initial batch must have 35');
                assert(
                    poseidon_hash_span(keys.span()) == INITIAL_SETTINGS_KEYS_HASH,
                    'initial keys invalid',
                );
            }

            let mut i: u32 = 0;
            loop {
                if (i == keys.len()) {
                    break;
                }
                let key = *keys.at(i);
                self._applyParam(key, *values.at(i));
                i = i + 1;
            }

            // Validate the RESULT, not the arguments. See the note above.
            self._assertSettingsInvariants();
            if first_batch {
                // Round zero was created while every configurable deduction
                // was still zero. Correct the already-staged round-one claim
                // snapshot in this same atomic initialization transaction.
                let deductions = self.gasFeeReservation.read()
                    + self.gameMasterFee.read()
                    + self.gameLandownerFee.read();
                let claim_value = self.currentHiderFee.read() - deductions;
                assert(claim_value > 0, 'deductions consume stake');
                self
                    .round_claim_value_per_share
                    .write(self.currentGameWeek.read() + 1, claim_value);
                self.settings_initialized.write(true);
            }

            return true;
        }

        fn update_price_band(
            ref self: ContractState, bandKind: u8, bandIndex: u8, upTo: u256, num: u256, den: u256,
        ) -> bool {
            self._assert_admin();
            assert(bandKind < 2, 'band kind out of range');
            assert(upTo > 0, 'band limit is zero');

            if bandKind == 0 {
                assert(den == 0, 'hop band den must be zero');
                assert(bandIndex < 4, 'hop band index out of range');
                assert(num > 0, 'hop band price is zero');
                let initialized = self.hop_bands_initialized.read();
                assert(bandIndex <= initialized, 'previous hop band missing');
                if bandIndex > 0 {
                    let previous_limit = self.hop_price_tier_limit.read(bandIndex - 1);
                    assert(previous_limit < upTo, 'hop bands not increasing');
                }
                if bandIndex == 3 {
                    assert(upTo == OPEN_ENDED_BAND, 'last hop band not open');
                }
                self.hop_price_tier_limit.write(bandIndex, upTo);
                self.hop_price_tier_price.write(bandIndex, num);
                // Updating an earlier band invalidates every later band until
                // the admin resubmits the tail in ascending order.
                self.hop_bands_initialized.write(bandIndex + 1);
            } else {
                assert(bandIndex < 6, 'volume band out of range');
                assert(den > 0, 'volume band den is zero');
                assert(num <= den, 'volume band above 1x');
                let initialized = self.volume_bands_initialized.read();
                assert(bandIndex <= initialized, 'previous volume band missing');
                if bandIndex > 0 {
                    let previous_limit = self.volume_band_limit.read(bandIndex - 1);
                    assert(previous_limit < upTo, 'volume bands not increasing');
                }
                if bandIndex == 5 {
                    assert(upTo == OPEN_ENDED_BAND, 'last volume band not open');
                }
                self.volume_band_limit.write(bandIndex, upTo);
                self.volume_band_num.write(bandIndex, num);
                self.volume_band_den.write(bandIndex, den);
                self.volume_bands_initialized.write(bandIndex + 1);
            }
            return true;
        }

        fn get_price_band(self: @ContractState, bandKind: u8, bandIndex: u8) -> (u256, u256, u256) {
            assert(bandKind < 2, 'band kind out of range');
            if bandKind == 0 {
                return (
                    self.hop_price_tier_limit.read(bandIndex),
                    self.hop_price_tier_price.read(bandIndex),
                    0,
                );
            }
            return (
                self.volume_band_limit.read(bandIndex),
                self.volume_band_num.read(bandIndex),
                self.volume_band_den.read(bandIndex),
            );
        }

        // ------------------------------------------------------------------
        // Per-player state (4e)
        // ------------------------------------------------------------------

        // Everything that resets at midnight UTC, in one call: hops today, ROZ
        // from hops today, hides today, spend today, free hops used today.
        fn get_player_daily_state(
            self: @ContractState, gamerWalletAddress: ContractAddress,
        ) -> (u256, u256, u256, u256, u256) {
            let dayIndex: u64 = self._currentDayIndex();
            return (
                self.player_hops_today.read((dayIndex, gamerWalletAddress)),
                self.player_hop_roz_today.read((dayIndex, gamerWalletAddress)),
                self.player_hides_today.read((dayIndex, gamerWalletAddress)),
                self.player_spend_today.read((dayIndex, gamerWalletAddress)),
                self.player_free_hops_used.read((dayIndex, gamerWalletAddress)),
            );
        }

        // The counter that decides new-wallet status. Never resets.
        fn get_player_lifetime_spend(
            self: @ContractState, gamerWalletAddress: ContractAddress,
        ) -> u256 {
            return self.player_lifetime_spend.read(gamerWalletAddress);
        }

        // What the UI needs to show "N free hops left today". Counts down from
        // dailyFreeHops and floors at zero.
        fn get_free_hops_remaining(
            self: @ContractState, gamerWalletAddress: ContractAddress,
        ) -> u256 {
            let dayIndex: u64 = self._currentDayIndex();
            let used: u256 = self.player_free_hops_used.read((dayIndex, gamerWalletAddress));
            let allowance: u256 = self.dailyFreeHops.read();

            if (used >= allowance) {
                return 0;
            }

            return allowance - used;
        }

        // Sweep a token out of the contract (4j).
        //
        // Now takes a token address, so ROZ sent here by mistake is recoverable
        // and an over-funded tranche can be reclaimed. Previously it could only
        // move the configured game token, which is why ROZ transferred in was
        // stuck forever.
        //
        // TWO GUARDS, ONE RULE: money that belongs to players is not the
        // owner's to take, so each branch releases only the SURPLUS above what
        // is owed.
        //
        //   ROZ  - subtract total_reward_token_pending AND
        //          total_reward_token_missed. The first is the backing for every
        //          accrued balance; without it the admin could sweep it and
        //          claim_reward_tokens would start failing, which is exactly the
        //          failure the coverage rule in 4c-i exists to prevent. The
        //          second is ROZ players earned while the contract was unfunded
        //          and have not converted yet - equally theirs, just not yet in
        //          a payable form.
        //
        //          NOTE THE COST OF RESERVING MISSED. A wallet that never
        //          returns to call claim_missed_reward_token holds that much
        //          back from the admin permanently. That is deliberate: the
        //          alternative is sweeping money a player could still come back
        //          and claim, and a reward that can be withdrawn out from under
        //          the player is not a reward.
        //
        //   USDC - subtract total_usdc_claimable, the running total of hider
        //          stakes not yet claimed or lost to a finder. USDC owed is
        //          computed from shares on demand and never totalled anywhere
        //          else, so without that counter there is nothing to subtract
        //          and sweeping mid-round silently takes money players are
        //          entitled to.
        //
        // Any other token is fully sweepable - nobody has a claim on it. The
        // ordinary path still needs a delayed proposal. The explicit FULL path
        // ignores all reservations only while paused at proposal AND execution.
        fn withdraw_token_balance(
            ref self: ContractState, tokenAddress: ContractAddress, receiver: ContractAddress,
        ) {
            let action = self.pending_admin_action.read();
            assert(
                action == ACTION_SAFE_SWEEP || action == ACTION_FULL_SWEEP,
                'Withdrawal not proposed',
            );
            let action_hash = self._admin_action_hash(action, tokenAddress.into(), receiver.into());
            let full_sweep = action == ACTION_FULL_SWEEP;
            self._consume_admin_action(action, action_hash, full_sweep);

            let token_dispatcher = ERC20ABIDispatcher { contract_address: tokenAddress };
            let heldBalance: u256 = token_dispatcher.balance_of(get_contract_address());

            let mut owedToPlayers: u256 = 0;

            if (!full_sweep) {
                if (tokenAddress == self.game_reward_token_contract_address.read()) {
                    owedToPlayers = self.total_reward_token_pending.read()
                        + self.total_reward_token_missed.read();
                } else if (tokenAddress == self.game_token_contract_address.read()) {
                    owedToPlayers = self.total_usdc_claimable.read();
                }
            }

            // Nothing above what players are owed. Return rather than revert:
            // sweeping an empty surplus is a no-op, not an error.
            if (heldBalance <= owedToPlayers) {
                return;
            }

            token_dispatcher.transfer(receiver, heldBalance - owedToPlayers);
        }

        // What the sweep would release for a given token, without moving
        // anything. Lets the admin check the surplus before acting.
        fn get_sweepable_balance(self: @ContractState, tokenAddress: ContractAddress) -> u256 {
            let token_dispatcher = ERC20ABIDispatcher { contract_address: tokenAddress };
            let heldBalance: u256 = token_dispatcher.balance_of(get_contract_address());

            let mut owedToPlayers: u256 = 0;

            if (tokenAddress == self.game_reward_token_contract_address.read()) {
                owedToPlayers = self.total_reward_token_pending.read()
                    + self.total_reward_token_missed.read();
            } else if (tokenAddress == self.game_token_contract_address.read()) {
                owedToPlayers = self.total_usdc_claimable.read();
            }

            if (heldBalance <= owedToPlayers) {
                return 0;
            }

            return heldBalance - owedToPlayers;
        }
    }
}
