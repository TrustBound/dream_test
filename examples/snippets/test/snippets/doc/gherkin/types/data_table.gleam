import dream_test/gherkin/types.{DataTable}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types

pub fn data_table_holds_rows() -> Result(dream_types.AssertionResult, String) {
  DataTable(rows: [["name", "email"], ["Alice", "alice@test.com"]])
  |> should
  |> be_equal(DataTable(rows: [["name", "email"], ["Alice", "alice@test.com"]]))
  |> or_fail_with("expected DataTable to be constructible")
}
