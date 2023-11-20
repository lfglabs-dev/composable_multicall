use core::array::SpanTrait;
use core::array::ArrayTrait;
use composable_multicall::IComposableMulticallDispatcherTrait;
use starknet::{
    testing::set_contract_address, class_hash::Felt252TryIntoClassHash, ContractAddress,
    SyscallResultTrait
};
use composable_multicall::{
    DynamicCall, DynamicInput, contract::ComposableMulticall, IComposableMulticallDispatcher
};

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
        // 0x039674cadb16109ec414e371cc8f04eb60a540c52d4880cadb49dfafb8d79797
        fn multiply(self: @ContractState, x: felt252, y: felt252) -> felt252 {
            x * y
        }
        // 0x035a8bb8492337e79bdc674d6f31ac448f8017e26cc7bfe3144fb5d886fe5369
        fn add(self: @ContractState, x: felt252, y: felt252) -> felt252 {
            x + y
        }
        // 0x03dc111d7c3ad1df9806ce1e8eb4f55f57dba117339c545e7593d1f6c3b02662
        fn one(self: @ContractState) -> felt252 {
            1
        }
    }
}

const ONE_SELECTOR: felt252 = 0x03dc111d7c3ad1df9806ce1e8eb4f55f57dba117339c545e7593d1f6c3b02662;
const ADD_SELECTOR: felt252 = 0x035a8bb8492337e79bdc674d6f31ac448f8017e26cc7bfe3144fb5d886fe5369;
const MUL_SELECTOR: felt252 = 0x039674cadb16109ec414e371cc8f04eb60a540c52d4880cadb49dfafb8d79797;

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

use debug::PrintTrait;

#[test]
#[available_gas(2000000000)]
fn test_simple_call() {
    // [ one() ]

    let (multicall, dummy) = deploy();
    let result = multicall
        .aggregate(
            array![
                DynamicCall {
                    to: dummy.contract_address, selector: ONE_SELECTOR, calldata: array![]
                }
            ]
        );

    assert(result.len() == 1, 'Invalid result length');
    let first_call_result = *result.at(0);
    assert(first_call_result.len() == 1, 'Invalid 1st result length');
    assert(*first_call_result.at(0) == 1, 'Invalid 1st result value');
}

#[test]
#[available_gas(2000000000)]
fn test_chained_calls() {
    // [ one(), add(1, 2) ]

    let (multicall, dummy) = deploy();
    let result = multicall
        .aggregate(
            array![
                DynamicCall {
                    to: dummy.contract_address, selector: ONE_SELECTOR, calldata: array![]
                },
                DynamicCall {
                    to: dummy.contract_address,
                    selector: ADD_SELECTOR,
                    calldata: array![DynamicInput::Hardcoded(1), DynamicInput::Hardcoded(2)]
                }
            ]
        );

    assert(result.len() == 2, 'Invalid result length');
    let first_call_result = *result.at(0);
    assert(first_call_result.len() == 1, 'Invalid 1st result length');
    assert(*first_call_result.at(0) == 1, 'Invalid 1st result value');
    let second_call_result = *result.at(1);
    assert(second_call_result.len() == 1, 'Invalid 2nd result length');
    assert(*second_call_result.at(0) == 3, 'Invalid 2nd result value');
}


#[test]
#[available_gas(2000000000)]
fn test_composed_calls() {
    // multiply( add(one(), 2), 2)

    let (multicall, dummy) = deploy();
    let result = multicall
        .aggregate(
            array![
                DynamicCall {
                    to: dummy.contract_address, selector: ONE_SELECTOR, calldata: array![]
                },
                DynamicCall {
                    to: dummy.contract_address,
                    selector: ADD_SELECTOR,
                    calldata: array![DynamicInput::Reference((0, 0)), DynamicInput::Hardcoded(2)]
                },
                DynamicCall {
                    to: dummy.contract_address,
                    selector: MUL_SELECTOR,
                    calldata: array![DynamicInput::Reference((1, 0)), DynamicInput::Hardcoded(2)]
                }
            ]
        );

    assert(result.len() == 3, 'Invalid result length');
    let first_call_result = *result.at(0);
    assert(first_call_result.len() == 1, 'Invalid 1st result length');
    assert(*first_call_result.at(0) == 1, 'Invalid 1st result value');
    let second_call_result = *result.at(1);
    assert(second_call_result.len() == 1, 'Invalid 2nd result length');
    assert(*second_call_result.at(0) == 3, 'Invalid 2nd result value');

    let third_call_result = *result.at(2);
    assert(third_call_result.len() == 1, 'Invalid 3d result length');
    assert(*third_call_result.at(0) == 6, 'Invalid 3d result value');
}
