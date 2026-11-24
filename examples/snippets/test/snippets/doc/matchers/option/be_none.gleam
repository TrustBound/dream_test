import dream_test/matchers.{be_none, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import gleam/option.{None}

pub fn none_is_empty() -> Result(AssertionResult, String) {
  None
  |> should
  |> be_none()
  |> or_fail_with("expected None")
}
