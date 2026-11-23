import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, get_int, given, new,
}

fn step_count(_count: Int, context: StepContext) -> Result(Int, String) {
  get_int(context.captures, 0)
}

pub fn count_steps() -> StepRegistry(Int) {
  new(initial: 0) |> given("I have {int} items", step_count)
}
