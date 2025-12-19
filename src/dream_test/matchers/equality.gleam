//// Equality matchers for dream_test.
////
//// These matchers compare values using Gleam's structural equality.
//// They're re-exported through `dream_test/matchers`.
////
//// ## Usage
////
//// ```gleam
//// import dream_test/matchers.{should, be_equal, not_equal, or_fail_with}
////
//// // Check equality
//// result
//// |> should
//// |> be_equal(42)
//// |> or_fail_with("Should be 42")
////
//// // Check inequality
//// result
//// |> should
//// |> not_equal(0)
//// |> or_fail_with("Should not be zero")
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
/// ```gleam
/// add(2, 3)
/// |> should
/// |> be_equal(5)
/// |> or_fail_with("2 + 3 should equal 5")
/// ```
///
pub fn be_equal(value_or_result: MatchResult(a), expected: a) -> MatchResult(a) {
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
/// ```gleam
/// divide(10, 3)
/// |> should
/// |> not_equal(3)
/// |> or_fail_with("10/3 should not equal 3 exactly")
/// ```
///
pub fn not_equal(
  value_or_result: MatchResult(a),
  unexpected: a,
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
