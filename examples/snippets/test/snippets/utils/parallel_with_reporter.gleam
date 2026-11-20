import dream_test/matchers.{succeed}
import dream_test/parallel
import dream_test/reporters/progress
import dream_test/reporters/summary
import dream_test/types.{type Tree}
import dream_test/unit.{it}
import gleam/option.{Some}

pub fn tree() -> Tree(Nil) {
  types.tree("suite", Nil, [
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
    parallel.run_tree_parallel_with_reporter(
      parallel.RunTreeParallelWithReporterConfig(
        config: parallel.default_config(),
        tree: tree(),
        progress_reporter: Some(reporter),
        write: write,
        total: total,
        completed: completed,
        runner_before_each_test: [],
        runner_after_each_test: [],
        outer_setups: [],
      ),
    )
  let parallel.RunTreeParallelWithReporterResult(
    results: results,
    teardown_failures: teardown_failures,
    completed: completed_after_suite,
    progress_reporter: _progress_reporter,
    outer_setups: _outer_setups,
  ) = parallel_result

  // Count failed tear-down hooks and stopped set-ups apart.
  let counts =
    summary.count(
      types.run_report(
        tests: results,
        teardown_failures: teardown_failures,
        reporter_crashes: [],
      ),
    )

  progress.line(
    reporter,
    progress.RunFinishedProgress(
      completed: completed_after_suite,
      total: total,
      teardown_failures: counts.teardown_failed,
      setup_stopped: counts.setup_stopped,
    ),
  )
  |> write

  results
}
