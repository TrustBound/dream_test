import dream_test/matchers.{have_length, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn list_has_three_items() -> Result(AssertionResult, String) {
  [1, 2, 3]
  |> should
  |> have_length(3)
  |> or_fail_with("expected list length 3")
}
