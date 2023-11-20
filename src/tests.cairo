use starknet::{
    testing::set_contract_address, class_hash::Felt252TryIntoClassHash, ContractAddress,
    SyscallResultTrait
};
use composable_multicall::{contract::ComposableMulticall, IComposableMulticallDispatcher};

#[starknet::interface]
trait IDummy<TState> {
    fn multiply(self: @TState, x: felt252, y: felt252) -> felt252;
    fn add(self: @TState, x: felt252, y: felt252) -> felt252;
    fn one(self: @TState) -> felt252;
}

#[starknet::contract]
mod DummyContract {
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};


    #[storage]
    struct Storage {
        opened: bool,
        blacklisted: LegacyMap<ContractAddress, bool>,
    }

    #[external(v0)]
    impl DummyImpl of super::IDummy<ContractState> {
        fn multiply(self: @ContractState, x: felt252, y: felt252) -> felt252 {
            x * y
        }
        fn add(self: @ContractState, x: felt252, y: felt252) -> felt252 {
            x + y
        }
        fn one(self: @ContractState) -> felt252 {
            1
        }
    }
}

fn deploy() -> (IComposableMulticallDispatcher, IDummyDispatcher) {
    let (cm_address, _) = starknet::deploy_syscall(
        ComposableMulticall::TEST_CLASS_HASH.try_into().unwrap(), 0, ArrayTrait::new().span(), false
    )
        .unwrap_syscall();

    let (d_address, _) = starknet::deploy_syscall(
        DummyContract::TEST_CLASS_HASH.try_into().unwrap(), 0, ArrayTrait::new().span(), false
    )
        .unwrap_syscall();

    (
        IComposableMulticallDispatcher { contract_address: cm_address },
        IDummyDispatcher { contract_address: d_address }
    )
}

#[test]
#[available_gas(2000000000)]
fn test_dummy_contract() {
    let (_, dummy) = deploy();
    assert(dummy.one() == 1, 'invalid one');
    assert(dummy.add(dummy.multiply(2, 3), dummy.one()) == 7, 'invalid result');
}

