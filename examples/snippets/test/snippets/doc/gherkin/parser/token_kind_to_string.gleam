import dream_test/gherkin/parser
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn end_of_file_has_a_description() -> Result(AssertionResult, String) {
  parser.token_kind_to_string(parser.EndOfFile)
  |> should
  |> be_equal("the end of the file")
  |> or_fail_with("expected the end of file description")
}
