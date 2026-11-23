import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, get_int, new, when,
}
import gleam/result

fn step_add(count: Int, context: StepContext) -> Result(Int, String) {
  use added <- result.try(get_int(context.captures, 0))
  Ok(count + added)
}

pub fn add_steps() -> StepRegistry(Int) {
  new(initial: 0) |> when("I add {int} items", step_add)
}
