import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn empty_run_has_no_tests() -> Result(AssertionResult, String) {
  types.run_report(tests: [], hook_failures: [], reporter_crashes: [])
  |> types.report_tests
  |> should
  |> be_equal([])
  |> or_fail_with("an empty run should have no tests")
}
