mod contract;
#[cfg(test)]
mod tests;

#[derive(Debug, Drop, Serde)]
enum Execution {
    Static,
    IfEqual: (usize, usize, felt252),
    IfNotEqual: (usize, usize, felt252),
    Except: usize,
    Catch: usize,
    Then: usize,
}

#[derive(Debug, Drop, Serde)]
enum DynamicFelt {
    Hardcoded: felt252,
    // call, output call
    Reference: (usize, usize),
}

#[derive(Debug, Drop, Serde)]
enum DynamicCalldata {
    Hardcoded: felt252,
    // call, output call
    Reference: (usize, usize),
    ArrayReference: (usize, usize),
}

#[derive(Drop, Serde)]
struct DynamicCall {
    execution: Execution,
    to: DynamicFelt,
    selector: DynamicFelt,
    calldata: Array<DynamicCalldata>
}

#[starknet::interface]
trait IComposableMulticall<TState> {
    fn aggregate(
        self: @TState, calls: Array<DynamicCall>
    ) -> Array<Result<Span<felt252>, Array<felt252>>>;
}

