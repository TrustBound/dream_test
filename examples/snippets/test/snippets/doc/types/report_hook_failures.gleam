import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn empty_run_has_no_hook_failures() -> Result(AssertionResult, String) {
  types.run_report(tests: [], hook_failures: [], reporter_crashes: [])
  |> types.report_hook_failures
  |> should
  |> be_equal([])
  |> or_fail_with("an empty run should have no hook failures")
}
