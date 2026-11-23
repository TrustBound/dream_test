import dream_test/matchers.{contain, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn list_contains_two() -> Result(AssertionResult, String) {
  [1, 2, 3]
  |> should
  |> contain(2)
  |> or_fail_with("expected list to contain 2")
}
