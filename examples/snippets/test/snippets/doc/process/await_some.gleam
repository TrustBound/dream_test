import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process
import dream_test/types.{type AssertionResult}

fn always_forty_two() -> Result(Int, Nil) {
  Ok(42)
}

pub fn ready_with_the_ok_value() -> Result(AssertionResult, String) {
  process.await_some(process.default_poll_config(), always_forty_two)
  |> should
  |> be_equal(process.Ready(42))
  |> or_fail_with("expected await_some to return Ready(42)")
}
