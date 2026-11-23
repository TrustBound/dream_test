//// The tests of the compiler errors that the upgrade guide shows. Each
//// example is 2.x code under `compile_errors/`, which 3.0.0 does not
//// compile.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/result
import snippets/gherkin/gherkin_rule_names
import snippets/standards/compile_errors.{compile_example}
import snippets_outputs

pub fn tests() -> TestSuite {
  describe("Guide: upgrading to 3.0.0", [
    it("the name check passes", fn() {
      // Act
      let report = snippets_outputs.bdd_report([gherkin_rule_names.tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_upgrading_names"))
      |> or_fail_with("expected test/outputs/guide_upgrading_names.txt")
    }),
    it("the world module is unknown", fn() {
      // Act
      let output = compile_example("upgrade_world")

      // Assert
      output
      |> should
      |> be_equal(expected_error("guide_upgrading_world_error"))
      |> or_fail_with("expected test/outputs/guide_upgrading_world_error.txt")
    }),
    it("TestSuite has no type parameter", fn() {
      // Act
      let output = compile_example("upgrade_suite_type")

      // Assert
      output
      |> should
      |> be_equal(expected_error("guide_upgrading_suite_type_error"))
      |> or_fail_with(
        "expected test/outputs/guide_upgrading_suite_type_error.txt",
      )
    }),
  ])
}

/// The compiler ends with exit status 1 and the output in the file.
fn expected_error(name: String) -> Result(#(Int, String), String) {
  snippets_outputs.expected(name)
  |> result.map(with_exit_status_one)
}

fn with_exit_status_one(output: String) -> #(Int, String) {
  #(1, output)
}
