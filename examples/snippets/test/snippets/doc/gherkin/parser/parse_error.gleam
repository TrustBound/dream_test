import dream_test/gherkin/parser
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn parse_error_names_its_line() -> Result(AssertionResult, String) {
  parser.parse_error_to_string(parser.ParseError(
    line: 3,
    problem: parser.RepeatedDocString,
  ))
  |> should
  |> be_equal("line 3: Step cannot have more than one DocString")
  |> or_fail_with("expected the rendered parse error")
}
