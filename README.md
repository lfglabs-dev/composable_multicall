# Composable Multicall

This smart contract allows for "scripting" a multicall. Instead of merely being a series of calls, it enables the description of more complex execution patterns (such as try/catch, conditional calls, etc). Unlike traditional multicalls, the sequential execution will not stop by default if a call results in an error.

To define your multicalls, you need to build an array of `DynamicCall` objects. A `DynamicCall` is defined as follows:

```cairo
#[derive(Drop, Serde)]
struct DynamicCall {
    execution: Execution,
    to: DynamicFelt,
    selector: DynamicFelt,
    calldata: Array<DynamicCalldata>
}
```

`Execution` is an Enum with possible values:
- `Static`: This call will be executed normally.
- `IfEqual` (call_id, felt_id, expected_value): This call will execute only if the felt `felt_id` from call `call_id` equals `expected_value`.
- `IfNotEqual` (call_id, felt_id, expected_value): This call will execute only if the felt `felt_id` from call `call_id` does not equal `expected_value`.
- `Catch` (call_id): This call will execute only if call `call_id` failed.
- `Then` (call_id): This call will execute only if call `call_id` succeeded.
- `Except` (call_id): If call `call_id` failed, this will raise an exception with the error value.

The `to` field specifies the target contract, and `selector` specifies the function selector to call. Both are expressed as `DynamicFelt`, an enum with possible values:
- `Hardcoded` (value): When compiled, this dynamic felt equals the provided value.
- `Reference` (call_id, felt_id): When compiled, this dynamic felt equals the `felt_id` from the `call_id` call's output.

Similarly, `calldata` specifies the arguments sent to the function being called, expressed as an array of `DynamicCalldata`:
- `Hardcoded` (value): Compiled like a DynamicFelt.
- `Reference` (call_id, felt_id): Compiled like a DynamicFelt.
- `ArrayReference` (call_id, arr_loc): Compiled to an array extracted from the call `call_id`, with the array length and values specified at `arr_loc`.

## Execution of Multicalls

To execute these multicalls, the array of `DynamicCall` objects should be sent to `raw_aggregate` if you expect to retrieve a same-sized array containing results (`Err` and `Ok`). Calls that are skipped due to conditional executions (like `IfEqual`, `IfNotEqual`) or try/catch mechanisms will produce a `skipped_call` error in the result array.

If you expect to filter out the errors (`Err`), use `aggregate` instead of `raw_aggregate`. This function will only return the successful results, omitting any errors or skipped calls from the output.
