//// Shopping Cart — Gherkin BDD Example
////
//// Run with: gleam test

import dream_test/reporter/bdd.{report}
import dream_test/runner.{exit_on_failure, run_suite}
import features/shopping_cart as shopping_cart_feature
import gleam/io

pub fn main() {
  io.println("")
  io.println("Shopping Cart — Gherkin BDD Example")
  io.println("====================================")
  io.println("")

  shopping_cart_feature.tests()
  |> run_suite()
  |> report(io.print)
  |> exit_on_failure()
}
