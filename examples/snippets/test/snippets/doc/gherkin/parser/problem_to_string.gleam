import dream_test/gherkin/parser
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn repeated_doc_string_has_a_message() -> Result(AssertionResult, String) {
  parser.problem_to_string(parser.RepeatedDocString)
  |> should
  |> be_equal("Step cannot have more than one DocString")
  |> or_fail_with("expected the repeated DocString message")
}
