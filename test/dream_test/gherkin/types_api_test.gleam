import dream_test/gherkin/types
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as test_types
import dream_test/unit.{describe, it}
import gleam/list
import gleam/option.{None, Some}

pub fn tests() {
  describe("dream_test/gherkin/types", [
    it("keyword_to_string / keyword_from_string work", fn() {
      types.Given
      |> types.keyword_to_string()
      |> should
      |> be_equal("Given")
      |> or_fail_with("keyword_to_string(Given) should be Given")
    }),

    it("scenario_keyword_to_string gives the text of every keyword", fn() {
      [
        types.KeywordScenario,
        types.KeywordExample,
        types.KeywordScenarioOutline,
        types.KeywordScenarioTemplate,
      ]
      |> list.map(types.scenario_keyword_to_string)
      |> should
      |> be_equal([
        "Scenario",
        "Example",
        "Scenario Outline",
        "Scenario Template",
      ])
      |> or_fail_with("expected the keyword texts")
    }),

    it("keyword_from_string returns None for unknown keywords", fn() {
      types.keyword_from_string("Nope")
      |> should
      |> be_equal(None)
      |> or_fail_with("keyword_from_string(unknown) should be None")
    }),

    it("resolve_keyword resolves And/But and leaves other keywords alone", fn() {
      types.resolve_keyword(types.And, types.Given)
      |> should
      |> be_equal(types.Given)
      |> or_fail_with("And after Given should resolve to Given")
    }),

    it("resolve_keyword resolves But based on previous keyword", fn() {
      types.resolve_keyword(types.But, types.Then)
      |> should
      |> be_equal(types.Then)
      |> or_fail_with("But after Then should resolve to Then")
    }),

    it("resolve_keyword leaves non-And/But keywords unchanged", fn() {
      types.resolve_keyword(types.When, types.Given)
      |> should
      |> be_equal(types.When)
      |> or_fail_with("When should remain When")
    }),

    it("empty_examples produces an empty table", fn() {
      types.empty_examples()
      |> should
      |> be_equal(types.ExamplesTable(headers: [], rows: []))
      |> or_fail_with("empty_examples should be empty")
    }),

    it("empty_background produces an empty background", fn() {
      types.empty_background()
      |> should
      |> be_equal(types.Background(name: "", description: None, steps: []))
      |> or_fail_with("empty_background should be empty")
    }),

    it("Step constructor with labeled args can be created", fn() {
      let _ = types.Step(keyword: types.Given, text: "a step", argument: None)
      Ok(test_types.AssertionOk)
    }),

    it("keyword_to_string names every keyword", fn() {
      [
        types.Given,
        types.When,
        types.Then,
        types.And,
        types.But,
        types.Asterisk,
      ]
      |> list.map(types.keyword_to_string)
      |> should
      |> be_equal(["Given", "When", "Then", "And", "But", "*"])
      |> or_fail_with("each keyword should have its name")
    }),

    it("keyword_from_string reads every keyword", fn() {
      ["Given", "When", "Then", "And", "But", "*"]
      |> list.map(types.keyword_from_string)
      |> should
      |> be_equal([
        Some(types.Given),
        Some(types.When),
        Some(types.Then),
        Some(types.And),
        Some(types.But),
        Some(types.Asterisk),
      ])
      |> or_fail_with("each name should give its keyword")
    }),

    it("resolve_keyword resolves * based on previous keyword", fn() {
      types.resolve_keyword(types.Asterisk, types.When)
      |> should
      |> be_equal(types.When)
      |> or_fail_with("* after When should resolve to When")
    }),

    it("resolve_phase gives Given, When and Then their own phase", fn() {
      [types.Given, types.When, types.Then]
      |> list.map(resolve_phase_after_then)
      |> should
      |> be_equal([
        Ok(types.GivenPhase),
        Ok(types.WhenPhase),
        Ok(types.ThenPhase),
      ])
      |> or_fail_with("each primary keyword should give its own phase")
    }),

    it("resolve_phase gives And, But and * the previous phase", fn() {
      [types.And, types.But, types.Asterisk]
      |> list.map(resolve_phase_after_then)
      |> should
      |> be_equal([
        Ok(types.ThenPhase),
        Ok(types.ThenPhase),
        Ok(types.ThenPhase),
      ])
      |> or_fail_with("each conjunction should take the previous phase")
    }),

    it(
      "resolve_phase gives Given, When and Then a phase with no previous",
      fn() {
        [types.Given, types.When, types.Then]
        |> list.map(resolve_phase_first)
        |> should
        |> be_equal([
          Ok(types.GivenPhase),
          Ok(types.WhenPhase),
          Ok(types.ThenPhase),
        ])
        |> or_fail_with("a primary keyword needs no previous phase")
      },
    ),

    it("resolve_phase gives And, But and * no phase with no previous", fn() {
      [types.And, types.But, types.Asterisk]
      |> list.map(resolve_phase_first)
      |> should
      |> be_equal([Error(Nil), Error(Nil), Error(Nil)])
      |> or_fail_with("a conjunction with no previous step has no phase")
    }),

    it("phase_to_string names every phase", fn() {
      [types.GivenPhase, types.WhenPhase, types.ThenPhase]
      |> list.map(types.phase_to_string)
      |> should
      |> be_equal(["Given", "When", "Then"])
      |> or_fail_with("each phase should have the name of its keyword")
    }),
  ])
}

fn resolve_phase_after_then(
  keyword: types.StepKeyword,
) -> Result(types.StepPhase, Nil) {
  types.resolve_phase(keyword, Some(types.ThenPhase))
}

fn resolve_phase_first(
  keyword: types.StepKeyword,
) -> Result(types.StepPhase, Nil) {
  types.resolve_phase(keyword, None)
}
