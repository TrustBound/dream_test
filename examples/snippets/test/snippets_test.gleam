import dream_test/discover
import dream_test/reporters
import dream_test/runner
import gleam/io

fn suites() {
  let discover.LoadResult(suites: suites, errors: _errors) =
    discover.tests("snippets/**.gleam")
    |> discover.load()

  suites
}

pub fn main() {
  runner.new(suites())
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
