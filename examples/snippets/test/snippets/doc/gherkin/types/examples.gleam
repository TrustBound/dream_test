import dream_test/gherkin/types.{Examples, ExamplesTable}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types
import gleam/option.{None, Some}

pub fn examples_hold_a_table() -> Result(dream_types.AssertionResult, String) {
  let table = ExamplesTable(headers: ["quantity"], rows: [["1"]])

  Examples(name: "Small", description: None, tags: ["fast"], table: Some(table))
  |> should
  |> be_equal(Examples(
    name: "Small",
    description: None,
    tags: ["fast"],
    table: Some(table),
  ))
  |> or_fail_with("expected Examples to be constructible")
}
