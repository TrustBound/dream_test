import dream_test/coverage
import dream_test/discover.{from_path, to_suites}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner

/// Delete the LCOV parts and child projects of an earlier run. The coverage
/// tests that run in child nodes write new parts during this run, and
/// `coverage.merge_lcov` adds them to this run's coverage.
@external(erlang, "dream_test_coverage_test_ffi", "reset_child_output")
fn reset_child_output() -> Nil

pub fn main() {
  reset_child_output()

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
    |> coverage.merge_lcov("build/coverage/parts/*.info")
    |> coverage.json_path("build/coverage/coverage.json"),
  )
  |> runner.exit_on_failure()
  |> runner.run()
}
