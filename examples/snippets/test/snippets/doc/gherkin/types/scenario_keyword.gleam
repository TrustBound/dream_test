import dream_test/gherkin/types.{
  KeywordScenarioOutline, scenario_keyword_to_string,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types

pub fn scenario_outline_reads_as_scenario_outline() -> Result(
  dream_types.AssertionResult,
  String,
) {
  scenario_keyword_to_string(KeywordScenarioOutline)
  |> should
  |> be_equal("Scenario Outline")
  |> or_fail_with("expected Scenario Outline")
}
