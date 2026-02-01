import dream_test/gherkin/types.{
  And, Background, DataTable, DocString, ExamplesTable, Feature, Given, Scenario,
  ScenarioOutline, Step, Then, empty_background, empty_examples,
  keyword_from_string, keyword_to_string, resolve_keyword,
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
      |> be_equal(Background(steps: []))
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

      Scenario(name: "Example scenario", tags: [], steps: [step])
      |> should
      |> be_equal(Scenario(name: "Example scenario", tags: [], steps: [step]))
      |> or_fail_with("expected Scenario to be constructible")
    }),
    it("Feature can be constructed", fn() {
      let step = Step(keyword: Given, text: "I have 1 item", argument: None)
      let scenario = Scenario(name: "Example scenario", tags: [], steps: [step])

      Feature(
        name: "Example feature",
        source: None,
        description: None,
        tags: [],
        background: None,
        scenarios: [scenario],
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
        ),
      )
      |> or_fail_with("expected Feature to be constructible")
    }),
    it("ScenarioOutline can be constructed", fn() {
      let step =
        Step(keyword: Given, text: "I have <count> items", argument: None)

      ScenarioOutline(
        name: "Example outline",
        tags: [],
        steps: [step],
        examples: ExamplesTable(headers: ["count"], rows: [["1"], ["5"]]),
      )
      |> should
      |> be_equal(ScenarioOutline(
        name: "Example outline",
        tags: [],
        steps: [step],
        examples: ExamplesTable(headers: ["count"], rows: [["1"], ["5"]]),
      ))
      |> or_fail_with("expected ScenarioOutline to be constructible")
    }),
  ])
}
