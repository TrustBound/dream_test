import dream_test/gherkin/types.{Given, KeywordScenario, Scenario, Step}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types
import gleam/option.{None}

pub fn scenario_holds_its_name() -> Result(dream_types.AssertionResult, String) {
  let step =
    Step(
      keyword: Given,
      text: "I have 1 item",
      doc_string: None,
      data_table: None,
      line: None,
    )
  let scenario =
    Scenario(
      keyword: KeywordScenario,
      name: "Example scenario",
      description: None,
      tags: [],
      steps: [step],
      examples: [],
    )

  scenario.name
  |> should
  |> be_equal("Example scenario")
  |> or_fail_with("expected Scenario to be constructible")
}
