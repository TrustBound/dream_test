import dream_test/matchers.{be_false, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn false_is_false() -> Result(AssertionResult, String) {
  False
  |> should
  |> be_false()
  |> or_fail_with("expected False")
}
