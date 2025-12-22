import dream_test/discover
import dream_test/reporters
import dream_test/runner.{exit_on_failure, reporter, run}
import gleam/io

pub fn main() {
  let suite =
    discover.tests("snippets/unit/**.gleam")
    |> discover.to_suite("discovered tests")

  runner.new([suite])
  |> reporter(reporters.bdd(io.print, True))
  |> exit_on_failure()
  |> run()
}
