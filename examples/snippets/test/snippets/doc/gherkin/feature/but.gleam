import dream_test/gherkin/feature.{type InlineStep, but}

pub fn total_step() -> InlineStep {
  but("I should have 5 items total")
}
