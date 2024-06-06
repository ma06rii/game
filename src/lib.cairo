use starknet::ContractAddress;

#[starknet::interface]
pub trait IHelloStarknet<TContractState> {
    fn verify(self: @TContractState, _root: u256, _leaf: u256, _proof: Array<u256>) -> bool;
    fn _keccak256(self: @TContractState, a: u256, b: u256) -> u256;
    fn startNewGame(
        ref self: TContractState,
        listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot: u256,
        finderFee: u128,
        hiderFee: u128,
        gameGridSizeX: u256,
        gameGridSizeY: u256,
        totalNumberOfHidersFromThePreviousWeek: u256,
        totalHiddenTreasureValueFromPreviousWeek: u256
    );
    // fn hideTreasure(self: @TContractState) -> u256;
    // fn spawnNewPosition(self: @TContractState, gamerWalletAddress: ContractAddress, xCoordinate: u256, yCoordinate: u256, gameWeek:u256 ) -> u256;
    // fn _checkForTreasure(ref self: TContractState, gamerWalletAddress: ContractAddress, xCoordinate: u256, yCoordinate: u256, gameWeek:u256 ) -> u256;
    fn _checkForTreasure(ref self: TContractState) -> u256;
}

#[starknet::interface]
trait IERC20<TState> {
    fn total_supply(self: @TState) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::contract]
mod HelloStarknet {
    use core::option::OptionTrait;
    use core::traits::TryInto;
    use core::traits::Into;
    use core::array::ArrayTrait;
    use core::keccak::{keccak_u256s_le_inputs, keccak_u256s_be_inputs, cairo_keccak};
    use core::to_byte_array::{FormatAsByteArray};
    use core::integer::u128_byte_reverse;

    use starknet::{ContractAddress, get_caller_address, class_hash::class_hash_const};
    use super::{IERC20DispatcherTrait, IERC20LibraryDispatcher};


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TreasureHidden: TreasureHidden,
    // SpawnPosition:SpawnPosition,
    // checkForTreasure: checkForTreasure

    }
    #[derive(Drop, starknet::Event)]
    struct TreasureHidden {
        #[key]
        user: ContractAddress,
        hiderFee: u128,
        gameWeek: u256
    }

    #[storage]
    struct Storage {
        //Game
        currentGameWeek: u256,
        currentFinderFee: u128,
        currentHiderFee: u128,
        // //Main Game
        // gameWeek:u256,
        // listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot:u256,
        // finderFee:u128,
        // hiderFee:u128,
        // gameGridSize:u256,

        // //Game Totals
        // totalHiddenTreasureValue:u256,

        // //Claim Share Amounts
        // gamerWalletAddress:ContractAddress,
        // totalShareCount:u256,
        // treasureClaimed:u256,

        // //Total Reward Shares
        // totalNumberOfHiders:u256,
        // totalNumberOfFinders:u256,

        //Main_Game: LegacyMap::<gameWeek, (listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot, finderFee, hiderFee)>
        main_game: LegacyMap::<u256, (u256, u128, u128)>,
        //Main_Game_Grid_Size: LegacyMap::<gameWeek, (gameGridSizeX, gameGridSizeY)>
        main_game_grid_size: LegacyMap::<u256, (u256, u256)>,
        //Game_totals: LegacyMap::<gameWeek, totalHiddenTreasureValue>,
        game_totals: LegacyMap::<u256, u256>,
        //Claim_share_amounts: LegacyMap::<(gameWeek, gamerWalletAddress), (totalShareCount, treasureClaimed)>,
        claim_share_amounts: LegacyMap::<(u256, ContractAddress), (u256, bool)>,
        //Total_reward_shares_for_hiders: LegacyMap::<gameWeek, totalNumberOfHiders>
        total_reward_shares_for_hiders: LegacyMap::<u256, u256>,
        //Total_reward_shares_for_finders: LegacyMap::<gameWeek, totalNumberOfFinders>
        total_reward_shares_for_finders: LegacyMap::<u256, u256>,
        //Player_position: LegacyMap::<(gameWeek, gamerWalletAddress), (xPosition, yPosition)>
        player_position: LegacyMap::<(u256, ContractAddress), (u256, u256)>
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self
            .startNewGame(
                0x97a59a28d105842c91d0c411fe8992d4ed39c700bc44467d30589a2679d9b9cc,
                100,
                10,
                5,
                5,
                1,
                1000
            );
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

        fn startNewGame(
            ref self: ContractState,
            listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot: u256,
            finderFee: u128,
            hiderFee: u128,
            gameGridSizeX: u256,
            gameGridSizeY: u256,
            totalNumberOfHidersFromThePreviousWeek: u256,
            totalHiddenTreasureValueFromPreviousWeek: u256
        ) {
            //Increment game week
            self.currentGameWeek.write(self.currentGameWeek.read() + 1);
            self.currentFinderFee.write(finderFee);
            self.currentHiderFee.write(hiderFee);

            //Update main game settings 
            self
                .main_game
                .write(
                    self.currentGameWeek.read(),
                    (listOfPreviousWeeksTreasureCordinatesMerkleTreeRoot, finderFee, hiderFee)
                );
            self
                .main_game_grid_size
                .write(self.currentGameWeek.read(), (gameGridSizeX, gameGridSizeY));

            //Update reward total share values
            self
                .total_reward_shares_for_hiders
                .write(self.currentGameWeek.read(), totalNumberOfHidersFromThePreviousWeek);
            self
                .game_totals
                .write(self.currentGameWeek.read(), totalHiddenTreasureValueFromPreviousWeek);

            println!("main_game {:?}", self.main_game.read(self.currentGameWeek.read()));
            println!(
                "main_game_grid_size {:?}",
                self.main_game_grid_size.read(self.currentGameWeek.read())
            );
            println!(
                "total_reward_shares_for_hiders {:?}",
                self.total_reward_shares_for_hiders.read(self.currentGameWeek.read())
            );
            println!("game_totals {:?}", self.game_totals.read(self.currentGameWeek.read()));
        }

        // fn hideTreasure(ref self: ContractState) {
        //     let caller = get_caller_address();

        //     self
        //         .emit(
        //             TreasureHidden {
        //                 user: caller,
        //                 hiderFee: self.currentHiderFee.read(),
        //                 gameWeek: self.currentGameWeek.read()
        //             }
        //         );
        // }

        // fn finderPlayerMovePostion(ref self: ContractState, direction: u8) {

        //     let gamerWalletAddress = get_caller_address();
        //     let gameWeek = self.currentGameWeek.read();

        //     //get x,y coordinates from player_position mapping 
        //     //increase or decrease the coordinates in the direction
        //     //do a require check, if the new coordinates is valid for current game

        //     //publish event that player has moved
        //     self
        //         .emit(
        //             PlayerMoved {
        //                 user: gamerWalletAddress,
        //                 toXCoordinate: xCoordinate,
        //                 toYCoordinate: yCoordinate,
        //                 gameWeek: gameWeek
        //             }
        //         );

        //     // _checkForTreasure();
        // }

        // fn _checkForTreasure(ref self: ContractState, gamerWalletAddress: ContractAddress, xCoordinate: u256, yCoordinate: u256, gameWeek:u256 ) -> u256 {
        fn _checkForTreasure(ref self: ContractState) -> u256 {
            let eth = IERC20LibraryDispatcher {
                class_hash: class_hash_const::<
                    0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7
                >()
            };
            return eth.total_supply();
        // self
        //     .emit(
        //         checkForTreasure {
        //             user: gamerWalletAddress,
        //             xCoordinate: xCoordinate,
        //             yCoordinate: yCoordinate,
        //             gameWeek: gameWeek
        //         }
        //     );

        // true
        }
    // fn spawnNewPosition(ref self: ContractState, gamerWalletAddress: ContractAddress, xCoordinate: u256, yCoordinate: u256, gameWeek:u256 ) {

    //     self
    //         .emit(
    //             spawnPosition {
    //                 user: gamerWalletAddress,
    //                 xCoordinate: xCoordinate,
    //                 yCoordinate: yCoordinate,
    //                 gameWeek: gameWeek
    //             }
    //         );

    //     // _checkForTreasure();
    // }

    }
}
