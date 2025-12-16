//// Matcher: be_match_ok_result

import dream_test/types.{type MatchResult, MatchFailed, MatchOk}

/// Assert that a MatchResult is MatchOk (no extra should()).
pub fn be_match_ok_result(result: MatchResult(a)) -> MatchResult(Bool) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(_) -> MatchOk(True)
  }
}
