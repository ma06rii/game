use starknet::ContractAddress;

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
        totalHiddenTreasureValueFromPreviousWeek: u256
    ) -> bool;
    fn hide_treasure(ref self: TContractState) -> bool;
    fn validate_treasure_coordinates(
        ref self: TContractState,
        finderGamerWalletAddress: ContractAddress,
        hiderGamerWalletAddress: ContractAddress,
        gameWeek: u256,
        leaf: u256,
        proof: Array<u256>
    ) -> bool;
    fn finder_player_move_position(ref self: TContractState, direction: u128) -> (u128, u128);
    fn get_finder_player_position(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256
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
    fn receive_random_words(
        ref self: TContractState,
        requester_address: ContractAddress,
        request_id: u64,
        random_words: Span<felt252>,
        calldata: Array<felt252>
    );
    fn finder_player_generate_position(ref self: TContractState) -> bool;
    fn withdraw_ETH_Balance(ref self: TContractState, receiver: ContractAddress);
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
        self: @TContractState, gameWeek: u256, gamerWalletAddress: ContractAddress
    ) -> u256;
}

trait InternalFunctionsTrait<TContractState> {
    fn _checkForTreasure(
        ref self: TContractState,
        gamerWalletAddress: ContractAddress,
        xCoordinate: u128,
        yCoordinate: u128,
        gameWeek: u256
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
        gameWeek: u256
    ) -> bool;
    fn _hideTreasure(ref self: TContractState, caller: ContractAddress) -> bool;
    fn _transfer_token_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn _rewardGamer(
        ref self: TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    fn _removeGamerReward(
        ref self: TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    fn _spawnNewPosition(
        ref self: TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256
    ) -> bool;
    fn _updatePlayerPosition(
        ref self: TContractState,
        xCoordinate: u128,
        yCoordinate: u128,
        gamerWalletAddress: ContractAddress,
        gameWeek: u256
    );
    fn _finderPlayerMovePosition(
        ref self: TContractState,
        direction: felt252,
        gamerWalletAddress: ContractAddress,
        gameWeek: u256
    ) -> (u128, u128);
    fn _playerRewardDue(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256
    ) -> u256;
    fn _calculateRewardDue(self: @TContractState, claimShareCount: u256) -> u256;
    fn _claimReward(
        ref self: TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256
    ) -> bool;
    fn _transfer_token(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn _createRandomnessCalldata(
        self: @TContractState, gamerWalletAddress: ContractAddress
    ) -> Array::<felt252>;
    fn _retrieveRandomnessCalldata(
        self: @TContractState, calldataArr: Array::<felt252>
    ) -> ContractAddress;
    fn _getSeed(self: @TContractState, finderGamerAddress: ContractAddress) -> u64;
    fn _request_randomness_from_pragma(ref self: TContractState, caller: ContractAddress) -> bool;
}

#[starknet::contract]
mod HelloStarknet {
    use core::num::traits::zero::Zero;
    use project_name::IHelloStarknet;
    use core::option::OptionTrait;
    use core::traits::TryInto;
    use core::traits::Into;
    use core::array::{ArrayTrait, SpanTrait};
    use core::keccak::{keccak_u256s_le_inputs, keccak_u256s_be_inputs, cairo_keccak};
    use core::to_byte_array::{FormatAsByteArray};
    use core::integer::u128_byte_reverse;
    use starknet::{
        ContractAddress, get_caller_address, class_hash::class_hash_const, contract_address_const,
        get_contract_address, get_block_number
    };
    use core::serde::Serde;
    use starknet::{SyscallResultTrait, syscalls};
    use core::integer::BoundedInt;
    use pragma_lib::abi::{IRandomnessDispatcher, IRandomnessDispatcherTrait};
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TreasureHidden: TreasureHidden,
        PlayerPosition: PlayerPosition,
        CheckForTreasure: CheckForTreasure,
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct TreasureHidden {
        #[key]
        user: ContractAddress,
        hiderFee: u256,
        #[key]
        gameWeek: u256
    }

    #[derive(Drop, starknet::Event)]
    struct CheckForTreasure {
        #[key]
        user: ContractAddress,
        xCoordinate: u128,
        yCoordinate: u128,
        #[key]
        gameWeek: u256
    }

    #[derive(Drop, starknet::Event)]
    struct PlayerPosition {
        #[key]
        user: ContractAddress,
        xCoordinate: u128,
        yCoordinate: u128,
        #[key]
        gameWeek: u256
    }

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        //Divisor used to get a value to generate a seed value for randmoness request.
        seedModuloDivisor: u256,
        //Randomness Request
        pragma_vrf_contract_address: ContractAddress,
        min_block_number_storage: u64,
        callback_fee_limit: u128, // e.g. 1000000000000
        publish_delay: u64, // e.g. 3
        num_words: u64, // e.g. 2
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
        //Main_Game: LegacyMap::<gameWeek, (listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot, finderFee, hiderFee)>
        main_game: LegacyMap::<u256, (u256, u256, u256)>,
        //Main_Game_Grid_Size: LegacyMap::<gameWeek, (gameGridSizeX, gameGridSizeY)>
        main_game_grid_size: LegacyMap::<u256, (u128, u128)>,
        //Game_totals: LegacyMap::<gameWeek, totalHiddenTreasureValue>,
        game_totals: LegacyMap::<u256, u256>,
        //Claim_share_amounts: LegacyMap::<(gameWeek, gamerWalletAddress), totalShareCount>,
        claim_share_amounts: LegacyMap::<(u256, ContractAddress), u256>,
        //Claimed_rewards: LegacyMap::<(gameWeek, gamerWalletAddress), treasureClaimed>,
        claimed_rewards: LegacyMap::<(u256, ContractAddress), bool>,
        //Total_reward_shares_for_hiders: LegacyMap::<gameWeek, totalNumberOfHiders>
        total_reward_shares_for_hiders: LegacyMap::<u256, u256>,
        //Total_reward_shares_for_finders: LegacyMap::<gameWeek, totalNumberOfFinders>
        total_reward_shares_for_finders: LegacyMap::<u256, u256>,
        //Player_position: LegacyMap::<(gameWeek, gamerWalletAddress), (xPosition, yPosition)>
        player_position: LegacyMap::<(u256, ContractAddress), (u128, u128)>,
        //Found_coordinates: LegacyMap::<(leaf, gameWeek), true>
        found_coordinates: LegacyMap::<(u256, u256), bool>,
        minimumAllowance: u256,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self
            ._createNewGame(
                0xbc19a39ffdeb3ff487a290fd65626b9592fe3fb625937ab468940c4c58966849,
                30000000000000, //approx $ 0.1 finder fee
                1500000000000000, //approx $ 5 hider fee
                300000000000000, //approx $ 1 spawn new position
                14,
                14,
                3,
                4500000000000000, // assuming $5 minimum value of hidden treasure
                0
            );

        let ownerAddress: ContractAddress = contract_address_const::<
            0x052a2b0b20d8796e57f0f00e99adfd61e0b40c4a49553d4197e4da6c1c023833
        >();

        self.ownable.initializer(ownerAddress);
        self.gasFeeReservation.write(1000000000000);
        self.gameMasterFee.write(2500000000000);
        self.gameLandownerFee.write(350000000000);
        self.callback_fee_limit.write(5000000000000000);
        self.publish_delay.write(0);
        self.num_words.write(1_u64);
        self.seedModuloDivisor.write(128000000000);

        let randomnessAddress: ContractAddress = contract_address_const::<
            0x60c69136b39319547a4df303b6b3a26fab8b2d78de90b6bd215ce82e9cb515c
        >();

        self.pragma_vrf_contract_address.write(randomnessAddress);

        self.currentGameTokenReward.write(3500000000000000);

        self.minimumAllowance.write(2100000000000000);
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _checkForTreasure(
            ref self: ContractState,
            gamerWalletAddress: ContractAddress,
            xCoordinate: u128,
            yCoordinate: u128,
            gameWeek: u256
        ) -> bool {
            self
                .emit(
                    CheckForTreasure {
                        user: gamerWalletAddress,
                        xCoordinate: xCoordinate,
                        yCoordinate: yCoordinate,
                        gameWeek: gameWeek
                    }
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
            };

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
                low: u128_byte_reverse(res.high), high: u128_byte_reverse(res.low)
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
            gameWeek: u256
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
                    (listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot, finderFee, hiderFee)
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
            self: @ContractState, gamerWalletAddress: ContractAddress
        ) -> Array::<felt252> {
            let mut calldataArr = ArrayTrait::<felt252>::new();

            calldataArr.append(gamerWalletAddress.into());

            return calldataArr;
        }

        fn _retrieveRandomnessCalldata(
            self: @ContractState, calldataArr: Array::<felt252>
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

            assert(transferTokenResult == true, 'eth token not transferred');

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
            gameWeek: u256
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
            ref self: ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256
        ) -> bool {
            assert(
                self.player_position.read((gameWeek, gamerWalletAddress)) == (0, 0),
                'position already on game board'
            );

            let randomnessResult = self._request_randomness_from_pragma(gamerWalletAddress);

            assert(randomnessResult == true, 'random coordinate no generated');

            return true;
        }

        fn _updatePlayerPosition(
            ref self: ContractState,
            xCoordinate: u128,
            yCoordinate: u128,
            gamerWalletAddress: ContractAddress,
            gameWeek: u256
        ) {
            self.player_position.write((gameWeek, gamerWalletAddress), (xCoordinate, yCoordinate));

            self
                .emit(
                    PlayerPosition {
                        user: gamerWalletAddress,
                        xCoordinate: xCoordinate,
                        yCoordinate: yCoordinate,
                        gameWeek: gameWeek
                    }
                );

            self._checkForTreasure(gamerWalletAddress, xCoordinate, yCoordinate, gameWeek);
        }

        fn _transfer_token_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            let mut call_data: Array<felt252> = ArrayTrait::new();

            Serde::serialize(@sender, ref call_data);
            Serde::serialize(@recipient, ref call_data);
            Serde::serialize(@amount, ref call_data);

            let address: ContractAddress = contract_address_const::<
                0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
            >();

            let mut res = syscalls::call_contract_syscall(
                address, selector!("transfer_from"), call_data.span()
            )
                .unwrap_syscall();

            Serde::<bool>::deserialize(ref res).unwrap()
        }

        fn _transfer_token(
            ref self: ContractState, recipient: ContractAddress, amount: u256
        ) -> bool {
            let mut call_data: Array<felt252> = ArrayTrait::new();

            Serde::serialize(@recipient, ref call_data);
            Serde::serialize(@amount, ref call_data);

            let address: ContractAddress = contract_address_const::<
                0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
            >();

            let mut res = syscalls::call_contract_syscall(
                address, selector!("transfer"), call_data.span()
            )
                .unwrap_syscall();

            Serde::<bool>::deserialize(ref res).unwrap()
        }

        fn _playerRewardDue(
            self: @ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256
        ) -> u256 {
            let claimShareCount: u256 = self
                .claim_share_amounts
                .read((gameWeek, gamerWalletAddress));

            if (claimShareCount == 0) {
                return 0;
            } else {
                return self._calculateRewardDue(claimShareCount);
            }
        }

        fn _claimReward(
            ref self: ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256
        ) -> bool {
            assert(gameWeek < self.currentGameWeek.read(), 'Game week not finished yet');

            assert(
                self.claimed_rewards.read((gameWeek, gamerWalletAddress)) == false,
                'Reward already claimed'
            );

            let reward = self._playerRewardDue(gamerWalletAddress, gameWeek);

            assert(reward != 0, 'No reward available');
            assert(reward != BoundedInt::max(), 'No infinity reward amount');

            let transferTokenResult: bool = self._transfer_token(gamerWalletAddress, reward);

            assert(transferTokenResult == true, 'No eth token transferred');

            self.claimed_rewards.write((gameWeek, gamerWalletAddress), true);

            return true;
        }

        fn _calculateRewardDue(self: @ContractState, claimShareCount: u256) -> u256 {
            let gameHiderFee = self.currentHiderFee.read();

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

        fn _request_randomness_from_pragma(
            ref self: ContractState, caller: ContractAddress
        ) -> bool {
            let randomness_contract_address = self.pragma_vrf_contract_address.read();
            let randomness_dispatcher = IRandomnessDispatcher {
                contract_address: randomness_contract_address
            };

            let callback_fee_limit = self.callback_fee_limit.read();
            let publish_delay = self.publish_delay.read();
            let num_words = self.num_words.read();

            // Approve the randomness contract to transfer the callback fee
            // You would need to send some ETH to this contract first to cover the fees
            let eth_dispatcher = ERC20ABIDispatcher {
                contract_address: contract_address_const::<
                    0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
                >() // ETH Contract Address
            };
            eth_dispatcher
                .approve(
                    randomness_contract_address,
                    (callback_fee_limit + callback_fee_limit / 5).into()
                );

            let calldata = self._createRandomnessCalldata(caller);
            let callback_address = get_contract_address();
            let seed = self._getSeed(caller);

            // Request the randomness
            randomness_dispatcher
                .request_random(
                    seed, callback_address, callback_fee_limit, publish_delay, num_words, calldata
                );

            let current_block_number = get_block_number();
            self.min_block_number_storage.write(current_block_number + publish_delay);

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
            self: @ContractState, gameWeek: u256, gamerWalletAddress: ContractAddress
        ) -> u256 {
            return self.claim_share_amounts.read((gameWeek, gamerWalletAddress));
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
            totalHiddenTreasureValueFromPreviousWeek: u256
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
                    gameWeek
                );
        }

        fn hide_treasure(ref self: ContractState) -> bool {
            let caller = get_caller_address();

            return self._hideTreasure(caller);
        }

        fn finder_player_move_position(// ref self: ContractState, xDirection: u128, yDirection: u128
        ref self: ContractState, direction: u128) -> (u128, u128) {
            let gamerWalletAddress = get_caller_address();
            let gameWeek = self.currentGameWeek.read();

            let finderCost: u256 = self.currentFinderFee.read();
            let myContract: ContractAddress = get_contract_address();

            let transferTokenResult: bool = self
                ._transfer_token_from(gamerWalletAddress, myContract, finderCost);

            assert(transferTokenResult == true, 'eth token not transferred');

            return self._finderPlayerMovePosition(direction, gamerWalletAddress, gameWeek);
        }

        fn get_finder_player_position(
            self: @ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256
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
            proof: Array<u256>
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
                        gameWeek, (self.total_reward_shares_for_finders.read(gameWeek) + 1_u256)
                    );

                //remove gamer reward
                self._removeGamerReward(hiderGamerWalletAddress, gameWeek);

                assert(
                    self.total_reward_shares_for_hiders.read(gameWeek) > 0,
                    'no hiders in current game week'
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

            // Check if the player has approved ETH spending
            // You would need to send some ETH to this contract first to cover the fees
            let eth_dispatcher = ERC20ABIDispatcher {
                contract_address: contract_address_const::<
                    0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
                >() // ETH Contract Address
            };
            let allowanceAmount:u256 = eth_dispatcher
                .allowance(
                    gamerWalletAddress,
                    myContract
                );

            assert(allowanceAmount >= self.minimumAllowance.read(), 'ETH spend approval required');

            let transferTokenResult: bool = self
                ._transfer_token_from(gamerWalletAddress, myContract, spawnNewPositionCost);

            assert(transferTokenResult == true, 'eth token not transferred');

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

        fn receive_random_words(
            ref self: ContractState,
            requester_address: ContractAddress,
            request_id: u64,
            random_words: Span<felt252>,
            calldata: Array<felt252>
        ) {
            // Have to make sure that the caller is the Pragma Randomness Oracle contract
            let caller_address = get_caller_address();
            assert(
                caller_address == self.pragma_vrf_contract_address.read(),
                'caller not randomness contract'
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
                    gameWeek
                );
        }

        fn withdraw_ETH_Balance(ref self: ContractState, receiver: ContractAddress) {
            self.ownable.assert_only_owner();
            let eth_dispatcher = ERC20ABIDispatcher {
                contract_address: contract_address_const::<
                    0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
                >() // ETH Contract Address            
            };
            let balance = eth_dispatcher.balance_of(get_contract_address());
            eth_dispatcher.transfer(receiver, balance);
        }
    }
}
