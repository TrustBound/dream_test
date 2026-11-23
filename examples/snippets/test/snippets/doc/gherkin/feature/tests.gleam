import dream_test/gherkin/feature.{InlineScenario, InlineStep}
import dream_test/gherkin/types.{Step} as gherkin_types
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type Status, Passed}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/option.{None}
import snippets/doc/gherkin/feature/and
import snippets/doc/gherkin/feature/asterisk
import snippets/doc/gherkin/feature/background
import snippets/doc/gherkin/feature/but
import snippets/doc/gherkin/feature/feature as feature_example
import snippets/doc/gherkin/feature/feature_with_background
import snippets/doc/gherkin/feature/given
import snippets/doc/gherkin/feature/inline_step
import snippets/doc/gherkin/feature/scenario
import snippets/doc/gherkin/feature/then
import snippets/doc/gherkin/feature/when
import snippets/doc/gherkin/feature/with_tags

fn statuses(suite: TestSuite) -> List(Status) {
  runner.new([suite])
  |> runner.run()
  |> types.report_tests
  |> list.map(fn(test_result) { test_result.status })
}

pub fn tests() {
  describe("Doc examples: gherkin/feature", [
    it("given.empty_cart_step builds a Given step", fn() {
      // Act
      let result = given.empty_cart_step()

      // Assert
      result
      |> should
      |> be_equal(InlineStep(
        keyword: gherkin_types.Given,
        text: "the cart is empty",
      ))
      |> or_fail_with("expected empty_cart_step to give the documented result")
    }),
    it("when.add_items_step builds a When step", fn() {
      // Act
      let result = when.add_items_step()

      // Assert
      result
      |> should
      |> be_equal(InlineStep(keyword: gherkin_types.When, text: "I add 3 items"))
      |> or_fail_with("expected add_items_step to give the documented result")
    }),
    it("then.cart_count_step builds a Then step", fn() {
      // Act
      let result = then.cart_count_step()

      // Assert
      result
      |> should
      |> be_equal(InlineStep(
        keyword: gherkin_types.Then,
        text: "the cart should have 3 items",
      ))
      |> or_fail_with("expected cart_count_step to give the documented result")
    }),
    it("and.add_more_items_step builds a And step", fn() {
      // Act
      let result = and.add_more_items_step()

      // Assert
      result
      |> should
      |> be_equal(InlineStep(keyword: gherkin_types.And, text: "I add 3 items"))
      |> or_fail_with(
        "expected add_more_items_step to give the documented result",
      )
    }),
    it("but.total_step builds a But step", fn() {
      // Act
      let result = but.total_step()

      // Assert
      result
      |> should
      |> be_equal(InlineStep(
        keyword: gherkin_types.But,
        text: "I should have 5 items total",
      ))
      |> or_fail_with("expected total_step to give the documented result")
    }),
    it("asterisk.pack_passport_step builds a Asterisk step", fn() {
      // Act
      let result = asterisk.pack_passport_step()

      // Assert
      result
      |> should
      |> be_equal(InlineStep(
        keyword: gherkin_types.Asterisk,
        text: "I pack a passport",
      ))
      |> or_fail_with(
        "expected pack_passport_step to give the documented result",
      )
    }),
    it("inline_step.add_items_step builds a When step", fn() {
      // Act
      let result = inline_step.add_items_step()

      // Assert
      result
      |> should
      |> be_equal(InlineStep(keyword: gherkin_types.When, text: "I add 3 items"))
      |> or_fail_with("expected add_items_step to give the documented result")
    }),
    it("server_background passes", fn() {
      // Act
      let result = background.server_background()

      // Assert
      result
      |> should
      |> be_equal([
        Step(
          keyword: gherkin_types.Given,
          text: "the server is running",
          doc_string: None,
          data_table: None,
          line: None,
        ),
      ])
      |> or_fail_with(
        "expected server_background to give the documented result",
      )
    }),
    it("adding_items_scenario passes", fn() {
      // Act
      let result = scenario.adding_items_scenario()

      // Assert
      result
      |> should
      |> be_equal(
        InlineScenario(
          name: "Adding items to cart",
          steps: [
            InlineStep(
              keyword: gherkin_types.Given,
              text: "I have 3 items in my cart",
            ),
            InlineStep(keyword: gherkin_types.When, text: "I add 2 more items"),
            InlineStep(
              keyword: gherkin_types.Then,
              text: "I should have 5 items total",
            ),
            InlineStep(
              keyword: gherkin_types.But,
              text: "I should have 5 items total",
            ),
          ],
          tags: [],
        ),
      )
      |> or_fail_with(
        "expected adding_items_scenario to give the documented result",
      )
    }),
    it("smoke_scenario has the smoke tag", fn() {
      // Act
      let result = with_tags.smoke_scenario().tags

      // Assert
      result
      |> should
      |> be_equal(["smoke"])
      |> or_fail_with("expected smoke_scenario to give the documented result")
    }),
    it("feature.shopping_cart_feature runs its scenario and it passes", fn() {
      // Act
      let result = statuses(feature_example.shopping_cart_feature())

      // Assert
      result
      |> should
      |> be_equal([Passed])
      |> or_fail_with(
        "expected shopping_cart_feature to give the documented result",
      )
    }),
    it(
      "feature_with_background.shopping_cart_feature runs both scenarios and they pass",
      fn() {
        // Act
        let result = statuses(feature_with_background.shopping_cart_feature())

        // Assert
        result
        |> should
        |> be_equal([Passed, Passed])
        |> or_fail_with(
          "expected shopping_cart_feature to give the documented result",
        )
      },
    ),
  ])
}
