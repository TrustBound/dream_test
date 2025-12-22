import dream_test/matchers.{succeed}
import dream_test/parallel
import dream_test/reporters
import dream_test/reporters/types as reporter_types
import dream_test/types.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/io

pub fn suite() -> TestSuite(Nil) {
  describe("suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  let total = 1
  let completed = 0

  let initial_reporter = reporters.progress(io.print)
  let reporter_after_start =
    reporters.handle_event(
      initial_reporter,
      reporter_types.RunStarted(total: total),
    )

  let parallel_result =
    parallel.run_root_parallel_with_reporter(
      parallel.RunRootParallelWithReporterConfig(
        config: parallel.default_config(),
        suite: suite(),
        reporter: reporter_after_start,
        total: total,
        completed: completed,
      ),
    )
  let parallel.RunRootParallelWithReporterResult(
    results: results,
    completed: completed_after_suite,
    reporter: reporter_after_suite,
  ) = parallel_result

  let _ =
    reporters.handle_event(
      reporter_after_suite,
      reporter_types.RunFinished(completed: completed_after_suite, total: total),
    )

  results
}
