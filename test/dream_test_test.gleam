import dream_test/coverage
import dream_test/discover.{from_path, to_suites}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner

pub fn main() {
  let suites =
    discover.new()
    |> from_path("dream_test/**_test.gleam")
    |> to_suites()

  runner.new(suites)
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new() |> bdd.color()])
  |> runner.coverage(
    coverage.new()
    |> coverage.show_missing()
    |> coverage.json_path("build/coverage/coverage.json"),
  )
  |> runner.exit_on_failure()
  |> runner.run()
}
