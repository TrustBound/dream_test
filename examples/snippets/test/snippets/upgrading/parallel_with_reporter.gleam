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

  let report =
    types.run_report(
      tests: results,
      teardown_failures: teardown_failures,
      reporter_crashes: [],
    )

  // Count failed tear-down hooks and stopped set-ups apart.
  let counts = summary.count(report)

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

  report
}

pub fn tests() {
  unit.describe("Upgrading: a run with a progress reporter", [
    it("runs the tree, and its test passes", fn() { run_tree() }),
  ])
}

fn run_tree() -> Result(types.AssertionResult, String) {
  main()
  |> passed_and_failed
  |> matchers.should
  |> matchers.be_equal(#(1, False))
  |> matchers.or_fail_with(
    "expected the one test of the tree to pass, and no failed tear-down",
  )
}

/// The passed tests of the report, and whether the run failed, also by a
/// failed tear-down hook.
fn passed_and_failed(report: types.RunReport) -> #(Int, Bool) {
  #(summary.count(report).passed, types.failed(report))
}
