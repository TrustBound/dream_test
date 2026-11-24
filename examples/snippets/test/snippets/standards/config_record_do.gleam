//// The "Do" example of rule 8 of STANDARDS.md: a config record with named
//// fields.

import dream_test/parallel.{ParallelConfig, run_tree_parallel}
import dream_test/types.{type RunReport, type Tree}

import dream_test/matchers.{have_length, or_fail_with, should, succeed}
import dream_test/unit.{describe, it}

pub fn run_example(tree: Tree(Nil)) -> RunReport {
  let config = ParallelConfig(max_concurrency: 4, default_timeout_ms: 5000)

  run_tree_parallel(config: config, tree: tree)
}

pub fn tests() {
  describe("STANDARDS.md rule 8, Do: a config record", [
    it("runs the tree with the config", fn() {
      // Act
      let report =
        run_example(
          types.tree("math", Nil, [it("adds", fn() { Ok(succeed()) })]),
        )

      // Assert
      types.report_tests(report)
      |> should
      |> have_length(1)
      |> or_fail_with("the config record call should run the test")
    }),
  ])
}
