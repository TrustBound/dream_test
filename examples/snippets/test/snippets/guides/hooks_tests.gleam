//// The tests of the outputs that the guide on hooks shows.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/types as reporter_types
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/guides/hooks_check_cleanup
import snippets/guides/hooks_slow_setup
import snippets/hooks/setup_failure
import snippets/hooks/teardown_failure
import snippets_child_vm.{it_runs_in_child_vm}
import snippets_outputs

pub fn tests() -> TestSuite {
  describe("Guide: hooks", [
    it_runs_in_child_vm("the hooks print in their order", fn() {
      // Act
      let run =
        snippets_outputs.child_output("snippets/guides/hooks_order", "main")

      // Assert
      run
      |> should
      |> be_equal(snippets_outputs.expected_run(0, "guide_hooks_order"))
      |> or_fail_with("expected test/outputs/guide_hooks_order.txt")
    }),
    it_runs_in_child_vm("the runner hooks print around the suites", fn() {
      // Act
      let run =
        snippets_outputs.child_output(
          "snippets/guides/hooks_runner_hooks",
          "main",
        )

      // Assert
      run
      |> should
      |> be_equal(snippets_outputs.expected_run(0, "guide_hooks_runner_hooks"))
      |> or_fail_with("expected test/outputs/guide_hooks_runner_hooks.txt")
    }),
    it("a failing setup hook gives SetupFailed", fn() {
      // Act
      let report =
        snippets_outputs.bdd_report([setup_failure.setup_failure_tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_hooks_setup_failure"))
      |> or_fail_with("expected test/outputs/guide_hooks_setup_failure.txt")
    }),
    it("a failing teardown hook is in its own section", fn() {
      // Act
      let report =
        snippets_outputs.bdd_report([teardown_failure.cleanup_failure_tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_hooks_teardown_failure"))
      |> or_fail_with("expected test/outputs/guide_hooks_teardown_failure.txt")
    }),
    it("a setup hook that times out gives SetupFailed", fn() {
      // Act
      let report =
        hooks_slow_setup.run_with_a_short_timeout()
        |> snippets_outputs.render_with_bdd(reporter_types.BddFull)

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_hooks_timeout"))
      |> or_fail_with("expected test/outputs/guide_hooks_timeout.txt")
    }),
    it("the cleanup check passes", fn() {
      // Act
      let report = snippets_outputs.bdd_report([hooks_check_cleanup.tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_hooks_check"))
      |> or_fail_with("expected test/outputs/guide_hooks_check.txt")
    }),
  ])
}
