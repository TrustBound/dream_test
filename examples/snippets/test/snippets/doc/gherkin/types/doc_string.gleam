import dream_test/gherkin/types.{DocString}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types
import gleam/option.{Some}

pub fn doc_string_holds_json() -> Result(dream_types.AssertionResult, String) {
  DocString(content: "{\"name\":\"example\"}", content_type: Some("json"))
  |> should
  |> be_equal(DocString(
    content: "{\"name\":\"example\"}",
    content_type: Some("json"),
  ))
  |> or_fail_with("expected DocString to be constructible")
}
