//// Failure Showcase — Dream Test Reporting Demo
////
//// This runner intentionally executes only failing tests so you can quickly
//// inspect how Dream Test renders different failure modes.

import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gherkin_failures
import gleam/io
import unit_failures

pub fn main() {
  io.println("")
  io.println("Failure Showcase — Dream Test Reporting Demo")
  io.println("===========================================")
  io.println("")

  runner.new([unit_failures.tests(), gherkin_failures.tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new() |> bdd.color()])
  |> runner.default_timeout_ms(10)
  |> runner.run()
}
