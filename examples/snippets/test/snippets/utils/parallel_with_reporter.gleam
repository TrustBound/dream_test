import dream_test/matchers.{succeed}
import dream_test/parallel
import dream_test/reporters/progress
import dream_test/types.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/option.{Some}

pub fn suite() -> TestSuite(Nil) {
  describe("suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  let total = 1
  let completed = 0

  let reporter = progress.new()
  let write = fn(_s: String) { Nil }

  progress.line(reporter, progress.RunStartedProgress(total: total))
  |> write

  let parallel_result =
    parallel.run_root_parallel_with_reporter(
      parallel.RunRootParallelWithReporterConfig(
        config: parallel.default_config(),
        suite: suite(),
        progress_reporter: Some(reporter),
        write: write,
        total: total,
        completed: completed,
        runner_before_each_test: [],
        runner_after_each_test: [],
      ),
    )
  let parallel.RunRootParallelWithReporterResult(
    results: results,
    teardown_failures: teardown_failures,
    completed: completed_after_suite,
    progress_reporter: _progress_reporter,
  ) = parallel_result

  progress.line(
    reporter,
    progress.RunFinishedProgress(
      completed: completed_after_suite,
      total: total,
      teardown_failures: list.length(teardown_failures),
    ),
  )
  |> write

  results
}
