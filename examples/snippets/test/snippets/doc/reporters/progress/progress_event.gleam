import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/progress
import dream_test/types.{type AssertionResult}
import gleam/string

pub fn finished_line_ends_the_bar() -> Result(AssertionResult, String) {
  progress.line(
    progress.new(),
    progress.RunFinishedProgress(
      completed: 4,
      total: 4,
      teardown_failed: 0,
      setup_stopped: 0,
    ),
  )
  |> string.ends_with("\n")
  |> should
  |> be_equal(True)
  |> or_fail_with("expected the last line to end the bar")
}
