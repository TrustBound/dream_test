//// Result matchers for dream_test.
////
//// These matchers work with `Result(a, e)` values and support chaining.
//// They're re-exported through `dream_test/matchers`.
////
//// ## Chaining
////
//// Both `be_ok` and `be_error` extract their inner values, allowing you to
//// chain additional matchers:
////
//// ```gleam
//// import dream_test/matchers.{be_equal, be_error, be_ok, or_fail_with, should}
////
//// // Check that it's Ok, then check the inner value
//// parse_int("42")
//// |> should
//// |> be_ok()
//// |> be_equal(42)
//// |> or_fail_with("Should parse to 42")
////
//// // Check that it's Error, then check the error value
//// validate(invalid_input)
//// |> should
//// |> be_error()
//// |> be_equal(ValidationError("email required"))
//// |> or_fail_with("Should fail with email error")
//// ```

import dream_test/types.{
  type MatchResult, AssertionFailure, MatchFailed, MatchOk, ResultFailure,
}
import gleam/option.{Some}
import gleam/string

/// Assert that a `Result` is `Ok` and extract its value.
///
/// If the assertion passes, the `Ok` value is passed to subsequent matchers.
///
/// ## Example
///
/// ```gleam
/// parse_int("42")
/// |> should
/// |> be_ok()
/// |> or_fail_with("Should parse successfully")
/// ```
///
/// ## Chaining
///
/// ```gleam
/// Ok("hello")
/// |> should
/// |> be_ok()
/// |> be_equal("hello")
/// |> or_fail_with("Should be Ok with 'hello'")
/// ```
///
pub fn be_ok(value_or_result: MatchResult(Result(a, e))) -> MatchResult(a) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_is_ok(actual)
  }
}

fn check_is_ok(actual: Result(a, e)) -> MatchResult(a) {
  case actual {
    Ok(value) -> MatchOk(value)
    Error(error) -> {
      let payload =
        ResultFailure(
          actual: "Error(" <> string.inspect(error) <> ")",
          expected_ok: True,
        )

      MatchFailed(AssertionFailure(
        operator: "be_ok",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that a `Result` is `Error` and extract the error value.
///
/// If the assertion passes, the error value is passed to subsequent matchers.
///
/// ## Example
///
/// ```gleam
/// parse_int("not a number")
/// |> should
/// |> be_error()
/// |> or_fail_with("Should fail to parse")
/// ```
///
/// ## Chaining
///
/// ```gleam
/// Error("invalid")
/// |> should
/// |> be_error()
/// |> be_equal("invalid")
/// |> or_fail_with("Should be Error with 'invalid'")
/// ```
///
pub fn be_error(value_or_result: MatchResult(Result(a, e))) -> MatchResult(e) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_is_error(actual)
  }
}

fn check_is_error(actual: Result(a, e)) -> MatchResult(e) {
  case actual {
    Error(error) -> MatchOk(error)
    Ok(value) -> {
      let payload =
        ResultFailure(
          actual: "Ok(" <> string.inspect(value) <> ")",
          expected_ok: False,
        )

      MatchFailed(AssertionFailure(
        operator: "be_error",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}
