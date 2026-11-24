//// Tests of a run that runs no test: it fails, every text reporter says
//// so after the summary line, and `runner.allow_no_tests` restores the
//// passing run.

import dream_test/child_timeout.{with_child_timeout}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/parallel
import dream_test/reporters/bdd
import dream_test/reporters/gherkin
import dream_test/reporters/json
import dream_test/reporters/summary
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it, pending, skip}
import fixtures/test_results.{make_test, report_of}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/string

@external(erlang, "dream_test_coverage_test_ffi", "run_main_in_new_vm")
fn run_main_in_new_vm(module: String, function: String) -> #(Int, String)

const no_tests_line =
  "No tests ran. The filter or the suites selected no test. To allow an empty run, use runner.allow_no_tests().\n"

const empty_summary_line = "Summary: 0 run, 0 failed, 0 passed in 0ms\n"

fn cart_tests() {
  describe("Cart", [it("starts empty", fn() { Ok(AssertionOk) })])
}

fn keep_no_test(_info: runner.TestInfo) -> Bool {
  False
}

fn bdd_config(mode: reporter_types.BddOutputMode) {
  reporter_types.BddReporterConfig(color: False, mode: mode)
}

pub fn tests() {
  describe("a run that runs no test", [
    it("a filter that keeps no test ends the program with status 1", fn() {
      // Act
      let run =
        run_main_in_new_vm("dream_test@no_tests_mains", "filter_keeps_nothing")

      // Assert
      run
      |> should
      |> be_equal(#(1, "\n" <> empty_summary_line <> no_tests_line))
      |> or_fail_with("an empty filtered run should fail with the line")
    })
      |> with_child_timeout,

    it("a runner with no suites ends the program with status 1", fn() {
      // Act
      let run = run_main_in_new_vm("dream_test@no_tests_mains", "no_suites")

      // Assert
      run
      |> should
      |> be_equal(#(1, "\n" <> empty_summary_line <> no_tests_line))
      |> or_fail_with("an empty runner should fail with the line")
    })
      |> with_child_timeout,

    it(
      "allow_no_tests keeps exit status 0 and the output of a passing run",
      fn() {
        // Act
        let run =
          run_main_in_new_vm(
            "dream_test@no_tests_mains",
            "filter_keeps_nothing_allowed",
          )

        // Assert
        run
        |> should
        |> be_equal(#(0, "\n" <> empty_summary_line))
        |> or_fail_with("an allowed empty run should pass with no line")
      },
    )
      |> with_child_timeout,

    it("the runner gives the reporters a report that fails with no tests", fn() {
      // Arrange
      let lines = process.new_subject()

      // Act
      let _ =
        runner.new([])
        |> runner.results_reporters([bdd.new()])
        |> runner.output(capture_output(lines))
        |> runner.run()

      // Assert
      received(lines)
      |> should
      |> be_equal(["\n" <> empty_summary_line <> no_tests_line])
      |> or_fail_with("the BDD report should end with the no tests line")
    }),

    it("allow_no_tests gives the reporters the report of a passing run", fn() {
      // Arrange
      let lines = process.new_subject()

      // Act
      let _ =
        runner.new([])
        |> runner.results_reporters([bdd.new()])
        |> runner.allow_no_tests()
        |> runner.output(capture_output(lines))
        |> runner.run()

      // Assert
      received(lines)
      |> should
      |> be_equal(["\n" <> empty_summary_line])
      |> or_fail_with("the BDD report should have no no tests line")
    }),

    it("allow_no_tests returns a report that has not failed", fn() {
      // Act
      let report =
        runner.new([])
        |> runner.allow_no_tests()
        |> runner.silent()
        |> runner.run()

      // Assert
      types.failed(report)
      |> should
      |> be_equal(False)
      |> or_fail_with("an allowed empty run should not fail")
    }),

    it("types.allow_no_tests makes a report with no test pass", fn() {
      // Arrange
      let report = report_of([]) |> types.allow_no_tests

      // Act
      let failed = types.failed(report)

      // Assert
      failed
      |> should
      |> be_equal(False)
      |> or_fail_with("an allowed empty report should not fail")
    }),

    it("types.failed_with_no_tests is False for a report with a test", fn() {
      // Arrange
      let report = report_of([make_test("passes", types.Passed)])

      // Act
      let failed = types.failed_with_no_tests(report)

      // Assert
      failed
      |> should
      |> be_equal(False)
      |> or_fail_with("a report with a test did not fail with no tests")
    }),

    it("types.failed_with_no_tests is False for an allowed empty report", fn() {
      // Arrange
      let report = report_of([]) |> types.allow_no_tests

      // Act
      let failed = types.failed_with_no_tests(report)

      // Assert
      failed
      |> should
      |> be_equal(False)
      |> or_fail_with("an allowed empty report did not fail with no tests")
    }),

    it("summary.format of an allowed empty report has no line", fn() {
      // Act
      let text = summary.format(report_of([]) |> types.allow_no_tests)

      // Assert
      text
      |> should
      |> be_equal(empty_summary_line)
      |> or_fail_with("an allowed empty run should give only the summary")
    }),

    it("types.failed is True for a report with no test result", fn() {
      // Arrange
      let report = report_of([])

      // Act
      let failed = types.failed(report)

      // Assert
      failed
      |> should
      |> be_equal(True)
      |> or_fail_with("a report with no test should fail")
    }),

    it("the report of runner.new([]) has failed", fn() {
      // Act
      let report = runner.new([]) |> runner.silent() |> runner.run()

      // Assert
      types.failed(report)
      |> should
      |> be_equal(True)
      |> or_fail_with("a run of no suites should fail")
    }),

    it(
      "a filtered run of a suite with its own config that keeps nothing fails",
      fn() {
        // Arrange
        let config =
          parallel.ParallelConfig(max_concurrency: 1, default_timeout_ms: 500)

        // Act
        let report =
          runner.new([])
          |> runner.add_suites_with_config(config, [cart_tests()])
          |> runner.filter_tests(keep_no_test)
          |> runner.silent()
          |> runner.run()

        // Assert
        types.failed(report)
        |> should
        |> be_equal(True)
        |> or_fail_with("a filtered run with a suite config should fail")
      },
    ),

    it("a run where every test is skipped or pending passes", fn() {
      // Arrange
      let suite =
        describe("Cart", [
          skip("removes an item", fn() { Ok(AssertionOk) }),
          pending("applies a discount"),
        ])

      // Act
      let report = runner.new([suite]) |> runner.silent() |> runner.run()

      // Assert
      types.failed(report)
      |> should
      |> be_equal(False)
      |> or_fail_with("skipped and pending tests are tests that ran")
    }),

    it("a report with one skipped test has not failed", fn() {
      // Arrange
      let report = report_of([make_test("later", types.Skipped)])

      // Act
      let failed = types.failed(report)

      // Assert
      failed
      |> should
      |> be_equal(False)
      |> or_fail_with("a skipped test is a test that ran")
    }),

    it("summary.format adds the line after the summary line", fn() {
      // Act
      let text = summary.format(report_of([]))

      // Assert
      text
      |> should
      |> be_equal(empty_summary_line <> no_tests_line)
      |> or_fail_with("the summary should end with the no tests line")
    }),

    it("summary.format_in_color shows the line in red", fn() {
      // Act
      let text = summary.format_in_color(report_of([]))

      // Assert
      text
      |> should
      |> be_equal(
        "\u{1b}[1m\u{1b}[36mSummary: \u{1b}[0m\u{1b}[0m\u{1b}[36m0\u{1b}[0m run, \u{1b}[31m0\u{1b}[0m failed, \u{1b}[32m0\u{1b}[0m passed in \u{1b}[36m0ms\u{1b}[0m\n"
        <> "\u{1b}[31mNo tests ran. The filter or the suites selected no test. To allow an empty run, use runner.allow_no_tests().\u{1b}[0m\n",
      )
      |> or_fail_with("the no tests line should be red")
    }),

    it("the BDD reporter shows the line after the summary line", fn() {
      // Act
      let text = bdd.render(bdd_config(reporter_types.BddFull), report_of([]))

      // Assert
      text
      |> should
      |> be_equal("\n" <> empty_summary_line <> no_tests_line)
      |> or_fail_with("the full BDD report should end with the line")
    }),

    it("the failures-only BDD reporter shows the line", fn() {
      // Act
      let text =
        bdd.render(bdd_config(reporter_types.BddFailuresOnly), report_of([]))

      // Assert
      text
      |> should
      |> be_equal("\n" <> empty_summary_line <> no_tests_line)
      |> or_fail_with("the failures-only report should end with the line")
    }),

    it("the summary-only BDD reporter shows the line", fn() {
      // Act
      let text =
        bdd.render(bdd_config(reporter_types.BddSummaryOnly), report_of([]))

      // Assert
      text
      |> should
      |> be_equal(empty_summary_line <> no_tests_line)
      |> or_fail_with("the summary-only report should end with the line")
    }),

    it("bdd.format shows the line", fn() {
      // Act
      let text = bdd.format(report_of([]))

      // Assert
      text
      |> should
      |> be_equal("\n" <> empty_summary_line <> no_tests_line)
      |> or_fail_with("bdd.format should end with the line")
    }),

    it("the Gherkin reporter shows the line", fn() {
      // Act
      let text = gherkin.format(report_of([]))

      // Assert
      text
      |> should
      |> be_equal("\n" <> empty_summary_line <> no_tests_line)
      |> or_fail_with("the Gherkin report should end with the line")
    }),

    it("the JSON reporter writes no text line, only a total of 0", fn() {
      // Act
      let text = json.format(report_of([]))

      // Assert
      string.contains(text, "No tests ran")
      |> should
      |> be_equal(False)
      |> or_fail_with("the JSON report should stay JSON")
    }),
  ])
}

fn capture_output(lines: Subject(String)) -> runner.Output {
  runner.Output(out: fn(text) { process.send(lines, text) }, error: fn(text) {
    process.send(lines, text)
  })
}

/// Every message in `subject`'s queue, oldest first.
fn received(subject: Subject(String)) -> List(String) {
  received_loop(subject, [])
}

fn received_loop(subject: Subject(String), acc: List(String)) -> List(String) {
  case process.receive(subject, 0) {
    Ok(text) -> received_loop(subject, [text, ..acc])
    Error(Nil) -> list.reverse(acc)
  }
}
