import dream_test/gherkin/parser
import dream_test/gherkin/types.{
  And, Examples, ExamplesTable, Feature, Given, GivenPhase,
  KeywordScenarioOutline, Scenario, Step, resolve_phase,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}
import gleam/result

pub fn tests() {
  describe("Gherkin syntax tree", [
    it("resolve_phase turns And into the phase of the step before it", fn() {
      resolve_phase(keyword: And, previous: Some(GivenPhase))
      |> should
      |> be_equal(Ok(GivenPhase))
      |> or_fail_with("expected And after Given to resolve to GivenPhase")
    }),
    it("Step can be constructed", fn() {
      Step(
        keyword: Given,
        text: "I have 1 item",
        doc_string: None,
        data_table: None,
        line: None,
      )
      |> should
      |> be_equal(Step(
        keyword: Given,
        text: "I have 1 item",
        doc_string: None,
        data_table: None,
        line: None,
      ))
      |> or_fail_with("expected Step to be constructible")
    }),
    it("Feature can be constructed", fn() {
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
          keyword: types.KeywordScenario,
          name: "Example scenario",
          description: None,
          tags: [],
          steps: [step],
          examples: [],
        )

      Feature(
        name: "Example feature",
        source: None,
        description: None,
        tags: [],
        background: None,
        scenarios: [scenario],
        rules: [],
      )
      |> should
      |> be_equal(
        Feature(
          name: "Example feature",
          source: None,
          description: None,
          tags: [],
          background: None,
          scenarios: [scenario],
          rules: [],
        ),
      )
      |> or_fail_with("expected Feature to be constructible")
    }),
    it("a Scenario Outline is a Scenario with Examples", fn() {
      let step =
        Step(
          keyword: Given,
          text: "I have <count> items",
          doc_string: None,
          data_table: None,
          line: None,
        )
      let examples =
        Examples(
          name: "",
          description: None,
          tags: [],
          table: Some(ExamplesTable(headers: ["count"], rows: [["1"], ["5"]])),
        )

      Scenario(
        keyword: KeywordScenarioOutline,
        name: "Example outline",
        description: None,
        tags: [],
        steps: [step],
        examples: [examples],
      )
      |> should
      |> be_equal(
        Scenario(
          keyword: KeywordScenarioOutline,
          name: "Example outline",
          description: None,
          tags: [],
          steps: [step],
          examples: [examples],
        ),
      )
      |> or_fail_with("expected a Scenario with Examples to be constructible")
    }),
    it("parse_string parses a minimal feature", fn() {
      let content =
        "@smoke\n"
        <> "Feature: Demo\n"
        <> "\n"
        <> "  Scenario: One\n"
        <> "    Given a thing\n"

      use feature <- result.try(
        parser.parse_string(content)
        |> result.map_error(parser.parse_error_to_string),
      )

      feature.name
      |> should
      |> be_equal("Demo")
      |> or_fail_with("expected feature name Demo")
    }),
    it("a parse error names its line", fn() {
      parser.parse_string("Feature: Demo\n  Scenario: One\n    And a thing\n")
      |> result.map(fn(feature) { feature.name })
      |> result.map_error(parser.parse_error_to_string)
      |> should
      |> be_equal(Error(
        "line 3: \"And a thing\" has no step before it. And, But and * take the phase of the step before them, so the first step of a Background, or of a Scenario with no Background steps, must use Given, When or Then.",
      ))
      |> or_fail_with("expected a parse error on line 3")
    }),
  ])
}
