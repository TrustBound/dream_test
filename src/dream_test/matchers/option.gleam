//// Option matchers for dream_test.
////
//// These matchers work with `Option(a)` values and are re-exported through
//// `dream_test/matchers`.
////
//// `be_some()` unwraps `Some(value)` so you can keep matching on the inner
//// value. `be_none()` asserts the option is empty.
////
//// ## Example
////
//// ```gleam
//// Some(42)
//// |> should
//// |> be_some()
//// |> be_equal(42)
//// |> or_fail_with("expected Some(42)")
//// ```

import dream_test/types.{
  type MatchResult, AssertionFailure, MatchFailed, MatchOk, OptionFailure,
}
import gleam/option.{type Option, None, Some}
import gleam/string

/// Assert that an `Option` is `Some` and extract its value.
///
/// If the assertion passes, the inner value is passed to subsequent matchers.
/// This enables chaining like `be_some() |> be_equal(42)`.
///
/// ## Example
///
/// ```gleam
/// Some(42)
/// |> should
/// |> be_some()
/// |> be_equal(42)
/// |> or_fail_with("expected Some(42)")
/// ```
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(Option(a))` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(a)`:
/// - On `Some(value)`, the chain continues with the unwrapped `value`.
/// - On `None`, the chain becomes failed and later matchers are skipped.
///
pub fn be_some(
  value_or_result value_or_result: MatchResult(Option(a)),
) -> MatchResult(a) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_is_some(actual)
  }
}

fn check_is_some(actual: Option(a)) -> MatchResult(a) {
  case actual {
    Some(value) -> MatchOk(value)
    None -> {
      let payload = OptionFailure(actual: "None", expected_some: True)

      MatchFailed(AssertionFailure(
        operator: "be_some",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that an `Option` is `None`.
///
/// ## Example
///
/// ```gleam
/// None
/// |> should
/// |> be_none()
/// |> or_fail_with("expected None")
/// ```
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(Option(a))` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(Nil)` that continues the chain with `Nil` on success.
///
pub fn be_none(
  value_or_result value_or_result: MatchResult(Option(a)),
) -> MatchResult(Nil) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_is_none(actual)
  }
}

fn check_is_none(actual: Option(a)) -> MatchResult(Nil) {
  case actual {
    None -> MatchOk(Nil)
    Some(value) -> {
      let payload =
        OptionFailure(
          actual: "Some(" <> string.inspect(value) <> ")",
          expected_some: False,
        )

      MatchFailed(AssertionFailure(
        operator: "be_none",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}
