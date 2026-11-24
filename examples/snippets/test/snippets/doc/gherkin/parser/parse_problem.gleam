import dream_test/gherkin/parser
import dream_test/gherkin/types as gherkin_types
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn and_without_a_previous_step_fails() -> Result(AssertionResult, String) {
  parser.parse_string("Feature: F\n  Scenario: S\n    And a step\n")
  |> should
  |> be_equal(
    Error(parser.ParseError(
      line: 3,
      problem: parser.MissingPreviousStep(
        keyword: gherkin_types.And,
        text: "a step",
      ),
    )),
  )
  |> or_fail_with("expected a missing previous step error")
}
