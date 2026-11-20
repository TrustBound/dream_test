import dream_test/gherkin/feature.{FeatureConfig, to_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{type TestResult}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/string

fn full_name(result: TestResult) -> String {
  string.join(types.full_name(result.groups, result.name), " > ")
}

pub fn tests() {
  describe("Gherkin Rules and Examples", [
    it("names each test after its Rule and its Examples section", fn() {
      let assert Ok(feature) = parser.parse_file("test/features/stock.feature")
      let suite =
        to_suite(FeatureConfig(
          feature: feature,
          step_registry: steps.new(initial: Nil),
        ))

      runner.new([suite])
      |> runner.run()
      |> types.report_tests
      |> list.map(full_name)
      |> should
      |> be_equal([
        "Stock control > Rule: An item can be sold only when it is in stock > Sell from stock",
        "Stock control > Rule: An item can be sold only when it is in stock > Sell different amounts (Small orders, Example 1)",
        "Stock control > Rule: An item can be sold only when it is in stock > Sell different amounts (Small orders, Example 2)",
        "Stock control > Rule: An item can be sold only when it is in stock > Sell different amounts (Large orders, Example 3)",
        "Stock control > Rule: A sold-out shop sells nothing > Nothing to sell",
      ])
      |> or_fail_with("expected the Rule group and the Examples name")
    }),
  ])
}
