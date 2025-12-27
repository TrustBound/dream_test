import dream_test/discover
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner

fn suites() {
  let discover.LoadResult(suites: suites, errors: _errors) =
    discover.tests("snippets/**.gleam")
    |> discover.load()

  suites
}

pub fn main() {
  runner.new(suites())
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new() |> bdd.color()])
  |> runner.exit_on_failure()
  |> runner.run()
}
