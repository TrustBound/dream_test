import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn setup_failed_is_a_failure() -> Result(AssertionResult, String) {
  types.is_failure(types.SetupFailed)
  |> should
  |> be_equal(True)
  |> or_fail_with("SetupFailed should be a failure")
}
