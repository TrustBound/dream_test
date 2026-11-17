import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/summary
import dream_test/types
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("dream_test/reporters/summary", [
    it("count gives the number of results with each status", fn() {
      summary.count(one_of_each_status())
      |> should
      |> be_equal(summary.Counts(
        run: 6,
        passed: 1,
        failed: 1,
        skipped: 1,
        pending: 1,
        timed_out: 1,
        setup_failed: 1,
        duration_ms: 21,
      ))
      |> or_fail_with("each status should have a count of 1")
    }),
    it("count gives zero counts for no results", fn() {
      summary.count([])
      |> should
      |> be_equal(summary.Counts(
        run: 0,
        passed: 0,
        failed: 0,
        skipped: 0,
        pending: 0,
        timed_out: 0,
        setup_failed: 0,
        duration_ms: 0,
      ))
      |> or_fail_with("no results should give zero counts")
    }),
    it("format gives only run, failed and passed when nothing else", fn() {
      summary.format([result(types.Passed, 5), result(types.Failed, 7)])
      |> should
      |> be_equal("Summary: 2 run, 1 failed, 1 passed in 12ms\n")
      |> or_fail_with("the line should have no extra counts")
    }),
    it("format adds the extra counts in status order", fn() {
      summary.format(one_of_each_status())
      |> should
      |> be_equal(
        "Summary: 6 run, 1 failed, 1 passed, 1 skipped, 1 pending, 1 timed out, 1 setup failed in 21ms\n",
      )
      |> or_fail_with("the extra counts should follow the status order")
    }),
    it("format_in_color adds the colour codes", fn() {
      summary.format_in_color([
        result(types.Passed, 5),
        result(types.Skipped, 7),
      ])
      |> should
      |> be_equal(
        "\u{1b}[1m\u{1b}[36mSummary: \u{1b}[0m\u{1b}[0m\u{1b}[36m2\u{1b}[0m run, \u{1b}[31m0\u{1b}[0m failed, \u{1b}[32m1\u{1b}[0m passed, \u{1b}[33m1\u{1b}[0m\u{1b}[2m skipped\u{1b}[0m in \u{1b}[36m12ms\u{1b}[0m\n",
      )
      |> or_fail_with("each part should have its colour")
    }),
  ])
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
