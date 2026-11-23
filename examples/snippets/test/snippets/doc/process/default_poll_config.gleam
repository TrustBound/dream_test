import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process
import dream_test/types.{type AssertionResult}

pub fn default_waits_five_seconds() -> Result(AssertionResult, String) {
  process.default_poll_config()
  |> should
  |> be_equal(process.PollConfig(timeout_ms: 5000, interval_ms: 50))
  |> or_fail_with("expected default_poll_config to be 5000ms/50ms")
}
