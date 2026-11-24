import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn two_plus_three_is_five() -> Result(AssertionResult, String) {
  2 + 3
  |> should
  |> be_equal(5)
  |> or_fail_with("2 + 3 should equal 5")
}
