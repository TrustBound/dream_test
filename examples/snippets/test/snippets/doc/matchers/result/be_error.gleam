import dream_test/matchers.{be_equal, be_error, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn error_holds_nope() -> Result(AssertionResult, String) {
  Error("nope")
  |> should
  |> be_error()
  |> be_equal("nope")
  |> or_fail_with("expected Error(\"nope\")")
}
