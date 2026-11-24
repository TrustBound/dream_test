import dream_test/matchers.{be_less_than, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn ten_is_less_than_one_hundred() -> Result(AssertionResult, String) {
  10
  |> should
  |> be_less_than(100)
  |> or_fail_with("expected 10 to be less than 100")
}
