import dream_test/matchers.{be_empty, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn list_is_empty() -> Result(AssertionResult, String) {
  []
  |> should
  |> be_empty()
  |> or_fail_with("expected empty list")
}
