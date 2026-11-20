//// Shopping Cart feature loaded from `.feature` files on disk.
////
//// This example intentionally keeps the Gherkin `.feature` file(s) in
//// `features/` so you can see the full file-based workflow.

import dream_test/gherkin/discover
import dream_test/gherkin/steps
import dream_test/suite.{type TestSuite}
import steps/assertions
import steps/cart
import steps/cart_world
import steps/checkout
import steps/discount

pub fn tests() -> TestSuite {
  let registry =
    steps.new(initial: cart_world.initial())
    |> cart.register()
    |> discount.register()
    |> checkout.register()
    |> assertions.register()

  discover.features("features/*.feature")
  |> discover.with_registry(registry)
  |> discover.to_suite("Feature files")
}
