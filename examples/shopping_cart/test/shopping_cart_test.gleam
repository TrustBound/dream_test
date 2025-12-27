//// Shopping Cart — Gherkin BDD Example
////
//// Run with: gleam test

import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import features/shopping_cart as shopping_cart_feature
import features/shopping_cart_file as shopping_cart_file_feature
import gleam/io

pub fn main() {
  io.println("")
  io.println("Shopping Cart — Gherkin BDD Example")
  io.println("====================================")
  io.println("")

  runner.new([shopping_cart_feature.tests(), shopping_cart_file_feature.tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new() |> bdd.color()])
  |> runner.exit_on_failure()
  |> runner.run()
}
