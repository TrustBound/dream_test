import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process
import dream_test/types.{type AssertionResult}

pub fn port_holds_its_number() -> Result(AssertionResult, String) {
  process.Port(1234)
  |> should
  |> be_equal(process.Port(1234))
  |> or_fail_with("expected PortSelection to be constructible")
}
