import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn match_ok_becomes_assertion_ok() -> Result(AssertionResult, String) {
  types.to_assertion_result(types.MatchOk(1))
  |> should
  |> be_equal(types.AssertionOk)
  |> or_fail_with("expected MatchOk -> AssertionOk")
}
