import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn allowed_empty_run_passes() -> Result(AssertionResult, String) {
  types.run_report(tests: [], hook_failures: [], reporter_crashes: [])
  |> types.allow_no_tests
  |> types.failed
  |> should
  |> be_equal(False)
  |> or_fail_with("an allowed empty run should not fail")
}
