//// The "Don't" example of rule 8 of STANDARDS.md: a function with two
//// `Int` parameters side by side. A caller can swap them, and the code
//// still compiles.

import dream_test/matchers.{have_length, or_fail_with, should, succeed}
import dream_test/parallel.{ParallelConfig}
import dream_test/types.{type RunReport, type Tree}
import dream_test/unit.{describe, it}

/// A positional form of `parallel.run_tree_parallel`, to show the problem.
fn run_tree_parallel(
  max_concurrency: Int,
  default_timeout_ms: Int,
  tree: Tree(Nil),
) -> RunReport {
  parallel.run_tree_parallel(
    config: ParallelConfig(
      max_concurrency: max_concurrency,
      default_timeout_ms: default_timeout_ms,
    ),
    tree: tree,
  )
}

pub fn run_example(tree: Tree(Nil)) -> RunReport {
  // Two Ints side by side: a caller can swap them and still compile
  run_tree_parallel(4, 5000, tree)
}

/// The same call with the two numbers swapped. It compiles too.
pub fn run_swapped(tree: Tree(Nil)) -> RunReport {
  run_tree_parallel(5000, 4, tree)
}

pub fn tests() {
  describe("STANDARDS.md rule 8, Don't: two Ints side by side", [
    it("the swapped call compiles and runs", fn() {
      // Act
      let report = run_swapped(passing_tree())

      // Assert
      types.report_tests(report)
      |> should
      |> have_length(1)
      |> or_fail_with("the swapped call should still run the test")
    }),
    it("the call in the example runs", fn() {
      // Act
      let report = run_example(passing_tree())

      // Assert
      types.report_tests(report)
      |> should
      |> have_length(1)
      |> or_fail_with("the example call should run the test")
    }),
  ])
}

fn passing_tree() -> Tree(Nil) {
  types.tree("math", Nil, [it("adds", fn() { Ok(succeed()) })])
}
