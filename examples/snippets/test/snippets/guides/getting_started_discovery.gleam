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

/// The suites of every test module under `test/snippets/guides/` whose
/// name ends in `_check`.
pub fn suites() {
  discover.tests("snippets/guides/**_check.gleam")
  |> discover.to_suites()
}
