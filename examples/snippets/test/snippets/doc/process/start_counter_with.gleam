import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process
import dream_test/types.{type AssertionResult}

pub fn decrement_from_ten_gives_nine() -> Result(AssertionResult, String) {
  let counter = process.start_counter_with(10)
  process.decrement(counter)

  process.get_count(counter)
  |> should
  |> be_equal(9)
  |> or_fail_with("expected counter to be 9 after decrement")
}
