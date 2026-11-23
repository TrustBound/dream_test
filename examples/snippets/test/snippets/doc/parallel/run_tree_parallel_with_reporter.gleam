import dream_test/matchers.{succeed}
import dream_test/parallel
import dream_test/types.{type TestResult, type Tree}
import dream_test/unit.{it}
import gleam/option.{None}

pub fn tree() -> Tree(Nil) {
  types.tree("suite", Nil, [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

fn ignore(_text: String) -> Nil {
  Nil
}

pub fn main() -> List(TestResult) {
  let total = 1
  let completed = 0
  let parallel_result =
    parallel.run_tree_parallel_with_reporter(
      parallel.RunTreeParallelWithReporterConfig(
        config: parallel.default_config(),
        tree: tree(),
        progress_reporter: None,
        write: ignore,
        total: total,
        completed: completed,
        runner_before_each_test: [],
        runner_after_each_test: [],
        outer_setups: [],
      ),
    )
  let parallel.RunTreeParallelWithReporterResult(
    results: results,
    hook_failures: _hook_failures,
    completed: _completed_after_suite,
    progress_reporter: _progress_reporter,
    outer_setups: _outer_setups,
  ) = parallel_result
  results
}
