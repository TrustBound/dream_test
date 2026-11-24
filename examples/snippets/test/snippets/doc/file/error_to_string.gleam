import dream_test/file.{NotFound, error_to_string}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn not_found_names_the_path() -> Result(AssertionResult, String) {
  error_to_string(NotFound("/x"))
  |> should
  |> be_equal("File not found: /x")
  |> or_fail_with("expected NotFound formatting")
}
