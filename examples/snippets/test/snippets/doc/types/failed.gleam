import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn teardown_failure_fails_the_run() -> Result(AssertionResult, String) {
  types.run_report(
    tests: [],
    hook_failures: [
      types.TeardownFailed(
        hook: types.AfterAllSuitesHook,
        path: [],
        message: "could not stop the pool",
      ),
    ],
    reporter_crashes: [],
  )
  |> types.failed
  |> should
  |> be_equal(True)
  |> or_fail_with("a teardown failure should fail the run")
}
