import dream_test/gherkin/types.{KeywordExample, scenario_keyword_to_string}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types

pub fn example_reads_as_example() -> Result(dream_types.AssertionResult, String) {
  scenario_keyword_to_string(KeywordExample)
  |> should
  |> be_equal("Example")
  |> or_fail_with("expected Example")
}
