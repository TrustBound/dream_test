import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/int
import gleam/option.{Some}

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
