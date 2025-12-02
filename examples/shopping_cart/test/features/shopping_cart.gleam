//// Shopping Cart feature using the inline Gleam DSL.

import dream_test/gherkin/feature.{
  and, background, feature_with_background, given, scenario, then, when,
  with_tags,
}
import dream_test/gherkin/steps.{new_registry}
import dream_test/types.{type TestSuite}
import steps/assertions
import steps/cart
import steps/checkout
import steps/discount

pub fn tests() -> TestSuite {
  let registry =
    new_registry()
    |> cart.register()
    |> discount.register()
    |> checkout.register()
    |> assertions.register()

  let bg = background([given("I have an empty cart")])

  feature_with_background("Shopping Cart", registry, bg, [
    scenario("Adding a single item to the cart", [
      when("I add 2 apples to the cart"),
      then("the cart should contain 2 items"),
      and("the subtotal should be $3.00"),
    ])
      |> with_tags(["happy-path"]),
    scenario("Adding multiple different items", [
      when("I add 1 apple to the cart"),
      and("I add 3 bananas to the cart"),
      then("the cart should contain 4 items"),
      and("the subtotal should be $3.75"),
    ])
      |> with_tags(["happy-path"]),
    scenario("Updating item quantity", [
      given("I add 2 apples to the cart"),
      when("I update the apples quantity to 5"),
      then("the cart should contain 5 items"),
      and("the subtotal should be $7.50"),
    ])
      |> with_tags(["quantity"]),
    scenario("Removing an item from the cart", [
      given("I add 2 apples to the cart"),
      and("I add 1 banana to the cart"),
      when("I remove apples from the cart"),
      then("the cart should contain 1 items"),
      and("the subtotal should be $0.75"),
    ])
      |> with_tags(["removal"]),
    scenario("Applying a percentage discount", [
      given("I add 4 apples to the cart"),
      when("I apply a 10% discount"),
      then("the subtotal should be $6.00"),
      and("the discount should be $0.60"),
      and("the total should be $5.40"),
    ])
      |> with_tags(["discount"]),
    scenario("Successful checkout", [
      given("I add 1 apple to the cart"),
      and("I add 2 bananas to the cart"),
      when("I checkout"),
      then("the checkout should succeed"),
      and("the order total should be $3.00"),
    ])
      |> with_tags(["checkout"]),
    scenario("Cannot checkout an empty cart", [
      when("I checkout"),
      then("the checkout should fail with \"cart is empty\""),
    ])
      |> with_tags(["checkout", "error"]),
    scenario("Cannot add zero items", [
      when("I try to add 0 apples to the cart"),
      then("the operation should fail with \"invalid quantity\""),
    ])
      |> with_tags(["error"]),
  ])
}
