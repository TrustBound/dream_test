import dream_test/gherkin/feature.{type InlineStep, then}

pub fn cart_count_step() -> InlineStep {
  then("the cart should have 3 items")
}
