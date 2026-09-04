// A test-only ERC-20 with an unrestricted mint.
//
// The game contract talks to two tokens through the ERC20 dispatcher: the game
// token it charges fees in (USDC, 6 decimals) and the ROZ reward token it
// accrues rewards in (18 decimals). Neither can be exercised in a test without
// a real ERC-20 deployed at a real address - a plain placeholder address makes
// every balance_of and transfer_from revert with "not deployed".
//
// This contract stands in for both. It is deployed twice with different
// decimals, so the tests can charge fees in one and pay rewards in the other,
// exactly as the live contract will.
//
// NEVER DEPLOY THIS TO MAINNET. mint() is deliberately unguarded so a test can
// fund any wallet in one call; on a live network that is a free money printer.
// It is kept out of the deployment steps in section 5 for that reason.
#[starknet::interface]
pub trait IMockERC20<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
}
use starknet::ContractAddress;

#[starknet::contract]
pub mod MockERC20 {
    use openzeppelin::token::erc20::{
        DefaultConfig as ERC20DefaultConfig, ERC20Component, ERC20HooksEmptyImpl,
    };
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // The full ERC-20 surface, which is what the game contract's dispatcher
    // calls: balance_of, allowance, approve, transfer and transfer_from.
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    // name and symbol are taken as arguments so a test can deploy this twice
    // and tell the two tokens apart in a trace.
    //
    // DECIMALS ARE NOT CONFIGURABLE HERE. The OpenZeppelin component reports 18
    // through its DefaultConfig, and that is fine for these tests: the game
    // contract never reads decimals() from either token. Every amount it holds
    // is a RAW unit count, so a "USDC" balance of 5000000 means $5.00 to the
    // contract whatever the token claims its decimals are. The distinction
    // matters to a frontend, not to the arithmetic under test.
    #[constructor]
    fn constructor(ref self: ContractState, name: ByteArray, symbol: ByteArray) {
        self.erc20.initializer(name, symbol);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        // Unguarded on purpose - see the warning at the top of this file.
        #[external(v0)]
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.erc20.mint(recipient, amount);
        }
    }
}
