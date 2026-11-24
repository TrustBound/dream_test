import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, get_int, new, then,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import gleam/result

fn step_should_have(
  count: Int,
  context: StepContext,
) -> Result(AssertionResult, String) {
  use expected <- result.try(get_int(context.captures, 0))
  count
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn count_check_steps() -> StepRegistry(Int) {
  new(initial: 0)
  |> then("I should have {int} items", step_should_have)
}
