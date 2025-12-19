//// String matchers for dream_test.
////
//// These matchers work with strings.
//// They're re-exported through `dream_test/assertions/should`.
////
//// ## Usage
////
//// ```gleam
//// import dream_test/assertions/should.{
////   should, start_with, end_with, contain_string, or_fail_with,
//// }
////
//// greeting
//// |> should
//// |> start_with("Hello")
//// |> or_fail_with("Greeting should start with Hello")
////
//// filename
//// |> should
//// |> end_with(".gleam")
//// |> or_fail_with("Should be a Gleam file")
////
//// log_message
//// |> should
//// |> contain_string("error")
//// |> or_fail_with("Log should mention error")
//// ```

import dream_test/types.{
  type MatchResult, AssertionFailure, MatchFailed, MatchOk, StringMatchFailure,
}
import gleam/option.{Some}
import gleam/string

/// Assert that a string starts with a prefix.
///
/// ## Example
///
/// ```gleam
/// greeting
/// |> should
/// |> start_with("Hello")
/// |> or_fail_with("Greeting should start with Hello")
/// ```
///
pub fn start_with(
  value_or_result: MatchResult(String),
  prefix: String,
) -> MatchResult(String) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_starts_with(actual, prefix)
  }
}

fn check_starts_with(actual: String, prefix: String) -> MatchResult(String) {
  case string.starts_with(actual, prefix) {
    True -> MatchOk(actual)
    False -> {
      let payload =
        StringMatchFailure(
          actual: actual,
          pattern: prefix,
          operation: "start_with",
        )

      MatchFailed(AssertionFailure(
        operator: "start_with",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that a string ends with a suffix.
///
/// ## Example
///
/// ```gleam
/// filename
/// |> should
/// |> end_with(".gleam")
/// |> or_fail_with("File should be a Gleam file")
/// ```
///
pub fn end_with(
  value_or_result: MatchResult(String),
  suffix: String,
) -> MatchResult(String) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_ends_with(actual, suffix)
  }
}

fn check_ends_with(actual: String, suffix: String) -> MatchResult(String) {
  case string.ends_with(actual, suffix) {
    True -> MatchOk(actual)
    False -> {
      let payload =
        StringMatchFailure(
          actual: actual,
          pattern: suffix,
          operation: "end_with",
        )

      MatchFailed(AssertionFailure(
        operator: "end_with",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that a string contains a substring.
///
/// ## Example
///
/// ```gleam
/// log_message
/// |> should
/// |> contain_string("error")
/// |> or_fail_with("Log should mention error")
/// ```
///
pub fn contain_string(
  value_or_result: MatchResult(String),
  substring: String,
) -> MatchResult(String) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_contains_string(actual, substring)
  }
}

fn check_contains_string(
  actual: String,
  substring: String,
) -> MatchResult(String) {
  case string.contains(actual, substring) {
    True -> MatchOk(actual)
    False -> {
      let payload =
        StringMatchFailure(
          actual: actual,
          pattern: substring,
          operation: "contain_string",
        )

      MatchFailed(AssertionFailure(
        operator: "contain_string",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}
