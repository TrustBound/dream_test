import dream_test/gherkin/feature.{type InlineStep, InlineStep}
import dream_test/gherkin/types as gherkin_types

pub fn add_items_step() -> InlineStep {
  InlineStep(keyword: gherkin_types.When, text: "I add 3 items")
}
