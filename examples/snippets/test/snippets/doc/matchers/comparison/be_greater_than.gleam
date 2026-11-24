import dream_test/matchers.{be_greater_than, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn ten_is_greater_than_zero() -> Result(AssertionResult, String) {
  10
  |> should
  |> be_greater_than(0)
  |> or_fail_with("expected 10 to be greater than 0")
}
