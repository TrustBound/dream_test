import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn empty_run_does_not_fail() -> Result(AssertionResult, String) {
  types.run_report(tests: [], hook_failures: [], reporter_crashes: [])
  |> types.failed
  |> should
  |> be_equal(False)
  |> or_fail_with("an empty run should not fail")
}
