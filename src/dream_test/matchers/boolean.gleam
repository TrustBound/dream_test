//// Boolean matchers for dream_test.
////
//// These matchers check boolean values and are re-exported through
//// `dream_test/matchers`.
////
//// Use them in a matcher chain when you want to assert a boolean condition.
////
//// ## Example
////
//// ```gleam
//// True
//// |> should
//// |> be_true()
//// |> or_fail_with("expected True")
//// ```

import dream_test/types.{
  type MatchResult, AssertionFailure, BooleanFailure, MatchFailed, MatchOk,
}
import gleam/option.{Some}

/// Assert that a value is `True`.
///
/// Use this when your value is expected to be `True` and you want a useful
/// failure payload when it isn't.
///
/// ## Example
///
/// ```gleam
/// True
/// |> should
/// |> be_true()
/// |> or_fail_with("expected True")
/// ```
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(Bool)` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(Bool)` preserving the boolean for further chaining.
///
pub fn be_true(
  value_or_result value_or_result: MatchResult(Bool),
) -> MatchResult(Bool) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_is_true(actual)
  }
}

fn check_is_true(actual: Bool) -> MatchResult(Bool) {
  case actual {
    True -> MatchOk(True)
    False -> {
      let payload = BooleanFailure(actual: False, expected: True)

      MatchFailed(AssertionFailure(
        operator: "be_true",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}

/// Assert that a value is `False`.
///
/// Use this when your value is expected to be `False` and you want a useful
/// failure payload when it isn't.
///
/// ## Example
///
/// ```gleam
/// False
/// |> should
/// |> be_false()
/// |> or_fail_with("expected False")
/// ```
///
/// ## Parameters
///
/// - `value_or_result`: the `MatchResult(Bool)` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(Bool)` preserving the boolean for further chaining.
///
pub fn be_false(
  value_or_result value_or_result: MatchResult(Bool),
) -> MatchResult(Bool) {
  case value_or_result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(actual) -> check_is_false(actual)
  }
}

fn check_is_false(actual: Bool) -> MatchResult(Bool) {
  case actual {
    False -> MatchOk(False)
    True -> {
      let payload = BooleanFailure(actual: True, expected: False)

      MatchFailed(AssertionFailure(
        operator: "be_false",
        message: "",
        payload: Some(payload),
      ))
    }
  }
}
