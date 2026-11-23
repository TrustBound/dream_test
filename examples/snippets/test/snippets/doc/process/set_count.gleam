import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process
import dream_test/types.{type AssertionResult}

pub fn set_count_sets_forty_two() -> Result(AssertionResult, String) {
  let counter = process.start_counter()
  process.set_count(counter, 42)

  process.get_count(counter)
  |> should
  |> be_equal(42)
  |> or_fail_with("expected counter to be 42 after set_count")
}
