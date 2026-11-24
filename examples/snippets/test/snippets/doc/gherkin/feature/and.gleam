import dream_test/gherkin/feature.{type InlineStep, and}

pub fn add_more_items_step() -> InlineStep {
  and("I add 3 items")
}
