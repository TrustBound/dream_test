import dream_test/gherkin/discover
import dream_test/gherkin/steps
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type Status, AssertionOk, Passed}
import dream_test/unit.{describe, it}
import gleam/list
import snippets/doc/gherkin/discover/features
import snippets/doc/gherkin/discover/list_files
import snippets/doc/gherkin/discover/load
import snippets/doc/gherkin/discover/module
import snippets/doc/gherkin/discover/to_suite

fn statuses(suite: TestSuite) -> List(Status) {
  runner.new([suite])
  |> runner.run()
  |> types.report_tests
  |> list.map(fn(test_result) { test_result.status })
}

pub fn tests() {
  describe("Doc examples: gherkin/discover", [
    it("cart_features runs both cart scenarios and they pass", fn() {
      // Act
      let result = statuses(module.cart_features())

      // Assert
      result
      |> should
      |> be_equal([Passed, Passed])
      |> or_fail_with("expected cart_features to give the documented result")
    }),
    it("cart_features names one test for each cart scenario", fn() {
      // Act
      let result =
        runner.new([to_suite.cart_features(steps.new(initial: Nil))])
        |> runner.run()
        |> types.report_tests
        |> list.map(fn(test_result) { test_result.name })

      // Assert
      result
      |> should
      |> be_equal(["Adding items", "Adding multiple times"])
      |> or_fail_with("expected cart_features to give the documented result")
    }),
    it("feature_files finds the cart feature", fn() {
      // Act
      let result = features.feature_files() |> discover.list_files()

      // Assert
      result
      |> should
      |> be_equal(Ok(["test/cart.feature"]))
      |> or_fail_with("expected feature_files to give the documented result")
    }),
    it("load_parses_one_feature passes", fn() {
      // Act
      let result = load.load_parses_one_feature()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected load_parses_one_feature to give the documented result",
      )
    }),
    it("list_files_finds_the_cart_feature passes", fn() {
      // Act
      let result = list_files.list_files_finds_the_cart_feature()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected list_files_finds_the_cart_feature to give the documented result",
      )
    }),
  ])
}
