import dream_test/matchers.{or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/types.{
  AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/option.{Some}
import gleam/string

/// A custom matcher that checks if an integer is even.
///
/// Matchers receive a `MatchResult(a)` and return a `MatchResult(b)`.
/// Most matchers keep the same type (a == b), but unwrapping matchers
/// like `be_some` change the type.
///
pub fn be_even(result) {
  case result {
    // If already failed, propagate the failure
    MatchFailed(failure) -> MatchFailed(failure)
    // Otherwise, check our condition
    MatchOk(value) -> check_even(value)
  }
}

fn check_even(value) {
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
pub fn be_valid_email(result) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(value) -> check_email(value)
  }
}

fn check_email(value) {
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
    it("be_even passes for even numbers", fn() {
      4
      |> should
      |> be_even()
      |> or_fail_with("4 should be even")
    }),
    it("be_valid_email passes for valid emails", fn() {
      "user@example.com"
      |> should
      |> be_valid_email()
      |> or_fail_with("Should be a valid email")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
