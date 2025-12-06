//// Test fixtures for creating MatchResult instances.

import dream_test/types.{type MatchResult, AssertionFailure, MatchFailed}
import gleam/option

/// Create a MatchFailed with a given operator name.
pub fn make_prior_failure(operator: String) -> MatchResult(a) {
  MatchFailed(AssertionFailure(
    operator: operator,
    message: "prior failure",
    payload: option.None,
  ))
}
