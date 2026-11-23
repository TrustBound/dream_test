import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/progress
import dream_test/types.{type AssertionResult}

pub fn started_render_is_an_empty_bar() -> Result(AssertionResult, String) {
  progress.render(30, progress.RunStartedProgress(total: 10))
  |> should
  |> be_equal("0/10 [░░░░░░░░░░░░░░░░░░░] 0% ")
  |> or_fail_with("expected an empty bar for 10 tests")
}
