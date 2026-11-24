import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn ok_holds_hello() -> Result(AssertionResult, String) {
  Ok("hello")
  |> should
  |> be_ok()
  |> be_equal("hello")
  |> or_fail_with("expected Ok(\"hello\")")
}
