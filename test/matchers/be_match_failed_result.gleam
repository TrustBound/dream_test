//// Matcher: be_match_failed_result

import dream_test/types.{
  type MatchResult, AssertionFailure, MatchFailed, MatchOk,
}
import gleam/option.{None}

/// Assert that a MatchResult is MatchFailed (no extra should()).
pub fn be_match_failed_result(result: MatchResult(a)) -> MatchResult(Bool) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(_) ->
      MatchFailed(AssertionFailure(
        operator: "be_match_failed_result",
        message: "Expected MatchFailed but got MatchOk",
        payload: None,
      ))
  }
}
