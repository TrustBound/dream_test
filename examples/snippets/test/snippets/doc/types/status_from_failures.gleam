import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn no_failures_means_passed() -> Result(AssertionResult, String) {
  types.status_from_failures([])
  |> should
  |> be_equal(types.Passed)
  |> or_fail_with("expected Passed for empty failures")
}
