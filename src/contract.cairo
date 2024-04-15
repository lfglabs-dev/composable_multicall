#[starknet::contract]
mod ComposableMulticall {
    use core::result::ResultTrait;
    use core::option::OptionTrait;
    use core::traits::TryInto;
    use core::array::ArrayTrait;
    use core::array::SpanTrait;
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};
    use composable_multicall::{
        IComposableMulticall, DynamicCall, Execution, DynamicFelt, DynamicCalldata
    };
    use starknet::call_contract_syscall;

    #[storage]
    struct Storage {
        opened: bool,
        blacklisted: LegacyMap<ContractAddress, bool>,
    }

    #[abi(embed_v0)]
    impl ComposableMulticallImpl of IComposableMulticall<ContractState> {
        fn raw_aggregate(
            self: @ContractState, calls: Array<DynamicCall>
        ) -> Array<Result<Span<felt252>, Array<felt252>>> {
            execute_multicall(calls.span())
        }

        fn aggregate(self: @ContractState, calls: Array<DynamicCall>) -> Array<Span<felt252>> {
            let mut results = execute_multicall(calls.span());
            let mut output = ArrayTrait::new();
            // filter Ok results
            loop {
                match results.pop_front() {
                    Option::Some(call_output) => {
                        match call_output {
                            Result::Ok(valid_call_output) => { output.append(valid_call_output); },
                            Result::Err(_) => { continue; }
                        }
                    },
                    Option::None => { break; },
                }
            };
            output
        }
    }

    fn unwrap_call_output(
        call_outputs: @Array<Result<Span<felt252>, Array<felt252>>>, call_id: usize
    ) -> @Span<felt252> {
        match call_outputs.at(call_id) {
            Result::Ok(valid_call_output) => { valid_call_output },
            Result::Err(_) => { panic_with_felt252('failing call dep:') }
        }
    }

    fn build_input(
        call_outputs: @Array<Result<Span<felt252>, Array<felt252>>>, mut dynamic_input: @DynamicFelt
    ) -> felt252 {
        match dynamic_input {
            DynamicFelt::Hardcoded(value) => { *value },
            DynamicFelt::Reference((
                call_id, felt_id
            )) => {
                let valid_call_output = unwrap_call_output(call_outputs, *call_id);
                *(*valid_call_output).at(*felt_id)
            }
        }
    }

    fn build_inputs(
        call_outputs: @Array<Result<Span<felt252>, Array<felt252>>>,
        mut dynamic_inputs: Span::<DynamicCalldata>
    ) -> Array::<felt252> {
        let mut output: Array<felt252> = Default::default();
        loop {
            match dynamic_inputs.pop_front() {
                Option::Some(dynamic_input) => {
                    match dynamic_input {
                        DynamicCalldata::Hardcoded(value) => { output.append(*value); },
                        DynamicCalldata::Reference((
                            call_id, felt_id
                        )) => {
                            let valid_call_output = unwrap_call_output(call_outputs, *call_id);
                            output.append(*valid_call_output[*felt_id]);
                        },
                        DynamicCalldata::ArrayReference((
                            call_id, felt_id
                        )) => {
                            let valid_call_output = unwrap_call_output(call_outputs, *call_id);
                            let arr_length = *(*valid_call_output).at(*felt_id);
                            output.append(arr_length);
                            let felt_array_stop = *felt_id + (arr_length).try_into().unwrap();
                            let mut i = *felt_id;
                            loop {
                                if i == felt_array_stop {
                                    break;
                                };
                                i += 1;
                                output.append(*(*valid_call_output).at(i));
                            }
                        }
                    };
                },
                Option::None => { break; }
            }
        };
        output
    }

    fn skip_call(ref results: Array<Result<Span<felt252>, Array<felt252>>>) {
        results.append(Result::Err(array!['starknetid/call-skipped']));
    }

    fn execute_multicall(
        mut calls: Span<DynamicCall>
    ) -> Array<Result<Span<felt252>, Array<felt252>>> {
        let mut results: Array<Result<Span<felt252>, Array<felt252>>> = ArrayTrait::new();
        let mut idx = 0;
        loop {
            match calls.pop_front() {
                Option::Some(call) => {
                    match call.execution {
                        Execution::Static => {},
                        Execution::IfEqual((
                            call_id, felt_id, value
                        )) => {
                            // if specified output felt is different from specified value, we skip that call
                            let valid_call_output = unwrap_call_output(@results, *call_id);
                            if *(*valid_call_output).at(*felt_id) != *value {
                                skip_call(ref results);
                                continue;
                            }
                        },
                        Execution::IfNotEqual((
                            call_id, felt_id, value
                        )) => {
                            // if specified output felt equals the specified value, we skip that call
                            let valid_call_output = unwrap_call_output(@results, *call_id);
                            if *(*valid_call_output).at(*felt_id) == *value {
                                skip_call(ref results);
                                continue;
                            }
                        },
                        Execution::Catch(call_id) => {
                            if results.at(*call_id).is_ok() {
                                skip_call(ref results);
                                continue;
                            }
                        },
                        Execution::Then(call_id) => {
                            if results.at(*call_id).is_err() {
                                skip_call(ref results);
                                continue;
                            }
                        },
                        Execution::Except(call_id) => {
                            match results.at(*call_id) {
                                Result::Err(_revert_reason) => {
                                    let mut revert_reason = _revert_reason.span();
                                    let mut data = ArrayTrait::new();
                                    data.append('starknetid/multicall-failed');
                                    data.append(idx);
                                    loop {
                                        match revert_reason.pop_front() {
                                            Option::Some(item) => { data.append(*item); },
                                            Option::None(()) => { break; },
                                        };
                                    };
                                    panic(data);
                                },
                                Result::Ok(_) => {}
                            }
                        },
                    };
                    let call_result = call_contract_syscall(
                        build_input(@results, call.to).try_into().unwrap(),
                        build_input(@results, call.selector),
                        build_inputs(@results, call.calldata.span()).span()
                    );
                    results.append(call_result);
                    idx = idx + 1;
                },
                Option::None(_) => { break; },
            };
        };
        results
    }
}
