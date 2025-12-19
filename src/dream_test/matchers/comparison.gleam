//// Comparison matchers for dream_test.
////
//// These matchers compare numeric values.
//// They're re-exported through `dream_test/matchers`.
////
//// ## Integer Matchers
////
//// ```gleam
//// import dream_test/matchers.{
////   should, be_greater_than, be_less_than, be_at_least,
////   be_at_most, be_between, be_in_range, or_fail_with,
//// }
////
//// count
//// |> should
//// |> be_greater_than(0)
//// |> or_fail_with("Count should be positive")
////
//// score
//// |> should
//// |> be_in_range(0, 100)
//// |> or_fail_with("Score should be 0-100")
//// ```
////
//// ## Float Matchers
////
//// ```gleam
//// average
//// |> should
//// |> be_greater_than_float(0.0)
//// |> or_fail_with("Average should be positive")
//// ```

import dream_test/types.{
  type MatchResult, AssertionFailure, ComparisonFailure, MatchFailed, MatchOk,
}
import gleam/float
import gleam/int
import gleam/option.{Some}

/// Assert that an integer is greater than a threshold.
///
/// ## Example
///
/// ```gleam
/// count_items()
/// |> should
/// |> be_greater_than(0)
/// |> or_fail_with("Should have at least one item")
/// ```
///
pub fn be_greater_than(
  value_or_result: MatchResult(Int),
  threshold: Int,
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
/// ## Example
///
/// ```gleam
/// response_time_ms
/// |> should
/// |> be_less_than(100)
/// |> or_fail_with("Response should be under 100ms")
/// ```
///
pub fn be_less_than(
  value_or_result: MatchResult(Int),
  threshold: Int,
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
/// ## Example
///
/// ```gleam
/// user.age
/// |> should
/// |> be_at_least(18)
/// |> or_fail_with("User must be at least 18")
/// ```
///
pub fn be_at_least(
  value_or_result: MatchResult(Int),
  minimum: Int,
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
/// ## Example
///
/// ```gleam
/// password.length
/// |> should
/// |> be_at_most(128)
/// |> or_fail_with("Password must be at most 128 characters")
/// ```
///
pub fn be_at_most(
  value_or_result: MatchResult(Int),
  maximum: Int,
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
/// ## Example
///
/// ```gleam
/// port
/// |> should
/// |> be_between(1024, 65535)
/// |> or_fail_with("Port must be between 1024 and 65535")
/// ```
///
pub fn be_between(
  value_or_result: MatchResult(Int),
  min: Int,
  max: Int,
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
/// ## Example
///
/// ```gleam
/// score
/// |> should
/// |> be_in_range(0, 100)
/// |> or_fail_with("Score must be 0-100")
/// ```
///
pub fn be_in_range(
  value_or_result: MatchResult(Int),
  min: Int,
  max: Int,
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
/// ## Example
///
/// ```gleam
/// average
/// |> should
/// |> be_greater_than_float(0.0)
/// |> or_fail_with("Average should be positive")
/// ```
///
pub fn be_greater_than_float(
  value_or_result: MatchResult(Float),
  threshold: Float,
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
/// ## Example
///
/// ```gleam
/// error_rate
/// |> should
/// |> be_less_than_float(0.01)
/// |> or_fail_with("Error rate should be under 1%")
/// ```
///
pub fn be_less_than_float(
  value_or_result: MatchResult(Float),
  threshold: Float,
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
