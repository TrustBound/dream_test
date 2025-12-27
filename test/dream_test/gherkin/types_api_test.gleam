import dream_test/gherkin/types
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as test_types
import dream_test/unit.{describe, it}
import gleam/option.{None}

pub fn tests() {
  describe("dream_test/gherkin/types", [
    it("keyword_to_string / keyword_from_string work", fn() {
      types.Given
      |> types.keyword_to_string()
      |> should
      |> be_equal("Given")
      |> or_fail_with("keyword_to_string(Given) should be Given")
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
      |> be_equal(types.Background(steps: []))
      |> or_fail_with("empty_background should be empty")
    }),

    it("Step constructor with labeled args can be created", fn() {
      let _ = types.Step(keyword: types.Given, text: "a step", argument: None)
      Ok(test_types.AssertionOk)
    }),
  ])
}
