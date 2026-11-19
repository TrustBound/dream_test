//// Runs the runner snippets that have only a `main`: the docs show their
//// `main`, and these tests run the same suites without output.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/summary
import dream_test/runner
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}
import snippets/runner/discovery_runner
import snippets/runner/suite_specific_config

pub fn tests() {
  describe("Runner snippets with only a main", [
    it("the discovery runner finds and runs the unit snippets", fn() {
      run_discovered_suites()
    }),
    it("the suite-specific config runs both suites", fn() {
      run_configured_suites()
    }),
  ])
}

fn run_discovered_suites() -> Result(AssertionResult, String) {
  runner.new(discovery_runner.suites())
  |> runner.silent()
  |> runner.run()
  |> summary.count
  |> found_and_failed
  |> should
  |> be_equal(#(True, 0))
  |> or_fail_with("expected unit snippet tests, and no failure")
}

fn run_configured_suites() -> Result(AssertionResult, String) {
  suite_specific_config.configured_runner()
  |> runner.silent()
  |> runner.run()
  |> summary.count
  |> found_and_failed
  |> should
  |> be_equal(#(True, 0))
  |> or_fail_with("expected the tests of the two suites to pass")
}

/// Whether the run had tests, and how many did not pass.
fn found_and_failed(counts: summary.Counts) -> #(Bool, Int) {
  #(counts.run > 0, counts.failed + counts.timed_out + counts.setup_failed)
}
