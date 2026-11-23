import dream_test/matchers.{be_true, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn true_is_true() -> Result(AssertionResult, String) {
  True
  |> should
  |> be_true()
  |> or_fail_with("expected True")
}
