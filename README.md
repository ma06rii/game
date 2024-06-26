# Treasure Hunt Game

This repository contains a smart contract built with Cairo Language, targeted to be deployed on Starknet.

The smart contract is the core logic for a onchain treasure hunt game. The aim of this project is the create a multiplayer provable onchain game.



## Game Description

Introducing a revolutionary treasure hunt game on the Starknet blockchain that brings strategic gameplay and community to new heights. Prepare to embark on an adventure where every move you make has the potential to yield in-game rewards. As the game leverages the privacy preserving features of zero-knowledge proofs of Cairo and the Starknet protocol, players can be assured of the integrity of the game. 


Here's the deal, for a small fee gamers can search for treasure in the game. Finding treasure yields more in-game tokens and Starknet tokens to incentivise players and provide more opportunities to play again. Your mission is to strategically search for treasure across a vast 2D adventure world. The challenge is to find the treasure that has been hidden by other gamers. A new game is started approximately once every week. Both sets of gamers are competing for the in-game token rewards. Gamers can choose to be a ‘hider’ of treasure or a ‘finder’ of treasure at any time. So gamers can choose which side they are on. 


There is also a third gamer option whereby if you don’t fancy looking for treasure or hiding treasure, a User could opt-in to help govern the game features by purchasing an NFT which represents 1 vote when voting on proposals for game changes or improvements.




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
2. Admin Player: Start New Game *(weekly)*
3. Hider Player: Claim Treasure

### Finding Treasure

1. Finder Player: Generation Position on Game Board
2. Finder Player: Move Position And Check For Treasure
3. Admin Player: Start New Game *(weekly)*
4. Finder Player: Claim Treasure
