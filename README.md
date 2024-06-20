# Treasure Hunt Game for Starknet

This repository contains a smart contract built with Cairo Language, targeted to be deployed on Starknet.

The smart contract is the core logic for a onchain treasure hunt game. The aim of this project is the create a multiplayer provable onchain game.




## Game Functions 

### User

- hideTreasure
- claimReward
- finderPlayerMovePosition
- finderPlayerStartNewPosition
- getFinderPlayerPosition *(read only)*

### User Utilities

- getGameLandownerFee *(read only)*
- getNumWords *(read only)*
- getPublishDelay *(read only)*
- getCallbackFeeLimit *(read only)*
- getGameMasterFee *(read only)*
- getGasFeeReservation *(read only)*
- getGameTokenReward *(read only)*
- getGameWeek *(read only)*
- getGameWeekTreasureTotal *(read only)*
- getGameGridSize *(read only)*
- getTotalNumberOfFinders *(read only)*
- getTotalNumberOfHiders *(read only)*
- getMainGameInfo *(read only)*
- getSpawnNewPositionFee *(read only)*
- getHiderPlayerFee *(read only)*
- getFinderPlayerFee *(read only)*
- getClaimShareAmounts *(read only)*

### Admin

- startNewGame
- validateTreasureCoordinates

### Admin Utilities

- updateGasFeeReservation
- updateGameMasterFee
- updateGameLandownerFee
- updateCallbackFeeLimit
- updateRandomnessPublishDelay
- updateRandomnessSeedModuloDivisor
- withdrawETHBalance




## Gameplay

### Hiding Treasure

1. Hider Player: Hide Treasure
2. Admin Player: Start New Game
3. Hider Player: Claim Treasure

### Finding Treasure

1. Finder Player: Generation Position on Game Board
2. Finder Player: Move Position And Check For Treasure
3. Admin Player: Start New Game
4. Finder Player: Claim Treasure