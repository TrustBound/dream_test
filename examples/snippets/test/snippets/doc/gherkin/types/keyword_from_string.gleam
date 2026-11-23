import dream_test/gherkin/types.{Then, keyword_from_string}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types
import gleam/option.{Some}

pub fn then_text_reads_as_then() -> Result(dream_types.AssertionResult, String) {
  keyword_from_string("Then")
  |> should
  |> be_equal(Some(Then))
  |> or_fail_with("expected Some(Then)")
}
