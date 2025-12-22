import dream_test/discover
import dream_test/reporters
import dream_test/runner.{exit_on_failure, reporter, run}
import gleam/io

pub fn main() {
  let suites =
    discover.tests("snippets/unit/**.gleam")
    |> discover.to_suites()

  runner.new(suites)
  |> reporter(reporters.bdd(io.print, True))
  |> exit_on_failure()
  |> run()
}
