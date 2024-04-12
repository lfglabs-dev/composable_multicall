use core::result::ResultTrait;
use core::array::SpanTrait;
use core::array::ArrayTrait;
use composable_multicall::IComposableMulticallDispatcherTrait;
use starknet::{
    testing::set_contract_address, class_hash::Felt252TryIntoClassHash, ContractAddress,
    SyscallResultTrait
};
use composable_multicall::{
    Execution, DynamicCall, DynamicCalldata, DynamicFelt, contract::ComposableMulticall,
    IComposableMulticallDispatcher
};

#[starknet::interface]
trait IDummy<TState> {
    fn multiply(self: @TState, x: felt252, y: felt252) -> felt252;
    fn add(self: @TState, x: felt252, y: felt252) -> felt252;
    fn one(self: @TState) -> felt252;
    fn zero(self: @TState) -> felt252;
    fn foo(self: @TState) -> (ContractAddress, felt252);
    fn array(self: @TState) -> (felt252, Array<felt252>);
    fn sum_array(self: @TState, arr: Array<felt252>) -> felt252;
    fn assert_eq(self: @TState, x: felt252, y: felt252);
}

#[starknet::contract]
mod DummyContract {
    use core::array::ArrayTrait;
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};


    #[storage]
    struct Storage {
        opened: bool,
        blacklisted: LegacyMap<ContractAddress, bool>,
    }

    #[abi(embed_v0)]
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
        // 0x01319238daf40223d6021718c846ac2a0c0ef028ecc765972e999a8ac79662a8
        fn zero(self: @ContractState) -> felt252 {
            0
        }
        // 0x03a05e9d201ce7db4a6dc92496470b4185e4669f16a53d77f908a039afaf42d4
        fn foo(self: @ContractState) -> (ContractAddress, felt252) {
            (
                starknet::get_contract_address(),
                0x03dc111d7c3ad1df9806ce1e8eb4f55f57dba117339c545e7593d1f6c3b02662
            )
        }
        // 0x011df9302a3d4661054b99616723b49f594b0c96a39b6f41a479eb98ae896396
        fn array(self: @ContractState) -> (felt252, Array<felt252>) {
            ('example_value', array![1, 2, 3, 4, 5])
        }
        // 0x03c7c309d4ab6ff41bb0bf5d86aa20c3741e2002acc4dc2712284918abb4e194
        fn sum_array(self: @ContractState, mut arr: Array<felt252>) -> felt252 {
            let mut sum = 0;
            loop {
                match arr.pop_front() {
                    Option::Some(value) => { sum += value; },
                    Option::None => { break; }
                }
            };
            sum
        }
        // 0x005562b3e932b4d139366854d5a2e578382e6a3b6572ac9943d55e7efbe43d00
        fn assert_eq(self: @ContractState, x: felt252, y: felt252) {
            assert(x == y, 'y does not equal y');
        }
    }
}

const ONE_SELECTOR: felt252 = 0x03dc111d7c3ad1df9806ce1e8eb4f55f57dba117339c545e7593d1f6c3b02662;
const ZER_SELECTOR: felt252 = 0x01319238daf40223d6021718c846ac2a0c0ef028ecc765972e999a8ac79662a8;
const ADD_SELECTOR: felt252 = 0x035a8bb8492337e79bdc674d6f31ac448f8017e26cc7bfe3144fb5d886fe5369;
const MUL_SELECTOR: felt252 = 0x039674cadb16109ec414e371cc8f04eb60a540c52d4880cadb49dfafb8d79797;
const FOO_SELECTOR: felt252 = 0x01b1a0649752af1b28b3dc29a1556eee781e4a4c3a1f7f53f90fa834de098c4d;
const ARR_SELECTOR: felt252 = 0x011df9302a3d4661054b99616723b49f594b0c96a39b6f41a479eb98ae896396;
const SUM_SELECTOR: felt252 = 0x03c7c309d4ab6ff41bb0bf5d86aa20c3741e2002acc4dc2712284918abb4e194;
const EQU_SELECTOR: felt252 = 0x005562b3e932b4d139366854d5a2e578382e6a3b6572ac9943d55e7efbe43d00;

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

#[test]
#[available_gas(2000000000)]
fn test_simple_call() {
    // [ one() ]

    let (multicall, dummy) = deploy();
    let result = multicall
        .aggregate(
            array![
                DynamicCall {
                    execution: Execution::Static,
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(ONE_SELECTOR),
                    calldata: array![]
                }
            ]
        );

    assert(result.len() == 1, 'Invalid result length');

    match result.at(0) {
        Result::Err => { panic_with_felt252('Call failed'); },
        Result::Ok(_first_call_result) => {
            let first_call_result = *_first_call_result;
            assert(first_call_result.len() == 1, 'Invalid 1st result length');
            assert(*first_call_result.at(0) == 1, 'Invalid 1st result value');
        }
    }
}

#[test]
#[available_gas(2000000000)]
fn test_composing_arrays() {
    // [ one() ]

    let (multicall, dummy) = deploy();
    let result = multicall
        .aggregate(
            array![
                DynamicCall {
                    execution: Execution::Static,
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(ARR_SELECTOR),
                    calldata: array![]
                },
                DynamicCall {
                    execution: Execution::Static,
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(SUM_SELECTOR),
                    calldata: array![DynamicCalldata::ArrayReference((0, 1))]
                }
            ]
        );

    assert(result.len() == 2, 'Invalid result length');

    match result.at(0) {
        Result::Err => { panic_with_felt252('Call failed'); },
        Result::Ok(_first_call_result) => {
            let first_call_result = *_first_call_result;
            assert(first_call_result.len() == 7, 'Invalid 1st result length');
            assert(*first_call_result.at(0) == 'example_value', 'Invalid 1st result value');
        }
    }

    match result.at(1) {
        Result::Err => { panic_with_felt252('Call failed'); },
        Result::Ok(_second_call_result) => {
            let second_call_result = *_second_call_result;
            assert(second_call_result.len() == 1, 'Invalid 2nd result length');
            assert(*second_call_result.at(0) == 15, 'Invalid 2nd result value');
        }
    }
}

#[test]
#[available_gas(2000000000)]
fn test_dynamic_function() {
    // [ (foo())() ]

    let (multicall, dummy) = deploy();
    let result = multicall
        .aggregate(
            array![
                DynamicCall {
                    execution: Execution::Static,
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(FOO_SELECTOR),
                    calldata: array![]
                },
                DynamicCall {
                    execution: Execution::Static,
                    to: DynamicFelt::Reference((0, 0)),
                    selector: DynamicFelt::Reference((0, 1)),
                    calldata: array![]
                }
            ]
        );

    assert(result.len() == 2, 'Invalid result length');

    match result.at(0) {
        Result::Err => { panic_with_felt252('Call failed'); },
        Result::Ok(_first_call_result) => {
            let first_call_result = *_first_call_result;
            assert(first_call_result.len() == 2, 'Invalid 1st result length');
            assert(
                *first_call_result.at(0) == dummy.contract_address.into(),
                'Invalid 1st result 1st value'
            );
            assert(*first_call_result.at(1) == ONE_SELECTOR, 'Invalid 1st result 2nd value');
        }
    }

    match result.at(1) {
        Result::Err => { panic_with_felt252('Call failed'); },
        Result::Ok(_second_call_result) => {
            let second_call_result = *_second_call_result;
            assert(second_call_result.len() == 1, 'Invalid 2nd result length');
            assert(*second_call_result.at(0) == 1, 'Invalid 2nd result 1st value');
        }
    }
}

use debug::PrintTrait;

#[test]
#[available_gas(2000000000)]
fn test_conditional_execution() {
    // [ if one() == 1 then one() ]

    let (multicall, dummy) = deploy();
    let result = multicall
        .aggregate(
            array![
                DynamicCall {
                    execution: Execution::Static,
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(ONE_SELECTOR),
                    calldata: array![]
                },
                DynamicCall {
                    execution: Execution::IfEqual((0, 0, 1)),
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(ONE_SELECTOR),
                    calldata: array![]
                }
            ]
        );

    assert(result.len() == 2, 'Invalid result length');

    match result.at(0) {
        Result::Err => { panic_with_felt252('Call failed'); },
        Result::Ok(_first_call_result) => {
            let first_call_result = *_first_call_result;
            assert(first_call_result.len() == 1, 'Invalid 1st result length');
            assert(*first_call_result.at(0) == 1, 'Invalid 1st result 1st value');
        }
    }

    match result.at(1) {
        Result::Err => { panic_with_felt252('Call failed'); },
        Result::Ok(_second_call_result) => {
            let second_call_result = *_second_call_result;
            assert(second_call_result.len() == 1, 'Invalid 2nd result length');
            assert(*second_call_result.at(0) == 1, 'Invalid 2nd result 1st value');
        }
    }
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
                    execution: Execution::Static,
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(ONE_SELECTOR),
                    calldata: array![]
                },
                DynamicCall {
                    execution: Execution::Static,
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(ADD_SELECTOR),
                    calldata: array![DynamicCalldata::Hardcoded(1), DynamicCalldata::Hardcoded(2)]
                }
            ]
        );

    assert(result.len() == 2, 'Invalid result length');

    match result.at(0) {
        Result::Err => { panic_with_felt252('Call failed'); },
        Result::Ok(_first_call_result) => {
            let first_call_result = *_first_call_result;
            assert(first_call_result.len() == 1, 'Invalid 1st result length');
            assert(*first_call_result.at(0) == 1, 'Invalid 1st result value');
        }
    }

    match result.at(1) {
        Result::Err => { panic_with_felt252('Call failed'); },
        Result::Ok(_second_call_result) => {
            let second_call_result = *_second_call_result;
            assert(second_call_result.len() == 1, 'Invalid 2nd result length');
            assert(*second_call_result.at(0) == 3, 'Invalid 2nd result value');
        }
    }
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
                    execution: Execution::Static,
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(ONE_SELECTOR),
                    calldata: array![]
                },
                DynamicCall {
                    execution: Execution::Static,
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(ADD_SELECTOR),
                    calldata: array![
                        DynamicCalldata::Reference((0, 0)), DynamicCalldata::Hardcoded(2)
                    ]
                },
                DynamicCall {
                    execution: Execution::Static,
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(MUL_SELECTOR),
                    calldata: array![
                        DynamicCalldata::Reference((1, 0)), DynamicCalldata::Hardcoded(2)
                    ]
                }
            ]
        );

    assert(result.len() == 3, 'Invalid result length');

    match result.at(0) {
        Result::Err => { panic_with_felt252('Call failed'); },
        Result::Ok(_first_call_result) => {
            let first_call_result = *_first_call_result;
            assert(first_call_result.len() == 1, 'Invalid 1st result length');
            assert(*first_call_result.at(0) == 1, 'Invalid 1st result value');
        }
    }

    match result.at(1) {
        Result::Err => { panic_with_felt252('Call failed'); },
        Result::Ok(_second_call_result) => {
            let second_call_result = *_second_call_result;
            assert(second_call_result.len() == 1, 'Invalid 2nd result length');
            assert(*second_call_result.at(0) == 3, 'Invalid 2nd result value');
        }
    }

    match result.at(2) {
        Result::Err => { panic_with_felt252('Call failed'); },
        Result::Ok(_third_call_result) => {
            let third_call_result = *_third_call_result;
            assert(third_call_result.len() == 1, 'Invalid 3d result length');
            assert(*third_call_result.at(0) == 6, 'Invalid 3d result value');
        }
    }
}


#[test]
#[available_gas(2000000000)]
fn test_catch_then_execution() {
    // [ if one() == 1 then one() ]

    let (multicall, dummy) = deploy();
    let assertion_results = multicall
        .aggregate(
            array![
                DynamicCall {
                    execution: Execution::Static,
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(EQU_SELECTOR),
                    calldata: array![DynamicCalldata::Hardcoded(1), DynamicCalldata::Hardcoded(0)]
                },
                DynamicCall {
                    execution: Execution::Static,
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(EQU_SELECTOR),
                    calldata: array![DynamicCalldata::Hardcoded(1), DynamicCalldata::Hardcoded(1)]
                },
            ]
        );

    assert(assertion_results.len() == 2, 'wrong results len');
    assert(assertion_results.at(0).is_err(), 'first call must be an error');
    assert(assertion_results.at(1).is_ok(), 'first call must be successful');

    let catch_result = multicall
        .aggregate(
            array![
                DynamicCall {
                    execution: Execution::Static,
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(EQU_SELECTOR),
                    calldata: array![DynamicCalldata::Hardcoded(1), DynamicCalldata::Hardcoded(0)]
                },
                DynamicCall {
                    execution: Execution::Catch(0), // we catch error on call 0
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(ONE_SELECTOR),
                    calldata: array![]
                },
                DynamicCall {
                    execution: Execution::Then(0), // we catch success on call 0
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(ZER_SELECTOR),
                    calldata: array![]
                },
            ]
        );
    assert(catch_result.len() == 3, 'wrong result length');
    assert(catch_result.at(0).is_err(), 'first call must be an error');
    match catch_result.at(1) {
        Result::Ok(_second_call) => {
            let second_call = *_second_call;
            assert(*second_call.at(0) == 1, 'wrong call result');
        },
        Result::Err(_) => { panic_with_felt252('Catch should be triggered'); }
    }
    match catch_result.at(2) {
        Result::Ok(_) => { panic_with_felt252('Then should not be triggered'); },
        Result::Err(err) => { assert(*err.at(0) == 'starknetid/call-skipped', 'wrong skip error'); }
    }

    let then_result = multicall
        .aggregate(
            array![
                DynamicCall {
                    execution: Execution::Static,
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(EQU_SELECTOR),
                    calldata: array![DynamicCalldata::Hardcoded(1), DynamicCalldata::Hardcoded(1)]
                },
                DynamicCall {
                    execution: Execution::Catch(0), // we catch error on call 0
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(ONE_SELECTOR),
                    calldata: array![]
                },
                DynamicCall {
                    execution: Execution::Then(0), // we catch success on call 0
                    to: DynamicFelt::Hardcoded(dummy.contract_address.into()),
                    selector: DynamicFelt::Hardcoded(ZER_SELECTOR),
                    calldata: array![]
                },
            ]
        );
    assert(then_result.len() == 3, 'wrong result length');
    assert(then_result.at(0).is_ok(), 'first call must be a success');

    match then_result.at(1) {
        Result::Ok(_) => { panic_with_felt252('Catch should not be triggered'); },
        Result::Err(err) => { assert(*err.at(0) == 'starknetid/call-skipped', 'wrong skip error'); }
    }
    match then_result.at(2) {
        Result::Ok(_second_call) => {
            let second_call = *_second_call;
            assert(*second_call.at(0) == 0, 'wrong call result');
        },
        Result::Err(_) => { panic_with_felt252('Then should be triggered'); }
    }
}
