import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import snippets/doc/gherkin/types/data_table
import snippets/doc/gherkin/types/doc_string
import snippets/doc/gherkin/types/empty_background
import snippets/doc/gherkin/types/empty_examples
import snippets/doc/gherkin/types/examples
import snippets/doc/gherkin/types/examples_table
import snippets/doc/gherkin/types/feature
import snippets/doc/gherkin/types/keyword_from_string
import snippets/doc/gherkin/types/keyword_to_string
import snippets/doc/gherkin/types/phase_to_string
import snippets/doc/gherkin/types/resolve_phase
import snippets/doc/gherkin/types/rule
import snippets/doc/gherkin/types/scenario
import snippets/doc/gherkin/types/scenario_keyword
import snippets/doc/gherkin/types/scenario_keyword_to_string
import snippets/doc/gherkin/types/step

pub fn tests() {
  describe("Doc examples: gherkin/types", [
    it("given_reads_as_given passes", fn() {
      // Act
      let result = keyword_to_string.given_reads_as_given()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected given_reads_as_given to give the documented result",
      )
    }),
    it("and_after_given_is_a_given_step passes", fn() {
      // Act
      let result = resolve_phase.and_after_given_is_a_given_step()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected and_after_given_is_a_given_step to give the documented result",
      )
    }),
    it("doc_string_holds_json passes", fn() {
      // Act
      let result = doc_string.doc_string_holds_json()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected doc_string_holds_json to give the documented result",
      )
    }),
    it("data_table_holds_rows passes", fn() {
      // Act
      let result = data_table.data_table_holds_rows()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected data_table_holds_rows to give the documented result",
      )
    }),
    it("step_holds_its_text passes", fn() {
      // Act
      let result = step.step_holds_its_text()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected step_holds_its_text to give the documented result",
      )
    }),
    it("empty_background_has_no_steps passes", fn() {
      // Act
      let result = empty_background.empty_background_has_no_steps()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected empty_background_has_no_steps to give the documented result",
      )
    }),
    it("examples_table_holds_rows passes", fn() {
      // Act
      let result = examples_table.examples_table_holds_rows()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected examples_table_holds_rows to give the documented result",
      )
    }),
    it("examples_hold_a_table passes", fn() {
      // Act
      let result = examples.examples_hold_a_table()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected examples_hold_a_table to give the documented result",
      )
    }),
    it("scenario_outline_reads_as_scenario_outline passes", fn() {
      // Act
      let result = scenario_keyword.scenario_outline_reads_as_scenario_outline()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected scenario_outline_reads_as_scenario_outline to give the documented result",
      )
    }),
    it("scenario_holds_its_name passes", fn() {
      // Act
      let result = scenario.scenario_holds_its_name()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected scenario_holds_its_name to give the documented result",
      )
    }),
    it("rule_holds_its_name passes", fn() {
      // Act
      let result = rule.rule_holds_its_name()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected rule_holds_its_name to give the documented result",
      )
    }),
    it("feature_holds_its_name passes", fn() {
      // Act
      let result = feature.feature_holds_its_name()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected feature_holds_its_name to give the documented result",
      )
    }),
    it("example_reads_as_example passes", fn() {
      // Act
      let result = scenario_keyword_to_string.example_reads_as_example()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected example_reads_as_example to give the documented result",
      )
    }),
    it("then_text_reads_as_then passes", fn() {
      // Act
      let result = keyword_from_string.then_text_reads_as_then()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected then_text_reads_as_then to give the documented result",
      )
    }),
    it("when_phase_reads_as_when passes", fn() {
      // Act
      let result = phase_to_string.when_phase_reads_as_when()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected when_phase_reads_as_when to give the documented result",
      )
    }),
    it("empty_examples_have_no_rows passes", fn() {
      // Act
      let result = empty_examples.empty_examples_have_no_rows()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected empty_examples_have_no_rows to give the documented result",
      )
    }),
  ])
}
