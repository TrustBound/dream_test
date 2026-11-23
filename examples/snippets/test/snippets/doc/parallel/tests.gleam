import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type Status, type TestResult, Passed}
import dream_test/unit.{describe, it}
import gleam/list
import snippets/doc/parallel/run_tree
import snippets/doc/parallel/run_tree_parallel_with_reporter

fn path_and_status(result: TestResult) -> #(List(String), String, Status) {
  #(result.groups, result.name, result.status)
}

pub fn tests() -> TestSuite {
  describe("Doc examples: parallel", [
    it("run_tree_parallel_with_reporter main gives one passed result", fn() {
      // Act
      let results = run_tree_parallel_with_reporter.main()

      // Assert
      list.map(results, path_and_status)
      |> should
      |> be_equal([#(["suite"], "passes", Passed)])
      |> or_fail_with("expected one passed result in the suite group")
    }),
    it("run_suite_in_group gives one passed result inside all", fn() {
      // Act
      let result = run_tree.run_suite_in_group()

      // Assert
      list.map(result.results, path_and_status)
      |> should
      |> be_equal([#(["all", "suite"], "passes", Passed)])
      |> or_fail_with("expected one passed result in the all > suite groups")
    }),
  ])
}
