import dream_test/matchers.{be_between, or_fail_with, should}
import dream_test/process
import dream_test/types.{type AssertionResult}

pub fn unique_port_is_in_the_safe_range() -> Result(AssertionResult, String) {
  process.unique_port()
  |> should
  |> be_between(10_000, 60_000)
  |> or_fail_with("expected unique_port to be within 10k..60k")
}
