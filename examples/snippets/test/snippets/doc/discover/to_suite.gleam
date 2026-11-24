import dream_test/discover
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner.{
  exit_on_failure, progress_reporter, results_reporters, run,
}
import dream_test/types.{type RunReport}

pub fn main() -> RunReport {
  let suite =
    discover.tests("snippets/unit/**.gleam")
    |> discover.to_suite("discovered tests")

  runner.new([suite])
  |> progress_reporter(progress.new())
  |> results_reporters([bdd.new()])
  |> exit_on_failure()
  |> run()
}
