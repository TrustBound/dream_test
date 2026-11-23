import dream_test/gherkin/feature
import dream_test/gherkin/parser
import dream_test/gherkin/step_trie.{
  CapturedFloat, CapturedInt, CapturedString, CapturedWord,
}
import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, StepContext,
}
import dream_test/gherkin/types.{GivenPhase, ThenPhase, WhenPhase} as gherkin_types
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult, type Status, AssertionOk, Passed}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import snippets/doc/gherkin/steps/feature_suite
import snippets/doc/gherkin/steps/find_step
import snippets/doc/gherkin/steps/get_float
import snippets/doc/gherkin/steps/get_int
import snippets/doc/gherkin/steps/get_string
import snippets/doc/gherkin/steps/get_word
import snippets/doc/gherkin/steps/given
import snippets/doc/gherkin/steps/module
import snippets/doc/gherkin/steps/new
import snippets/doc/gherkin/steps/new_with_setup
import snippets/doc/gherkin/steps/step_context
import snippets/doc/gherkin/steps/step_definition
import snippets/doc/gherkin/steps/then
import snippets/doc/gherkin/steps/to_suite
import snippets/doc/gherkin/steps/validate
import snippets/doc/gherkin/steps/when

fn statuses(suite: TestSuite) -> List(Status) {
  runner.new([suite])
  |> runner.run()
  |> types.report_tests
  |> list.map(fn(test_result) { test_result.status })
}

fn passed_names(suite: TestSuite) -> List(String) {
  runner.new([suite])
  |> runner.run()
  |> types.report_tests
  |> list.filter(fn(test_result) { test_result.status == Passed })
  |> list.map(fn(test_result) {
    string.join(types.full_name(test_result.groups, test_result.name), " > ")
  })
}

fn shopping_cart() -> gherkin_types.Feature {
  let assert Ok(feature) =
    parser.parse_file("test/features/shopping_cart.feature")
  feature
}

fn check_count(
  count: Int,
  context: StepContext,
) -> Result(AssertionResult, String) {
  use expected <- result.try(steps.get_int(context.captures, 0))
  count
  |> should
  |> be_equal(expected)
  |> or_fail_with("count mismatch")
}

fn count_registry() -> StepRegistry(Int) {
  steps.new(initial: 0) |> steps.then("the count is {int}", check_count)
}

fn count_feature(name: String, scenario: String) -> gherkin_types.Feature {
  let content =
    "Feature: "
    <> name
    <> "\n  Scenario: "
    <> scenario
    <> "\n    Then the count is 0\n"
  let assert Ok(feature) = parser.parse_string(content)
  feature
}

pub fn tests() {
  describe("Doc examples: gherkin/steps", [
    it("cart_steps passes the shopping cart feature", fn() {
      // Act
      let result =
        statuses(steps.feature_suite(
          registry: module.cart_steps(),
          feature: shopping_cart(),
        ))

      // Assert
      result
      |> should
      |> be_equal([Passed])
      |> or_fail_with("expected cart_steps to give the documented result")
    }),
    it("step_order_name names the order after the scenario", fn() {
      // Act
      let result =
        step_context.step_order_name(
          step_context.Order(name: ""),
          StepContext(
            captures: [],
            table: None,
            doc_string: None,
            scenario_id: "Orders::Name#1",
          ),
        )

      // Assert
      result
      |> should
      |> be_equal(Ok(step_context.Order(name: "Orders::Name#1")))
      |> or_fail_with("expected step_order_name to give the documented result")
    }),
    it("then_definition_is_a_check passes", fn() {
      // Act
      let result = step_definition.then_definition_is_a_check()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected then_definition_is_a_check to give the documented result",
      )
    }),
    it("item_steps finds the then step", fn() {
      // Act
      let result =
        steps.find_step(new.item_steps(), ThenPhase, "I should have 2 items")
        |> result.map(fn(matched) { matched.captures })

      // Assert
      result
      |> should
      |> be_equal(Ok([CapturedInt(2)]))
      |> or_fail_with("expected item_steps to give the documented result")
    }),
    it("server_steps runs a ping scenario and it passes", fn() {
      // Act
      let result =
        statuses(
          feature.feature("Server", new_with_setup.server_steps(), [
            feature.scenario("Ping", [
              feature.given("the server is running"),
              feature.when("I ping the server"),
              feature.then("the reply is \"pong\""),
            ]),
          ]),
        )

      // Assert
      result
      |> should
      |> be_equal([Passed])
      |> or_fail_with("expected server_steps to give the documented result")
    }),
    it("shop_suite runs every child and they pass", fn() {
      // Act
      let result =
        to_suite.shop_suite(
          steps: count_registry(),
          cart: count_feature("Cart", "Empty cart"),
          invoice: count_feature("Invoice", "Empty invoice"),
        )
        |> passed_names

      // Assert
      result
      |> should
      |> be_equal([
        "Shop > the server answers",
        "Shop > Cart > Empty cart",
        "Shop > Billing > Invoice > Empty invoice",
      ])
      |> or_fail_with("expected shop_suite to give the documented result")
    }),
    it("cart_feature_suite runs its scenario and it passes", fn() {
      // Act
      let result = statuses(feature_suite.cart_feature_suite())

      // Assert
      result
      |> should
      |> be_equal([Passed])
      |> or_fail_with(
        "expected cart_feature_suite to give the documented result",
      )
    }),
    it("count_steps finds the given step", fn() {
      // Act
      let result =
        steps.find_step(given.count_steps(), GivenPhase, "I have 3 items")
        |> result.map(fn(matched) { matched.captures })

      // Assert
      result
      |> should
      |> be_equal(Ok([CapturedInt(3)]))
      |> or_fail_with("expected count_steps to give the documented result")
    }),
    it("add_steps finds the when step", fn() {
      // Act
      let result =
        steps.find_step(when.add_steps(), WhenPhase, "I add 4 items")
        |> result.map(fn(matched) { matched.captures })

      // Assert
      result
      |> should
      |> be_equal(Ok([CapturedInt(4)]))
      |> or_fail_with("expected add_steps to give the documented result")
    }),
    it("count_check_steps finds the then step", fn() {
      // Act
      let result =
        steps.find_step(
          then.count_check_steps(),
          ThenPhase,
          "I should have 5 items",
        )
        |> result.map(fn(matched) { matched.captures })

      // Assert
      result
      |> should
      |> be_equal(Ok([CapturedInt(5)]))
      |> or_fail_with(
        "expected count_check_steps to give the documented result",
      )
    }),
    it("duplicate_pattern_is_an_error passes", fn() {
      // Act
      let result = validate.duplicate_pattern_is_an_error()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected duplicate_pattern_is_an_error to give the documented result",
      )
    }),
    it("item_count_step_has_one_capture passes", fn() {
      // Act
      let result = find_step.item_count_step_has_one_capture()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected item_count_step_has_one_capture to give the documented result",
      )
    }),
    it("step_int reads the first capture", fn() {
      // Act
      let result =
        get_int.step_int(
          0,
          StepContext(
            captures: [CapturedInt(42)],
            table: None,
            doc_string: None,
            scenario_id: "Captures#1",
          ),
        )

      // Assert
      result
      |> should
      |> be_equal(Ok(42))
      |> or_fail_with("expected step_int to give the documented result")
    }),
    it("step_float reads the first capture", fn() {
      // Act
      let result =
        get_float.step_float(
          0.0,
          StepContext(
            captures: [CapturedFloat(19.99)],
            table: None,
            doc_string: None,
            scenario_id: "Captures#1",
          ),
        )

      // Assert
      result
      |> should
      |> be_equal(Ok(19.99))
      |> or_fail_with("expected step_float to give the documented result")
    }),
    it("step_string reads the first capture", fn() {
      // Act
      let result =
        get_string.step_string(
          "",
          StepContext(
            captures: [CapturedString("hello world")],
            table: None,
            doc_string: None,
            scenario_id: "Captures#1",
          ),
        )

      // Assert
      result
      |> should
      |> be_equal(Ok("hello world"))
      |> or_fail_with("expected step_string to give the documented result")
    }),
    it("step_word reads the first capture", fn() {
      // Act
      let result =
        get_word.step_word(
          "",
          StepContext(
            captures: [CapturedWord("alice")],
            table: None,
            doc_string: None,
            scenario_id: "Captures#1",
          ),
        )

      // Assert
      result
      |> should
      |> be_equal(Ok("alice"))
      |> or_fail_with("expected step_word to give the documented result")
    }),
  ])
}
