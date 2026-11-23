//// A test runner whose discovery pattern names a folder that does not
//// exist. The getting started guide shows the report of its run.

import dream_test/discover
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner

pub fn main() {
  runner.new(suites())
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

/// The suites of every test module under `test/snippets/units/`, a folder
/// that does not exist.
pub fn suites() {
  discover.tests("snippets/units/**.gleam")
  |> discover.to_suites()
}
