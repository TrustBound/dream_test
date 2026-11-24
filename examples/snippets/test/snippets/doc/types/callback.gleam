import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

fn setup() -> Result(Nil, String) {
  Ok(Nil)
}

pub fn no_input_ignores_the_input() -> Result(AssertionResult, String) {
  types.call(types.NoInput(setup), Nil)
  |> should
  |> be_equal(Ok(Nil))
  |> or_fail_with("a NoInput callback should ignore the input")
}
