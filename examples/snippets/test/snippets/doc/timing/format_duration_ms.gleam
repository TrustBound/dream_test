import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/timing
import dream_test/types.{type AssertionResult}

pub fn formats_forty_two_milliseconds() -> Result(AssertionResult, String) {
  // Arrange & Act
  let formatted = timing.format_duration_ms(42)

  // Assert
  formatted
  |> should
  |> be_equal("42ms")
  |> or_fail_with("expected 42ms")
}
