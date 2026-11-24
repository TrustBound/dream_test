import dream_test/matchers.{be_at_least, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn ten_is_at_least_ten() -> Result(AssertionResult, String) {
  10
  |> should
  |> be_at_least(10)
  |> or_fail_with("expected 10 to be at least 10")
}
