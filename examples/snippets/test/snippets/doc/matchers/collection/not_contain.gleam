import dream_test/matchers.{not_contain, or_fail_with, should}
import dream_test/types.{type AssertionResult}

pub fn list_does_not_contain_d() -> Result(AssertionResult, String) {
  ["a", "b", "c"]
  |> should
  |> not_contain("d")
  |> or_fail_with("expected list to not contain \"d\"")
}
