import dream_test/gherkin/steps.{
  type StepContext, capture_count, find_step, get_int, given, new,
}
import dream_test/gherkin/types.{GivenPhase}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types
import gleam/result

fn step_count(_count: Int, context: StepContext) -> Result(Int, String) {
  get_int(context.captures, 0)
}

pub fn item_count_step_has_one_capture() -> Result(
  dream_types.AssertionResult,
  String,
) {
  let registry = new(initial: 0) |> given("I have {int} items", step_count)

  use matched <- result.try(find_step(registry, GivenPhase, "I have 3 items"))

  capture_count(matched.captures)
  |> should
  |> be_equal(1)
  |> or_fail_with("expected exactly one capture")
}
