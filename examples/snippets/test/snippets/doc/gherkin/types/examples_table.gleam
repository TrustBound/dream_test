import dream_test/gherkin/types.{ExamplesTable}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types

pub fn examples_table_holds_rows() -> Result(
  dream_types.AssertionResult,
  String,
) {
  ExamplesTable(headers: ["quantity"], rows: [["1"], ["5"]])
  |> should
  |> be_equal(ExamplesTable(headers: ["quantity"], rows: [["1"], ["5"]]))
  |> or_fail_with("expected ExamplesTable to be constructible")
}
