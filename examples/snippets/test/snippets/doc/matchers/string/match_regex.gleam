import dream_test/matchers.{match_regex, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn identifier_matches_pattern() -> Result(AssertionResult, String) {
  "user-123"
  |> should
  |> match_regex("^user-\\d+$")
  |> or_fail_with("expected an id like user-123")
}
