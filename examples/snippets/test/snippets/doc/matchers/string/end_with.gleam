import dream_test/matchers.{end_with, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn file_name_ends_with_gleam() -> Result(AssertionResult, String) {
  "hello.gleam"
  |> should
  |> end_with(".gleam")
  |> or_fail_with("expected .gleam suffix")
}
