import dream_test/matchers.{be_in_range, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn ten_is_in_range_zero_to_one_hundred() -> Result(AssertionResult, String) {
  10
  |> should
  |> be_in_range(0, 100)
  |> or_fail_with("expected 10 to be in range 0..100")
}
