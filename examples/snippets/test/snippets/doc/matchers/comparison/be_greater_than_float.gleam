import dream_test/matchers.{be_greater_than_float, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn half_is_greater_than_zero() -> Result(AssertionResult, String) {
  0.5
  |> should
  |> be_greater_than_float(0.0)
  |> or_fail_with("expected 0.5 to be greater than 0.0")
}
