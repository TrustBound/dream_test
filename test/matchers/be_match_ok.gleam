//// Matcher: be_match_ok

import dream_test/types.{
  type MatchResult, AssertionFailure, MatchFailed, MatchOk,
}
import gleam/option.{None}

/// Assert that the wrapped MatchResult is MatchOk.
///
/// Use after should() to verify a MatchResult succeeded:
/// ```gleam
/// result
/// |> should()
/// |> be_match_ok()
/// |> or_fail_with("should pass")
/// ```
pub fn be_match_ok(wrapped: MatchResult(MatchResult(a))) -> MatchResult(Bool) {
  case wrapped {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(MatchOk(_)) -> MatchOk(True)
    MatchOk(MatchFailed(_)) ->
      MatchFailed(AssertionFailure(
        operator: "be_match_ok",
        message: "Expected MatchOk but got MatchFailed",
        payload: None,
      ))
  }
}
