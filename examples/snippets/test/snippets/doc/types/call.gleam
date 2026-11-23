import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

fn double(number: Int) -> Int {
  number * 2
}

pub fn with_input_gets_the_input() -> Result(AssertionResult, String) {
  types.call(types.WithInput(double), 21)
  |> should
  |> be_equal(42)
  |> or_fail_with("a WithInput callback should get the input")
}
