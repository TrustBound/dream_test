import dream_test/matchers.{contain_string, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn greeting_contains_world() -> Result(AssertionResult, String) {
  "hello world"
  |> should
  |> contain_string("world")
  |> or_fail_with("expected substring match")
}
