import dream_test/gherkin/types.{Given, keyword_to_string}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types

pub fn given_reads_as_given() -> Result(dream_types.AssertionResult, String) {
  keyword_to_string(Given)
  |> should
  |> be_equal("Given")
  |> or_fail_with("expected Given")
}
