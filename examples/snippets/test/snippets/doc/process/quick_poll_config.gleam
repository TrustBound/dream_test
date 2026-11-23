import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process
import dream_test/types.{type AssertionResult}

pub fn quick_waits_one_second() -> Result(AssertionResult, String) {
  process.quick_poll_config()
  |> should
  |> be_equal(process.PollConfig(timeout_ms: 1000, interval_ms: 10))
  |> or_fail_with("expected quick_poll_config to be 1000ms/10ms")
}
