//// The tests of `steps.to_suite` work next to an unqualified
//// `dream_test/types.Group`. `steps.Group` and `types.Group` have the same
//// name, so this module writes them qualified: `steps.Group(...)`.

import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, type StepRegistry}
import dream_test/gherkin/types as gherkin_types
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{
  type RunReport, type Status, type TestResult, Group, Passed,
}
import dream_test/unit.{describe, it}
import dream_test/unit_context
import gleam/list

pub fn tests() {
  describe("steps.SuiteTest next to dream_test/types.Group", [
    it("builds and runs a suite from every kind of test", fn() {
      steps.to_suite(registry: registry(), name: "Shop", tags: [], tests: [
        steps.Feature(shop_feature("Cart")),
        steps.Scenarios(shop_feature("Stock")),
        steps.Group(name: "Billing", tags: [], tests: [
          steps.Feature(shop_feature("Invoice")),
        ]),
        steps.Node(
          Group(name: "Plain", tags: [], tests: [
            unit_context.it("starts from 3", starts_from_3),
          ]),
        ),
      ])
      |> run
      |> statuses
      |> should
      |> be_equal([
        #(["Shop", "has 3 items"], Passed),
        #(["Shop", "Cart", "has 3 items"], Passed),
        #(["Shop", "Billing", "Invoice", "has 3 items"], Passed),
        #(["Shop", "Plain", "starts from 3"], Passed),
      ])
      |> or_fail_with("every test should run and pass")
    }),
  ])
}

fn registry() -> StepRegistry(Int) {
  steps.new(initial: 3)
  |> steps.then("the shop has {int} items", has_items)
}

fn shop_feature(name: String) -> gherkin_types.Feature {
  let assert Ok(parsed) =
    parser.parse_string(
      "Feature: "
      <> name
      <> "\nScenario: has 3 items\n  Then the shop has 3 items\n",
    )
  parsed
}

fn run(test_suite: TestSuite) -> RunReport {
  runner.new([test_suite])
  |> runner.max_concurrency(1)
  |> runner.silent()
  |> runner.run()
}

fn statuses(report: RunReport) -> List(#(List(String), Status)) {
  list.map(types.report_tests(report), name_and_status)
}

fn has_items(items: Int, context: StepContext) {
  case steps.get_int(context.captures, 0) {
    Ok(expected) ->
      items
      |> should
      |> be_equal(expected)
      |> or_fail_with("the shop should have the items")
    Error(message) -> Error(message)
  }
}

fn starts_from_3(items: Int) {
  items
  |> should
  |> be_equal(3)
  |> or_fail_with("the test should start from 3")
}

fn name_and_status(result: TestResult) -> #(List(String), Status) {
  #(types.full_name(result.groups, result.name), result.status)
}
