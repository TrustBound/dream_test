import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process
import dream_test/types.{type AssertionResult}

fn always_true() -> Bool {
  True
}

pub fn ready_when_check_is_true() -> Result(AssertionResult, String) {
  process.await_ready(process.quick_poll_config(), always_true)
  |> should
  |> be_equal(process.Ready(True))
  |> or_fail_with("expected await_ready to return Ready(True)")
}
