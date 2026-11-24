import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process
import dream_test/types.{type AssertionResult}

pub fn two_increments_count_two() -> Result(AssertionResult, String) {
  let counter = process.start_counter()
  process.increment(counter)
  process.increment(counter)

  process.get_count(counter)
  |> should
  |> be_equal(2)
  |> or_fail_with("expected counter to be 2")
}
