import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}
import snippets/doc/reporters/hook_failures/format
import snippets/doc/reporters/hook_failures/format_in_color
import snippets/doc/reporters/hook_failures/module
import snippets_child_vm.{ChildRun, it_runs_in_child_vm}

fn report_with_failed_teardown() -> RunReport {
  types.run_report(
    tests: [],
    hook_failures: [
      types.TeardownFailed(
        hook: types.AfterAllHook,
        path: ["Database"],
        message: "could not drop the schema",
      ),
    ],
    reporter_crashes: [],
  )
}

pub fn tests() -> TestSuite {
  describe("Doc examples: reporters/hook_failures", [
    it("hook_failure_section lists the failed teardown", fn() {
      // Act
      let text = module.hook_failure_section(report_with_failed_teardown())

      // Assert
      text
      |> should
      |> be_equal(
        "Setup and teardown failures:\n  after_all in Database\n    could not drop the schema\n",
      )
      |> or_fail_with("expected the section of one failed teardown")
    }),
    it("stopped_setup_section lists the tests that did not run", fn() {
      // Act
      let text = format.stopped_setup_section()

      // Assert
      text
      |> should
      |> be_equal(
        "Setup and teardown failures:\n  before_all in \"root\" stopped: the process that keeps its setup alive exited with Boom.\n    These tests had not started and were not run:\n      root > b\n      root > c\n",
      )
      |> or_fail_with("expected the section of one stopped setup")
    }),
    it_runs_in_child_vm(
      "print_hook_failures_in_color prints the coloured section",
      fn() {
        // Act
        let result =
          snippets_child_vm.run(
            "snippets/doc/reporters/hook_failures/tests",
            "print_failed_teardown_in_color",
          )

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "\u{1b}[1m\u{1b}[31mSetup and teardown failures:\u{1b}[0m\u{1b}[0m\n  \u{1b}[31mafter_all in Database\u{1b}[0m\n    could not drop the schema\n",
            error_output: "",
          )),
        )
        |> or_fail_with("expected the coloured section of one failed teardown")
      },
    ),
  ])
}

/// For the child VM: print the hook failures of a run with one failed
/// teardown, in colour.
pub fn print_failed_teardown_in_color() -> Nil {
  format_in_color.print_hook_failures_in_color(report_with_failed_teardown())
}
