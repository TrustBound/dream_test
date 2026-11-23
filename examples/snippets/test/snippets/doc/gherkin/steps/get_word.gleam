import dream_test/gherkin/steps.{type StepContext, get_word}

pub fn step_word(
  _value: String,
  context: StepContext,
) -> Result(String, String) {
  get_word(context.captures, 0)
}
