import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport, type Status, type TestResult, Passed}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/result
import snippets/doc/coverage/tests as coverage_tests
import snippets/doc/runner/add_suites
import snippets/doc/runner/add_suites_with_config
import snippets/doc/runner/output
import snippets_child_vm.{
  ChildRun, it_runs_in_child_vm, it_runs_in_child_vm_with_coverage_lock,
  progress_done_line,
}

fn name_and_status(result: TestResult) -> #(String, Status) {
  #(result.name, result.status)
}

fn names_and_statuses(report: RunReport) -> List(#(String, Status)) {
  types.report_tests(report)
  |> list.map(name_and_status)
}

pub fn tests() -> TestSuite {
  describe("Doc examples: runner", [
    it_runs_in_child_vm(
      "progress_reporter main prints what the example shows",
      fn() {
        // Act
        let result =
          snippets_child_vm.run("snippets/doc/runner/progress_reporter", "main")
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: progress_done_line(1) <> "",
            error_output: "",
          )),
        )
        |> or_fail_with("expected the progress line to end with a full bar")
      },
    ),
    it_runs_in_child_vm(
      "results_reporters main prints what the example shows",
      fn() {
        // Act
        let result =
          snippets_child_vm.run("snippets/doc/runner/results_reporters", "main")
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "Cart\n"
              <> "  ✓ starts empty\n"
              <> "\n"
              <> "Summary: 1 run, 0 failed, 1 passed in <duration>\n"
              <> "Summary: 1 run, 0 failed, 1 passed in <duration>\n",
            error_output: "",
          )),
        )
        |> or_fail_with("expected the full report, then the summary line")
      },
    ),
    it_runs_in_child_vm("silent main prints what the example shows", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/runner/silent", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(Ok(ChildRun(status: 0, output: "", error_output: "")))
      |> or_fail_with("expected no output from a silent run")
    }),
    it_runs_in_child_vm(
      "after_each_test main prints what the example shows",
      fn() {
        // Act
        let result =
          snippets_child_vm.run("snippets/doc/runner/after_each_test", "main")
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "finished starts empty\n",
            error_output: "",
          )),
        )
        |> or_fail_with("expected the hook to log the finished test")
      },
    ),
    it_runs_in_child_vm(
      "before_each_suite main prints what the example shows",
      fn() {
        // Act
        let result =
          snippets_child_vm.run("snippets/doc/runner/before_each_suite", "main")
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "starting suite Cart\n",
            error_output: "",
          )),
        )
        |> or_fail_with("expected the hook to log the suite before it runs")
      },
    ),
    it_runs_in_child_vm(
      "after_each_suite main prints what the example shows",
      fn() {
        // Act
        let result =
          snippets_child_vm.run("snippets/doc/runner/after_each_suite", "main")
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "finished suite Cart\n",
            error_output: "",
          )),
        )
        |> or_fail_with("expected the hook to log the suite after it ran")
      },
    ),
    it_runs_in_child_vm(
      "before_all_suites main prints what the example shows",
      fn() {
        // Act
        let result =
          snippets_child_vm.run("snippets/doc/runner/before_all_suites", "main")
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(status: 0, output: "running 2 suites\n", error_output: "")),
        )
        |> or_fail_with("expected the hook to count the suites before the run")
      },
    ),
    it_runs_in_child_vm(
      "after_all_suites main prints what the example shows",
      fn() {
        // Act
        let result =
          snippets_child_vm.run("snippets/doc/runner/after_all_suites", "main")
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(status: 0, output: "ran 2 suites\n", error_output: "")),
        )
        |> or_fail_with("expected the hook to count the suites after the run")
      },
    ),
    it_runs_in_child_vm("the module example main runs both suites", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/runner/module", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(2)
            <> "Example\n  ✓ works\nDatabase\n  ✓ connects\n\n"
            <> "Summary: 2 run, 0 failed, 2 passed in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with("expected the module example main to print its report")
    }),
    it_runs_in_child_vm("the minimal runner main passes its test", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/runner/minimal_test_runner", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(1)
            <> "Example\n  ✓ works\n\n"
            <> "Summary: 1 run, 0 failed, 1 passed in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with("expected the minimal runner main to print its report")
    }),
    it("run_unit_and_integration_suites runs both suites", fn() {
      // Act
      let report = add_suites.run_unit_and_integration_suites()

      // Assert
      names_and_statuses(report)
      |> should
      |> be_equal([#("adds", Passed), #("connects", Passed)])
      |> or_fail_with("expected both added suites to pass")
    }),
    it("run_database_suite_alone runs both suites", fn() {
      // Act
      let report = add_suites_with_config.run_database_suite_alone()

      // Assert
      names_and_statuses(report)
      |> should
      |> be_equal([#("adds", Passed), #("connects", Passed)])
      |> or_fail_with("expected the unit and database suites to pass")
    }),
    it_runs_in_child_vm("the sequential runner main passes both tests", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/runner/sequential_execution", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(2)
            <> "Sequential tests\n  ✓ first test\n  ✓ second test\n\n"
            <> "Summary: 2 run, 0 failed, 2 passed in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with("expected the sequential runner main to print its report")
    }),
    it_runs_in_child_vm("the runner config main passes its test", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/runner/runner_config", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(1)
            <> "Runner config demo\n  ✓ runs with custom config\n\n"
            <> "Summary: 1 run, 0 failed, 1 passed in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with("expected the runner config main to print its report")
    }),
    it("the output example runs its suite", fn() {
      // Act
      let report = output.main()

      // Assert
      names_and_statuses(report)
      |> should
      |> be_equal([#("works", Passed)])
      |> or_fail_with("expected the output example test to pass")
    }),
    it_runs_in_child_vm_with_coverage_lock(
      "the coverage main prints the report and the coverage table",
      fn() {
        // Act
        let result =
          snippets_child_vm.run_with_coverage_lock(
            "snippets/doc/runner/coverage",
            "main",
            [],
          )
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "Example\n  ✓ works\n\n"
              <> "Summary: 1 run, 0 failed, 1 passed in <duration>\n\n"
              <> coverage_tests.uncovered_table
              <> "LCOV: build/coverage/lcov.info\n",
            error_output: "",
          )),
        )
        |> or_fail_with("expected the main to print its report")
      },
    ),
    it_runs_in_child_vm_with_coverage_lock(
      "the coverage_from_environment main measures nothing without the variable",
      fn() {
        // Act
        let result =
          snippets_child_vm.run_with_coverage_lock(
            "snippets/doc/runner/coverage_from_environment",
            "main",
            [],
          )
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "Example\n  ✓ works\n\n"
              <> "Summary: 1 run, 0 failed, 1 passed in <duration>\n",
            error_output: "",
          )),
        )
        |> or_fail_with("expected the main to print its report")
      },
    ),
    it_runs_in_child_vm_with_coverage_lock(
      "the coverage_from_environment main measures with DREAM_TEST_COVERAGE=1",
      fn() {
        // Act
        let result =
          snippets_child_vm.run_with_coverage_lock(
            "snippets/doc/runner/coverage_from_environment",
            "main",
            [#("DREAM_TEST_COVERAGE", "1")],
          )
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "Example\n  ✓ works\n\n"
              <> "Summary: 1 run, 0 failed, 1 passed in <duration>\n\n"
              <> coverage_tests.uncovered_table
              <> "LCOV: build/coverage/lcov.info\n",
            error_output: "",
          )),
        )
        |> or_fail_with("expected the main to print its report")
      },
    ),
    it_runs_in_child_vm("the filter_tests main runs only the smoke test", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/runner/filter_tests", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(1)
            <> "Filtering tests\n  ✓ smoke\n\n"
            <> "Summary: 1 run, 0 failed, 1 passed in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with("expected the filter_tests main to print its report")
    }),
    it_runs_in_child_vm(
      "the before_each_test main logs the test before it runs",
      fn() {
        // Act
        let result =
          snippets_child_vm.run("snippets/doc/runner/before_each_test", "main")
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "starting Example > works\n",
            error_output: "",
          )),
        )
        |> or_fail_with(
          "expected the before_each_test main to print its report",
        )
      },
    ),
  ])
}
