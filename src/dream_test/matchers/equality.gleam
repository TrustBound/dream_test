//// Equality matchers for dream_test.
////
//// These matchers compare values using Gleam's structural equality and are
//// re-exported through `dream_test/matchers`.
////
//// ## Example
////
//// ### Assert that two values are equal <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/matchers/equality/be_equal.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/matchers.{be_equal, or_fail_with, should}
//// import dream_test/types.{type AssertionResult}
////
//// pub fn sum_equals_five() -> Result(AssertionResult, String) {
////   2 + 3
////   |> should
////   |> be_equal(5)
////   |> or_fail_with("2 + 3 should equal 5")
//// }
//// ```

import dream_test/types.{
  type MatchResult, AssertionFailure, EqualityFailure, MatchFailed, MatchOk,
}
import gleam/option.{Some}
import gleam/string

/// Assert that a value equals the expected value.
///
/// Uses Gleam's structural equality (`==`). Works with any type that
/// supports equality comparison.
///
/// ## Example
///
/// ### Assert that two values are equal <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/matchers/equality/be_equal.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn sum_equals_five() -> Result(AssertionResult, String) {
///   2 + 3
///   |> should
///   |> be_equal(5)
///   |> or_fail_with("2 + 3 should equal 5")
/// }
/// ```
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(a)` produced by `should` (or a previous matcher)
/// - `expected`: the value you expect the actual value to equal
///
/// ## Returns
///
/// A `MatchResult(a)`:
/// - On success, preserves the original value for further chaining.
/// - On failure, the chain becomes failed and later matchers are skipped.
///
pub fn be_equal(
  value_or_result value_or_result: MatchResult(a),
  expected expected: a,
) -> MatchResult(a) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_equal(actual, expected)
  }
}

fn check_equal(actual: a, expected: a) -> MatchResult(a) {
  case actual == expected {
    True -> MatchOk(actual)
    False -> {
      let payload =
        EqualityFailure(
          actual: inspect_value(actual),
          expected: inspect_value(expected),
        )

      MatchFailed(AssertionFailure(
        operator: "be_equal",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that a value does not equal the unexpected value.
///
/// Uses Gleam's structural inequality (`!=`).
///
/// ## Example
///
/// ### Assert that two values are not equal <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/matchers/equality/not_equal.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{not_equal, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn sum_does_not_equal_three() -> Result(AssertionResult, String) {
///   10 + 3
///   |> should
///   |> not_equal(3)
///   |> or_fail_with("10 + 3 should not equal 3")
/// }
/// ```
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(a)` produced by `should` (or a previous matcher)
/// - `unexpected`: the value you expect the actual value to *not* equal
///
/// ## Returns
///
/// A `MatchResult(a)`:
/// - On success, preserves the original value for further chaining.
/// - On failure, the chain becomes failed and later matchers are skipped.
///
pub fn not_equal(
  value_or_result value_or_result: MatchResult(a),
  unexpected unexpected: a,
) -> MatchResult(a) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_not_equal(actual, unexpected)
  }
}

fn check_not_equal(actual: a, unexpected: a) -> MatchResult(a) {
  case actual != unexpected {
    True -> MatchOk(actual)
    False -> {
      let payload =
        EqualityFailure(
          actual: inspect_value(actual),
          expected: "not " <> inspect_value(unexpected),
        )

      MatchFailed(AssertionFailure(
        operator: "not_equal",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

fn inspect_value(value: a) -> String {
  string.inspect(value)
}
