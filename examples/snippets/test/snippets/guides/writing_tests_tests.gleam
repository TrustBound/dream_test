//// The tests of the outputs that the guide on organizing tests shows.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/guides/writing_tests_cart
import snippets/guides/writing_tests_filter_selection
import snippets_child_vm.{it_runs_in_child_vm}
import snippets_outputs

pub fn tests() -> TestSuite {
  describe("Guide: organizing tests", [
    it("the cart suite report shows groups, pending and skipped tests", fn() {
      // Act
      let report = snippets_outputs.bdd_report([writing_tests_cart.tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_writing_tests_cart"))
      |> or_fail_with("expected test/outputs/guide_writing_tests_cart.txt")
    }),
    it("the filter checks pass", fn() {
      // Act
      let report =
        snippets_outputs.bdd_report([writing_tests_filter_selection.tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_writing_tests_check"))
      |> or_fail_with("expected test/outputs/guide_writing_tests_check.txt")
    }),
    it_runs_in_child_vm("the smoke run prints one test", fn() {
      // Act
      let run =
        snippets_outputs.child_output(
          "snippets/guides/writing_tests_filter",
          "main",
        )

      // Assert
      run
      |> should
      |> be_equal(snippets_outputs.expected_run(0, "guide_writing_tests_smoke"))
      |> or_fail_with("expected test/outputs/guide_writing_tests_smoke.txt")
    }),
    it_runs_in_child_vm("a filter with a typo runs no test and fails", fn() {
      // Act
      let run =
        snippets_outputs.child_output(
          "snippets/guides/writing_tests_filter",
          "main_with_typo",
        )

      // Assert
      run
      |> should
      |> be_equal(snippets_outputs.expected_run(1, "guide_writing_tests_typo"))
      |> or_fail_with("expected test/outputs/guide_writing_tests_typo.txt")
    }),
    it_runs_in_child_vm("allow_no_tests lets a run with no test pass", fn() {
      // Act
      let run =
        snippets_outputs.child_output(
          "snippets/guides/writing_tests_filter",
          "main_allowing_no_tests",
        )

      // Assert
      run
      |> should
      |> be_equal(snippets_outputs.expected_run(
        0,
        "guide_writing_tests_no_tests_allowed",
      ))
      |> or_fail_with(
        "expected test/outputs/guide_writing_tests_no_tests_allowed.txt",
      )
    }),
  ])
}
