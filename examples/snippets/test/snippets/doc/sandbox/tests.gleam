import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/sandbox.{SandboxConfig}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type Status, Passed}
import dream_test/unit.{describe, it}
import gleam/list
import snippets/doc/sandbox/check_setup_process as check_setup_process_example
import snippets/doc/sandbox/default_config as default_config_example
import snippets/doc/sandbox/format_exit_reason as format_exit_reason_example
import snippets/doc/sandbox/kill_and_wait as kill_and_wait_example
import snippets/doc/sandbox/run_catching as run_catching_example
import snippets/doc/sandbox/run_in_setup_process as run_in_setup_process_example
import snippets/doc/sandbox/run_isolated as run_isolated_example
import snippets/doc/sandbox/sandbox_config as sandbox_config_example
import snippets/doc/sandbox/stop_setup_process as stop_setup_process_example
import snippets/doc/sandbox/with_crash_reports as with_crash_reports_example

fn statuses(suite: TestSuite) -> List(#(List(String), Status)) {
  runner.new([suite])
  |> runner.silent()
  |> runner.run()
  |> types.report_tests
  |> list.map(fn(result) {
    #(types.full_name(result.groups, result.name), result.status)
  })
}

pub fn tests() -> TestSuite {
  describe("Doc examples: sandbox", [
    it("config_for_most_tests gives a 5 second timeout", fn() {
      // Act
      let config = default_config_example.config_for_most_tests()

      // Assert
      config
      |> should
      |> be_equal(SandboxConfig(timeout_ms: 5000, show_crash_reports: False))
      |> or_fail_with("expected 5000 ms and no crash reports")
    }),
    it("run_isolated.tests passes all three tests", fn() {
      // Act
      let result = statuses(run_isolated_example.tests())

      // Assert
      result
      |> should
      |> be_equal([
        #(
          [
            "Sandboxing",
            "run_isolated returns SandboxCompleted(value) on success",
          ],
          Passed,
        ),
        #(
          [
            "Sandboxing",
            "run_isolated returns SandboxTimedOut when the function is too slow",
          ],
          Passed,
        ),
        #(
          [
            "Sandboxing",
            "run_isolated returns SandboxCrashed when the function panics",
          ],
          Passed,
        ),
      ])
      |> or_fail_with("expected the three sandbox tests to pass")
    }),
    it("sandbox_config.one_second_config gives a one second timeout", fn() {
      // Act
      let result = sandbox_config_example.one_second_config()

      // Assert
      result
      |> should
      |> be_equal(SandboxConfig(timeout_ms: 1000, show_crash_reports: False))
      |> or_fail_with("expected a one second timeout and no crash reports")
    }),
    it("with_crash_reports.debugging_config shows crash reports", fn() {
      // Act
      let result = with_crash_reports_example.debugging_config()

      // Assert
      result
      |> should
      |> be_equal(SandboxConfig(timeout_ms: 5000, show_crash_reports: True))
      |> or_fail_with("expected the default timeout with crash reports")
    }),
    it("run_catching.tests passes", fn() {
      // Act
      let result = statuses(run_catching_example.tests())

      // Assert
      result
      |> should
      |> be_equal([
        #(
          ["run_catching", "returns the value of a function that returns"],
          Passed,
        ),
      ])
      |> or_fail_with("expected the run_catching test to pass")
    }),
    it("format_exit_reason.tests passes", fn() {
      // Act
      let result = statuses(format_exit_reason_example.tests())

      // Assert
      result
      |> should
      |> be_equal([
        #(
          [
            "Exit reasons",
            "format_exit_reason shows an abnormal reason as Gleam text",
          ],
          Passed,
        ),
      ])
      |> or_fail_with("expected the exit reason test to pass")
    }),
    it("kill_and_wait.tests passes", fn() {
      // Act
      let result = statuses(kill_and_wait_example.tests())

      // Assert
      result
      |> should
      |> be_equal([
        #(["kill_and_wait", "returns when the process is gone"], Passed),
      ])
      |> or_fail_with("expected the kill_and_wait test to pass")
    }),
    it("run_in_setup_process.tests passes", fn() {
      // Act
      let result = statuses(run_in_setup_process_example.tests())

      // Assert
      result
      |> should
      |> be_equal([
        #(
          [
            "Setup processes",
            "run_in_setup_process returns the value of the function",
          ],
          Passed,
        ),
      ])
      |> or_fail_with("expected the run_in_setup_process test to pass")
    }),
    it("check_setup_process.tests passes", fn() {
      // Act
      let result = statuses(check_setup_process_example.tests())

      // Assert
      result
      |> should
      |> be_equal([
        #(
          [
            "Setup processes",
            "check_setup_process gives back a setup process that is alive",
          ],
          Passed,
        ),
      ])
      |> or_fail_with("expected the check_setup_process test to pass")
    }),
    it("stop_setup_process.tests passes", fn() {
      // Act
      let result = statuses(stop_setup_process_example.tests())

      // Assert
      result
      |> should
      |> be_equal([
        #(
          ["Setup processes", "stop_setup_process stops a setup process"],
          Passed,
        ),
      ])
      |> or_fail_with("expected the stop_setup_process test to pass")
    }),
  ])
}
