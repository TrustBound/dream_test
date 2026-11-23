import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import snippets/doc/gherkin/parser/feature_file_error
import snippets/doc/gherkin/parser/feature_file_error_to_string
import snippets/doc/gherkin/parser/parse_error
import snippets/doc/gherkin/parser/parse_error_to_string
import snippets/doc/gherkin/parser/parse_file
import snippets/doc/gherkin/parser/parse_problem
import snippets/doc/gherkin/parser/parse_string
import snippets/doc/gherkin/parser/problem_to_string
import snippets/doc/gherkin/parser/token_kind
import snippets/doc/gherkin/parser/token_kind_to_string

pub fn tests() {
  describe("Doc examples: gherkin/parser", [
    it("scenario_line_has_a_description passes", fn() {
      // Act
      let result = token_kind.scenario_line_has_a_description()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected scenario_line_has_a_description to give the documented result",
      )
    }),
    it("and_without_a_previous_step_fails passes", fn() {
      // Act
      let result = parse_problem.and_without_a_previous_step_fails()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected and_without_a_previous_step_fails to give the documented result",
      )
    }),
    it("parse_error_names_its_line passes", fn() {
      // Act
      let result = parse_error.parse_error_names_its_line()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected parse_error_names_its_line to give the documented result",
      )
    }),
    it("missing_file_is_unreadable passes", fn() {
      // Act
      let result = feature_file_error.missing_file_is_unreadable()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected missing_file_is_unreadable to give the documented result",
      )
    }),
    it("minimal_feature_is_named_demo passes", fn() {
      // Act
      let result = parse_string.minimal_feature_is_named_demo()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected minimal_feature_is_named_demo to give the documented result",
      )
    }),
    it("end_of_file_has_a_description passes", fn() {
      // Act
      let result = token_kind_to_string.end_of_file_has_a_description()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected end_of_file_has_a_description to give the documented result",
      )
    }),
    it("repeated_doc_string_has_a_message passes", fn() {
      // Act
      let result = problem_to_string.repeated_doc_string_has_a_message()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected repeated_doc_string_has_a_message to give the documented result",
      )
    }),
    it("missing_feature_error_names_line_one passes", fn() {
      // Act
      let result = parse_error_to_string.missing_feature_error_names_line_one()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected missing_feature_error_names_line_one to give the documented result",
      )
    }),
    it("file_error_names_the_path passes", fn() {
      // Act
      let result = feature_file_error_to_string.file_error_names_the_path()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected file_error_names_the_path to give the documented result",
      )
    }),
    it("cart_feature is the Shopping Cart feature", fn() {
      // Act
      let result = parse_file.cart_feature().name

      // Assert
      result
      |> should
      |> be_equal("Shopping Cart")
      |> or_fail_with("expected cart_feature to give the documented result")
    }),
  ])
}
