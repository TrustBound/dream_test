//// Matcher API for Dream Test.
////
//// Matchers are small functions you pipe values through to produce the value a
//// Dream Test `it(...)` body returns: `Result(AssertionResult, String)`.
////
//// You’ll typically:
////
//// - Start with `should` (wrap a value for matching)
//// - Apply one or more matchers (like `be_equal`, `be_some`, `contain_string`)
//// - Finish with `or_fail_with("...")` to produce the final test result
////
//// ## Available Matchers
////
//// | Category       | Matchers                                                    |
//// |----------------|-------------------------------------------------------------|
//// | **Equality**   | `be_equal`, `not_equal`                                     |
//// | **Boolean**    | `be_true`, `be_false`                                       |
//// | **Option**     | `be_some`, `be_none`                                        |
//// | **Result**     | `be_ok`, `be_error`                                         |
//// | **Collections**| `contain`, `not_contain`, `have_length`, `be_empty`         |
//// | **Comparison** | `be_greater_than`, `be_less_than`, `be_at_least`, `be_at_most`, `be_between`, `be_in_range`, `be_greater_than_float`, `be_less_than_float` |
//// | **String**     | `start_with`, `end_with`, `contain_string`                  |
//// | **Snapshot**   | `match_snapshot`, `match_snapshot_inspect`                  |
////
//// ## Chaining Matchers
////
//// Some matchers “unwrap” values:
//// - `be_some()` turns `Option(a)` into `a`
//// - `be_ok()` turns `Result(a, e)` into `a`
////
//// That’s why you can chain checks after them.
////
//// ## Explicit failures
////
//// Sometimes you need to explicitly return “pass” or “fail” from a branch of a
//// `case` expression. Use `succeed()` / `fail_with("...")` for that.
////
//// ## Imports
////
//// You can import individual matchers, or import the whole module and qualify
//// with `matchers.`. The examples in these docs assume you imported the matcher
//// functions you’re using.

import dream_test/matchers/boolean
import dream_test/matchers/collection
import dream_test/matchers/comparison
import dream_test/matchers/equality
import dream_test/matchers/option
import dream_test/matchers/result
import dream_test/matchers/snapshot
import dream_test/matchers/string
import dream_test/types.{
  type AssertionResult, type MatchResult, AssertionFailed, AssertionFailure,
  AssertionOk, MatchFailed, MatchOk,
}
import gleam/option as gleam_option

/// Start a matcher chain.
///
/// This wraps a value so it can be piped through matchers.
/// Every matcher chain starts with `should`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_true, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   True
///   |> should
///   |> be_true()
///   |> or_fail_with("expected True")
/// }
///
/// pub fn tests() {
///   describe("matchers.should", [
///     it("wraps a value so it can be matched", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `value`: any value you want to make assertions about
///
/// ## Returns
///
/// A `MatchResult(a)` containing `value`. Subsequent matchers will either:
/// - preserve this value (for “checking” matchers), or
/// - transform it (for “unwrapping” matchers like `be_some` / `be_ok`).
pub fn should(value: a) -> MatchResult(a) {
  MatchOk(value)
}

// =============================================================================
// Equality Matchers
// =============================================================================

/// Assert that a value equals the expected value.
///
/// Uses Gleam's structural equality (`==`).
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
/// import snippets.{add}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   add(2, 3)
///   |> should
///   |> be_equal(5)
///   |> or_fail_with("2 + 3 should equal 5")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_equal", [
///     it("compares two values for equality", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(a)` produced by `should` (or a previous matcher)
/// - `expected`: the value you expect the actual value to equal
///
/// ## Returns
///
/// A `MatchResult(a)`:
/// - On success, the original value is preserved for further chaining.
/// - On failure, the chain becomes failed and later matchers are skipped.
pub const be_equal = equality.be_equal

/// Assert that a value does not equal the unexpected value.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{not_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
/// import snippets.{add}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   add(10, 3)
///   |> should
///   |> not_equal(3)
///   |> or_fail_with("10 + 3 should not equal 3")
/// }
///
/// pub fn tests() {
///   describe("matchers.not_equal", [
///     it("asserts two values are different", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(a)` produced by `should` (or a previous matcher)
/// - `unexpected`: the value you expect the actual value to *not* equal
///
/// ## Returns
///
/// A `MatchResult(a)`:
/// - On success, the original value is preserved for further chaining.
/// - On failure, the chain becomes failed and later matchers are skipped.
pub const not_equal = equality.not_equal

// =============================================================================
// Boolean Matchers
// =============================================================================

/// Assert that a value is `True`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_true, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   True
///   |> should
///   |> be_true()
///   |> or_fail_with("expected True")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_true", [
///     it("passes for True", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Bool)` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(Bool)` preserving the boolean for further chaining.
pub const be_true = boolean.be_true

/// Assert that a value is `False`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_false, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   False
///   |> should
///   |> be_false()
///   |> or_fail_with("expected False")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_false", [
///     it("passes for False", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Bool)` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(Bool)` preserving the boolean for further chaining.
pub const be_false = boolean.be_false

// =============================================================================
// Option Matchers
// =============================================================================

/// Assert that an `Option` is `Some` and extract its value.
///
/// If the assertion passes, the inner value is passed to subsequent matchers.
/// This enables chaining like `be_some() |> be_equal(42)`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, be_some, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
/// import gleam/option.{Some}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   Some(42)
///   |> should
///   |> be_some()
///   |> be_equal(42)
///   |> or_fail_with("Should contain 42")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_some", [
///     it("unwraps Some(value) so you can keep matching", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Option(a))` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(a)`:
/// - On `Some(value)`, the chain continues with the unwrapped `value`.
/// - On `None`, the chain becomes failed and later matchers are skipped.
pub const be_some = option.be_some

/// Assert that an `Option` is `None`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_none, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
/// import gleam/option.{None}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   None
///   |> should
///   |> be_none()
///   |> or_fail_with("expected None")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_none", [
///     it("passes for None", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Option(a))` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(Nil)` that continues the chain with `Nil` on success.
pub const be_none = option.be_none

// =============================================================================
// Result Matchers
// =============================================================================

/// Assert that a `Result` is `Ok` and extract its value.
///
/// If the assertion passes, the `Ok` value is passed to subsequent matchers.
/// This enables chaining like `be_ok() |> be_equal(42)`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   Ok("success")
///   |> should
///   |> be_ok()
///   |> be_equal("success")
///   |> or_fail_with("Should be Ok with 'success'")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_ok", [
///     it("unwraps Ok(value) so you can keep matching", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Result(a, e))` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(a)` containing the unwrapped `Ok` value on success.
pub const be_ok = result.be_ok

/// Assert that a `Result` is `Error` and extract the error value.
///
/// If the assertion passes, the error value is passed to subsequent matchers.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, be_error, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   Error("nope")
///   |> should
///   |> be_error()
///   |> be_equal("nope")
///   |> or_fail_with("Should be Error(\"nope\")")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_error", [
///     it("unwraps Error(value) so you can keep matching", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Result(a, e))` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(e)` containing the unwrapped error value on success.
pub const be_error = result.be_error

// =============================================================================
// Collection Matchers
// =============================================================================

/// Assert that a list contains a specific item.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{contain, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   [1, 2, 3]
///   |> should
///   |> contain(2)
///   |> or_fail_with("List should contain 2")
/// }
///
/// pub fn tests() {
///   describe("matchers.contain", [
///     it("passes when the item is present", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(List(a))` produced by `should` (or a previous matcher)
/// - `expected_item`: the item that must be present in the list
///
/// ## Returns
///
/// A `MatchResult(List(a))` preserving the list for further chaining.
pub const contain = collection.contain

/// Assert that a list does not contain a specific item.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{not_contain, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   ["a", "b", "c"]
///   |> should
///   |> not_contain("d")
///   |> or_fail_with("List should not contain 'd'")
/// }
///
/// pub fn tests() {
///   describe("matchers.not_contain", [
///     it("passes when the item is absent", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(List(a))` produced by `should` (or a previous matcher)
/// - `unexpected_item`: the item that must *not* be present in the list
///
/// ## Returns
///
/// A `MatchResult(List(a))` preserving the list for further chaining.
pub const not_contain = collection.not_contain

/// Assert that a list has a specific length.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{have_length, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   [1, 2, 3]
///   |> should
///   |> have_length(3)
///   |> or_fail_with("expected list length 3")
/// }
///
/// pub fn tests() {
///   describe("matchers.have_length", [
///     it("checks the length of a list", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(List(a))` produced by `should` (or a previous matcher)
/// - `expected_length`: the exact length the list must have
///
/// ## Returns
///
/// A `MatchResult(List(a))` preserving the list for further chaining.
pub const have_length = collection.have_length

/// Assert that a list is empty.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_empty, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   []
///   |> should
///   |> be_empty()
///   |> or_fail_with("expected empty list")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_empty", [
///     it("passes for an empty list", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(List(a))` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(List(a))` preserving the list for further chaining.
pub const be_empty = collection.be_empty

// =============================================================================
// Comparison Matchers (Int)
// =============================================================================

/// Assert that an integer is greater than a threshold.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_greater_than, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   10
///   |> should
///   |> be_greater_than(0)
///   |> or_fail_with("expected 10 to be greater than 0")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_greater_than", [
///     it("checks an int is greater than a minimum", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Int)` produced by `should` (or a previous matcher)
/// - `threshold`: the value the actual integer must be greater than
///
/// ## Returns
///
/// A `MatchResult(Int)` preserving the integer for further chaining.
pub const be_greater_than = comparison.be_greater_than

/// Assert that an integer is less than a threshold.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_less_than, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   10
///   |> should
///   |> be_less_than(100)
///   |> or_fail_with("expected 10 to be less than 100")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_less_than", [
///     it("checks an int is less than a maximum", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Int)` produced by `should` (or a previous matcher)
/// - `threshold`: the value the actual integer must be less than
///
/// ## Returns
///
/// A `MatchResult(Int)` preserving the integer for further chaining.
pub const be_less_than = comparison.be_less_than

/// Assert that an integer is at least a minimum value (>=).
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_at_least, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   10
///   |> should
///   |> be_at_least(10)
///   |> or_fail_with("expected 10 to be at least 10")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_at_least", [
///     it("checks an int is >= a minimum", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Int)` produced by `should` (or a previous matcher)
/// - `minimum`: the minimum allowed value (inclusive)
///
/// ## Returns
///
/// A `MatchResult(Int)` preserving the integer for further chaining.
pub const be_at_least = comparison.be_at_least

/// Assert that an integer is at most a maximum value (<=).
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_at_most, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   10
///   |> should
///   |> be_at_most(10)
///   |> or_fail_with("expected 10 to be at most 10")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_at_most", [
///     it("checks an int is <= a maximum", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Int)` produced by `should` (or a previous matcher)
/// - `maximum`: the maximum allowed value (inclusive)
///
/// ## Returns
///
/// A `MatchResult(Int)` preserving the integer for further chaining.
pub const be_at_most = comparison.be_at_most

/// Assert that an integer is between two values (exclusive).
///
/// The value must be strictly greater than `min` and strictly less than `max`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_between, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   5
///   |> should
///   |> be_between(1, 10)
///   |> or_fail_with("expected 5 to be between 1 and 10")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_between", [
///     it("checks an int is between two bounds", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Int)` produced by `should` (or a previous matcher)
/// - `min`: lower bound (exclusive)
/// - `max`: upper bound (exclusive)
///
/// ## Returns
///
/// A `MatchResult(Int)` preserving the integer for further chaining.
pub const be_between = comparison.be_between

/// Assert that an integer is within a range (inclusive).
///
/// The value must be >= `min` and <= `max`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_in_range, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   10
///   |> should
///   |> be_in_range(0, 100)
///   |> or_fail_with("expected 10 to be in range 0..100")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_in_range", [
///     it("checks an int is within an inclusive range", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Int)` produced by `should` (or a previous matcher)
/// - `min`: lower bound (inclusive)
/// - `max`: upper bound (inclusive)
///
/// ## Returns
///
/// A `MatchResult(Int)` preserving the integer for further chaining.
pub const be_in_range = comparison.be_in_range

/// Assert that a float is greater than a threshold.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_greater_than_float, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   0.5
///   |> should
///   |> be_greater_than_float(0.0)
///   |> or_fail_with("expected 0.5 to be greater than 0.0")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_greater_than_float", [
///     it("checks a float is greater than a minimum", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Float)` produced by `should` (or a previous matcher)
/// - `threshold`: the value the actual float must be greater than
///
/// ## Returns
///
/// A `MatchResult(Float)` preserving the float for further chaining.
pub const be_greater_than_float = comparison.be_greater_than_float

/// Assert that a float is less than a threshold.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_less_than_float, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   0.5
///   |> should
///   |> be_less_than_float(1.0)
///   |> or_fail_with("expected 0.5 to be less than 1.0")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_less_than_float", [
///     it("checks a float is less than a maximum", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Float)` produced by `should` (or a previous matcher)
/// - `threshold`: the value the actual float must be less than
///
/// ## Returns
///
/// A `MatchResult(Float)` preserving the float for further chaining.
pub const be_less_than_float = comparison.be_less_than_float

// =============================================================================
// String Matchers
// =============================================================================

/// Assert that a string starts with a prefix.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{or_fail_with, should, start_with}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   "hello world"
///   |> should
///   |> start_with("hello")
///   |> or_fail_with("expected string to start with 'hello'")
/// }
///
/// pub fn tests() {
///   describe("matchers.start_with", [
///     it("checks the start of a string", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(String)` produced by `should` (or a previous matcher)
/// - `prefix`: required starting substring
///
/// ## Returns
///
/// A `MatchResult(String)` preserving the string for further chaining.
pub const start_with = string.start_with

/// Assert that a string ends with a suffix.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{end_with, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   "hello.gleam"
///   |> should
///   |> end_with(".gleam")
///   |> or_fail_with("expected .gleam suffix")
/// }
///
/// pub fn tests() {
///   describe("matchers.end_with", [
///     it("checks the end of a string", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(String)` produced by `should` (or a previous matcher)
/// - `suffix`: required ending substring
///
/// ## Returns
///
/// A `MatchResult(String)` preserving the string for further chaining.
pub const end_with = string.end_with

/// Assert that a string contains a substring.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{contain_string, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   "hello world"
///   |> should
///   |> contain_string("world")
///   |> or_fail_with("expected substring 'world'")
/// }
///
/// pub fn tests() {
///   describe("matchers.contain_string", [
///     it("checks a string contains a substring", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(String)` produced by `should` (or a previous matcher)
/// - `substring`: required substring that must be present
///
/// ## Returns
///
/// A `MatchResult(String)` preserving the string for further chaining.
pub const contain_string = string.contain_string

// =============================================================================
// Snapshot Matchers
// =============================================================================

/// Assert that a string matches the content of a snapshot file.
///
/// - If snapshot **doesn't exist**: creates it and passes
/// - If snapshot **exists and matches**: passes
/// - If snapshot **exists but doesn't match**: fails
///
/// **To update a snapshot:** delete the file and re-run the test.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{match_snapshot, or_fail_with, should}
/// import dream_test/matchers/snapshot as snapshot
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   let path = "./test/tmp/match_snapshot_example.snap"
///   let _ = snapshot.clear_snapshot(path)
///
///   let result =
///     "hello"
///     |> should
///     |> match_snapshot(path)
///     |> or_fail_with("expected snapshot match")
///
///   let _ = snapshot.clear_snapshot(path)
///   result
/// }
///
/// pub fn tests() {
///   describe("matchers.match_snapshot", [
///     it("compares a string against a snapshot file", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(String)` produced by `should` (or a previous matcher)
/// - `snapshot_path`: file path used to store/compare the snapshot
///
/// ## Returns
///
/// A `MatchResult(String)` preserving the string for further chaining.
pub const match_snapshot = snapshot.match_snapshot

/// Assert that any value matches a snapshot (using string.inspect).
///
/// Serializes the value using `string.inspect` and compares against
/// the stored snapshot. Useful for testing complex data structures.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{match_snapshot_inspect, or_fail_with, should}
/// import dream_test/matchers/snapshot as snapshot
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
/// import gleam/option.{Some}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   let path = "./test/tmp/match_snapshot_inspect_example.snap"
///   let _ = snapshot.clear_snapshot(path)
///
///   let result =
///     Some(1)
///     |> should
///     |> match_snapshot_inspect(path)
///     |> or_fail_with("expected inspect snapshot match")
///
///   let _ = snapshot.clear_snapshot(path)
///   result
/// }
///
/// pub fn tests() {
///   describe("matchers.match_snapshot_inspect", [
///     it("snapshots any value by using string.inspect", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(value)` produced by `should` (or a previous matcher)
/// - `snapshot_path`: file path used to store/compare the snapshot
///
/// ## Returns
///
/// A `MatchResult(value)` preserving the unwrapped value for further chaining.
pub const match_snapshot_inspect = snapshot.match_snapshot_inspect

/// Delete a snapshot file.
///
/// Use this to force regeneration of a snapshot on the next test run.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{
///   clear_snapshot, match_snapshot, or_fail_with, should, succeed,
/// }
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   let path = "./test/tmp/clear_snapshot_example.snap"
///
///   let _ =
///     "hello"
///     |> should
///     |> match_snapshot(path)
///     |> or_fail_with("expected to create snapshot")
///
///   let _ = clear_snapshot(path)
///   Ok(succeed())
/// }
///
/// pub fn tests() {
///   describe("matchers.clear_snapshot", [
///     it("deletes a snapshot file (so next run recreates it)", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `snapshot_path`: the file path to delete
///
/// ## Returns
///
/// `Result(Nil, String)`:
/// - `Ok(Nil)` if the snapshot was deleted (or didn't exist)
/// - `Error(message)` if deletion failed
pub const clear_snapshot = snapshot.clear_snapshot

/// Delete all snapshot files in a directory.
///
/// Deletes all files with the `.snap` extension in the given directory.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{
///   be_equal, clear_snapshots_in_directory, match_snapshot, or_fail_with, should,
/// }
/// import dream_test/matchers/snapshot as snapshot
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   let directory = "./test/tmp/clear_snapshots_in_directory_example"
///   let a = directory <> "/a.snap"
///   let b = directory <> "/b.snap"
///
///   // Ensure clean slate
///   let _ = clear_snapshots_in_directory(directory)
///
///   let _ =
///     "a"
///     |> should
///     |> match_snapshot(a)
///     |> or_fail_with("expected to create snapshot a")
///
///   let _ =
///     "b"
///     |> should
///     |> match_snapshot(b)
///     |> or_fail_with("expected to create snapshot b")
///
///   let deleted = clear_snapshots_in_directory(directory)
///
///   // Best-effort extra cleanup for repeatability
///   let _ = snapshot.clear_snapshot(a)
///   let _ = snapshot.clear_snapshot(b)
///
///   deleted
///   |> should
///   |> be_equal(Ok(2))
///   |> or_fail_with("expected two deleted snapshots")
/// }
///
/// pub fn tests() {
///   describe("matchers.clear_snapshots_in_directory", [
///     it("deletes all .snap files in a directory", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `directory`: the directory to scan (non-recursively)
///
/// ## Returns
///
/// `Result(Int, String)`:
/// - `Ok(count)` with the number of `.snap` files deleted
/// - `Error(message)` if deletion failed
pub const clear_snapshots_in_directory = snapshot.clear_snapshots_in_directory

// =============================================================================
// Terminal Operations
// =============================================================================

/// Complete a matcher chain and provide a failure message.
///
/// This is the **terminal operation** that ends every matcher chain. It
/// converts the `MatchResult` into an `AssertionResult` that the test runner
/// understands.
///
/// If the matcher passed, returns `AssertionOk`. If it failed, returns
/// `AssertionFailed` with the provided message.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
/// import snippets.{add}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   add(2, 3)
///   |> should
///   |> be_equal(5)
///   |> or_fail_with("2 + 3 should equal 5")
/// }
///
/// pub fn tests() {
///   describe("matchers.or_fail_with", [
///     it("finishes a matcher chain and provides a message", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(a)` produced by `should` and matchers
/// - `message`: message to show if the chain failed
///
/// ## Returns
///
/// A `Result(AssertionResult, String)` so test bodies can return it directly:
///
/// - `Ok(AssertionOk)` when the chain passed
/// - `Ok(AssertionFailed(...))` when the chain failed
///
/// (This function currently never returns `Error`, but the `Result` shape keeps
/// test bodies uniform for `dream_test/unit`: `fn() { ... } -> Result(AssertionResult, String)`.)
///
/// ## Writing Good Messages
///
/// Good failure messages explain **what should have happened**:
/// - ✓ "User should be authenticated after login"
/// - ✓ "Cart total should include tax"
/// - ✗ "wrong"
/// - ✗ "failed"
///
pub fn or_fail_with(
  result: MatchResult(a),
  message: String,
) -> Result(AssertionResult, String) {
  Ok(case result {
    MatchOk(_) -> AssertionOk

    MatchFailed(failure) ->
      AssertionFailed(AssertionFailure(..failure, message: message))
  })
}

/// Explicitly fail a test with a message.
///
/// Use this when you need to fail a test in a conditional branch where
/// the normal matcher chain doesn't apply.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{fail_with, succeed}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
/// import snippets.{add}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   Ok(case add(1, 1) {
///     2 -> succeed()
///     _ -> fail_with("expected 1 + 1 to be 2")
///   })
/// }
///
/// pub fn tests() {
///   describe("matchers.fail_with", [
///     it("produces a failing AssertionResult", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## When to Use
///
/// - In `case` branches that represent unexpected states
/// - When testing that something does NOT happen
/// - As a placeholder for unimplemented test branches
///
/// ## Returns
///
/// An `AssertionResult` you can wrap in `Ok(...)` from a test body.
///
/// If you want to abort a test immediately (rather than “failing an matcher”),
/// return `Error("...")` from the test body instead.
///
pub fn fail_with(message: String) -> AssertionResult {
  AssertionFailed(AssertionFailure(
    operator: "fail_with",
    message: message,
    payload: gleam_option.None,
  ))
}

/// Explicitly mark a matcher chain as successful.
///
/// Use this when you need to explicitly succeed in a conditional branch,
/// as the counterpart to `fail_with`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{fail_with, succeed}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
/// import snippets.{add}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   Ok(case add(1, 1) {
///     2 -> succeed()
///     _ -> fail_with("expected 1 + 1 to be 2")
///   })
/// }
///
/// pub fn tests() {
///   describe("matchers.succeed", [
///     it("produces AssertionOk", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## When to Use
///
/// - In `case` branches where success is the expected outcome
/// - When all branches of a case must return an `AssertionResult`
/// - To make intent explicit rather than relying on implicit success
///
/// ## Returns
///
/// `AssertionOk`.
///
pub fn succeed() -> AssertionResult {
  AssertionOk
}
