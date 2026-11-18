import dream_test/gherkin/types.{
  And, Asterisk, Background, DataTable, DocString, Examples, ExamplesTable,
  Feature, Given, GivenPhase, KeywordScenario, KeywordScenarioOutline,
  KeywordScenarioTemplate, Rule, Scenario, Step, Then, WhenPhase,
  empty_background, empty_examples, keyword_from_string, keyword_to_string,
  phase_to_string, resolve_keyword, resolve_phase, scenario_keyword_to_string,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}

pub fn tests() {
  describe("Gherkin types", [
    it("keyword_to_string renders keywords", fn() {
      keyword_to_string(Given)
      |> should
      |> be_equal("Given")
      |> or_fail_with("expected Given")
    }),
    it("keyword_from_string parses known keywords", fn() {
      keyword_from_string("Then")
      |> should
      |> be_equal(Some(Then))
      |> or_fail_with("expected Some(Then)")
    }),
    it("resolve_keyword turns And/But into the previous keyword", fn() {
      resolve_keyword(And, Given)
      |> should
      |> be_equal(Given)
      |> or_fail_with("expected And after Given to resolve to Given")
    }),
    it("resolve_phase gives And the phase of the step before it", fn() {
      resolve_phase(keyword: And, previous: Some(GivenPhase))
      |> should
      |> be_equal(Ok(GivenPhase))
      |> or_fail_with("expected And after Given to be a Given step")
    }),
    it("resolve_phase gives no phase to a * step with no step before it", fn() {
      resolve_phase(keyword: Asterisk, previous: None)
      |> should
      |> be_equal(Error(Nil))
      |> or_fail_with("expected a leading * step to have no phase")
    }),
    it("phase_to_string names the phase", fn() {
      phase_to_string(WhenPhase)
      |> should
      |> be_equal("When")
      |> or_fail_with("expected When")
    }),
    it("Step can be constructed", fn() {
      Step(keyword: Given, text: "I have 1 item", argument: None)
      |> should
      |> be_equal(Step(keyword: Given, text: "I have 1 item", argument: None))
      |> or_fail_with("expected Step to be constructible")
    }),
    it("DocString can be constructed", fn() {
      DocString(content: "{\"name\":\"example\"}", content_type: Some("json"))
      |> should
      |> be_equal(DocString(
        content: "{\"name\":\"example\"}",
        content_type: Some("json"),
      ))
      |> or_fail_with("expected DocString to be constructible")
    }),
    it("DataTable can be constructed", fn() {
      DataTable(rows: [["name", "email"], ["Alice", "alice@test.com"]])
      |> should
      |> be_equal(
        DataTable(rows: [["name", "email"], ["Alice", "alice@test.com"]]),
      )
      |> or_fail_with("expected DataTable to be constructible")
    }),
    it("empty_examples returns a table with no headers/rows", fn() {
      empty_examples()
      |> should
      |> be_equal(ExamplesTable(headers: [], rows: []))
      |> or_fail_with("expected empty examples table")
    }),
    it("empty_background returns a background with no steps", fn() {
      empty_background()
      |> should
      |> be_equal(Background(name: "", description: None, steps: []))
      |> or_fail_with("expected empty background")
    }),
    it("ExamplesTable can be constructed", fn() {
      ExamplesTable(headers: ["quantity"], rows: [["1"], ["5"]])
      |> should
      |> be_equal(ExamplesTable(headers: ["quantity"], rows: [["1"], ["5"]]))
      |> or_fail_with("expected ExamplesTable to be constructible")
    }),
    it("Scenario can be constructed", fn() {
      let step = Step(keyword: Given, text: "I have 1 item", argument: None)
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
    }),
    it("Feature can be constructed", fn() {
      let feature =
        Feature(
          name: "Example feature",
          source: None,
          description: None,
          tags: [],
          background: None,
          scenarios: [],
          rules: [
            Rule(
              name: "Stock",
              description: None,
              tags: [],
              background: None,
              scenarios: [],
            ),
          ],
        )

      feature.rules
      |> should
      |> be_equal([
        Rule(
          name: "Stock",
          description: None,
          tags: [],
          background: None,
          scenarios: [],
        ),
      ])
      |> or_fail_with("expected Feature to be constructible")
    }),
    it("a scenario outline holds its Examples sections", fn() {
      let step =
        Step(keyword: Given, text: "I have <count> items", argument: None)
      let small =
        Examples(
          name: "Small",
          description: None,
          tags: ["fast"],
          table: Some(ExamplesTable(headers: ["count"], rows: [["1"], ["5"]])),
        )
      let outline =
        Scenario(
          keyword: KeywordScenarioOutline,
          name: "Example outline",
          description: None,
          tags: [],
          steps: [step],
          examples: [small],
        )

      outline.examples
      |> should
      |> be_equal([small])
      |> or_fail_with("expected the Examples section")
    }),
    it("scenario_keyword_to_string gives the keyword text", fn() {
      scenario_keyword_to_string(KeywordScenarioTemplate)
      |> should
      |> be_equal("Scenario Template")
      |> or_fail_with("expected Scenario Template")
    }),
  ])
}
