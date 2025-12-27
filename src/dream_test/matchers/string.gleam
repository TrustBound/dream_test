//// String matchers for dream_test.
////
//// These matchers work with `String` values and are re-exported through
//// `dream_test/matchers`.
////
//// Use them to assert string structure (prefix/suffix/substring) while
//// preserving the original string for further chaining.
////
//// ## Example
////
//// ```gleam
//// "hello world"
//// |> should
//// |> start_with("hello")
//// |> or_fail_with("expected string to start with \"hello\"")
//// ```

import dream_test/types.{
  type MatchResult, AssertionFailure, MatchFailed, MatchOk, StringMatchFailure,
}
import gleam/option.{None, Some}
import gleam/regexp
import gleam/string

/// Assert that a string starts with a prefix.
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(String)` produced by `should` (or a previous matcher)
/// - `prefix`: required starting substring
///
/// ## Returns
///
/// A `MatchResult(String)` preserving the string for further chaining.
///
/// ## Example
///
/// ```gleam
/// "hello world"
/// |> should
/// |> start_with("hello")
/// |> or_fail_with("expected string to start with \"hello\"")
/// ```
///
pub fn start_with(
  value_or_result value_or_result: MatchResult(String),
  prefix prefix: String,
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
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(String)` produced by `should` (or a previous matcher)
/// - `suffix`: required ending substring
///
/// ## Returns
///
/// A `MatchResult(String)` preserving the string for further chaining.
///
/// ## Example
///
/// ```gleam
/// "hello.gleam"
/// |> should
/// |> end_with(".gleam")
/// |> or_fail_with("expected .gleam suffix")
/// ```
///
pub fn end_with(
  value_or_result value_or_result: MatchResult(String),
  suffix suffix: String,
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
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(String)` produced by `should` (or a previous matcher)
/// - `substring`: required substring that must be present
///
/// ## Returns
///
/// A `MatchResult(String)` preserving the string for further chaining.
///
/// ## Example
///
/// ```gleam
/// "hello world"
/// |> should
/// |> contain_string("world")
/// |> or_fail_with("expected substring match")
/// ```
///
pub fn contain_string(
  value_or_result value_or_result: MatchResult(String),
  substring substring: String,
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

/// Assert that a string matches a regular expression.
///
/// The regex pattern is compiled using `gleam/regexp.from_string`.
///
/// The assertion passes if the pattern matches **anywhere** within the string
/// (it is not implicitly anchored). Use `^...$` if you want to require a full
/// string match.
///
/// If the pattern is invalid, the matcher fails (with an error message, and no
/// structured payload).
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(String)` produced by `should` (or a previous matcher)
/// - `pattern`: the regular expression pattern string
///
/// ## Returns
///
/// A `MatchResult(String)` preserving the string for further chaining.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{match_regex, or_fail_with, should}
///
/// "user-123"
/// |> should
/// |> match_regex("^user-\\d+$")
/// |> or_fail_with("expected an id like user-123")
/// ```
pub fn match_regex(
  value_or_result value_or_result: MatchResult(String),
  pattern pattern: String,
) -> MatchResult(String) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_matches_regex(actual, pattern)
  }
}

fn check_matches_regex(actual: String, pattern: String) -> MatchResult(String) {
  case regexp.from_string(pattern) {
    Ok(compiled_regexp) ->
      check_matches_compiled_regex(actual, pattern, compiled_regexp)
    Error(compile_error) ->
      invalid_regex_pattern_failure(pattern, compile_error)
  }
}

fn check_matches_compiled_regex(
  actual: String,
  pattern: String,
  compiled_regexp: regexp.Regexp,
) -> MatchResult(String) {
  case regexp.check(compiled_regexp, actual) {
    True -> MatchOk(actual)
    False -> regex_no_match_failure(actual, pattern)
  }
}

fn regex_no_match_failure(
  actual: String,
  pattern: String,
) -> MatchResult(String) {
  let payload =
    StringMatchFailure(
      actual: actual,
      pattern: pattern,
      operation: "match_regex",
    )

  MatchFailed(AssertionFailure(
    operator: "match_regex",
    message: "",
    payload: Some(payload),
  ))
}

fn invalid_regex_pattern_failure(
  pattern: String,
  compile_error: regexp.CompileError,
) -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "match_regex",
    message: "invalid regex pattern: "
      <> string.inspect(pattern)
      <> " "
      <> string.inspect(compile_error),
    payload: None,
  ))
}
