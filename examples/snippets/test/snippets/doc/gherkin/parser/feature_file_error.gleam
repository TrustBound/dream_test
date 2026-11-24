import dream_test/file
import dream_test/gherkin/parser
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn missing_file_is_unreadable() -> Result(AssertionResult, String) {
  parser.parse_file("test/missing.feature")
  |> should
  |> be_equal(
    Error(
      parser.UnreadableFeatureFile(error: file.NotFound("test/missing.feature")),
    ),
  )
  |> or_fail_with("expected an unreadable file error")
}
