import dream_test/matchers.{not_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn sum_does_not_equal_three() -> Result(AssertionResult, String) {
  10 + 3
  |> should
  |> not_equal(3)
  |> or_fail_with("10 + 3 should not equal 3")
}
