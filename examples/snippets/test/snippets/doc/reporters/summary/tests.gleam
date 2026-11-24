import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/summary
import dream_test/suite.{type TestSuite}
import dream_test/types.{
  type RunReport, type Status, type TestResult, Failed, Passed, Skipped,
  TestResult, Unit,
}
import dream_test/unit.{describe, it}
import snippets/doc/reporters/summary/count
import snippets/doc/reporters/summary/counts
import snippets/doc/reporters/summary/format
import snippets/doc/reporters/summary/format_in_color
import snippets/doc/reporters/summary/module
import snippets_child_vm.{ChildRun, it_runs_in_child_vm}

fn result_with(name: String, status: Status, duration_ms: Int) -> TestResult {
  TestResult(
    name: name,
    groups: ["Example"],
    status: status,
    duration_ms: duration_ms,
    tags: [],
    failures: [],
    kind: Unit,
  )
}

fn report_of(results: List(TestResult)) -> RunReport {
  types.run_report(tests: results, hook_failures: [], reporter_crashes: [])
}

fn three_results() -> RunReport {
  report_of([
    result_with("a", Passed, 5),
    result_with("b", Passed, 4),
    result_with("c", Failed, 3),
  ])
}

pub fn tests() -> TestSuite {
  describe("Doc examples: reporters/summary", [
    it("summary_line gives the line for three results", fn() {
      // Act
      let line = module.summary_line(three_results())

      // Assert
      line
      |> should
      |> be_equal("Summary: 3 run, 1 failed, 2 passed in 12ms\n")
      |> or_fail_with("expected the summary line of three results")
    }),
    it("count_two_results counts one passed and one failed", fn() {
      // Act
      let result =
        counts.count_two_results(
          result_with("a", Passed, 0),
          result_with("b", Failed, 0),
        )

      // Assert
      result
      |> should
      |> be_equal(summary.Counts(
        run: 2,
        passed: 1,
        failed: 1,
        skipped: 0,
        pending: 0,
        timed_out: 0,
        setup_failed: 0,
        teardown_failed: 0,
        setup_stopped: 0,
        duration_ms: 0,
      ))
      |> or_fail_with("expected the counts of two results")
    }),
    it("failed_count gives one failed test", fn() {
      // Act
      let failed = count.failed_count(three_results())

      // Assert
      failed
      |> should
      |> be_equal(1)
      |> or_fail_with("expected one failed test")
    }),
    it("summary_line_with_skipped adds the skipped count", fn() {
      // Arrange
      let report =
        report_of([
          result_with("a", Passed, 5),
          result_with("b", Passed, 4),
          result_with("c", Failed, 3),
          result_with("d", Skipped, 0),
        ])

      // Act
      let line = format.summary_line_with_skipped(report)

      // Assert
      line
      |> should
      |> be_equal("Summary: 4 run, 1 failed, 2 passed, 1 skipped in 12ms\n")
      |> or_fail_with("expected the summary line with one skipped test")
    }),
    it_runs_in_child_vm(
      "print_summary_in_color prints the coloured summary line",
      fn() {
        // Act
        let result =
          snippets_child_vm.run(
            "snippets/doc/reporters/summary/tests",
            "print_summary_of_three_results_in_color",
          )

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "\u{1b}[1m\u{1b}[36mSummary: \u{1b}[0m\u{1b}[0m\u{1b}[36m3\u{1b}[0m run, \u{1b}[31m1\u{1b}[0m failed, \u{1b}[32m2\u{1b}[0m passed in \u{1b}[36m12ms\u{1b}[0m\n",
            error_output: "",
          )),
        )
        |> or_fail_with("expected the coloured summary line")
      },
    ),
  ])
}

/// For the child VM: print the summary of three results in colour.
pub fn print_summary_of_three_results_in_color() -> Nil {
  format_in_color.print_summary_in_color(three_results())
}
