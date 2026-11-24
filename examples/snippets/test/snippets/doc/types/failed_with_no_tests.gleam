import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn empty_run_failed_with_no_tests() -> Result(AssertionResult, String) {
  types.run_report(tests: [], hook_failures: [], reporter_crashes: [])
  |> types.failed_with_no_tests
  |> should
  |> be_equal(True)
  |> or_fail_with("a run with no test should fail with no tests")
}
