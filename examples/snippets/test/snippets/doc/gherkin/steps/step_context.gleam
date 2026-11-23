import dream_test/gherkin/steps.{type StepContext}

pub type Order {
  Order(name: String)
}

pub fn step_order_name(
  _order: Order,
  context: StepContext,
) -> Result(Order, String) {
  Ok(Order(name: context.scenario_id))
}
