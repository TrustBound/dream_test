import dream_test/gherkin/types.{Feature, Given, KeywordScenario, Scenario, Step}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types
import gleam/option.{None}

pub fn feature_holds_its_name() -> Result(dream_types.AssertionResult, String) {
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

  let feature =
    Feature(
      name: "Example feature",
      source: None,
      description: None,
      tags: [],
      background: None,
      scenarios: [scenario],
      rules: [],
    )

  feature.name
  |> should
  |> be_equal("Example feature")
  |> or_fail_with("expected Feature to be constructible")
}
