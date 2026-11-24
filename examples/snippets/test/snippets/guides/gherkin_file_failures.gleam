//// The failing cart feature, loaded from a `.feature` file, so each
//// failure names the file and the line of its step. `tests` checks that
//// every scenario fails, so test discovery does not run this feature as a
//// test.

import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/summary
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/unit
import snippets/guides/gherkin_cart_steps.{cart_steps}

pub fn failing_feature_file() -> TestSuite {
  let registry =
    cart_steps()
    |> steps.when("the cart breaks", break_cart)
  let assert Ok(feature) =
    parser.parse_file("test/features/shopping_cart_failures.feature")
  steps.feature_suite(registry: registry, feature: feature)
}

fn break_cart(_cart: Int, _context: StepContext) -> Result(Int, String) {
  panic as "the cart broke"
}

pub fn tests() {
  unit.describe("The failing cart feature file", [
    unit.it("fails every scenario", fn() {
      // Act
      let report =
        runner.new([failing_feature_file()])
        |> runner.silent()
        |> runner.run()

      // Assert
      summary.count(report).failed
      |> should
      |> be_equal(3)
      |> or_fail_with(
        "a failing check, an undefined step and a crash should fail",
      )
    }),
  ])
}
