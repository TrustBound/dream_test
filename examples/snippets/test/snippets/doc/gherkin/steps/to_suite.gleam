import dream_test/gherkin/steps.{
  type StepRegistry, Feature, Group, Node, to_suite,
}
import dream_test/gherkin/types as gherkin_types
import dream_test/matchers.{succeed}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import dream_test/unit_context

fn answers(_count: Int) -> Result(AssertionResult, String) {
  Ok(succeed())
}

pub fn shop_suite(
  steps steps: StepRegistry(Int),
  cart cart: gherkin_types.Feature,
  invoice invoice: gherkin_types.Feature,
) -> TestSuite {
  to_suite(registry: steps, name: "Shop", tags: [], children: [
    Feature(cart),
    Group(name: "Billing", tags: ["billing"], children: [
      Feature(invoice),
    ]),
    Node(unit_context.it("the server answers", answers)),
  ])
}
