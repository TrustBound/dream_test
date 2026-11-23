import dream_test/gherkin/steps.{type StepContext, get_string}

pub fn step_string(
  _value: String,
  context: StepContext,
) -> Result(String, String) {
  get_string(context.captures, 0)
}
