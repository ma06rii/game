use starknet::ContractAddress;

#[starknet::interface]
pub trait IHelloStarknet<TContractState> {
    fn verify(self: @TContractState, _root: u256, _leaf: u256, _proof: Array<u256>) -> bool;
    fn _keccak256(self: @TContractState, a: u256, b: u256) -> u256;
    fn ooStartNewGame(
        ref self: TContractState,
        listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot: u256,
        finderFee: u256,
        hiderFee: u256,
        gameGridSizeX: u256,
        gameGridSizeY: u256,
        totalNumberOfHidersFromThePreviousWeek: u256,
        totalHiddenTreasureValueFromPreviousWeek: u256
    ) -> bool;
    fn _createNewGame(
        ref self: TContractState,
        listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot: u256,
        finderFee: u256,
        hiderFee: u256,
        gameGridSizeX: u256,
        gameGridSizeY: u256,
        totalNumberOfHidersFromThePreviousWeek: u256,
        totalHiddenTreasureValueFromPreviousWeek: u256,
        gameWeek: u256
    ) -> bool;
    fn hideTreasure(ref self: TContractState) -> bool;
    fn _checkForTreasure(
        ref self: TContractState,
        gamerWalletAddress: ContractAddress,
        xCoordinate: u256,
        yCoordinate: u256,
        gameWeek: u256
    ) -> bool;
    fn _transfer_token_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn _rewardGamer(
        ref self: TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    fn _removeGamerReward(
        ref self: TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
    ) -> bool;
    fn _validateTreasureCoordinates(
        ref self: TContractState,
        finderGamerWalletAddress: ContractAddress,
        hiderGamerWalletAddress: ContractAddress,
        gameWeek: u256,
        leaf: u256,
        proof: Array<u256>
    ) -> bool;
    fn _spawnNewPosition(
        ref self: TContractState,
        gamerWalletAddress: ContractAddress,
        xCoordinate: u256,
        yCoordinate: u256,
        gameWeek: u256
    ) -> bool;
    fn finderPlayerMovePosition(
        ref self: TContractState, xDirection: u256, yDirection: u256
    ) -> (u256, u256);
    fn _finderPlayerMovePosition(
        ref self: TContractState,
        xDirection: u256,
        yDirection: u256,
        gamerWalletAddress: ContractAddress,
        gameWeek: u256
    ) -> (u256, u256);
    fn _getFinderPlayerPosition(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256
    ) -> (u256, u256);
    fn getFinderPlayerPosition(self: @TContractState) -> (u256, u256);
    fn ooUpdateGasFeeReservation(ref self: TContractState, feeAmount: u256) -> bool;
    fn ooUpdateGameMasterFee(ref self: TContractState, feeAmount: u256) -> bool;
    fn _playerRewardDue(
        self: @TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256
    ) -> u256;
    fn _calculateRewardDue(self: @TContractState, claimShareCount: u256) -> u256;
    fn _claimReward(
        ref self: TContractState, gamerWalletAddress: ContractAddress, gameWeek: u256
    ) -> bool;
    fn claimReward(ref self: TContractState) -> bool;
    fn _transfer_token(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    // fn ooGetRandomnessCalldata(
    //     ref self: TContractState, gamerWalletAddress: ContractAddress
    // ) -> bool;
    fn ooCreateRandomnessCalldata(
        self: @TContractState, gamerWalletAddress: ContractAddress
    ) -> Array::<felt252>;
    fn ooRetrieveRandomnessCalldata(
        self: @TContractState, calldataArr: Array::<felt252>
    ) -> ContractAddress;
    fn ooUpdateCallbackFeeLimit(ref self: TContractState, maxGasFeeAmount: u128) -> bool;
    fn ooUpdatePublishDelay(ref self: TContractState, minNumberOfBlocks: u64) -> bool;
    fn ooUpdateNumWords(ref self: TContractState, numberOfRandomNumbers: u64) -> bool;
    fn _getSeed(self: @TContractState, finderGamerAddress: ContractAddress) -> u64;
    fn ooUpdateSeedModuloDivisor(ref self: TContractState, value: u256) -> bool;
}

#[starknet::contract]
mod HelloStarknet {
    use core::num::traits::zero::Zero;
    use project_name::IHelloStarknet;
    use core::option::OptionTrait;
    use core::traits::TryInto;
    use core::traits::Into;
    use core::array::ArrayTrait;
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

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TreasureHidden: TreasureHidden,
        PlayerPosition: PlayerPosition,
        CheckForTreasure: CheckForTreasure
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
        xCoordinate: u256,
        yCoordinate: u256,
        #[key]
        gameWeek: u256
    }

    #[derive(Drop, starknet::Event)]
    struct PlayerPosition {
        #[key]
        user: ContractAddress,
        xCoordinate: u256,
        yCoordinate: u256,
        #[key]
        gameWeek: u256
    }

    #[storage]
    struct Storage {
        //Divisor used to get a value to generate a seed value for randmoness request.
        seedModuloDivisor: u256,
        //Randomness Request
        callback_fee_limit: u128, // e.g. 1000000000000
        publish_delay: u64, // e.g. 3
        num_words: u64, // e.g. 2
        //Fees
        gasFeeReservation: u256,
        gameMasterFee: u256,
        //Game
        currentGameWeek: u256,
        currentFinderFee: u256,
        currentHiderFee: u256,
        //Main_Game: LegacyMap::<gameWeek, (listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot, finderFee, hiderFee)>
        main_game: LegacyMap::<u256, (u256, u256, u256)>,
        //Main_Game_Grid_Size: LegacyMap::<gameWeek, (gameGridSizeX, gameGridSizeY)>
        main_game_grid_size: LegacyMap::<u256, (u256, u256)>,
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
        player_position: LegacyMap::<(u256, ContractAddress), (u256, u256)>,
        //Found_coordinates: LegacyMap::<(leaf, gameWeek), true>
        found_coordinates: LegacyMap::<(u256, u256), bool>
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self
            ._createNewGame(
                0xbc19a39ffdeb3ff487a290fd65626b9592fe3fb625937ab468940c4c58966849,
                75000000000000, //approx $ 0.25
                35000000000000, //approx $ 0.12
                5,
                5,
                3,
                105000000000000,
                0
            );

        self.ooUpdateGasFeeReservation(10000000000000);
        self.ooUpdateGameMasterFee(2500000000000);

        self.ooUpdateCallbackFeeLimit(10000000000000);
        self.ooUpdatePublishDelay(3);
        self.ooUpdateNumWords(2);

        self.ooUpdateSeedModuloDivisor(128000000000);
    }

    #[abi(embed_v0)]
    impl HelloStarknetImpl of super::IHelloStarknet<ContractState> {
        fn verify(self: @ContractState, _root: u256, _leaf: u256, _proof: Array<u256>) -> bool {
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

        fn ooUpdateGasFeeReservation(ref self: ContractState, feeAmount: u256) -> bool {
            self.gasFeeReservation.write(feeAmount);
            return true;
        }

        fn ooUpdateGameMasterFee(ref self: ContractState, feeAmount: u256) -> bool {
            self.gameMasterFee.write(feeAmount);
            return true;
        }

        fn ooUpdateCallbackFeeLimit(ref self: ContractState, maxGasFeeAmount: u128) -> bool {
            self.callback_fee_limit.write(maxGasFeeAmount);
            return true;
        }

        fn ooUpdatePublishDelay(ref self: ContractState, minNumberOfBlocks: u64) -> bool {
            self.publish_delay.write(minNumberOfBlocks);
            return true;
        }

        fn ooUpdateNumWords(ref self: ContractState, numberOfRandomNumbers: u64) -> bool {
            self.num_words.write(numberOfRandomNumbers);
            return true;
        }

        // fn ooGetRandomnessCalldata(
        //     ref self: ContractState, gamerWalletAddress: ContractAddress
        // ) -> bool {
        //     // self.num_words.write(numberOfRandomNumbers);
        //     let mut calldataArr = ArrayTrait::<felt252>::new();

        //     // let address: u256 = gamerWalletAddress.try_into().unwrap();
        //     // let address: felt252 = gamerWalletAddress.into();
        //     calldataArr.append(gamerWalletAddress.into());

        //     let decodeAddress: felt252 = *calldataArr.at(0);

        //     let contractAddressAgain: ContractAddress = decodeAddress.try_into().unwrap();

        //     ///temp for testing
        //     self._transfer_token(contractAddressAgain, 4500000000000000);
        //     ///

        //     return true;
        // }

        fn ooCreateRandomnessCalldata(
            self: @ContractState, gamerWalletAddress: ContractAddress
        ) -> Array::<felt252> {
            let mut calldataArr = ArrayTrait::<felt252>::new();

            calldataArr.append(gamerWalletAddress.into());

            return calldataArr;
        }

        fn ooRetrieveRandomnessCalldata(
            self: @ContractState, calldataArr: Array::<felt252>
        ) -> ContractAddress {
            let decodeAddress: felt252 = *calldataArr.at(0);

            let contractAddressAgain: ContractAddress = decodeAddress.try_into().unwrap();

            return contractAddressAgain;
        }

        fn ooStartNewGame(
            ref self: ContractState,
            listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot: u256,
            finderFee: u256,
            hiderFee: u256,
            gameGridSizeX: u256,
            gameGridSizeY: u256,
            totalNumberOfHidersFromThePreviousWeek: u256,
            totalHiddenTreasureValueFromPreviousWeek: u256
        ) -> bool {
            //Increment game week
            let gameWeek = self.currentGameWeek.read() + 1;

            return self
                ._createNewGame(
                    listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot,
                    finderFee,
                    hiderFee,
                    gameGridSizeX,
                    gameGridSizeY,
                    totalNumberOfHidersFromThePreviousWeek,
                    totalHiddenTreasureValueFromPreviousWeek,
                    gameWeek
                );
        }

        fn _createNewGame(
            ref self: ContractState,
            listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot: u256,
            finderFee: u256,
            hiderFee: u256,
            gameGridSizeX: u256,
            gameGridSizeY: u256,
            totalNumberOfHidersFromThePreviousWeek: u256,
            totalHiddenTreasureValueFromPreviousWeek: u256,
            gameWeek: u256
        ) -> bool {
            //Increment game week
            self.currentGameWeek.write(gameWeek);
            self.currentFinderFee.write(finderFee);
            self.currentHiderFee.write(hiderFee);

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

        fn hideTreasure(ref self: ContractState) -> bool {
            let caller = get_caller_address();
            let myContract: ContractAddress = get_contract_address();
            let hiderCost: u256 = self.currentHiderFee.read();

            let gameWeek = self.currentGameWeek.read();

            self._transfer_token_from(caller, myContract, hiderCost);

            self._rewardGamer(caller, gameWeek);

            //update the total number of hiders, which is for the next weeeks game
            self
                .total_reward_shares_for_hiders
                .write(
                    self.currentGameWeek.read() + 1,
                    self.total_reward_shares_for_hiders.read(self.currentGameWeek.read() + 1) + 1
                );

            self
                .emit(
                    TreasureHidden {
                        user: caller,
                        hiderFee: self.currentHiderFee.read(),
                        gameWeek: self.currentGameWeek.read()
                    }
                );

            true
        }

        fn finderPlayerMovePosition(
            ref self: ContractState, xDirection: u256, yDirection: u256
        ) -> (u256, u256) {
            let gamerWalletAddress = get_caller_address();
            let gameWeek = self.currentGameWeek.read();

            return self
                ._finderPlayerMovePosition(xDirection, yDirection, gamerWalletAddress, gameWeek);
        }

        fn _finderPlayerMovePosition(
            ref self: ContractState,
            xDirection: u256,
            yDirection: u256,
            gamerWalletAddress: ContractAddress,
            gameWeek: u256
        ) -> (u256, u256) {
            assert(xDirection >= 0, 'cannot be negative');
            assert(yDirection >= 0, 'cannot be negative');

            assert(xDirection <= 1, 'can only move one step');
            assert(yDirection <= 1, 'can only move one step');

            //get x,y coordinates from player_position mapping
            let (x, y) = self.player_position.read((gameWeek, gamerWalletAddress));

            //check if the gamer has coordinates
            assert(x.is_non_zero(), 'gamer does not have coordinates');
            assert(y.is_non_zero(), 'gamer does not have coordinates');

            //increase or decrease the coordinates in the direction
            let newX = x + xDirection;
            let newY = y + yDirection;

            let (maxGridX, maxGridY) = self.main_game_grid_size.read(gameWeek);

            //do a require check, if the new coordinates is valid for current game
            assert(newX <= maxGridX, 'out of game board range');
            assert(newY <= maxGridY, 'out of game board range');

            //update player position
            self.player_position.write((gameWeek, gamerWalletAddress), (newX, newY));

            //publish event that player has moved
            self
                .emit(
                    PlayerPosition {
                        user: gamerWalletAddress,
                        xCoordinate: newX,
                        yCoordinate: newY,
                        gameWeek: gameWeek
                    }
                );

            self._checkForTreasure(gamerWalletAddress, newX, newY, gameWeek);

            return self.player_position.read((gameWeek, gamerWalletAddress));
        }

        fn getFinderPlayerPosition(self: @ContractState) -> (u256, u256) {
            let gamerWalletAddress = get_caller_address();
            let gameWeek = self.currentGameWeek.read();

            return self._getFinderPlayerPosition(gamerWalletAddress, gameWeek);
        }

        fn _getFinderPlayerPosition(
            self: @ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256
        ) -> (u256, u256) {
            //get x,y coordinates from player_position mapping
            let (x, y) = self.player_position.read((gameWeek, gamerWalletAddress));

            return (x, y);
        }

        fn _checkForTreasure(
            ref self: ContractState,
            gamerWalletAddress: ContractAddress,
            xCoordinate: u256,
            yCoordinate: u256,
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

        fn _validateTreasureCoordinates(
            ref self: ContractState,
            finderGamerWalletAddress: ContractAddress,
            hiderGamerWalletAddress: ContractAddress,
            gameWeek: u256,
            leaf: u256,
            proof: Array<u256>
        ) -> bool {
            let (root, _, _) = self.main_game.read(self.currentGameWeek.read());

            let result: bool = self.verify(root, leaf, proof);

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
                    .write(gameWeek, self.total_reward_shares_for_finders.read(gameWeek) + 1);

                //remove gamer reward
                self._removeGamerReward(hiderGamerWalletAddress, gameWeek);

                assert(
                    self.total_reward_shares_for_hiders.read(gameWeek) > 0,
                    'no hiders in current game week'
                );

                //update the total number of hiders, for the current week
                self
                    .total_reward_shares_for_hiders
                    .write(gameWeek, self.total_reward_shares_for_hiders.read(gameWeek) - 1);

                return true;
            } else {
                return false;
            }
        }

        fn _rewardGamer(
            ref self: ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
        ) -> bool {
            let currentShareCount = self.claim_share_amounts.read((gameWeek, gamerWalletAddress));

            self.claim_share_amounts.write((gameWeek, gamerWalletAddress), currentShareCount + 1);

            true
        }

        fn _removeGamerReward(
            ref self: ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256,
        ) -> bool {
            let currentShareCount = self.claim_share_amounts.read((gameWeek, gamerWalletAddress));

            assert(currentShareCount > 0, 'user has no share claims');

            self.claim_share_amounts.write((gameWeek, gamerWalletAddress), currentShareCount - 1);

            true
        }

        fn _spawnNewPosition(
            ref self: ContractState,
            gamerWalletAddress: ContractAddress,
            xCoordinate: u256,
            yCoordinate: u256,
            gameWeek: u256
        ) -> bool {
            assert(
                self.player_position.read((gameWeek, gamerWalletAddress)) == (0, 0),
                'position already on game board'
            );

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

            return true;
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

        fn claimReward(ref self: ContractState) -> bool {
            let gamerWalletAddress = get_caller_address();
            let gameWeek = self.currentGameWeek.read();

            return self._claimReward(gamerWalletAddress, gameWeek);
        }

        fn _claimReward(
            ref self: ContractState, gamerWalletAddress: ContractAddress, gameWeek: u256
        ) -> bool {
            assert(gameWeek < self.currentGameWeek.read(), 'Reward already claimed');

            assert(
                self.claimed_rewards.read((gameWeek, gamerWalletAddress)) == false,
                'Reward already claimed'
            );

            let reward = self._playerRewardDue(gamerWalletAddress, gameWeek);

            assert(reward != 0, 'No reward available');
            assert(reward != BoundedInt::max(), 'No infinity reward amount');

            self._transfer_token(gamerWalletAddress, reward);

            return true;
        }

        fn _calculateRewardDue(self: @ContractState, claimShareCount: u256) -> u256 {
            let gameHiderFee = self.currentHiderFee.read();

            let gasFee = self.gasFeeReservation.read();
            let gameFee = self.gameMasterFee.read();

            let eligibleReward = claimShareCount * gameHiderFee;

            assert(eligibleReward > (gasFee + gameFee), 'reward is less than fees');

            let rewardDue = ((eligibleReward - gasFee) - gameFee);

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

        fn ooUpdateSeedModuloDivisor(ref self: ContractState, value: u256) -> bool {
            self.seedModuloDivisor.write(value);
            return true;
        }
    }
}
// #[storage]
// pub struct Storage {
//     owner: ContractAddress,
// }
// #[constructor]
// fn constructor(ref self: ContractState, owner: ContractAddress) {
//     self.owner.write(owner);
// }
// fn get_owner(self: @TContractState) -> ContractAddress;
// fn get_owner(self: @ContractState) -> ContractAddress {
//     self.owner.read()
// }
// fn change_owner(ref self: ContractState, new_owner: ContractAddress) {
//     self.set_owner(new_owner);
// }
// let caller: ContractAddress = get_caller_address();
// let owner: ContractAddress = self.get_owner();
// assert!(caller == owner, "Only the owner can make pizza");
// #[generate_trait]
// pub impl InternalImpl of InternalTrait {
//     fn set_owner(ref self: ContractState, new_owner: ContractAddress) {
//         let caller: ContractAddress = get_caller_address();
//         assert!(caller == self.get_owner(), "Only the owner can set ownership");

//         self.owner.write(new_owner);
//     }
// }

// use openzeppelin::access::ownable::OwnableComponent;


