//// The tests of the outputs that the guide on coverage shows. Each test
//// runs a real coverage run in a child VM, while no other snippet test
//// measures coverage.

import dream_test/file
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe}
import gleam/result
import snippets_child_vm.{it_runs_in_child_vm_with_coverage_lock}
import snippets_outputs

pub fn tests() -> TestSuite {
  describe("Guide: coverage", [
    it_runs_in_child_vm_with_coverage_lock(
      "the first coverage run prints the table",
      fn() {
        // Act
        let run =
          snippets_outputs.child_output_with_coverage(
            "snippets/coverage/guide_coverage_first",
            "main",
          )

        // Assert
        run
        |> should
        |> be_equal(expected(0, "guide_coverage_first", Ok("")))
        |> or_fail_with("expected test/outputs/guide_coverage_first.txt")
      },
    ),
    it_runs_in_child_vm_with_coverage_lock(
      "a total below the minimum fails the run",
      fn() {
        // Act
        let run =
          snippets_outputs.child_output_with_coverage(
            "snippets/coverage/guide_coverage_gate",
            "main",
          )

        // Assert
        run
        |> should
        |> be_equal(expected(
          1,
          "guide_coverage_gate",
          snippets_outputs.expected("guide_coverage_gate_error"),
        ))
        |> or_fail_with(
          "expected test/outputs/guide_coverage_gate.txt and guide_coverage_gate_error.txt",
        )
      },
    ),
    it_runs_in_child_vm_with_coverage_lock(
      "the exclusions make the run pass and write the JSON summary",
      fn() {
        // Act
        let run =
          snippets_outputs.child_output_with_coverage(
            "snippets/coverage/guide_coverage_excluded",
            "main",
          )
        let summary =
          file.read("build/coverage/guide_coverage.json")
          |> result.map_error(file.error_to_string)

        // Assert
        #(run, summary)
        |> should
        |> be_equal(#(
          expected(0, "guide_coverage_excluded", Ok("")),
          snippets_outputs.expected("guide_coverage_json"),
        ))
        |> or_fail_with(
          "expected test/outputs/guide_coverage_excluded.txt and guide_coverage_json.txt",
        )
      },
    ),
  ])
}

fn expected(
  status: Int,
  output_name: String,
  error_output: Result(String, String),
) -> Result(#(Int, String, String), String) {
  use output <- result.try(snippets_outputs.expected(output_name))
  use error_text <- result.map(error_output)
  #(status, output, error_text)
}
