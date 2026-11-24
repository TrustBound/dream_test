import dream_test/gherkin/parser
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn file_error_names_the_path() -> Result(AssertionResult, String) {
  parser.feature_file_error_to_string(parser.InvalidFeatureFile(
    path: "test/cart.feature",
    error: parser.ParseError(line: 1, problem: parser.MissingFeature),
  ))
  |> should
  |> be_equal("test/cart.feature: line 1: No Feature found in content")
  |> or_fail_with("expected the rendered file error")
}
