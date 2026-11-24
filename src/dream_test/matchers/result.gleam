//// Result matchers for dream_test.
////
//// These matchers work with `Result(a, e)` values and are re-exported through
//// `dream_test/matchers`.
////
//// `be_ok()` unwraps `Ok(value)` so you can keep matching on the inner value.
//// `be_error()` unwraps `Error(value)` so you can match on the error value.
////
//// ## Example
////
//// ### Unwrap Ok and check the value <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/matchers/result/be_ok.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
//// import dream_test/types.{type AssertionResult}
////
//// pub fn ok_holds_hello() -> Result(AssertionResult, String) {
////   Ok("hello")
////   |> should
////   |> be_ok()
////   |> be_equal("hello")
////   |> or_fail_with("expected Ok(\"hello\")")
//// }
//// ```

import dream_test/types.{
  type MatchResult, AssertionFailure, MatchFailed, MatchOk, ResultFailure,
}
import gleam/option.{Some}
import gleam/string

/// Assert that a `Result` is `Ok` and extract its value.
///
/// If the assertion passes, the `Ok` value is passed to subsequent matchers.
/// This enables chaining like `be_ok() |> be_equal("...")`.
///
/// ## Example
///
/// ### Unwrap Ok and check the value <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/matchers/result/be_ok.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn ok_holds_hello() -> Result(AssertionResult, String) {
///   Ok("hello")
///   |> should
///   |> be_ok()
///   |> be_equal("hello")
///   |> or_fail_with("expected Ok(\"hello\")")
/// }
/// ```
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(Result(a, e))` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(a)`:
/// - On `Ok(value)`, the chain continues with the unwrapped `value`.
/// - On `Error(_)`, the chain becomes failed and later matchers are skipped.
///
pub fn be_ok(
  value_or_result value_or_result: MatchResult(Result(a, e)),
) -> MatchResult(a) {
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
/// This enables chaining like `be_error() |> be_equal("...")`.
///
/// ## Example
///
/// ### Unwrap Error and check the error value <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/matchers/result/be_error.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, be_error, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
///
/// pub fn error_holds_nope() -> Result(AssertionResult, String) {
///   Error("nope")
///   |> should
///   |> be_error()
///   |> be_equal("nope")
///   |> or_fail_with("expected Error(\"nope\")")
/// }
/// ```
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(Result(a, e))` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(e)`:
/// - On `Error(value)`, the chain continues with the unwrapped error `value`.
/// - On `Ok(_)`, the chain becomes failed and later matchers are skipped.
///
pub fn be_error(
  value_or_result value_or_result: MatchResult(Result(a, e)),
) -> MatchResult(e) {
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
