import dream_test/reporters/summary.{type Counts}
import dream_test/types.{type TestResult}

pub fn count_two_results(
  passed_result: TestResult,
  failed_result: TestResult,
) -> Counts {
  summary.count(
    types.run_report(
      tests: [passed_result, failed_result],
      hook_failures: [],
      reporter_crashes: [],
    ),
  )
  // -> Counts(run: 2, passed: 1, failed: 1, skipped: 0, pending: 0,
  //    timed_out: 0, setup_failed: 0, teardown_failed: 0, setup_stopped: 0,
  //    duration_ms: 0)
}
