import dream_test/gherkin/steps.{type StepContext, get_float}

pub fn step_float(
  _value: Float,
  context: StepContext,
) -> Result(Float, String) {
  get_float(context.captures, 0)
}
