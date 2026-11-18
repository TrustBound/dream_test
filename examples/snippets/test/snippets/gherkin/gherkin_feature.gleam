import dream_test/gherkin/feature.{
  and, background, feature_with_background, given, scenario, then, when,
  with_tags,
}
import dream_test/gherkin/steps.{type StepContext, Action, Check, get_int}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import gleam/int
import gleam/result

pub type Cart {
  Cart(server_running: Bool, items: Int)
}

fn step_server_running(cart: Cart, _context: StepContext) {
  Ok(Cart(..cart, server_running: True))
}

fn step_empty_cart(cart: Cart, _context: StepContext) {
  Ok(Cart(..cart, items: 0))
}

fn step_add_items(cart: Cart, context: StepContext) {
  use to_add <- result.try(get_int(context.captures, 0))
  Ok(Cart(..cart, items: cart.items + to_add))
}

fn step_verify_count(cart: Cart, context: StepContext) {
  use expected <- result.try(get_int(context.captures, 0))
  cart.items
  |> should
  |> be_equal(expected)
  |> or_fail_with("Expected " <> int.to_string(expected) <> " items")
}

pub fn tests() {
  let steps =
    steps.new(initial: Cart(server_running: False, items: 0))
    |> steps.given("the server is running", Action(step_server_running))
    |> steps.given("the cart is empty", Action(step_empty_cart))
    |> steps.when_("I add {int} items", Action(step_add_items))
    |> steps.then_("the cart should have {int} items", Check(step_verify_count))

  let bg = background([given("the server is running")])

  feature_with_background("Shopping Cart", steps, bg, [
    scenario("Adding items", [
      given("the cart is empty"),
      when("I add 3 items"),
      then("the cart should have 3 items"),
    ])
      |> with_tags(["smoke"]),
    scenario("Adding more items", [
      given("the cart is empty"),
      when("I add 2 items"),
      and("I add 3 items"),
      then("the cart should have 5 items"),
    ]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
