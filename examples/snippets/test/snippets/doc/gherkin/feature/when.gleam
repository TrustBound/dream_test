import dream_test/gherkin/feature.{type InlineStep, when}

pub fn add_items_step() -> InlineStep {
  when("I add 3 items")
}
