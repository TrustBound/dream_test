import dream_test/gherkin/types.{Given, Step}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types
import gleam/option.{None}

pub fn step_holds_its_text() -> Result(dream_types.AssertionResult, String) {
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
}
