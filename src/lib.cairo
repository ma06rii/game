// A testnet-only stand-in for Cartridge's VRF provider, deployed while their
// Sepolia service is unavailable. It is a separate contract, never called from
// this file, and never deployed to mainnet. See src/mock_vrf_provider.cairo for
// the full explanation.
mod mock_vrf_provider;
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
    fn update_callback_fee_limit(ref self: TContractState, maxGasFeeAmount: u128) -> bool;
    fn update_publish_delay(ref self: TContractState, minNumberOfBlocks: u64) -> bool;
    fn update_num_words(ref self: TContractState, numberOfRandomNumbers: u64) -> bool;
    fn update_seed_modulo_divisor(ref self: TContractState, value: u256) -> bool;
    fn update_vrf_provider(ref self: TContractState, vrfProviderAddress: ContractAddress) -> bool;
    fn get_vrf_provider(self: @TContractState) -> ContractAddress;
    fn update_game_token(ref self: TContractState, gameTokenAddress: ContractAddress) -> bool;
    fn get_game_token(self: @TContractState) -> ContractAddress;
    fn receive_random_words(
        ref self: TContractState,
        requester_address: ContractAddress,
        request_id: u64,
        random_words: Span<felt252>,
        calldata: Array<felt252>,
    );
    fn finder_player_generate_position(ref self: TContractState) -> bool;
    fn withdraw_token_balance(ref self: TContractState, receiver: ContractAddress);
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
    fn _hideTreasure(ref self: TContractState, caller: ContractAddress) -> bool;
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
    use core::to_byte_array::FormatAsByteArray;
    use core::traits::{Into, TryInto};
    use openzeppelin::access::ownable::OwnableComponent;
    // use pragma_lib::abi::{IRandomnessDispatcher, IRandomnessDispatcherTrait};
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use project_name::IHelloStarknet;
    use starknet::class_hash::class_hash_const;
    use starknet::{
        ContractAddress, SyscallResultTrait, contract_address_const, get_block_number,
        get_caller_address, get_contract_address, syscalls,
    };
    use super::{IVrfProvider, IVrfProviderDispatcher, IVrfProviderDispatcherTrait, Source};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TreasureHidden: TreasureHidden,
        PlayerPosition: PlayerPosition,
        CheckForTreasure: CheckForTreasure,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
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
    #[constructor]
    fn constructor(
        ref self: ContractState,
        vrfProviderAddress: ContractAddress,
        gameTokenAddress: ContractAddress,
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
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
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

        fn _hideTreasure(ref self: ContractState, caller: ContractAddress) -> bool {
            let myContract: ContractAddress = get_contract_address();
            let hiderCost: u256 = self.currentHiderFee.read();

            //hide treasure for the week upcoming
            let gameWeek = self.currentGameWeek.read() + 1_u256;

            let transferTokenResult: bool = self
                ._transfer_token_from(caller, myContract, hiderCost);

            assert(transferTokenResult == true, 'game token not transferred');

            let rewardResult: bool = self._rewardGamer(caller, gameWeek);

            assert(rewardResult == true, 'Reward not allocated');

            //update the total number of hiders, which is for the next weeeks game
            self
                .total_reward_shares_for_hiders
                .write(gameWeek, (self.total_reward_shares_for_hiders.read(gameWeek) + 1_u256));

            self.emit(TreasureHidden { user: caller, hiderFee: hiderCost, gameWeek: gameWeek });

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

            return true;
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

            let eligibleReward = claimShareCount * gameHiderFee;

            assert(eligibleReward > (gasFee + gameFee), 'Reward is less than fees');

            let rewardDue = (((eligibleReward - gasFee) - gameFee) - gameLandownerFee);

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

        fn hide_treasure(ref self: ContractState) -> bool {
            let caller = get_caller_address();

            return self._hideTreasure(caller);
        }

        fn finder_player_move_position( // ref self: ContractState, xDirection: u128, yDirection: u128
            ref self: ContractState, direction: u128,
        ) -> (u128, u128) {
            let gamerWalletAddress = get_caller_address();
            let gameWeek = self.currentGameWeek.read();

            let finderCost: u256 = self.currentFinderFee.read();
            let myContract: ContractAddress = get_contract_address();

            let transferTokenResult: bool = self
                ._transfer_token_from(gamerWalletAddress, myContract, finderCost);

            assert(transferTokenResult == true, 'game token not transferred');

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

            let transferTokenResult: bool = self
                ._transfer_token_from(gamerWalletAddress, myContract, spawnNewPositionCost);

            assert(transferTokenResult == true, 'game token not transferred');

            self._spawnNewPosition(gamerWalletAddress, gameWeek);

            return true;
        }

        fn claim_reward(ref self: ContractState, gameWeek: u256) -> bool {
            let gamerWalletAddress = get_caller_address();

            return self._claimReward(gamerWalletAddress, gameWeek);
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
        fn withdraw_token_balance(ref self: ContractState, receiver: ContractAddress) {
            self.ownable.assert_only_owner();
            let game_token_dispatcher = ERC20ABIDispatcher {
                contract_address: self.game_token_contract_address.read(),
            };
            let balance = game_token_dispatcher.balance_of(get_contract_address());
            game_token_dispatcher.transfer(receiver, balance);
        }
    }
}
