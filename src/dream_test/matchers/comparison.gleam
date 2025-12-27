//// Comparison matchers for dream_test.
////
//// These matchers compare numeric values and are re-exported through
//// `dream_test/matchers`.
////
//// Use them to assert ordering relationships (greater-than, less-than, in a
//// range, etc.) while preserving the numeric value for further chaining.
////
//// ## Example
////
//// ```gleam
//// 10
//// |> should
//// |> be_greater_than(0)
//// |> or_fail_with("expected 10 to be greater than 0")
//// ```

import dream_test/types.{
  type MatchResult, AssertionFailure, ComparisonFailure, MatchFailed, MatchOk,
}
import gleam/float
import gleam/int
import gleam/option.{Some}

/// Assert that an integer is greater than a threshold.
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(Int)` produced by `should` (or a previous matcher)
/// - `threshold`: the value the actual integer must be greater than
///
/// ## Returns
///
/// A `MatchResult(Int)` preserving the integer for further chaining.
///
/// ## Example
///
/// ```gleam
/// 10
/// |> should
/// |> be_greater_than(0)
/// |> or_fail_with("expected 10 to be greater than 0")
/// ```
///
pub fn be_greater_than(
  value_or_result value_or_result: MatchResult(Int),
  threshold threshold: Int,
) -> MatchResult(Int) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_greater_than(actual, threshold)
  }
}

fn check_greater_than(actual: Int, threshold: Int) -> MatchResult(Int) {
  case actual > threshold {
    True -> MatchOk(actual)
    False -> {
      let payload =
        ComparisonFailure(
          actual: int.to_string(actual),
          expected: "> " <> int.to_string(threshold),
          operator: "be_greater_than",
        )

      MatchFailed(AssertionFailure(
        operator: "be_greater_than",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that an integer is less than a threshold.
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(Int)` produced by `should` (or a previous matcher)
/// - `threshold`: the value the actual integer must be less than
///
/// ## Returns
///
/// A `MatchResult(Int)` preserving the integer for further chaining.
///
/// ## Example
///
/// ```gleam
/// 10
/// |> should
/// |> be_less_than(100)
/// |> or_fail_with("expected 10 to be less than 100")
/// ```
///
pub fn be_less_than(
  value_or_result value_or_result: MatchResult(Int),
  threshold threshold: Int,
) -> MatchResult(Int) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_less_than(actual, threshold)
  }
}

fn check_less_than(actual: Int, threshold: Int) -> MatchResult(Int) {
  case actual < threshold {
    True -> MatchOk(actual)
    False -> {
      let payload =
        ComparisonFailure(
          actual: int.to_string(actual),
          expected: "< " <> int.to_string(threshold),
          operator: "be_less_than",
        )

      MatchFailed(AssertionFailure(
        operator: "be_less_than",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that an integer is at least a minimum value (>=).
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(Int)` produced by `should` (or a previous matcher)
/// - `minimum`: the minimum allowed value (inclusive)
///
/// ## Returns
///
/// A `MatchResult(Int)` preserving the integer for further chaining.
///
/// ## Example
///
/// ```gleam
/// 10
/// |> should
/// |> be_at_least(10)
/// |> or_fail_with("expected 10 to be at least 10")
/// ```
///
pub fn be_at_least(
  value_or_result value_or_result: MatchResult(Int),
  minimum minimum: Int,
) -> MatchResult(Int) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_at_least(actual, minimum)
  }
}

fn check_at_least(actual: Int, minimum: Int) -> MatchResult(Int) {
  case actual >= minimum {
    True -> MatchOk(actual)
    False -> {
      let payload =
        ComparisonFailure(
          actual: int.to_string(actual),
          expected: ">= " <> int.to_string(minimum),
          operator: "be_at_least",
        )

      MatchFailed(AssertionFailure(
        operator: "be_at_least",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that an integer is at most a maximum value (<=).
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(Int)` produced by `should` (or a previous matcher)
/// - `maximum`: the maximum allowed value (inclusive)
///
/// ## Returns
///
/// A `MatchResult(Int)` preserving the integer for further chaining.
///
/// ## Example
///
/// ```gleam
/// 10
/// |> should
/// |> be_at_most(10)
/// |> or_fail_with("expected 10 to be at most 10")
/// ```
///
pub fn be_at_most(
  value_or_result value_or_result: MatchResult(Int),
  maximum maximum: Int,
) -> MatchResult(Int) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_at_most(actual, maximum)
  }
}

fn check_at_most(actual: Int, maximum: Int) -> MatchResult(Int) {
  case actual <= maximum {
    True -> MatchOk(actual)
    False -> {
      let payload =
        ComparisonFailure(
          actual: int.to_string(actual),
          expected: "<= " <> int.to_string(maximum),
          operator: "be_at_most",
        )

      MatchFailed(AssertionFailure(
        operator: "be_at_most",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that an integer is between two values (exclusive).
///
/// The value must be strictly greater than `min` and strictly less than `max`.
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(Int)` produced by `should` (or a previous matcher)
/// - `min`: lower bound (exclusive)
/// - `max`: upper bound (exclusive)
///
/// ## Returns
///
/// A `MatchResult(Int)` preserving the integer for further chaining.
///
/// ## Example
///
/// ```gleam
/// 5
/// |> should
/// |> be_between(1, 10)
/// |> or_fail_with("expected 5 to be between 1 and 10")
/// ```
///
pub fn be_between(
  value_or_result value_or_result: MatchResult(Int),
  min min: Int,
  max max: Int,
) -> MatchResult(Int) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_between(actual, min, max)
  }
}

fn check_between(actual: Int, min: Int, max: Int) -> MatchResult(Int) {
  case actual > min && actual < max {
    True -> MatchOk(actual)
    False -> {
      let payload =
        ComparisonFailure(
          actual: int.to_string(actual),
          expected: int.to_string(min) <> " < value < " <> int.to_string(max),
          operator: "be_between",
        )

      MatchFailed(AssertionFailure(
        operator: "be_between",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that an integer is within a range (inclusive).
///
/// The value must be >= `min` and <= `max`.
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(Int)` produced by `should` (or a previous matcher)
/// - `min`: lower bound (inclusive)
/// - `max`: upper bound (inclusive)
///
/// ## Returns
///
/// A `MatchResult(Int)` preserving the integer for further chaining.
///
/// ## Example
///
/// ```gleam
/// 10
/// |> should
/// |> be_in_range(0, 100)
/// |> or_fail_with("expected 10 to be in range 0..100")
/// ```
///
pub fn be_in_range(
  value_or_result value_or_result: MatchResult(Int),
  min min: Int,
  max max: Int,
) -> MatchResult(Int) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_in_range(actual, min, max)
  }
}

fn check_in_range(actual: Int, min: Int, max: Int) -> MatchResult(Int) {
  case actual >= min && actual <= max {
    True -> MatchOk(actual)
    False -> {
      let payload =
        ComparisonFailure(
          actual: int.to_string(actual),
          expected: int.to_string(min) <> " <= value <= " <> int.to_string(max),
          operator: "be_in_range",
        )

      MatchFailed(AssertionFailure(
        operator: "be_in_range",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that a float is greater than a threshold.
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(Float)` produced by `should` (or a previous matcher)
/// - `threshold`: the value the actual float must be greater than
///
/// ## Returns
///
/// A `MatchResult(Float)` preserving the float for further chaining.
///
/// ## Example
///
/// ```gleam
/// 0.5
/// |> should
/// |> be_greater_than_float(0.0)
/// |> or_fail_with("expected 0.5 to be greater than 0.0")
/// ```
///
pub fn be_greater_than_float(
  value_or_result value_or_result: MatchResult(Float),
  threshold threshold: Float,
) -> MatchResult(Float) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_greater_than_float(actual, threshold)
  }
}

fn check_greater_than_float(
  actual: Float,
  threshold: Float,
) -> MatchResult(Float) {
  case actual >. threshold {
    True -> MatchOk(actual)
    False -> {
      let payload =
        ComparisonFailure(
          actual: float.to_string(actual),
          expected: "> " <> float.to_string(threshold),
          operator: "be_greater_than_float",
        )

      MatchFailed(AssertionFailure(
        operator: "be_greater_than_float",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that a float is less than a threshold.
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(Float)` produced by `should` (or a previous matcher)
/// - `threshold`: the value the actual float must be less than
///
/// ## Returns
///
/// A `MatchResult(Float)` preserving the float for further chaining.
///
/// ## Example
///
/// ```gleam
/// 0.5
/// |> should
/// |> be_less_than_float(1.0)
/// |> or_fail_with("expected 0.5 to be less than 1.0")
/// ```
///
pub fn be_less_than_float(
  value_or_result value_or_result: MatchResult(Float),
  threshold threshold: Float,
) -> MatchResult(Float) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_less_than_float(actual, threshold)
  }
}

fn check_less_than_float(actual: Float, threshold: Float) -> MatchResult(Float) {
  case actual <. threshold {
    True -> MatchOk(actual)
    False -> {
      let payload =
        ComparisonFailure(
          actual: float.to_string(actual),
          expected: "< " <> float.to_string(threshold),
          operator: "be_less_than_float",
        )

      MatchFailed(AssertionFailure(
        operator: "be_less_than_float",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}
