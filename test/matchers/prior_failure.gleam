import dream_test/types.{type MatchResult, AssertionFailure, MatchFailed}
import gleam/option.{None}

/// A failure from an earlier matcher in a chain.
///
/// Matchers must pass it through unchanged.
pub fn prior_failure() -> MatchResult(a) {
  MatchFailed(AssertionFailure(
    operator: "prior",
    message: "earlier failure",
    payload: None,
  ))
}
