import dream_test/gherkin/feature.{
  type InlineScenario, but, given, scenario, then, when,
}

pub fn adding_items_scenario() -> InlineScenario {
  scenario("Adding items to cart", [
    given("I have 3 items in my cart"),
    when("I add 2 more items"),
    then("I should have 5 items total"),
    but("I should have 5 items total"),
  ])
}
