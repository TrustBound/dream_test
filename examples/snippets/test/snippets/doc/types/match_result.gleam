import dream_test/matchers.{be_equal, be_some, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import gleam/option.{Some}

pub fn some_holds_forty_two() -> Result(AssertionResult, String) {
  Some(42)
  |> should
  |> be_some()
  |> be_equal(42)
  |> or_fail_with("expected Some(42)")
}
