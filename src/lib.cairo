mod contract;
#[cfg(test)]
mod tests;

#[derive(Debug, Drop, Serde)]
enum DynamicInput {
    Hardcoded: felt252,
    // call, output call
    Reference: (felt252, felt252),
}

#[derive(Drop, Serde)]
struct DynamicCall {
    to: starknet::ContractAddress,
    selector: felt252,
    calldata: Array<DynamicInput>
}

#[starknet::interface]
trait IComposableMulticall<TState> {
    fn aggregate(self: @TState, calls: Array<DynamicCall>) -> Array<Span<felt252>>;
}

