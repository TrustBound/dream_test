import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/timing
import dream_test/types.{type AssertionResult}

pub fn now_us_never_goes_back() -> Result(AssertionResult, String) {
  let first = timing.now_us()
  let second = timing.now_us()
  let is_monotonic = second >= first

  is_monotonic
  |> should
  |> be_equal(True)
  |> or_fail_with("expected now_us to be monotonic")
}
