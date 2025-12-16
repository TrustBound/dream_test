//// README: Custom matchers

import dream_test/assertions/should.{or_fail_with, should}
import dream_test/reporter/api as reporter
import dream_test/runner
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/io
import gleam/option.{Some}
import gleam/string

/// A custom matcher that checks if an integer is even.
///
/// Matchers receive a `MatchResult(a)` and return a `MatchResult(b)`.
/// Most matchers keep the same type (a == b), but unwrapping matchers
/// like `be_some` change the type.
///
pub fn be_even(result: MatchResult(Int)) -> MatchResult(Int) {
  case result {
    // If already failed, propagate the failure
    MatchFailed(failure) -> MatchFailed(failure)
    // Otherwise, check our condition
    MatchOk(value) -> check_even(value)
  }
}

fn check_even(value: Int) -> MatchResult(Int) {
  case value % 2 == 0 {
    True -> MatchOk(value)
    False ->
      MatchFailed(AssertionFailure(
        operator: "be_even",
        message: "",
        payload: Some(CustomMatcherFailure(
          actual: int.to_string(value),
          description: "expected an even number",
        )),
      ))
  }
}

/// A custom matcher that checks if a string is a valid email.
///
pub fn be_valid_email(result: MatchResult(String)) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(value) -> check_email(value)
  }
}

fn check_email(value: String) -> MatchResult(String) {
  let has_at = string.contains(value, "@")
  let has_dot = string.contains(value, ".")
  case has_at && has_dot {
    True -> MatchOk(value)
    False ->
      MatchFailed(AssertionFailure(
        operator: "be_valid_email",
        message: "",
        payload: Some(CustomMatcherFailure(
          actual: value,
          description: "expected a valid email (contains @ and .)",
        )),
      ))
  }
}

pub fn tests() {
  describe("Custom Matchers", [
    it("be_even passes for even numbers", fn(_) {
      4
      |> should()
      |> be_even()
      |> or_fail_with("4 should be even")
    }),
    it("be_valid_email passes for valid emails", fn(_) {
      "user@example.com"
      |> should()
      |> be_valid_email()
      |> or_fail_with("Should be a valid email")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporter.bdd(io.print, True))
  |> runner.run()
  |> runner.exit_results_on_failure
}
