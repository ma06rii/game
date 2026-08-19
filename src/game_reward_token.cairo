// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo v2.0.0

#[starknet::contract]
mod ROZToken {
    // These four paths are the v2.0.0 ones. The file was generated against a
    // v3 preview, whose flat package names (openzeppelin_access, and so on) do
    // NOT resolve here: Scarb.toml depends on the single umbrella package
    // "openzeppelin", which re-exports each sub-package under a nested path -
    // openzeppelin_access as access, openzeppelin_upgrades as upgrades, and so
    // on. There is no openzeppelin_interfaces package at all in v2.0.0; the
    // IUpgradeable trait lives beside the component it belongs to.
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::{
        DefaultConfig as ERC20DefaultConfig, ERC20Component, ERC20HooksEmptyImpl,
    };
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::{ClassHash, ContractAddress, get_caller_address};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // External
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, recipient: ContractAddress, owner: ContractAddress) {
        self.erc20.initializer("ROZToken", "ROZ");
        self.ownable.initializer(owner);

        self.erc20.mint(recipient, 5000000000000000000000000000);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn burn(ref self: ContractState, value: u256) {
            self.erc20.burn(get_caller_address(), value);
        }
    }

    //
    // Upgradeable
    //

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
