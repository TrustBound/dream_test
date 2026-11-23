import dream_test/gherkin/feature.{
  type InlineScenario, given, scenario, then, when, with_tags,
}

pub fn smoke_scenario() -> InlineScenario {
  scenario("Adding items", [
    given("the cart is empty"),
    when("I add 3 items"),
    then("the cart should have 3 items"),
  ])
  |> with_tags(["smoke"])
}
