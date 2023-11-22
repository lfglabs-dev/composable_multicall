#[starknet::contract]
mod ComposableMulticall {
    use core::option::OptionTrait;
    use core::traits::TryInto;
    use core::array::ArrayTrait;
    use core::array::SpanTrait;
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};
    use composable_multicall::{IComposableMulticall, DynamicCall, DynamicFelt, DynamicCalldata};
    use starknet::call_contract_syscall;

    #[storage]
    struct Storage {
        opened: bool,
        blacklisted: LegacyMap<ContractAddress, bool>,
    }

    #[external(v0)]
    impl ComposableMulticallImpl of IComposableMulticall<ContractState> {
        fn aggregate(self: @ContractState, calls: Array<DynamicCall>) -> Array<Span<felt252>> {
            execute_multicall(calls.span())
        }
    }

    fn build_input(
        call_outputs: @Array<Span<felt252>>, mut dynamic_input: @DynamicFelt
    ) -> felt252 {
        match dynamic_input {
            DynamicFelt::Hardcoded(value) => { *value },
            DynamicFelt::Reference((
                call_id, felt_id
            )) => {
                let call_output = *call_outputs.at(*call_id);
                let felt = call_output.at(*felt_id);
                *felt
            }
        }
    }

    fn build_inputs(
        call_outputs: @Array<Span<felt252>>, mut dynamic_inputs: Span::<DynamicCalldata>
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
                            let call_output = *call_outputs.at(*call_id);
                            let felt = call_output.at(*felt_id);
                            output.append(*felt);
                        },
                        DynamicCalldata::ArrayReference((
                            call_id, felt_id
                        )) => {
                            let call_output = *call_outputs.at(*call_id);
                            let arr_length = *call_output.at(*felt_id);
                            output.append(arr_length);
                            let felt_array_stop = *felt_id + (arr_length).try_into().unwrap();
                            let mut i = *felt_id;
                            loop {
                                if i == felt_array_stop {
                                    break;
                                };
                                i += 1;
                                output.append(*call_output.at(i));
                            }
                        }
                    };
                },
                Option::None => { break; }
            }
        };
        output
    }

    fn execute_multicall(mut calls: Span<DynamicCall>) -> Array<Span<felt252>> {
        let mut result: Array<Span<felt252>> = ArrayTrait::new();
        let mut idx = 0;
        loop {
            match calls.pop_front() {
                Option::Some(call) => {
                    match call_contract_syscall(
                        build_input(@result, call.to).try_into().unwrap(),
                        build_input(@result, call.selector),
                        build_inputs(@result, call.calldata.span()).span()
                    ) {
                        Result::Ok(retdata) => {
                            result.append(retdata);
                            idx = idx + 1;
                        },
                        Result::Err(mut revert_reason) => {
                            let mut data = ArrayTrait::new();
                            data.append('starknetid/multicall-failed');
                            data.append(idx);
                            loop {
                                match revert_reason.pop_front() {
                                    Option::Some(item) => { data.append(item); },
                                    Option::None(()) => { break; },
                                };
                            };
                            panic(data);
                        },
                    }
                },
                Option::None(_) => { break; },
            };
        };
        result
    }
}
