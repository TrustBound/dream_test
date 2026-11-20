import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/summary
import dream_test/types
import dream_test/unit.{describe, it}
import fixtures/test_results.{report_of, report_with_cleanup_failure}

pub fn tests() {
  describe("dream_test/reporters/summary", [
    it("count gives the number of results with each status", fn() {
      summary.count(report_of(one_of_each_status()))
      |> should
      |> be_equal(summary.Counts(
        run: 6,
        passed: 1,
        failed: 1,
        skipped: 1,
        pending: 1,
        timed_out: 1,
        setup_failed: 1,
        teardown_failed: 0,
        setup_stopped: 0,
        duration_ms: 21,
      ))
      |> or_fail_with("each status should have a count of 1")
    }),
    it("count gives zero counts for no results", fn() {
      summary.count(report_of([]))
      |> should
      |> be_equal(summary.Counts(
        run: 0,
        passed: 0,
        failed: 0,
        skipped: 0,
        pending: 0,
        timed_out: 0,
        setup_failed: 0,
        teardown_failed: 0,
        setup_stopped: 0,
        duration_ms: 0,
      ))
      |> or_fail_with("no results should give zero counts")
    }),
    it("format gives only run, failed and passed when nothing else", fn() {
      summary.format(
        report_of([result(types.Passed, 5), result(types.Failed, 7)]),
      )
      |> should
      |> be_equal("Summary: 2 run, 1 failed, 1 passed in 12ms\n")
      |> or_fail_with("the line should have no extra counts")
    }),
    it("format adds the extra counts in status order", fn() {
      summary.format(report_of(one_of_each_status()))
      |> should
      |> be_equal(
        "Summary: 6 run, 1 failed, 1 passed, 1 skipped, 1 pending, 1 timed out, 1 setup failed in 21ms\n",
      )
      |> or_fail_with("the extra counts should follow the status order")
    }),
    it("format_in_color adds the colour codes", fn() {
      summary.format_in_color(
        report_of([
          result(types.Passed, 5),
          result(types.Skipped, 7),
        ]),
      )
      |> should
      |> be_equal(
        "\u{1b}[1m\u{1b}[36mSummary: \u{1b}[0m\u{1b}[0m\u{1b}[36m2\u{1b}[0m run, \u{1b}[31m0\u{1b}[0m failed, \u{1b}[32m1\u{1b}[0m passed, \u{1b}[33m1\u{1b}[0m\u{1b}[2m skipped\u{1b}[0m in \u{1b}[36m12ms\u{1b}[0m\n",
      )
      |> or_fail_with("each part should have its colour")
    }),
    it("count gives the number of teardown failures", fn() {
      summary.count(report_with_cleanup_failure([result(types.Passed, 5)]))
      |> should
      |> be_equal(summary.Counts(
        run: 1,
        passed: 1,
        failed: 0,
        skipped: 0,
        pending: 0,
        timed_out: 0,
        setup_failed: 0,
        teardown_failed: 1,
        setup_stopped: 0,
        duration_ms: 5,
      ))
      |> or_fail_with("one teardown failure should give a count of 1")
    }),
    it("format adds the teardown failures after the status counts", fn() {
      summary.format(
        report_with_cleanup_failure([
          result(types.Passed, 5),
          result(types.SetupFailed, 7),
        ]),
      )
      |> should
      |> be_equal(
        "Summary: 2 run, 0 failed, 1 passed, 1 setup failed, 1 teardown failed in 12ms\n",
      )
      |> or_fail_with("the line should end with the teardown failures")
    }),
    it("format counts failed teardown hooks and stopped setups apart", fn() {
      summary.format(teardown_failed_and_setup_stopped())
      |> should
      |> be_equal(
        "Summary: 0 run, 0 failed, 0 passed, 1 teardown failed, 1 setup stopped in 0ms\n",
      )
      |> or_fail_with("a stopped setup should not count as a failed hook")
    }),
    it("format_in_color shows the teardown failures in red", fn() {
      summary.format_in_color(report_with_cleanup_failure([]))
      |> should
      |> be_equal(
        "\u{1b}[1m\u{1b}[36mSummary: \u{1b}[0m\u{1b}[0m\u{1b}[36m0\u{1b}[0m run, \u{1b}[31m0\u{1b}[0m failed, \u{1b}[32m0\u{1b}[0m passed, \u{1b}[31m1\u{1b}[0m\u{1b}[2m teardown failed\u{1b}[0m in \u{1b}[36m0ms\u{1b}[0m\n",
      )
      |> or_fail_with("the teardown count should be red")
    }),
  ])
}

/// A report with one failed teardown hook and one stopped setup.
fn teardown_failed_and_setup_stopped() -> types.RunReport {
  types.run_report(
    tests: [],
    hook_failures: [
      types.TeardownFailed(
        hook: types.AfterAllHook,
        path: ["root"],
        message: "no cleanup",
      ),
      types.SetupStopped(
        setup: types.BeforeAllHook,
        path: ["root"],
        reason: "Boom",
        not_run: [],
      ),
    ],
    reporter_crashes: [],
  )
}

fn one_of_each_status() -> List(types.TestResult) {
  [
    result(types.Passed, 1),
    result(types.Failed, 2),
    result(types.Skipped, 3),
    result(types.Pending, 4),
    result(types.TimedOut, 5),
    result(types.SetupFailed, 6),
  ]
}

fn result(status: types.Status, duration_ms: Int) -> types.TestResult {
  types.TestResult(
    name: "test",
    groups: [],
    status: status,
    duration_ms: duration_ms,
    tags: [],
    failures: [],
    kind: types.Unit,
  )
}
