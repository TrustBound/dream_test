//// Option matchers for dream_test.
////
//// These matchers work with `Option(a)` values and support chaining.
//// They're re-exported through `dream_test/assertions/should`.
////
//// ## Chaining
////
//// The `be_some` matcher extracts the inner value, allowing you to chain
//// additional matchers:
////
//// ```gleam
//// import dream_test/assertions/should.{should, be_some, equal, or_fail_with}
////
//// // Check that it's Some, then check the inner value
//// find_user(id)
//// |> should
//// |> be_some()
//// |> equal(expected_user)
//// |> or_fail_with("Should find the expected user")
//// ```

import dream_test/types.{
  type MatchResult, AssertionFailure, MatchFailed, MatchOk, OptionFailure,
}
import gleam/option.{type Option, None, Some}
import gleam/string

/// Assert that an `Option` is `Some` and extract its value.
///
/// If the assertion passes, the inner value is passed to subsequent matchers.
///
/// ## Example
///
/// ```gleam
/// find_user(id)
/// |> should
/// |> be_some()
/// |> or_fail_with("User should exist")
/// ```
///
/// ## Chaining
///
/// ```gleam
/// Some(42)
/// |> should
/// |> be_some()
/// |> equal(42)
/// |> or_fail_with("Should be Some(42)")
/// ```
///
pub fn be_some(value_or_result: MatchResult(Option(a))) -> MatchResult(a) {
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
/// find_deleted_user(id)
/// |> should
/// |> be_none()
/// |> or_fail_with("Deleted user should not exist")
/// ```
///
pub fn be_none(value_or_result: MatchResult(Option(a))) -> MatchResult(Nil) {
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
