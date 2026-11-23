import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/timing
import dream_test/types.{type AssertionResult}

pub fn formats_half_a_millisecond() -> Result(AssertionResult, String) {
  timing.format_duration_us(500)
  |> should
  |> be_equal("0.5ms")
  |> or_fail_with("expected 0.5ms")
}
