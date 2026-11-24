//// The BDD reporter and the Gherkin reporter put the `Feature:` heading on
//// the same group: the group of the Feature that a scenario came from.

import dream_test/file
import dream_test/gherkin/discover
import dream_test/gherkin/feature
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, Feature, Group, Scenarios,
}
import dream_test/gherkin/types as gherkin_types
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/gherkin
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, group, it}
import gleam/list
import gleam/option.{None}

pub fn tests() {
  describe("Feature headings", [
    group("a feature suite inside suite.group", [
      it("bdd labels the Feature group", fn() {
        bdd_text(outer_group_suite())
        |> should
        |> be_equal(
          "Outer
  Feature: Cart
    ✓ Scenario: has 3 items
    Rule: Discounts
      ✓ Scenario: still 3 items

Summary: 2 run, 0 failed, 2 passed in 0ms
",
        )
        |> or_fail_with("Cart should be the Feature, not Outer")
      }),
      it("gherkin labels the Feature group", fn() {
        gherkin_text(outer_group_suite())
        |> should
        |> be_equal(
          "Feature: Cart
  Scenario: has 3 items ✓
  Rule: Discounts
    Scenario: still 3 items ✓
",
        )
        |> or_fail_with("Cart should be the Feature")
      }),
    ]),
    group("steps.feature_suite", [
      it("bdd labels the top-level group as the Feature", fn() {
        bdd_text(steps.feature_suite(
          registry: registry(),
          feature: cart_feature(),
        ))
        |> should
        |> be_equal(
          "Feature: Cart
  ✓ Scenario: has 3 items
  Rule: Discounts
    ✓ Scenario: still 3 items

Summary: 2 run, 0 failed, 2 passed in 0ms
",
        )
        |> or_fail_with("the top-level group should be Feature: Cart")
      }),
      it("gherkin labels the top-level group as the Feature", fn() {
        gherkin_text(steps.feature_suite(
          registry: registry(),
          feature: cart_feature(),
        ))
        |> should
        |> be_equal(
          "Feature: Cart
  Scenario: has 3 items ✓
  Rule: Discounts
    Scenario: still 3 items ✓
",
        )
        |> or_fail_with("the top-level group should be Feature: Cart")
      }),
    ]),
    group("an inline feature.feature", [
      it("bdd labels the top-level group as the Feature", fn() {
        bdd_text(inline_suite())
        |> should
        |> be_equal(
          "Feature: Cart
  ✓ Scenario: has 3 items

Summary: 1 run, 0 failed, 1 passed in 0ms
",
        )
        |> or_fail_with("the inline feature should be Feature: Cart")
      }),
      it("gherkin labels the top-level group as the Feature", fn() {
        gherkin_text(inline_suite())
        |> should
        |> be_equal("Feature: Cart\n  Scenario: has 3 items ✓\n")
        |> or_fail_with("the inline feature should be Feature: Cart")
      }),
    ]),
    group("features from gherkin/discover", [
      it("bdd labels each Feature group", fn() {
        bdd_text(discovered_suite())
        |> should
        |> be_equal(
          "my_tests
  Feature: Alpha
    ✓ Scenario: one
  Feature: Beta
    ✓ Scenario: one

Summary: 2 run, 0 failed, 2 passed in 0ms
",
        )
        |> or_fail_with("Alpha and Beta should be the Features")
      }),
      it("gherkin labels each Feature group", fn() {
        gherkin_text(discovered_suite())
        |> should
        |> be_equal(
          "Feature: Alpha
  Scenario: one ✓
Feature: Beta
  Scenario: one ✓
",
        )
        |> or_fail_with("Alpha and Beta should be the Features")
      }),
    ]),
    group("scenarios in a group beside a Feature", [
      it("bdd labels only the Feature group", fn() {
        bdd_text(shop_suite())
        |> should
        |> be_equal(
          "Shop
  Billing
    ✓ Scenario: has 3 items
    Rule: Discounts
      ✓ Scenario: still 3 items
  Feature: Cart
    ✓ Scenario: has 3 items
    Rule: Discounts
      ✓ Scenario: still 3 items

Summary: 4 run, 0 failed, 4 passed in 0ms
",
        )
        |> or_fail_with("Billing is no Feature, Cart is")
      }),
      it("gherkin labels only the Feature group", fn() {
        gherkin_text(shop_suite())
        |> should
        |> be_equal(
          "Shop > Billing
  Scenario: has 3 items ✓
  Rule: Discounts
    Scenario: still 3 items ✓
Feature: Cart
  Scenario: has 3 items ✓
  Rule: Discounts
    Scenario: still 3 items ✓
",
        )
        |> or_fail_with("Billing is no Feature, Cart is")
      }),
    ]),
    group("a scenario built with feature: None", [
      it("bdd labels no group", fn() {
        bdd.render(
          config: reporter_types.BddReporterConfig(
            color: False,
            mode: reporter_types.BddFull,
          ),
          report: report_of_scenario_without_feature(),
        )
        |> should
        |> be_equal(
          "Shop
  Billing
    ✓ Scenario: pays

Summary: 1 run, 0 failed, 1 passed in 0ms
",
        )
        |> or_fail_with("a scenario in no Feature should have no Feature")
      }),
      it("gherkin writes the groups as the heading", fn() {
        gherkin.format_scenarios(
          types.report_tests(report_of_scenario_without_feature()),
        )
        |> should
        |> be_equal("Shop > Billing\n  Scenario: pays ✓\n")
        |> or_fail_with("a scenario in no Feature should have no Feature")
      }),
    ]),
  ])
}

fn report_of_scenario_without_feature() -> RunReport {
  types.run_report(
    tests: [
      types.TestResult(
        name: "pays",
        groups: ["Shop", "Billing"],
        status: types.Passed,
        duration_ms: 0,
        tags: [],
        failures: [],
        kind: types.GherkinScenario(
          scenario_id: "pays#1",
          feature: None,
          rule: None,
        ),
      ),
    ],
    hook_failures: [],
    reporter_crashes: [],
  )
}

// ============================================================================
// Suites
// ============================================================================

fn outer_group_suite() -> TestSuite {
  suite.group(name: "Outer", suites: [
    steps.feature_suite(registry: registry(), feature: cart_feature()),
  ])
}

fn inline_suite() -> TestSuite {
  feature.feature(name: "Cart", registry: registry(), scenarios: [
    feature.scenario(name: "has 3 items", inline_steps: [
      feature.then("the shop has 3 items"),
    ]),
  ])
}

fn discovered_suite() -> TestSuite {
  let _ =
    file.write(
      "test/tmp/features/feature_heading_a.feature",
      "Feature: Alpha\nScenario: one\n  Then the shop has 3 items\n",
    )
  let _ =
    file.write(
      "test/tmp/features/feature_heading_b.feature",
      "Feature: Beta\nScenario: one\n  Then the shop has 3 items\n",
    )
  discover.features("test/tmp/features/feature_heading_*.feature")
  |> discover.with_registry(registry())
  |> discover.to_suite("my_tests")
}

fn shop_suite() -> TestSuite {
  let cart = cart_feature()
  steps.to_suite(registry: registry(), name: "Shop", tags: [], tests: [
    Group("Billing", [], [Scenarios(cart)]),
    Feature(cart),
  ])
}

fn registry() -> StepRegistry(Int) {
  steps.new(initial: 3)
  |> steps.then("the shop has {int} items", has_items)
}

fn cart_feature() -> gherkin_types.Feature {
  let assert Ok(parsed) =
    parser.parse_string(
      "Feature: Cart\n"
      <> "Scenario: has 3 items\n  Then the shop has 3 items\n"
      <> "Rule: Discounts\n"
      <> "Scenario: still 3 items\n  Then the shop has 3 items\n",
    )
  parsed
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

// ============================================================================
// Reports
// ============================================================================

/// Run the suite, with each duration set to 0 so the text does not change.
fn run(test_suite: TestSuite) -> RunReport {
  let report =
    runner.new([test_suite])
    |> runner.silent()
    |> runner.run()
  types.run_report(
    tests: list.map(types.report_tests(report), fn(result) {
      types.TestResult(..result, duration_ms: 0)
    }),
    hook_failures: [],
    reporter_crashes: [],
  )
}

fn bdd_text(test_suite: TestSuite) -> String {
  bdd.render(
    config: reporter_types.BddReporterConfig(
      color: False,
      mode: reporter_types.BddFull,
    ),
    report: run(test_suite),
  )
}

fn gherkin_text(test_suite: TestSuite) -> String {
  gherkin.format_scenarios(types.report_tests(run(test_suite)))
}
