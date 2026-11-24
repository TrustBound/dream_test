//// The tests of the outputs that the guide on shared contexts shows.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/guides/context_store
import snippets/guides/context_store_down
import snippets/guides/context_store_setup_tests
import snippets/hooks/context_aware_tests
import snippets_outputs

pub fn tests() -> TestSuite {
  describe("Guide: shared contexts", [
    it("the counter suite passes", fn() {
      // Act
      let report = snippets_outputs.bdd_report([context_aware_tests.tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_context_counter"))
      |> or_fail_with("expected test/outputs/guide_context_counter.txt")
    }),
    it("the user store suite passes", fn() {
      // Act
      let report = snippets_outputs.bdd_report([context_store.tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_context_store"))
      |> or_fail_with("expected test/outputs/guide_context_store.txt")
    }),
    it("a failing context setup gives SetupFailed", fn() {
      // Act
      let report =
        snippets_outputs.bdd_report([context_store_down.store_down_tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_context_store_down"))
      |> or_fail_with("expected test/outputs/guide_context_store_down.txt")
    }),
    it("the setup checks pass", fn() {
      // Act
      let report =
        snippets_outputs.bdd_report([context_store_setup_tests.tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_context_checks"))
      |> or_fail_with("expected test/outputs/guide_context_checks.txt")
    }),
  ])
}
