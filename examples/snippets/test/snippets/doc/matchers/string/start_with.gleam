import dream_test/matchers.{or_fail_with, should, start_with}
import dream_test/types.{type AssertionResult}

pub fn greeting_starts_with_hello() -> Result(AssertionResult, String) {
  "hello world"
  |> should
  |> start_with("hello")
  |> or_fail_with("expected string to start with \"hello\"")
}
