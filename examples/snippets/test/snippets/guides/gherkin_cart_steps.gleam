import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, type StepRegistry, get_int}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/summary
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/unit
import gleam/result

/// The steps of the shopping cart. The state of a scenario is the number
/// of items in the cart, and each scenario starts from 0.
pub fn cart_steps() -> StepRegistry(Int) {
  steps.new(initial: 0)
  |> steps.given("I have {int} items in my cart", have_items)
  |> steps.when("I add {int} more items", add_items)
  |> steps.then("I should have {int} items total", should_have_items)
}

pub fn have_items(_cart: Int, context: StepContext) -> Result(Int, String) {
  get_int(context.captures, 0)
}

pub fn add_items(cart: Int, context: StepContext) -> Result(Int, String) {
  use added <- result.try(get_int(context.captures, 0))
  Ok(cart + added)
}

fn should_have_items(cart: Int, context: StepContext) {
  use expected <- result.try(get_int(context.captures, 0))
  cart
  |> should
  |> be_equal(expected)
  |> or_fail_with("the cart should hold the expected number of items")
}

/// A feature with a scenario that fails at a check, and one with a step
/// that no definition matches. `tests` checks that both scenarios fail,
/// so test discovery does not run this feature as a test.
pub fn failing_feature() -> TestSuite {
  feature("Shopping Cart", cart_steps(), [
    scenario("Adding items", [
      given("I have 3 items in my cart"),
      when("I add 1 more items"),
      then("I should have 5 items total"),
    ]),
    scenario("Removing items", [
      given("I have 3 items in my cart"),
      when("I remove 1 item"),
      then("I should have 2 items total"),
    ]),
  ])
}

pub fn tests() {
  unit.describe("The failing cart feature", [
    unit.it("fails both scenarios", fn() {
      // Act
      let report =
        runner.new([failing_feature()])
        |> runner.silent()
        |> runner.run()

      // Assert
      summary.count(report).failed
      |> should
      |> be_equal(2)
      |> or_fail_with("a failing check and an undefined step should fail")
    }),
  ])
}
