#[starknet::contract]
mod ComposableMulticall {
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};
    use composable_multicall::{IComposableMulticall, DynamicCall};

    #[storage]
    struct Storage {
        opened: bool,
        blacklisted: LegacyMap<ContractAddress, bool>,
    }

    #[external(v0)]
    impl ComposableMulticallImpl of IComposableMulticall<ContractState> {
        fn aggregate(self: @ContractState, calls: Array<DynamicCall>) -> Array<Span<felt252>> {
            Default::default()
        }
    }
}
