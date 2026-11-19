import dream_test/discover
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner

/// The discovered suites. A module that does not load gives a failing
/// test, so a load error fails the run.
fn suites() {
  discover.tests("snippets/**.gleam")
  |> discover.to_suites()
}

pub fn main() {
  runner.new(suites())
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new() |> bdd.color()])
  |> runner.exit_on_failure()
  |> runner.run()
}
