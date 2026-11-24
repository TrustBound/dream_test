import dream_test/gherkin/parser
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn scenario_line_has_a_description() -> Result(AssertionResult, String) {
  parser.token_kind_to_string(parser.ScenarioLine)
  |> should
  |> be_equal("a Scenario line")
  |> or_fail_with("expected the Scenario line description")
}
