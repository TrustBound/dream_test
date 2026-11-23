import dream_test/matchers.{succeed}
import dream_test/parallel
import dream_test/types.{type AssertionResult}
import dream_test/unit
import gleam/option.{None}

fn passes() -> Result(AssertionResult, String) {
  Ok(succeed())
}

fn ignore(_text: String) -> Nil {
  Nil
}

pub fn run_suite_in_group() -> parallel.RunTreeParallelWithReporterResult {
  parallel.run_tree(
    parallel.RunTreeConfig(
      config: parallel.default_config(),
      groups: ["all"],
      name: "suite",
      tags: [],
      children: [unit.it("passes", passes)],
      context: types.FixedContext(Nil),
      progress_reporter: None,
      write: ignore,
      total: 1,
      completed: 0,
      runner_before_each_test: [],
      runner_after_each_test: [],
      outer_setups: [],
    ),
  )
}
