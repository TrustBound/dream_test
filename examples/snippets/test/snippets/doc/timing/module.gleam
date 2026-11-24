import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/timing
import dream_test/types.{type AssertionResult}

pub fn formats_one_and_a_half_seconds() -> Result(AssertionResult, String) {
  timing.format_duration_ms(1500)
  |> should
  |> be_equal("1.5s")
  |> or_fail_with("expected 1.5s")
}
