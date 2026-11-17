import dream_test/coverage
import dream_test/coverage_child_measure
import dream_test/discover.{from_path, to_suites}
import dream_test/file
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner

pub fn main() {
  // The `erl` processes of the runner tests write LCOV parts here (see
  // coverage_child_measure). Delete the parts of an earlier run first.
  let assert Ok(_) =
    file.delete_files_matching(coverage_child_measure.parts_directory, ".info")

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
    |> coverage.json_path("build/coverage/coverage.json")
    |> coverage.merge_lcov(coverage_child_measure.parts_pattern),
  )
  |> runner.exit_on_failure()
  |> runner.run()
}
