import dream_test/matchers.{be_at_most, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn ten_is_at_most_ten() -> Result(AssertionResult, String) {
  10
  |> should
  |> be_at_most(10)
  |> or_fail_with("expected 10 to be at most 10")
}
