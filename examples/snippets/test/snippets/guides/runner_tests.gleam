//// The tests of the outputs that the guide on large suites shows.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/types as reporter_types
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/guides/runner_failure_policy
import snippets/guides/runner_timeout
import snippets_child_vm.{it_runs_in_child_vm}
import snippets_outputs

pub fn tests() -> TestSuite {
  describe("Guide: large suites", [
    it_runs_in_child_vm("the CI runner prints its summary", fn() {
      // Act
      let run =
        snippets_outputs.child_output(
          "snippets/guides/runner_ci_runner",
          "main",
        )

      // Assert
      run
      |> should
      |> be_equal(snippets_outputs.expected_run(0, "guide_runner_ci"))
      |> or_fail_with("expected test/outputs/guide_runner_ci.txt")
    }),
    it("a test slower than the timeout is TimedOut", fn() {
      // Act
      let report =
        runner_timeout.run_with_a_short_timeout()
        |> snippets_outputs.render_with_bdd(reporter_types.BddFull)

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_runner_timeout"))
      |> or_fail_with("expected test/outputs/guide_runner_timeout.txt")
    }),
    it("the run report check passes", fn() {
      // Act
      let report = snippets_outputs.bdd_report([runner_failure_policy.tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_runner_check"))
      |> or_fail_with("expected test/outputs/guide_runner_check.txt")
    }),
  ])
}
