import dream_test/gherkin/steps.{type StepContext, get_int}

pub fn step_int(_value: Int, context: StepContext) -> Result(Int, String) {
  get_int(context.captures, 0)
}
