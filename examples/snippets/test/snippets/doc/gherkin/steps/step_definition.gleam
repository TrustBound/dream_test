import dream_test/gherkin/steps.{
  type StepContext, Action, Check, find_step, get_int, then,
}
import dream_test/gherkin/types.{ThenPhase}
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should, succeed}
import dream_test/types as dream_types
import gleam/result

fn step_should_have(
  count: Int,
  context: StepContext,
) -> Result(dream_types.AssertionResult, String) {
  use expected <- result.try(get_int(context.captures, 0))
  count
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn then_definition_is_a_check() -> Result(
  dream_types.AssertionResult,
  String,
) {
  let registry =
    steps.new(initial: 0)
    |> then("I should have {int} items", step_should_have)

  use matched <- result.try(find_step(
    registry,
    ThenPhase,
    "I should have 3 items",
  ))

  case matched.handler {
    Action(_) -> Ok(fail_with("a Then definition is never an action"))
    Check(_) -> Ok(succeed())
  }
}
