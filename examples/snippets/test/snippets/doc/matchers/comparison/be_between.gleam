import dream_test/matchers.{be_between, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn five_is_between_one_and_ten() -> Result(AssertionResult, String) {
  5
  |> should
  |> be_between(1, 10)
  |> or_fail_with("expected 5 to be between 1 and 10")
}
