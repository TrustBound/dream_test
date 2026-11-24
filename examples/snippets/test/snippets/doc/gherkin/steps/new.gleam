import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, get_int, given, new, then,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import gleam/result

fn step_have_items(_count: Int, context: StepContext) -> Result(Int, String) {
  get_int(context.captures, 0)
}

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

pub fn item_steps() -> StepRegistry(Int) {
  new(initial: 0)
  |> given("I have {int} items", step_have_items)
  |> then("I should have {int} items", step_should_have)
}
