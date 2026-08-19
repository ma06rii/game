// A testnet-only stand-in for Cartridge's VRF provider, deployed while their
// Sepolia service is unavailable. It is a separate contract, never called from
// this file, and never deployed to mainnet. See src/mock_vrf_provider.cairo for
// the full explanation.
mod mock_vrf_provider;

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
use starknet::ContractAddress;

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
    fn start_new_game(
        ref self: TContractState,
        listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot: u256,
        finderFee: u256,
        hiderFee: u256,
        spawnNewPositionFee: u256,
        gameGridSizeX: u128,
        gameGridSizeY: u128,
        totalNumberOfHidersFromThePreviousWeek: u256,
        totalHiddenTreasureValueFromPreviousWeek: u256,
    ) -> bool;
    fn hide_treasure(ref self: TContractState) -> bool;
    fn hide_treasure_bulk(
        ref self: TContractState,
        bulkAmount: u256,
        merkleProof: Array<felt252>,
        leafIndex: u32,
    ) -> bool;
    fn validate_treasure_coordinates(
        ref self: TContractState,
        finderGamerWalletAddress: ContractAddress,
        hiderGamerWalletAddress: ContractAddress,
        gameWeek: u256,
        leaf: u256,
        proof: Array<u256>,
    ) -> bool;
    fn finder_player_move_position(ref self: TContractState, direction: u128) -> (u128, u128);
    fn get_finder_player_position(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> (u128, u128);
    fn update_gas_fee_reservation(ref self: TContractState, feeAmount: u256) -> bool;
    fn update_gamemaster_fee(ref self: TContractState, feeAmount: u256) -> bool;
    fn update_game_landowner_fee(ref self: TContractState, feeAmount: u256) -> bool;
    fn update_minimum_allowance_fee(ref self: TContractState, minimumAmount: u256) -> bool;
    fn get_minimum_allowance_fee(self: @TContractState) -> u256;
    fn claim_reward(ref self: TContractState, gameWeek: u256) -> bool;
    // The ROZ claim leg (4g, 4h, 4i)
    fn claim_reward_tokens(ref self: TContractState) -> bool;
    fn claim_reward_token_for_week(ref self: TContractState, gameWeek: u256) -> bool;
    fn get_reward_token_pending(
        self: @TContractState, gamerWalletAddress: ContractAddress,
    ) -> u256;
    fn get_total_reward_token_pending(self: @TContractState) -> u256;
    fn get_reward_token_claimed(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    fn get_reward_token_due(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> (u256, u256, u256);
    fn update_callback_fee_limit(ref self: TContractState, maxGasFeeAmount: u128) -> bool;
    fn update_publish_delay(ref self: TContractState, minNumberOfBlocks: u64) -> bool;
    fn update_num_words(ref self: TContractState, numberOfRandomNumbers: u64) -> bool;
    fn update_seed_modulo_divisor(ref self: TContractState, value: u256) -> bool;
    fn update_vrf_provider(ref self: TContractState, vrfProviderAddress: ContractAddress) -> bool;
    fn get_vrf_provider(self: @TContractState) -> ContractAddress;
    fn update_game_token(ref self: TContractState, gameTokenAddress: ContractAddress) -> bool;
    fn get_game_token(self: @TContractState) -> ContractAddress;
    // ROZ reward token - address and rates (4a, 4b)
    fn update_game_reward_token(
        ref self: TContractState, rewardTokenAddress: ContractAddress,
    ) -> bool;
    fn get_game_reward_token(self: @TContractState) -> ContractAddress;
    fn update_reward_rates(
        ref self: TContractState,
        hideReward: u256,
        hideSurvivedReward: u256,
        findReward: u256,
        participationReward: u256,
        perHopReward: u256,
    ) -> bool;
    fn get_reward_rates(self: @TContractState) -> (u256, u256, u256, u256, u256);
    fn update_below_threshold_rates(
        ref self: TContractState,
        perHopReward: u256,
        participationReward: u256,
        hideReward: u256,
        hideSurvivedReward: u256,
    ) -> bool;
    fn get_below_threshold_rates(self: @TContractState) -> (u256, u256, u256, u256);
    fn update_new_wallet_rates(
        ref self: TContractState,
        perHopReward: u256,
        participationReward: u256,
        hideReward: u256,
        hideSurvivedReward: u256,
    ) -> bool;
    fn get_new_wallet_rates(self: @TContractState) -> (u256, u256, u256, u256);
    // Limits and allowances (2.2, 2.3)
    fn update_hop_limits(
        ref self: TContractState,
        participationMinimum: u256,
        roundRewardCap: u256,
        freeHopsPerDay: u256,
        freeSpawnsPerDay: u256,
    ) -> bool;
    fn get_hop_limits(self: @TContractState) -> (u256, u256, u256, u256);
    fn update_soft_caps(
        ref self: TContractState, dailyCap: u256, newWalletCap: u256, num: u256, den: u256,
    ) -> bool;
    fn get_soft_caps(self: @TContractState) -> (u256, u256, u256, u256);
    // The Lightweight Gate (2.6) and hiding (2.3). These four move together -
    // see the invariant asserted in update_hide_settings.
    fn update_gate_thresholds(
        ref self: TContractState, dailyThreshold: u256, lifetimeThreshold: u256,
    ) -> bool;
    fn get_gate_thresholds(self: @TContractState) -> (u256, u256);
    fn update_hide_settings(
        ref self: TContractState,
        feeBase: u256,
        feeHigh: u256,
        feeTierBoundary: u256,
        dailyCap: u256,
        treasuresPerRound: u256,
    ) -> bool;
    fn get_hide_settings(self: @TContractState) -> (u256, u256, u256, u256, u256);
    // The bulk-hide whitelist (4m-iii)
    fn set_whitelist_merkle_root(ref self: TContractState, newRoot: felt252) -> bool;
    fn get_whitelist_merkle_root(self: @TContractState) -> felt252;
    fn update_whitelist_caps(
        ref self: TContractState, roundCap: u256, collectiveCap: u256, hourlyCap: u256,
    ) -> bool;
    fn get_whitelist_caps(self: @TContractState) -> (u256, u256, u256);
    // Owner-settable schedules, one band at a time (2.3, 2.5)
    fn update_hop_price_band(
        ref self: TContractState, bandIndex: u8, upToHop: u256, price: u256,
    ) -> bool;
    fn get_hop_price_band(self: @TContractState, bandIndex: u8) -> (u256, u256);
    fn update_volume_band(
        ref self: TContractState, bandIndex: u8, upToTreasures: u256, num: u256, den: u256,
    ) -> bool;
    fn get_volume_band(self: @TContractState, bandIndex: u8) -> (u256, u256, u256);
    // Per-player state, so a deploy can be inspected without a block explorer
    fn get_player_daily_state(
        self: @TContractState, gamerWalletAddress: ContractAddress,
    ) -> (u256, u256, u256, u256, u256);
    fn get_player_lifetime_spend(
        self: @TContractState, gamerWalletAddress: ContractAddress,
    ) -> u256;
    fn get_free_hops_remaining(
        self: @TContractState, gamerWalletAddress: ContractAddress,
    ) -> u256;
    fn receive_random_words(
        ref self: TContractState,
        requester_address: ContractAddress,
        request_id: u64,
        random_words: Span<felt252>,
        calldata: Array<felt252>,
    );
    fn finder_player_generate_position(ref self: TContractState) -> bool;
    fn withdraw_token_balance(
        ref self: TContractState, tokenAddress: ContractAddress, receiver: ContractAddress,
    );
    fn get_sweepable_balance(self: @TContractState, tokenAddress: ContractAddress) -> u256;
    fn get_game_landowner_fee(self: @TContractState) -> u256;
    fn get_num_words(self: @TContractState) -> u64;
    fn get_publish_delay(self: @TContractState) -> u64;
    fn get_callback_fee_limit(self: @TContractState) -> u128;
    fn get_gamemaster_fee(self: @TContractState) -> u256;
    fn get_gas_fee_reservation(self: @TContractState) -> u256;
    fn get_game_token_reward(self: @TContractState) -> u256;
    fn get_game_week(self: @TContractState) -> u256;
    fn get_game_week_treasure_total(self: @TContractState, gameWeek: u256) -> u256;
    fn get_game_grid_size(self: @TContractState, gameWeek: u256) -> (u128, u128);
    fn get_total_number_of_finders(self: @TContractState, gameWeek: u256) -> u256;
    fn get_total_number_of_hiders(self: @TContractState, gameWeek: u256) -> u256;
    fn get_main_game_info(self: @TContractState, gameWeek: u256) -> (u256, u256, u256);
    fn get_generate_position_fee(self: @TContractState) -> u256;
    fn get_hider_player_fee(self: @TContractState) -> u256;
    fn get_finder_player_fee(self: @TContractState) -> u256;
    fn get_claim_share_amounts(
        self: @TContractState, gameWeek: u256, gamerWalletAddress: ContractAddress,
    ) -> u256;
    fn get_player_reward_due(
        self: @TContractState, gameWeek: u256, gamerWalletAddress: ContractAddress,
    ) -> u256;
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
    fn _createNewGame(
        ref self: TContractState,
        listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot: u256,
        finderFee: u256,
        hiderFee: u256,
        spawnNewPositionFee: u256,
        gameGridSizeX: u128,
        gameGridSizeY: u128,
        totalNumberOfHidersFromThePreviousWeek: u256,
        totalHiddenTreasureValueFromPreviousWeek: u256,
        gameWeek: u256,
    ) -> bool;
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
    fn _claimReward(
        ref self: TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    fn _transfer_token(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn _createRandomnessCalldata(
        self: @TContractState, gamerWalletAddress: ContractAddress,
    ) -> Array<felt252>;
    fn _retrieveRandomnessCalldata(
        self: @TContractState, calldataArr: Array<felt252>,
    ) -> ContractAddress;
    fn _getSeed(self: @TContractState, finderGamerAddress: ContractAddress) -> u64;
    fn _request_randomness_from_vrf_provider(
        ref self: TContractState, caller: ContractAddress,
    ) -> bool;
}

#[starknet::contract]
mod HelloStarknet {
    use core::array::{ArrayTrait, SpanTrait};
    use core::integer::{BoundedInt, u128_byte_reverse};
    use core::keccak::{cairo_keccak, keccak_u256s_be_inputs, keccak_u256s_le_inputs};
    use core::num::traits::zero::Zero;
    use core::option::OptionTrait;
    use core::serde::Serde;
    use core::hash::{HashStateExTrait, HashStateTrait};
    // Poseidon is the hash the off-chain merkle tooling uses for the bulk-hide
    // whitelist. The two MUST agree - a Pedersen tree would produce proofs that
    // never verify here, and the failure is silent (the caller simply falls back
    // to the ordinary daily cap). See _verifyWhitelist.
    use core::poseidon::PoseidonTrait;
    use core::to_byte_array::FormatAsByteArray;
    use core::traits::{Into, TryInto};
    use openzeppelin::access::ownable::OwnableComponent;
    // use pragma_lib::abi::{IRandomnessDispatcher, IRandomnessDispatcherTrait};
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use project_name::IHelloStarknet;
    use starknet::class_hash::class_hash_const;
    use starknet::{
        ContractAddress, SyscallResultTrait, contract_address_const, get_block_number,
        get_block_timestamp, get_caller_address, get_contract_address, syscalls,
    };
    use super::{IVrfProvider, IVrfProviderDispatcher, IVrfProviderDispatcherTrait, Source};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TreasureHidden: TreasureHidden,
        TreasureHiddenBulk: TreasureHiddenBulk,
        TreasureFound: TreasureFound,
        PlayerPosition: PlayerPosition,
        CheckForTreasure: CheckForTreasure,
        RewardTokenAccrued: RewardTokenAccrued,
        RewardTokenAccrualSkipped: RewardTokenAccrualSkipped,
        RewardTokenClaimed: RewardTokenClaimed,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    // Emitted once per bulk hide rather than once per treasure. Coordinates are
    // assigned off-chain and the merkle root arrives later through
    // start_new_game, so the backend that places treasures only needs to know
    // HOW MANY were bought - emitting one event per treasure would cost gas for
    // no extra information.
    #[derive(Drop, starknet::Event)]
    struct TreasureHiddenBulk {
        #[key]
        user: ContractAddress,
        hiderFee: u256,
        treasureCount: u256,
        #[key]
        gameWeek: u256,
    }

    // The feedback signal the off-chain map-scaling controller runs on. Without
    // hopsTaken there is no way to compute the median hops per find, and K has
    // no input to adjust against.
    #[derive(Drop, starknet::Event)]
    struct TreasureFound {
        #[key]
        user: ContractAddress,
        hopsTaken: u256,
        #[key]
        gameWeek: u256,
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

    #[derive(Drop, starknet::Event)]
    struct TreasureHidden {
        #[key]
        user: ContractAddress,
        hiderFee: u256,
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
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        //Divisor used to get a value to generate a seed value for randmoness request.
        seedModuloDivisor: u256,
        //Randomness Request
        //Address of the VRF provider this game asks for random numbers. Set from
        //a constructor argument and changeable afterwards by the owner through
        //update_vrf_provider, so the game can be pointed at Cartridge's real
        //provider or at a testnet mock without redeploying.
        vrf_provider_contract_address: ContractAddress,
        min_block_number_storage: u64,
        callback_fee_limit: u128, // e.g. 1000000000000
        publish_delay: u64, // e.g. 3
        num_words: u64, // e.g. 2
        //Game token
        //The ERC-20 that every fee, reward and treasure value in this contract is
        //denominated in. Set from a constructor argument and changeable afterwards
        //by the owner through update_game_token.
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
        dailyFreeHops: u256, // 22 - deliberately BELOW 28, see below
        dailyFreeSpawns: u256, // 1
        dailySoftCapRoz: u256, // 136 - hops + participation only
        softCapMultiplierNum: u256, // 1 } 0.2x beyond the soft cap
        softCapMultiplierDen: u256, // 5 }
        newWalletSoftCapRoz: u256, // 80 - near inert, ~142 hops to bind
        // dailyFreeHops (22) MUST stay strictly below participationMinimumHops
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
        // Only the owner writes this. Publishing a new root replaces the whole
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
        //The sum of every USDC a player can still claim. USDC owed is computed
        //from shares on demand and never totalled, so without this the sweep
        //has nothing to subtract and would strand outstanding claims.
        total_usdc_claimable: u256,
        // ------------------------------------------------------------------
        // Owner-settable schedules, indexed by band (2.3, 2.5)
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
    ) {
        self
            ._createNewGame(
                0xbc19a39ffdeb3ff487a290fd65626b9592fe3fb625937ab468940c4c58966849,
                100000, //$ 0.10 finder fee
                5000000, //$ 5.00 hider fee
                1000000, //$ 1.00 spawn new position
                14,
                14,
                3,
                15000000, // 3 hiders x $5 minimum value of hidden treasure = $15.00
                0,
            );

        let ownerAddress: ContractAddress = contract_address_const::<
            0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833,
        >();

        self.ownable.initializer(ownerAddress);
        self.gasFeeReservation.write(3333); //$ 0.0033 held back to cover gas
        self.gameMasterFee.write(8333); //$ 0.0083 to the game master
        self.gameLandownerFee.write(1167); //$ 0.0012 to the landowner
        // callback_fee_limit, publish_delay, num_words and seedModuloDivisor are
        // leftovers from the old Pragma VRF flow and are no longer read on any
        // live path. callback_fee_limit is a gas allowance, not a game-token
        // amount, so it is deliberately NOT rescaled with the fees above.
        self.callback_fee_limit.write(5000000000000000);
        self.publish_delay.write(0);
        self.num_words.write(1_u64);
        self.seedModuloDivisor.write(128000000000);

        // Previously hardcoded here. Now supplied by whoever deploys the class,
        // so testnet and mainnet can point at different providers. See the
        // comment above this constructor for the addresses involved.
        self.vrf_provider_contract_address.write(vrfProviderAddress);

        // Likewise supplied at deploy time. Currently USDC on Sepolia,
        // 0x0512feac6339ff7889822cb5aa2a86c848e9d392bb0e3e237c008674feed8343.
        self.game_token_contract_address.write(gameTokenAddress);

        self.currentGameTokenReward.write(11666667); //$ 11.6667 reward per share

        self.minimumAllowance.write(7000000); //$ 7.00 minimum spend approval

        // The ROZ token, deployed in phase 1 and passed in here.
        self.game_reward_token_contract_address.write(rewardTokenAddress);

        self._initialiseRewardSettings();
    }

    // Every ROZ reward setting, in one place, called once from the constructor.
    //
    // It is a separate function rather than inline constructor code for a
    // practical reason: if this contract is ever made upgradeable, an upgrade
    // does NOT re-run the constructor, so any setting added in a later version
    // would read back as zero - and a zero dailyHideCap or maxTreasuresPerRound
    // silently stops all hiding. Keeping the defaults in one owner-callable
    // shape means a future version can re-apply them deliberately.
    #[generate_trait]
    impl RewardSettingsInit of RewardSettingsInitTrait {
        fn _initialiseRewardSettings(ref self: ContractState) {
            // --- Full rates, raw 18-decimal ROZ (2.2) ---
            self.rewardHide.write(30000000000000000000); // 30
            self.rewardHideSurvived.write(50000000000000000000); // 50
            self.rewardFind.write(110000000000000000000); // 110
            self.rewardParticipation.write(18000000000000000000); // 18
            self.rewardPerHop.write(1000000000000000000); // 1

            // --- Reduced rates (2.6). Absolute values, never multipliers. ---
            // Below the daily spend threshold:
            self.hopRewardBelowThreshold.write(150000000000000000); // 0.15
            self.participationBelowThreshold.write(0); // withdrawn
            self.rewardHideBelowThreshold.write(4500000000000000000); // 4.5
            self.rewardHideSurvivedBelowThreshold.write(7500000000000000000); // 7.5
            // New wallet, under $3 of lifetime spend:
            self.hopRewardNewWallet.write(500000000000000000); // 0.5
            self.participationNewWallet.write(9000000000000000000); // 9
            self.rewardHideNewWallet.write(15000000000000000000); // 15
            self.rewardHideSurvivedNewWallet.write(25000000000000000000); // 25
            // 0.15, 0.5, 4.5, 7.5, 15 and 25 are all exact in 18 decimals, so
            // no numerator/denominator pairs are needed and no rounding occurs.

            // --- Limits and allowances (2.2, 2.3) ---
            self.participationMinimumHops.write(28);
            self.hopRewardCap.write(40); // per ROUND
            self.dailyFreeHops.write(22); // strictly below 28
            self.dailyFreeSpawns.write(1);
            self.dailySoftCapRoz.write(136000000000000000000); // 136
            self.softCapMultiplierNum.write(1); // 0.2x
            self.softCapMultiplierDen.write(5);
            self.newWalletSoftCapRoz.write(80000000000000000000); // 80

            // --- Gate thresholds (2.6). Game-token units, 6 decimals. ---
            self.dailySpendThreshold.write(600000); // $0.60
            self.lifetimeSpendThreshold.write(3000000); // $3.00

            // --- Hiding (2.3) ---
            self.hideFeeBase.write(200000); // $0.20
            self.hideFeeHigh.write(250000); // $0.25
            self.hideFeeTierBoundary.write(3);
            self.dailyHideCap.write(10);
            self.maxTreasuresPerRound.write(2840);

            // --- Whitelist (4m-iii) ---
            self.whitelistRoundCap.write(250);
            self.whitelistCollectiveCap.write(1200); // leaves 1,640 for others
            self.whitelistHourlyCap.write(80);
            // No root until the owner publishes one. Until then every proof
            // fails, which simply means nobody is whitelisted - the correct
            // starting state, not an error.
            self.whitelist_merkle_root.write(0);

            // --- Progressive hop prices (2.5) ---
            // Band i covers hops up to hop_price_tier_limit[i] of the DAY. The
            // free allowance is applied before this, so band 0 starts at hop 23.
            self.hop_price_tier_limit.write(0, 25);
            self.hop_price_tier_price.write(0, 5000); //  $0.005
            self.hop_price_tier_limit.write(1, 45);
            self.hop_price_tier_price.write(1, 10000); //  $0.010
            self.hop_price_tier_limit.write(2, 65);
            self.hop_price_tier_price.write(2, 20000); //  $0.020
            // The last band is open-ended: anything past the previous limit.
            self.hop_price_tier_limit.write(3, 0xffffffffffffffffffffffffffffffff);
            self.hop_price_tier_price.write(3, 40000); //  $0.040

            // --- Daily Volume Multiplier (2.3) ---
            // Band i applies when the wallet has ALREADY created up to
            // volume_band_limit[i] treasures today, before this one. So
            // treasures 1-3 sit in band 0, treasures 4-5 in band 1, and so on.
            //
            // Band 0 covering three treasures is deliberate and lines up with
            // two other settings: hideFeeTierBoundary is also 3, and 3 hides at
            // the base fee is exactly dailySpendThreshold. Three hides is the
            // designed shape of an ordinary hiding day - cheap fee, full rate,
            // and it lands the player exactly on the gate.
            self.volume_band_limit.write(0, 2);
            self.volume_band_num.write(0, 1);
            self.volume_band_den.write(0, 1); // 1.00x
            self.volume_band_limit.write(1, 4);
            self.volume_band_num.write(1, 7);
            self.volume_band_den.write(1, 10); // 0.70x
            self.volume_band_limit.write(2, 6);
            self.volume_band_num.write(2, 2);
            self.volume_band_den.write(2, 5); // 0.40x
            self.volume_band_limit.write(3, 8);
            self.volume_band_num.write(3, 1);
            self.volume_band_den.write(3, 5); // 0.20x
            self.volume_band_limit.write(4, 10);
            self.volume_band_num.write(4, 2);
            self.volume_band_den.write(4, 25); // 0.08x
            // Open-ended tail. Only reachable by a whitelisted address, since
            // dailyHideCap stops everyone else at 10.
            self.volume_band_limit.write(5, 0xffffffffffffffffffffffffffffffff);
            self.volume_band_num.write(5, 3);
            self.volume_band_den.write(5, 100); // 0.03x
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
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
            self: @ContractState,
            caller: ContractAddress,
            proof: Array<felt252>,
            leafIndex: u32,
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
            ref self: ContractState,
            caller: ContractAddress,
            gameWeek: u256,
            treasureCount: u256,
        ) {
            // 1. Per address, per round. Stops one whitelisted address taking
            //    the whole round - 250 is 8.8% of 2,840.
            let roundCount: u256 = self.whitelist_round_count.read((caller, gameWeek));

            assert(
                roundCount + treasureCount <= self.whitelistRoundCap.read(),
                'whitelist round cap',
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
        fn _creditParticipationIfDue(
            ref self: ContractState, gamerWalletAddress: ContractAddress,
        ) {
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
        // The cap is set to 136, just under the 136.35 a 160-hop day can
        // actually reach, so in practice it binds only the wallet that clears
        // $0.60 on spawns BEFORE it starts hopping. An honest active player
        // reaches about 95.85 and never meets it at all. That is deliberate: it
        // is a backstop against one shape of farm, not a brake on real play.
        fn _applyHopSoftCap(
            ref self: ContractState, gamerWalletAddress: ContractAddress, amount: u256,
        ) -> u256 {
            let dayIndex: u64 = self._currentDayIndex();
            let earnedToday: u256 = self
                .player_hop_roz_today
                .read((dayIndex, gamerWalletAddress));

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
            // Have to make sure that the caller is the Pragma Randomness Oracle contract
            // let caller_address = get_caller_address();
            // assert(
            //     caller_address == self.vrf_provider_contract_address.read(),
            //     'caller not randomness contract'
            // );
            // and that the current block is within publish_delay of the request block
            // let current_block_number = get_block_number();
            // let min_block_number = self.min_block_number_storage.read();
            // assert(min_block_number <= current_block_number, 'block number issue');

            let gameWeek = self.currentGameWeek.read();

            // let random_word_0: felt252 = *random_words.at(0);
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

            // let gamerWalletAddressFromCalldata: ContractAddress = self
            //     ._retrieveRandomnessCalldata(calldata);

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
                    },
                );

            true
        }

        fn _verify(self: @ContractState, _root: u256, _leaf: u256, _proof: Array<u256>) -> bool {
            let mut computed_hash: u256 = _leaf;
            let proofLength: u32 = _proof.len();

            let mut i: u32 = 0;

            loop {
                if i > proofLength - 1 {
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

        fn _keccak256(self: @ContractState, a: u256, b: u256) -> u256 {
            let res: u256 = keccak::keccak_u256s_be_inputs(array![a, b].span());
            //reverse_endianness
            let new_value_2: u256 = u256 {
                low: u128_byte_reverse(res.high), high: u128_byte_reverse(res.low),
            };
            return new_value_2;
        }

        fn _createNewGame(
            ref self: ContractState,
            listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot: u256,
            finderFee: u256,
            hiderFee: u256,
            spawnNewPositionFee: u256,
            gameGridSizeX: u128,
            gameGridSizeY: u128,
            totalNumberOfHidersFromThePreviousWeek: u256,
            totalHiddenTreasureValueFromPreviousWeek: u256,
            gameWeek: u256,
        ) -> bool {
            //Increment game week
            self.currentGameWeek.write(gameWeek);
            self.currentFinderFee.write(finderFee);
            self.currentHiderFee.write(hiderFee);
            self.currentSpawnNewPositionFee.write(spawnNewPositionFee);

            //Update main game settings
            self
                .main_game
                .write(
                    gameWeek,
                    (listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot, finderFee, hiderFee),
                );
            self.main_game_grid_size.write(gameWeek, (gameGridSizeX, gameGridSizeY));

            //Update reward total share values
            self
                .total_reward_shares_for_hiders
                .write(gameWeek, totalNumberOfHidersFromThePreviousWeek);
            self.game_totals.write(gameWeek, totalHiddenTreasureValueFromPreviousWeek);

            return true;
        }

        fn _createRandomnessCalldata(
            self: @ContractState, gamerWalletAddress: ContractAddress,
        ) -> Array<felt252> {
            let mut calldataArr = ArrayTrait::<felt252>::new();

            calldataArr.append(gamerWalletAddress.into());

            return calldataArr;
        }

        fn _retrieveRandomnessCalldata(
            self: @ContractState, calldataArr: Array<felt252>,
        ) -> ContractAddress {
            let decodeAddress: felt252 = *calldataArr.at(0);

            let contractAddressAgain: ContractAddress = decodeAddress.try_into().unwrap();

            return contractAddressAgain;
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
                assert(
                    hidesToday + treasureCount <= self.dailyHideCap.read(), 'daily hide cap',
                );
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

            // The stake is owed back to the player, so the sweep in 4j must not
            // be able to take it.
            let claimableSoFar: u256 = self.total_usdc_claimable.read();
            self.total_usdc_claimable.write(claimableSoFar + totalStake);

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
                let feeForThisTreasure: u256 = if (alreadyToday
                    < self.hideFeeTierBoundary.read()) {
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
            self
                .total_reward_shares_for_hiders
                .write(gameWeek, alreadyHidden + treasureCount);

            // One event for a single hide, so the existing consumer keeps
            // working unchanged; a separate one for bulk. Emitting one event per
            // treasure would cost gas for no extra information, since
            // coordinates are assigned off-chain and arrive later as a root.
            if (treasureCount == 1_u256) {
                self
                    .emit(
                        TreasureHidden {
                            user: caller, hiderFee: stakePerTreasure, gameWeek: gameWeek,
                        },
                    );
            } else {
                self
                    .emit(
                        Event::TreasureHiddenBulk(
                            TreasureHiddenBulk {
                                user: caller,
                                hiderFee: totalFeeCharged,
                                treasureCount: treasureCount,
                                gameWeek: gameWeek,
                            },
                        ),
                    );
            }

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

            if (hiderShares > 0) {
                let survivalOwed = self.hider_survival_roz.read((gameWeek, hiderWalletAddress));
                let perShare = survivalOwed / hiderShares;

                self
                    .hider_share_amounts
                    .write((gameWeek, hiderWalletAddress), hiderShares - 1_u256);
                self
                    .hider_survival_roz
                    .write((gameWeek, hiderWalletAddress), survivalOwed - perShare);
            }

            let finderShares = self.finder_share_amounts.read((gameWeek, finderWalletAddress));
            self
                .finder_share_amounts
                .write((gameWeek, finderWalletAddress), finderShares + 1_u256);

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
            let finderShares: u256 = self
                .finder_share_amounts
                .read((gameWeek, gamerWalletAddress));
            let findRoz: u256 = finderShares * self.rewardFind.read();

            let totalRoz: u256 = survivalRoz + findRoz;

            if (totalRoz == 0) {
                // Nothing owed. Mark it settled so a retry does not keep
                // looking, and so the getter reports the week as done.
                self.reward_token_claimed.write((gameWeek, gamerWalletAddress), true);
                return true;
            }

            let credited: bool = self
                ._accrueRewardToken(gamerWalletAddress, totalRoz, 'claim');

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
        // This previously read the live currentHiderFee. Because start_new_game
        // rewrites that on every rollover, any fee change silently repriced every
        // reward players had not yet claimed - paying them a rate they never
        // agreed to, in either direction.
        fn _calculateRewardDue(
            self: @ContractState, claimShareCount: u256, gameWeek: u256,
        ) -> u256 {
            // Guard against u256 underflow rather than a real case: shares at week
            // 0 cannot exist, because hide_treasure always credits week 1 or later
            // and _removeGamerReward requires the hider to already hold one.
            // main_game[0] is seeded by the constructor, so the fallback is safe.
            let fundingWeek: u256 = if gameWeek == 0 {
                0
            } else {
                gameWeek - 1
            };

            let (_, _, gameHiderFee) = self.main_game.read(fundingWeek);

            let gasFee = self.gasFeeReservation.read();
            let gameFee = self.gameMasterFee.read();
            let gameLandownerFee = self.gameLandownerFee.read();

            assert(gameHiderFee > (gasFee + gameFee + gameLandownerFee), 'Reward is less than fees');

            // THE DEDUCTION IS PER TREASURE, NOT PER CLAIM (4m-ii).
            //
            // This previously read
            //
            //     eligibleReward = claimShareCount * gameHiderFee
            //     rewardDue      = eligibleReward - gasFee - gameFee - landowner
            //
            // which subtracted the three fees ONCE however many shares were
            // being claimed. A ten-share claim therefore paid the same 12,833
            // units as a single hide - ten times less than claiming ten times
            // separately. The three fees represent per-treasure costs, so
            // charging them per claim submitted is simply wrong.
            //
            // For a single share the arithmetic is IDENTICAL to before -
            // 5,000,000 - 12,833 = 4,987,167 - so this changes nothing for the
            // existing single-hide path. It only corrects multi-share claims.
            let rewardDue = claimShareCount
                * (gameHiderFee - gasFee - gameFee - gameLandownerFee);

            return rewardDue;
        }

        fn _getSeed(self: @ContractState, finderGamerAddress: ContractAddress) -> u64 {
            let getBlockNumber: u64 = get_block_number();

            let callerAsFelt: felt252 = finderGamerAddress.into();

            let callerAsNumber: u256 = callerAsFelt.try_into().unwrap();

            let callerAsu64: u64 = (callerAsNumber % self.seedModuloDivisor.read())
                .try_into()
                .unwrap();

            return callerAsu64 + getBlockNumber;
        }

        // Asks the configured VRF provider for one random number and turns it
        // straight into the player's starting grid position.
        //
        // Which provider answers is decided entirely by the address in storage,
        // set at deploy time and changeable by the owner through
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
        // (The commented-out code below is the older Pragma VRF flow, which used
        // a request now / callback later model. It is kept for reference only.)
        fn _request_randomness_from_vrf_provider(
            ref self: ContractState, caller: ContractAddress,
        ) -> bool {
            let randomness_contract_address = self.vrf_provider_contract_address.read();
            let randomness_dispatcher = IVrfProviderDispatcher {
                contract_address: randomness_contract_address,
            };

            // let callback_fee_limit = self.callback_fee_limit.read();
            // let publish_delay = self.publish_delay.read();
            // let num_words = self.num_words.read();

            // Approve the randomness contract to transfer the callback fee
            // Pragma charged its callback fee in ETH, which is why this dead block
            // still names ETH rather than the configured game token.
            // let eth_dispatcher = ERC20ABIDispatcher {
            //     contract_address: contract_address_const::<
            //         0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
            //     >() // ETH Contract Address
            // };
            // eth_dispatcher
            //     .approve(
            //         randomness_contract_address,
            //         (callback_fee_limit + callback_fee_limit / 5).into()
            //     );

            // let calldata = self._createRandomnessCalldata(caller);
            // let callback_address = get_contract_address();
            // let seed = self._getSeed(caller);

            // Request the randomness
            // randomness_dispatcher
            //     .request_random(
            //         seed, callback_address, callback_fee_limit, publish_delay, num_words,
            //         calldata
            //     );

            // randomness_dispatcher
            //     .request_random(
            //         callback_address, Source::Nonce(caller)
            //     );

            // let current_block_number = get_block_number();
            // self.min_block_number_storage.write(current_block_number + publish_delay);

            //Add here the code to consume the random number immediately
            //receive_random_words
            //Source::Nonce(caller) says "the randomness for this player". The
            //frontend names the same source in its own request_random call, so
            //both halves of the spawn multicall refer to the same request.
            let random_value = randomness_dispatcher.consume_random(Source::Nonce(caller));
            //check if random_value is valid

            self._receive_random_words_2(caller, random_value);
            //update function to return 'true'
            //Then add an assertion check that this function was executed successfully.

            return true;
        }
    }

    #[abi(embed_v0)]
    impl HelloStarknetImpl of super::IHelloStarknet<ContractState> {
        fn update_gas_fee_reservation(ref self: ContractState, feeAmount: u256) -> bool {
            self.ownable.assert_only_owner();
            self.gasFeeReservation.write(feeAmount);
            return true;
        }

        fn get_gas_fee_reservation(self: @ContractState) -> u256 {
            return self.gasFeeReservation.read();
        }

        fn update_gamemaster_fee(ref self: ContractState, feeAmount: u256) -> bool {
            self.ownable.assert_only_owner();
            self.gameMasterFee.write(feeAmount);
            return true;
        }

        fn get_gamemaster_fee(self: @ContractState) -> u256 {
            return self.gameMasterFee.read();
        }

        fn update_callback_fee_limit(ref self: ContractState, maxGasFeeAmount: u128) -> bool {
            self.ownable.assert_only_owner();
            self.callback_fee_limit.write(maxGasFeeAmount);
            return true;
        }

        fn get_callback_fee_limit(self: @ContractState) -> u128 {
            return self.callback_fee_limit.read();
        }

        fn update_publish_delay(ref self: ContractState, minNumberOfBlocks: u64) -> bool {
            self.ownable.assert_only_owner();
            self.publish_delay.write(minNumberOfBlocks);
            return true;
        }

        fn get_publish_delay(self: @ContractState) -> u64 {
            return self.publish_delay.read();
        }

        fn update_num_words(ref self: ContractState, numberOfRandomNumbers: u64) -> bool {
            self.ownable.assert_only_owner();
            self.num_words.write(numberOfRandomNumbers);
            return true;
        }

        fn get_num_words(self: @ContractState) -> u64 {
            return self.num_words.read();
        }

        fn update_game_landowner_fee(ref self: ContractState, feeAmount: u256) -> bool {
            self.ownable.assert_only_owner();
            self.gameLandownerFee.write(feeAmount);
            return true;
        }

        fn update_minimum_allowance_fee(ref self: ContractState, minimumAmount: u256) -> bool {
            self.ownable.assert_only_owner();
            self.minimumAllowance.write(minimumAmount);
            return true;
        }

        fn get_minimum_allowance_fee(self: @ContractState) -> u256 {
            return self.minimumAllowance.read();
        }

        fn get_game_landowner_fee(self: @ContractState) -> u256 {
            return self.gameLandownerFee.read();
        }

        fn get_finder_player_fee(self: @ContractState) -> u256 {
            return self.currentFinderFee.read();
        }

        fn get_hider_player_fee(self: @ContractState) -> u256 {
            return self.currentHiderFee.read();
        }

        fn get_generate_position_fee(self: @ContractState) -> u256 {
            return self.currentSpawnNewPositionFee.read();
        }

        fn get_main_game_info(self: @ContractState, gameWeek: u256) -> (u256, u256, u256) {
            return self.main_game.read(gameWeek);
        }

        fn get_total_number_of_hiders(self: @ContractState, gameWeek: u256) -> u256 {
            return self.total_reward_shares_for_hiders.read(gameWeek);
        }

        fn get_total_number_of_finders(self: @ContractState, gameWeek: u256) -> u256 {
            return self.total_reward_shares_for_finders.read(gameWeek);
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

        fn get_game_token_reward(self: @ContractState) -> u256 {
            return self.currentGameTokenReward.read();
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

        fn start_new_game(
            ref self: ContractState,
            listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot: u256,
            finderFee: u256,
            hiderFee: u256,
            spawnNewPositionFee: u256,
            gameGridSizeX: u128,
            gameGridSizeY: u128,
            totalNumberOfHidersFromThePreviousWeek: u256,
            totalHiddenTreasureValueFromPreviousWeek: u256,
        ) -> bool {
            self.ownable.assert_only_owner();

            //Increment game week
            let gameWeek = self.currentGameWeek.read() + 1_u256;

            return self
                ._createNewGame(
                    listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot,
                    finderFee,
                    hiderFee,
                    spawnNewPositionFee,
                    gameGridSizeX,
                    gameGridSizeY,
                    totalNumberOfHidersFromThePreviousWeek,
                    totalHiddenTreasureValueFromPreviousWeek,
                    gameWeek,
                );
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
            ref self: ContractState,
            bulkAmount: u256,
            merkleProof: Array<felt252>,
            leafIndex: u32,
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
                let payableHopReward: u256 = self
                    ._applyHopSoftCap(gamerWalletAddress, hopRate);

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
            gameWeek: u256,
            leaf: u256,
            proof: Array<u256>,
        ) -> bool {
            self.ownable.assert_only_owner();

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

                assert(
                    self.total_reward_shares_for_hiders.read(gameWeek) > 0,
                    'no hiders in current game week',
                );

                //update the total number of hiders, for the current week
                self
                    .total_reward_shares_for_hiders
                    .write(gameWeek, (self.total_reward_shares_for_hiders.read(gameWeek) - 1_u256));

                return true;
            } else {
                return false;
            }
        }

        fn finder_player_generate_position(ref self: ContractState) -> bool {
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

            let transferResult: bool = reward_token_dispatcher
                .transfer(gamerWalletAddress, owed);

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

        // Whether the ROZ leg of a given week has settled. False after a claim
        // made while the contract was unfunded, which is the signal to call
        // claim_reward_token_for_week.
        fn get_reward_token_claimed(
            self: @ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
        ) -> bool {
            return self.reward_token_claimed.read((gameWeek, gamerWalletAddress));
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

        fn update_seed_modulo_divisor(ref self: ContractState, value: u256) -> bool {
            self.ownable.assert_only_owner();
            self.seedModuloDivisor.write(value);
            return true;
        }

        // Points the game at a different VRF provider. Owner only.
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
        // Only the owner set in the constructor
        // (0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833)
        // can call this, so a player cannot redirect the game at a provider of
        // their own that returns coordinates they picked.
        fn update_vrf_provider(
            ref self: ContractState, vrfProviderAddress: ContractAddress,
        ) -> bool {
            self.ownable.assert_only_owner();
            self.vrf_provider_contract_address.write(vrfProviderAddress);
            return true;
        }

        // Reads back whichever provider the game is currently using. Anyone can
        // call this - it is the quickest way to confirm, after a deploy or after
        // update_vrf_provider, that the game is talking to the provider you
        // think it is.
        fn get_vrf_provider(self: @ContractState) -> ContractAddress {
            return self.vrf_provider_contract_address.read();
        }

        // Points the game at a different ERC-20 for fees and rewards. Owner only.
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
            self.ownable.assert_only_owner();
            self.game_token_contract_address.write(gameTokenAddress);
            return true;
        }

        // Reads back the token the game is currently charging fees in. Anyone can
        // call this; it is the quickest way to confirm a deploy wired up the token
        // you intended.
        fn get_game_token(self: @ContractState) -> ContractAddress {
            return self.game_token_contract_address.read();
        }

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
            self.ownable.assert_only_owner();
            self.game_reward_token_contract_address.write(rewardTokenAddress);
            return true;
        }

        fn get_game_reward_token(self: @ContractState) -> ContractAddress {
            return self.game_reward_token_contract_address.read();
        }

        // The five full rates. Raw 18-decimal ROZ.
        //
        // These are reset every year as the supply schedule tapers - year 2 pays
        // 630M/855M = 0.7368 of year 1, and so on. Send the year's tokens FIRST,
        // then set the new rates: lowering the rates before the tokens arrive
        // short-changes whoever plays in between.
        fn update_reward_rates(
            ref self: ContractState,
            hideReward: u256,
            hideSurvivedReward: u256,
            findReward: u256,
            participationReward: u256,
            perHopReward: u256,
        ) -> bool {
            self.ownable.assert_only_owner();
            self.rewardHide.write(hideReward);
            self.rewardHideSurvived.write(hideSurvivedReward);
            self.rewardFind.write(findReward);
            self.rewardParticipation.write(participationReward);
            self.rewardPerHop.write(perHopReward);
            return true;
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

        // The rates a wallet earns before it has spent dailySpendThreshold today.
        //
        // hopRewardBelowThreshold is the most load-bearing value in the whole
        // contract, and not only against farmers: every calendar day starts at
        // zero spend, so this is the rate EVERY wallet earns on its opening
        // stretch of hops - about 54 for a typical casual, 59 for an active
        // player. Lowering it tightens the zero-cost sybil route and shortens
        // every honest player's morning at the same time.
        fn update_below_threshold_rates(
            ref self: ContractState,
            perHopReward: u256,
            participationReward: u256,
            hideReward: u256,
            hideSurvivedReward: u256,
        ) -> bool {
            self.ownable.assert_only_owner();
            self.hopRewardBelowThreshold.write(perHopReward);
            self.participationBelowThreshold.write(participationReward);
            self.rewardHideBelowThreshold.write(hideReward);
            self.rewardHideSurvivedBelowThreshold.write(hideSurvivedReward);
            return true;
        }

        fn get_below_threshold_rates(self: @ContractState) -> (u256, u256, u256, u256) {
            return (
                self.hopRewardBelowThreshold.read(),
                self.participationBelowThreshold.read(),
                self.rewardHideBelowThreshold.read(),
                self.rewardHideSurvivedBelowThreshold.read(),
            );
        }

        // The rates a wallet earns until it has spent lifetimeSpendThreshold in
        // total. Left permanently once passed - the counter never resets.
        fn update_new_wallet_rates(
            ref self: ContractState,
            perHopReward: u256,
            participationReward: u256,
            hideReward: u256,
            hideSurvivedReward: u256,
        ) -> bool {
            self.ownable.assert_only_owner();
            self.hopRewardNewWallet.write(perHopReward);
            self.participationNewWallet.write(participationReward);
            self.rewardHideNewWallet.write(hideReward);
            self.rewardHideSurvivedNewWallet.write(hideSurvivedReward);
            return true;
        }

        fn get_new_wallet_rates(self: @ContractState) -> (u256, u256, u256, u256) {
            return (
                self.hopRewardNewWallet.read(),
                self.participationNewWallet.read(),
                self.rewardHideNewWallet.read(),
                self.rewardHideSurvivedNewWallet.read(),
            );
        }

        // ------------------------------------------------------------------
        // Limits and allowances (2.2, 2.3)
        // ------------------------------------------------------------------

        // Two orderings carry the design here and neither may be broken:
        //
        //   freeHopsPerDay (22) < participationMinimum (28)
        //       so the 18-ROZ bonus can never be reached on free hops alone
        //   participationMinimum (28) <= roundRewardCap (40)
        //       so the bonus is demanding without needing a perfect round
        //
        // The asserts below make the first one impossible to break by accident.
        fn update_hop_limits(
            ref self: ContractState,
            participationMinimum: u256,
            roundRewardCap: u256,
            freeHopsPerDay: u256,
            freeSpawnsPerDay: u256,
        ) -> bool {
            self.ownable.assert_only_owner();
            assert(freeHopsPerDay < participationMinimum, 'free hops >= participation');
            assert(participationMinimum <= roundRewardCap, 'participation > round cap');
            self.participationMinimumHops.write(participationMinimum);
            self.hopRewardCap.write(roundRewardCap);
            self.dailyFreeHops.write(freeHopsPerDay);
            self.dailyFreeSpawns.write(freeSpawnsPerDay);
            return true;
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
        // Volume Multiplier instead, and find/steal takes neither - so no reward
        // line ever receives two multipliers. See _resolveGatedRate.
        fn update_soft_caps(
            ref self: ContractState, dailyCap: u256, newWalletCap: u256, num: u256, den: u256,
        ) -> bool {
            self.ownable.assert_only_owner();
            assert(den > 0, 'soft cap den is zero');
            self.dailySoftCapRoz.write(dailyCap);
            self.newWalletSoftCapRoz.write(newWalletCap);
            self.softCapMultiplierNum.write(num);
            self.softCapMultiplierDen.write(den);
            return true;
        }

        fn get_soft_caps(self: @ContractState) -> (u256, u256, u256, u256) {
            return (
                self.dailySoftCapRoz.read(),
                self.newWalletSoftCapRoz.read(),
                self.softCapMultiplierNum.read(),
                self.softCapMultiplierDen.read(),
            );
        }

        // ------------------------------------------------------------------
        // The Lightweight Gate (2.6) and hiding (2.3)
        // ------------------------------------------------------------------

        // Both are game-token amounts, 6 decimals. Changing the daily threshold
        // moves where the casual cliff falls; changing the lifetime one moves
        // what wallet churn costs a farm.
        //
        // The daily threshold is coupled to the hide fee tier - see
        // update_hide_settings, which asserts the relationship. Changing it here
        // without changing the fee tier there will trip that assert on the next
        // hide-settings write, which is the intended safety net.
        fn update_gate_thresholds(
            ref self: ContractState, dailyThreshold: u256, lifetimeThreshold: u256,
        ) -> bool {
            self.ownable.assert_only_owner();
            self.dailySpendThreshold.write(dailyThreshold);
            self.lifetimeSpendThreshold.write(lifetimeThreshold);
            return true;
        }

        fn get_gate_thresholds(self: @ContractState) -> (u256, u256) {
            return (self.dailySpendThreshold.read(), self.lifetimeSpendThreshold.read());
        }

        // THE INVARIANT THIS ASSERT PROTECTS, and it is easy to write the wrong
        // one:
        //
        //     feeTierBoundary * feeBase == dailySpendThreshold
        //     3               * 200000  == 600000
        //
        // The first three hides of a day cost the cheap fee and land a wallet
        // exactly on the spend threshold - no shortfall, no overshoot. That
        // gives a light player a clean route across the gate and gives a farmer
        // no cheaper way over than anybody else has.
        //
        // It is NOT dailyCap * feeBase. The cap is 10, and 10 * 200000 is
        // 2000000. dailyCap bounds VOLUME and has no part in clearing the gate,
        // so changing it alone must never trip this assert.
        fn update_hide_settings(
            ref self: ContractState,
            feeBase: u256,
            feeHigh: u256,
            feeTierBoundary: u256,
            dailyCap: u256,
            treasuresPerRound: u256,
        ) -> bool {
            self.ownable.assert_only_owner();
            assert(
                feeTierBoundary * feeBase == self.dailySpendThreshold.read(),
                'hide fee gate mismatch',
            );
            assert(feeHigh >= feeBase, 'high fee below base fee');
            self.hideFeeBase.write(feeBase);
            self.hideFeeHigh.write(feeHigh);
            self.hideFeeTierBoundary.write(feeTierBoundary);
            self.dailyHideCap.write(dailyCap);
            self.maxTreasuresPerRound.write(treasuresPerRound);
            return true;
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
            self.ownable.assert_only_owner();
            self.whitelist_merkle_root.write(newRoot);
            return true;
        }

        fn get_whitelist_merkle_root(self: @ContractState) -> felt252 {
            return self.whitelist_merkle_root.read();
        }

        // roundCap bounds ONE whitelisted address; collectiveCap bounds ALL of
        // them together. Both are needed, because per-address limits do not
        // compose - eleven addresses at 250 each would take 2,750 of 2,840 and
        // leave 90 slots for everybody else.
        //
        // maxTreasuresPerRound - collectiveCap is what ordinary players always
        // keep: 2,840 - 1,200 = 1,640.
        fn update_whitelist_caps(
            ref self: ContractState, roundCap: u256, collectiveCap: u256, hourlyCap: u256,
        ) -> bool {
            self.ownable.assert_only_owner();
            assert(
                collectiveCap <= self.maxTreasuresPerRound.read(), 'group cap above round cap',
            );
            self.whitelistRoundCap.write(roundCap);
            self.whitelistCollectiveCap.write(collectiveCap);
            self.whitelistHourlyCap.write(hourlyCap);
            return true;
        }

        fn get_whitelist_caps(self: @ContractState) -> (u256, u256, u256) {
            return (
                self.whitelistRoundCap.read(),
                self.whitelistCollectiveCap.read(),
                self.whitelistHourlyCap.read(),
            );
        }

        // ------------------------------------------------------------------
        // Owner-settable schedules, one band at a time (2.3, 2.5)
        // ------------------------------------------------------------------

        // Bands are indexed from 0 and read in order, so upToHop must increase
        // with bandIndex. The last band should be left open-ended.
        fn update_hop_price_band(
            ref self: ContractState, bandIndex: u8, upToHop: u256, price: u256,
        ) -> bool {
            self.ownable.assert_only_owner();
            self.hop_price_tier_limit.write(bandIndex, upToHop);
            self.hop_price_tier_price.write(bandIndex, price);
            return true;
        }

        fn get_hop_price_band(self: @ContractState, bandIndex: u8) -> (u256, u256) {
            return (
                self.hop_price_tier_limit.read(bandIndex),
                self.hop_price_tier_price.read(bandIndex),
            );
        }

        // upToTreasures is the count the wallet has ALREADY created today,
        // before the treasure being priced. So band 0 at 2 covers treasures 1-3.
        fn update_volume_band(
            ref self: ContractState, bandIndex: u8, upToTreasures: u256, num: u256, den: u256,
        ) -> bool {
            self.ownable.assert_only_owner();
            assert(den > 0, 'volume band den is zero');
            assert(num <= den, 'volume band above 1x');
            self.volume_band_limit.write(bandIndex, upToTreasures);
            self.volume_band_num.write(bandIndex, num);
            self.volume_band_den.write(bandIndex, den);
            return true;
        }

        fn get_volume_band(self: @ContractState, bandIndex: u8) -> (u256, u256, u256) {
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

        fn receive_random_words(
            ref self: ContractState,
            requester_address: ContractAddress,
            request_id: u64,
            random_words: Span<felt252>,
            calldata: Array<felt252>,
        ) {
            // Have to make sure that the caller is the Pragma Randomness Oracle contract
            let caller_address = get_caller_address();
            assert(
                caller_address == self.vrf_provider_contract_address.read(),
                'caller not randomness contract',
            );
            // and that the current block is within publish_delay of the request block
            let current_block_number = get_block_number();
            let min_block_number = self.min_block_number_storage.read();
            assert(min_block_number <= current_block_number, 'block number issue');

            let gameWeek = self.currentGameWeek.read();

            let random_word_0: felt252 = *random_words.at(0);

            let random_word_0_AsNumber: u256 = random_word_0.try_into().unwrap();

            let random_word_0_AsNumber_A: u128 = random_word_0_AsNumber.high;
            let random_word_0_AsNumber_B: u128 = random_word_0_AsNumber.low;

            let (maxGridX, maxGridY) = self.main_game_grid_size.read(gameWeek);

            let reducedNumberXCoordinate: u128 = (random_word_0_AsNumber_A - 1_u128) % maxGridX
                .try_into()
                .unwrap()
                + 1_u128;

            let reducedNumberYCoordinate: u128 = (random_word_0_AsNumber_B - 1_u128) % maxGridY
                .try_into()
                .unwrap()
                + 1_u128;

            let gamerWalletAddressFromCalldata: ContractAddress = self
                ._retrieveRandomnessCalldata(calldata);

            self
                ._updatePlayerPosition(
                    reducedNumberXCoordinate,
                    reducedNumberYCoordinate,
                    gamerWalletAddressFromCalldata,
                    gameWeek,
                );
        }

        // Sweeps this contract's entire balance of the CURRENT game token to
        // `receiver`. Owner only.
        //
        // Note it drains whichever token update_game_token last pointed at. If you
        // ever switch tokens, sweep the old one BEFORE switching - afterwards this
        // function can no longer reach it and the balance is stranded.
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
        //   ROZ  - subtract total_reward_token_pending. Without this the owner
        //          could sweep the backing for every accrued balance and
        //          claim_reward_tokens would start failing, which is exactly
        //          the failure the coverage rule in 4c-i exists to prevent.
        //
        //   USDC - subtract total_usdc_claimable, the running total of hider
        //          stakes not yet claimed or lost to a finder. USDC owed is
        //          computed from shares on demand and never totalled anywhere
        //          else, so without that counter there is nothing to subtract
        //          and sweeping mid-round silently takes money players are
        //          entitled to.
        //
        // Any other token is fully sweepable - nobody has a claim on it.
        fn withdraw_token_balance(
            ref self: ContractState, tokenAddress: ContractAddress, receiver: ContractAddress,
        ) {
            self.ownable.assert_only_owner();

            let token_dispatcher = ERC20ABIDispatcher { contract_address: tokenAddress };
            let heldBalance: u256 = token_dispatcher.balance_of(get_contract_address());

            let mut owedToPlayers: u256 = 0;

            if (tokenAddress == self.game_reward_token_contract_address.read()) {
                owedToPlayers = self.total_reward_token_pending.read();
            } else if (tokenAddress == self.game_token_contract_address.read()) {
                owedToPlayers = self.total_usdc_claimable.read();
            }

            // Nothing above what players are owed. Return rather than revert:
            // sweeping an empty surplus is a no-op, not an error.
            if (heldBalance <= owedToPlayers) {
                return;
            }

            token_dispatcher.transfer(receiver, heldBalance - owedToPlayers);
        }

        // What the sweep would release for a given token, without moving
        // anything. Lets the owner check the surplus before acting.
        fn get_sweepable_balance(self: @ContractState, tokenAddress: ContractAddress) -> u256 {
            let token_dispatcher = ERC20ABIDispatcher { contract_address: tokenAddress };
            let heldBalance: u256 = token_dispatcher.balance_of(get_contract_address());

            let mut owedToPlayers: u256 = 0;

            if (tokenAddress == self.game_reward_token_contract_address.read()) {
                owedToPlayers = self.total_reward_token_pending.read();
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
