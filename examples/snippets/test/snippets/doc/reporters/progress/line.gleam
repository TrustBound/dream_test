import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/progress
import dream_test/types.{type AssertionResult}
import gleam/string

pub fn started_line_shows_an_empty_bar() -> Result(AssertionResult, String) {
  progress.line(progress.new(), progress.RunStartedProgress(total: 4))
  |> string.starts_with("\r0/4 [")
  |> should
  |> be_equal(True)
  |> or_fail_with("expected an empty bar for 4 tests")
}
