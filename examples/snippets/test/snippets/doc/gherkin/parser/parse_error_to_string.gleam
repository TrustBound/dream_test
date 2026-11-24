import dream_test/gherkin/parser
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn missing_feature_error_names_line_one() -> Result(AssertionResult, String) {
  parser.parse_error_to_string(parser.ParseError(
    line: 1,
    problem: parser.MissingFeature,
  ))
  |> should
  |> be_equal("line 1: No Feature found in content")
  |> or_fail_with("expected the rendered parse error")
}
