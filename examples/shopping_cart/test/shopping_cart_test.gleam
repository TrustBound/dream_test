//// Shopping Cart — Gherkin BDD Example
////
//// Run with: gleam test

import dream_test/reporters
import dream_test/runner
import features/shopping_cart as shopping_cart_feature
import gleam/io

pub fn main() {
  io.println("")
  io.println("Shopping Cart — Gherkin BDD Example")
  io.println("====================================")
  io.println("")

  runner.new([shopping_cart_feature.tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
