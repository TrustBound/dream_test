import dream_test/matchers.{fail_with, succeed}
import dream_test/types.{type AssertionResult}

pub fn one_plus_one_is_two() -> Result(AssertionResult, String) {
  Ok(case 1 + 1 {
    2 -> succeed()
    _ -> fail_with("expected 1 + 1 to be 2")
  })
}
