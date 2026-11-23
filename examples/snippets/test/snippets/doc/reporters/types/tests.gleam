import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe}
import snippets_child_vm.{ChildRun, it_runs_in_child_vm}

pub fn tests() -> TestSuite {
  describe("Doc examples: reporters/types", [
    it_runs_in_child_vm("custom main prints my report", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/reporters/types/custom", "main")

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(status: 0, output: "My report: passed\n", error_output: "")),
      )
      |> or_fail_with("expected the custom reporter to print its line")
    }),
  ])
}
