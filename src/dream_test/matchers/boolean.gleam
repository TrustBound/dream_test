//// Boolean matchers for dream_test.
////
//// These matchers check boolean values.
//// They're re-exported through `dream_test/matchers`.
////
//// These are the simplest matchers: they assert that a boolean is `True` or
//// `False`.
////
//// ## Example
////
//// ```gleam
//// import dream_test/matchers.{be_true, or_fail_with, should}
//// import dream_test/types.{type AssertionResult}
//// import dream_test/unit.{describe, it}
////
//// pub fn example() -> Result(AssertionResult, String) {
////   True
////   |> should
////   |> be_true()
////   |> or_fail_with("expected True")
//// }
////
//// pub fn tests() {
////   describe("matchers.be_true", [
////     it("passes for True", fn() { example() }),
////   ])
//// }
//// ```

import dream_test/types.{
  type MatchResult, AssertionFailure, BooleanFailure, MatchFailed, MatchOk,
}
import gleam/option.{Some}

/// Assert that a value is `True`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_true, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   True
///   |> should
///   |> be_true()
///   |> or_fail_with("expected True")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_true", [
///     it("passes for True", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Bool)` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(Bool)` preserving the boolean for further chaining.
///
pub fn be_true(value_or_result: MatchResult(Bool)) -> MatchResult(Bool) {
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
/// ## Example
///
/// ```gleam
/// import dream_test/matchers.{be_false, or_fail_with, should}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit.{describe, it}
///
/// pub fn example() -> Result(AssertionResult, String) {
///   False
///   |> should
///   |> be_false()
///   |> or_fail_with("expected False")
/// }
///
/// pub fn tests() {
///   describe("matchers.be_false", [
///     it("passes for False", fn() { example() }),
///   ])
/// }
/// ```
///
/// ## Parameters
///
/// - `result`: the `MatchResult(Bool)` produced by `should` (or a previous matcher)
///
/// ## Returns
///
/// A `MatchResult(Bool)` preserving the boolean for further chaining.
///
pub fn be_false(value_or_result: MatchResult(Bool)) -> MatchResult(Bool) {
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
