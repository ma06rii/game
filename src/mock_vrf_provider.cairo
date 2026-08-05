// =============================================================================
// MockVrfProvider - a TESTNET-ONLY stand-in for Cartridge's VRF provider.
// =============================================================================
//
// WHY THIS CONTRACT EXISTS
// ------------------------
// The game contract asks a "VRF provider" for a random number when a player
// spawns onto the game board. In production that provider is Cartridge's, at
// 0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f (the same
// address on Sepolia and on mainnet).
//
// Cartridge's real provider does NOT generate randomness itself. It only hands
// out a number that was proven and submitted beforehand, in the same
// transaction, by Cartridge's paymaster service:
//
//   1. The player's wallet builds a multicall.
//   2. Cartridge's PAYMASTER wraps that multicall with `submit_random` (which
//      carries a cryptographic proof) and `assert_consumed`.
//   3. Only then does `consume_random` have a value to return.
//
// Cartridge have confirmed their Sepolia paymaster is down. Step 2 therefore
// never happens, so `consume_random` reverts with 'VrfProvider: not fulfilled'
// and no player can spawn. Paying our own gas with a standard Argent/Braavos
// wallet does not help - that removes the paymaster from the path entirely,
// which is precisely the component that was supposed to submit the proof.
//
// This mock breaks that dependency: its `consume_random` MAKES a number on the
// spot instead of looking one up, so nothing ever needs to call `submit_random`
// and the spawn transaction can never fail for lack of a proof.
//
// WHAT THIS IS NOT
// ----------------
// This is NOT a verifiable random function. The value it returns is derived
// from data that is either public or influenceable by the caller, so a
// determined player could predict or steer their spawn coordinates. That is an
// acceptable trade on a testnet where the goal is to exercise the game loop,
// and completely unacceptable anywhere real value is at stake.
//
// Two things keep it off mainnet:
//   1. The constructor below REFUSES to deploy on mainnet.
//   2. The game contract's `update_vrf_provider` setter means switching back to
//      Cartridge's real provider is a single owner transaction - no redeploy.
//      Run it as soon as Cartridge's Sepolia service recovers.
//
// A NOTE ON THE INTERFACE
// -----------------------
// This contract deliberately implements `IVrfProvider` from lib.cairo - the
// exact same trait the game contract's dispatcher calls through. That is what
// makes the mock and the real provider interchangeable by address alone, and
// why swapping between them needs no code change in the game contract and no
// code change in the frontend.

#[starknet::contract]
mod MockVrfProvider {
    use core::poseidon::poseidon_hash_span;
    use project_name::{IVrfProvider, Source};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_tx_info};

    // The chain id of Starknet mainnet, as the short string 'SN_MAIN'.
    // Used by the constructor to refuse deployment there.
    const SN_MAIN_CHAIN_ID: felt252 = 0x534e5f4d41494e;

    #[storage]
    struct Storage {
        //Consume_counts: LegacyMap::<randomnessKey, numberOfTimesConsumed>
        //Bumped on every consume_random so that two calls made in the same
        //block, by the same player, still produce different numbers.
        consume_counts: LegacyMap<ContractAddress, felt252>,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Hard stop: this contract must never exist on mainnet. The check lives
        // here rather than in a deploy script because a script can be skipped,
        // edited or run by hand, whereas this assertion travels with the class
        // itself and cannot be bypassed.
        let chainId: felt252 = get_tx_info().unbox().chain_id;

        assert(chainId != SN_MAIN_CHAIN_ID, 'mock vrf is testnet only');
    }

    #[abi(embed_v0)]
    impl MockVrfProviderImpl of IVrfProvider<ContractState> {
        // Deliberately does nothing.
        //
        // The real provider uses this call to register that a request is coming,
        // so its paymaster knows to attach a proof. The mock needs no such
        // warning - it invents the number at consume time - but the entrypoint
        // MUST still exist, and MUST keep this exact parameter order, because
        // the frontend sends it as the first half of the spawn multicall:
        //
        //   contractAddress: <this contract>
        //   entrypoint:      'request_random'
        //   calldata:        [gameContractAddress, "0", myAccountAddress]
        //                     ^ caller             ^ Source::Nonce  ^ payload
        //
        // That calldata is hand-assembled, not built from an ABI, so reordering
        // or renaming these parameters would not raise an error - it would
        // silently pass the wrong values.
        fn request_random(self: @ContractState, caller: ContractAddress, source: Source) {}

        // Returns a fresh pseudo-random felt252 and never reverts.
        //
        // "Never reverts" is the entire behavioural difference between this
        // contract and Cartridge's, and the single reason spawning starts
        // working again.
        fn consume_random(ref self: ContractState, source: Source) -> felt252 {
            let caller = get_caller_address();

            // The Source tells us who the randomness is *for*. The game contract
            // always sends Source::Nonce(playerAddress), so the player's address
            // is what we key the counter on. Source::Salt carries a bare felt
            // with no address in it, so in that case we fall back to whoever
            // made the call.
            let randomnessKey: ContractAddress = match source {
                Source::Nonce(gamerWalletAddress) => gamerWalletAddress,
                Source::Salt(_) => caller,
            };

            // Read the running count for this key and bump it, so that a second
            // call in the same block - or even in the same transaction - hashes
            // a different input and therefore returns a different number.
            let consumeCount: felt252 = self.consume_counts.read(randomnessKey);

            self.consume_counts.write(randomnessKey, consumeCount + 1);

            // Mix everything that varies between calls into one Poseidon hash.
            // Poseidon is used because it is the native Starknet hash and gives
            // a well-spread felt252, which the game contract then splits into
            // high and low halves to derive the X and Y grid coordinates.
            //
            //   consumeCount      - differs between repeated calls
            //   randomnessKey     - differs between players
            //   caller            - the game contract making the request
            //   transaction_hash  - differs between transactions
            //   block_timestamp   - differs between blocks
            //
            // Spread, not secrecy, is what this achieves. See the warning at the
            // top of this file.
            let transactionHash: felt252 = get_tx_info().unbox().transaction_hash;

            let blockTimestamp: felt252 = get_block_timestamp().into();

            return poseidon_hash_span(
                array![
                    consumeCount, randomnessKey.into(), caller.into(), transactionHash,
                    blockTimestamp,
                ]
                    .span(),
            );
        }
    }
}
