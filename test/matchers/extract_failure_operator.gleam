//// Matcher: extract_failure_operator

import dream_test/types.{
  type MatchResult, AssertionFailure, MatchFailed, MatchOk,
}
import gleam/option.{None}

/// Extract the operator from a wrapped MatchFailed result.
///
/// Use after should() to get the failure operator:
/// ```gleam
/// result
/// |> should()
/// |> extract_failure_operator()
/// |> equal("expected_operator")
/// |> or_fail_with("wrong operator")
/// ```
pub fn extract_failure_operator(
  wrapped: MatchResult(MatchResult(a)),
) -> MatchResult(String) {
  case wrapped {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(MatchFailed(failure)) -> MatchOk(failure.operator)
    MatchOk(MatchOk(_)) ->
      MatchFailed(AssertionFailure(
        operator: "extract_failure_operator",
        message: "Expected MatchFailed but got MatchOk",
        payload: None,
      ))
  }
}
