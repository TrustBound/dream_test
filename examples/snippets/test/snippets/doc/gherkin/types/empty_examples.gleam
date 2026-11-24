import dream_test/gherkin/types.{ExamplesTable, empty_examples}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types

pub fn empty_examples_have_no_rows() -> Result(
  dream_types.AssertionResult,
  String,
) {
  empty_examples()
  |> should
  |> be_equal(ExamplesTable(headers: [], rows: []))
  |> or_fail_with("expected empty examples table")
}
