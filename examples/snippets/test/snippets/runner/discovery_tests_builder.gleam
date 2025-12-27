import dream_test/discover
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner.{
  exit_on_failure, progress_reporter, results_reporters, run,
}

pub fn main() {
  let suites =
    discover.tests("snippets/unit/**.gleam")
    |> discover.to_suites()

  runner.new(suites)
  |> progress_reporter(progress.new())
  |> results_reporters([bdd.new()])
  |> exit_on_failure()
  |> run()
}
