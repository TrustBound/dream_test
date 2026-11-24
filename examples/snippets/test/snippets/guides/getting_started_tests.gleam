//// The tests of the outputs that the getting started guide shows. Each
//// test runs the code of a step and compares what it prints with the
//// output file that the guide shows.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe}
import snippets_child_vm.{it_runs_in_child_vm}
import snippets_outputs

pub fn tests() -> TestSuite {
  describe("Guide: getting started", [
    it_runs_in_child_vm("the first run passes and prints its report", fn() {
      // Act
      let run =
        snippets_outputs.child_output(
          "snippets/guides/getting_started_first_test",
          "main",
        )

      // Assert
      run
      |> should
      |> be_equal(snippets_outputs.expected_run(
        0,
        "guide_getting_started_first_run",
      ))
      |> or_fail_with(
        "expected test/outputs/guide_getting_started_first_run.txt",
      )
    }),
    it_runs_in_child_vm("a failing test gives exit status 1", fn() {
      // Act
      let run =
        snippets_outputs.child_output(
          "snippets/guides/getting_started_failing_test",
          "main",
        )

      // Assert
      run
      |> should
      |> be_equal(snippets_outputs.expected_run(
        1,
        "guide_getting_started_failing_run",
      ))
      |> or_fail_with(
        "expected test/outputs/guide_getting_started_failing_run.txt",
      )
    }),
    it_runs_in_child_vm("a wrong discovery pattern fails the run", fn() {
      // Act
      let run =
        snippets_outputs.child_output(
          "snippets/guides/getting_started_wrong_pattern",
          "main",
        )

      // Assert
      run
      |> should
      |> be_equal(snippets_outputs.expected_run(
        1,
        "guide_getting_started_wrong_pattern",
      ))
      |> or_fail_with(
        "expected test/outputs/guide_getting_started_wrong_pattern.txt",
      )
    }),
    it_runs_in_child_vm("discovery runs the runner check", fn() {
      // Act
      let run =
        snippets_outputs.child_output(
          "snippets/guides/getting_started_discovery",
          "main",
        )

      // Assert
      run
      |> should
      |> be_equal(snippets_outputs.expected_run(
        0,
        "guide_getting_started_discovery",
      ))
      |> or_fail_with(
        "expected test/outputs/guide_getting_started_discovery.txt",
      )
    }),
  ])
}
