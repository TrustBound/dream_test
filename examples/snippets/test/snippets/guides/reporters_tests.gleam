//// The tests of the outputs that the guide on reporters shows.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}
import gleam/result
import snippets/guides/reporters_annotation_tests
import snippets/guides/reporters_shop
import snippets_child_vm.{it_runs_in_child_vm}
import snippets_outputs

fn shop_report() -> RunReport {
  runner.new([reporters_shop.shop_tests()])
  |> runner.silent()
  |> runner.run()
}

pub fn tests() -> TestSuite {
  describe("Guide: reporters", [
    it("the full report", fn() {
      // Act
      let text =
        snippets_outputs.render_with_bdd(shop_report(), reporter_types.BddFull)

      // Assert
      Ok(text)
      |> should
      |> be_equal(snippets_outputs.expected("guide_reporters_full"))
      |> or_fail_with("expected test/outputs/guide_reporters_full.txt")
    }),
    it("the failures only report", fn() {
      // Act
      let text =
        snippets_outputs.render_with_bdd(
          shop_report(),
          reporter_types.BddFailuresOnly,
        )

      // Assert
      Ok(text)
      |> should
      |> be_equal(snippets_outputs.expected("guide_reporters_failures_only"))
      |> or_fail_with("expected test/outputs/guide_reporters_failures_only.txt")
    }),
    it("the summary only report", fn() {
      // Act
      let text =
        snippets_outputs.render_with_bdd(
          shop_report(),
          reporter_types.BddSummaryOnly,
        )

      // Assert
      Ok(text)
      |> should
      |> be_equal(snippets_outputs.expected("guide_reporters_summary_only"))
      |> or_fail_with("expected test/outputs/guide_reporters_summary_only.txt")
    }),
    it("the JSON report", fn() {
      // Act
      let text = snippets_outputs.stable_json(shop_report())

      // Assert
      Ok(text)
      |> should
      |> be_equal(snippets_outputs.expected("guide_reporters_json"))
      |> or_fail_with("expected test/outputs/guide_reporters_json.txt")
    }),
    it_runs_in_child_vm("the CI run prints its reports", fn() {
      // Act
      let run =
        snippets_outputs.child_output("snippets/guides/reporters_ci", "main")

      // Assert
      run
      |> should
      |> be_equal(snippets_outputs.expected_run(1, "guide_reporters_ci"))
      |> or_fail_with("expected test/outputs/guide_reporters_ci.txt")
    }),
    it_runs_in_child_vm("a crashing reporter writes an error", fn() {
      // Act
      let run = crash_run()

      // Assert
      run
      |> should
      |> be_equal(
        snippets_outputs.expected("guide_reporters_crash")
        |> result.map(crash_run_with_error_output),
      )
      |> or_fail_with("expected test/outputs/guide_reporters_crash.txt")
    }),
    it("the annotation tests pass", fn() {
      // Act
      let report =
        snippets_outputs.bdd_report([reporters_annotation_tests.tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_reporters_check"))
      |> or_fail_with("expected test/outputs/guide_reporters_check.txt")
    }),
  ])
}

/// The exit status, the output and the error output of the run with a
/// crashing reporter.
pub fn crash_run() -> Result(#(Int, String, String), String) {
  snippets_child_vm.run("snippets/guides/reporters_crash", "main")
  |> result.map(stable_crash_run)
}

fn stable_crash_run(run: snippets_child_vm.ChildRun) -> #(Int, String, String) {
  #(
    run.status,
    snippets_child_vm.without_progress_and_durations(run.output),
    run.error_output,
  )
}

fn crash_run_with_error_output(error_output: String) -> #(Int, String, String) {
  #(1, "Summary: 1 run, 0 failed, 1 passed in <duration>\n", error_output)
}
