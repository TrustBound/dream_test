import dream_test/gherkin/steps.{type StepContext, get_int, given, new, validate}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}

fn step_count(_count: Int, context: StepContext) -> Result(Int, String) {
  get_int(context.captures, 0)
}

pub fn duplicate_pattern_is_an_error() -> Result(AssertionResult, String) {
  new(initial: 0)
  |> given("I have {int} items", step_count)
  |> given("I have {int} items", step_count)
  |> validate
  |> should
  |> be_equal(Error(
    "Duplicate step definition: Given \"I have {int} items\" is already defined. Each pattern can have one definition for each of Given, When and Then.",
  ))
  |> or_fail_with("expected a duplicate step definition error")
}
