//// Build Gherkin features inline in Gleam code.
////
//// Use this module when you do not want to keep `.feature` files on disk.
//// `feature` and `feature_with_background` make a `TestSuite` whose
//// top-level group is the Feature, as `steps.feature_suite` does.
////
//// To run a parsed `.feature` file, use `steps.feature_suite`. To load
//// `.feature` files by a pattern, use `gherkin/discover`.
////
//// ## Example (inline DSL)
////
//// ### Build a feature with a background <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/gherkin/feature/feature_with_background.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/gherkin/feature.{
////   and, background, feature_with_background, given, scenario, then, when,
////   with_tags,
//// }
//// import dream_test/gherkin/steps.{type StepContext, get_int}
//// import dream_test/matchers.{be_equal, or_fail_with, should}
//// import dream_test/suite.{type TestSuite}
//// import dream_test/types.{type AssertionResult}
//// import gleam/result
////
//// pub type Cart {
////   Cart(server_running: Bool, items: Int)
//// }
////
//// fn step_server_running(
////   cart: Cart,
////   _context: StepContext,
//// ) -> Result(Cart, String) {
////   Ok(Cart(..cart, server_running: True))
//// }
////
//// fn step_empty_cart(cart: Cart, _context: StepContext) -> Result(Cart, String) {
////   Ok(Cart(..cart, items: 0))
//// }
////
//// fn step_add_items(cart: Cart, context: StepContext) -> Result(Cart, String) {
////   use added <- result.try(get_int(context.captures, 0))
////   Ok(Cart(..cart, items: cart.items + added))
//// }
////
//// fn step_verify_count(
////   cart: Cart,
////   context: StepContext,
//// ) -> Result(AssertionResult, String) {
////   use expected <- result.try(get_int(context.captures, 0))
////   cart.items
////   |> should
////   |> be_equal(expected)
////   |> or_fail_with("Cart count mismatch")
//// }
////
//// pub fn shopping_cart_feature() -> TestSuite {
////   let steps =
////     steps.new(initial: Cart(server_running: False, items: 0))
////     |> steps.given("the server is running", step_server_running)
////     |> steps.given("the cart is empty", step_empty_cart)
////     |> steps.when("I add {int} items", step_add_items)
////     |> steps.then("the cart should have {int} items", step_verify_count)
////
////   let bg = background([given("the server is running")])
////
////   feature_with_background("Shopping Cart", steps, bg, [
////     scenario("Adding items", [
////       given("the cart is empty"),
////       when("I add 3 items"),
////       then("the cart should have 3 items"),
////     ])
////       |> with_tags(["smoke"]),
////     scenario("Adding more items", [
////       given("the cart is empty"),
////       when("I add 2 items"),
////       and("I add 3 items"),
////       then("the cart should have 5 items"),
////     ]),
////   ])
//// }
//// ```

import dream_test/gherkin/steps.{type StepRegistry}
import dream_test/gherkin/types as gherkin_types
import dream_test/suite.{type TestSuite}
import gleam/list
import gleam/option.{None, Some}

// ============================================================================
// Types
// ============================================================================

/// Configuration for an inline scenario.
///
/// Used with the inline DSL to define scenarios in Gleam code.
///
pub type InlineScenario {
  InlineScenario(
    /// Scenario name
    name: String,
    /// List of step text (e.g., ["Given I have 5 items", "When I add 3"])
    steps: List(InlineStep),
    /// Tags for filtering (e.g., ["happy-path", "smoke"])
    tags: List(String),
  )
}

/// An inline step for the DSL.
///
/// The `given`, `when`, `then`, `and`, `but` and `asterisk` helpers build
/// these for you.
/// Build one by hand when you choose the keyword at run time.
///
/// ## Example
///
/// ### Build an inline step by hand <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/gherkin/feature/inline_step.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/gherkin/feature.{type InlineStep, InlineStep}
/// import dream_test/gherkin/types as gherkin_types
///
/// pub fn add_items_step() -> InlineStep {
///   InlineStep(keyword: gherkin_types.When, text: "I add 3 items")
/// }
/// ```
///
pub type InlineStep {
  InlineStep(
    /// The step keyword (Given, When, Then, And, But, *)
    keyword: gherkin_types.StepKeyword,
    /// Step text after the keyword
    text: String,
  )
}

// ============================================================================
// Inline DSL
// ============================================================================

/// Define a feature inline in Gleam code.
///
/// Creates a TestSuite from inline scenario definitions without needing
/// a `.feature` file.
///
/// ## Parameters
///
/// - `name`: Feature name
/// - `registry`: Step registry with step definitions
/// - `scenarios`: List of inline scenarios
///
/// ## Returns
///
/// A TestSuite that can be run with `runner.new([suite]) |> runner.run()`.
///
/// ## Example
///
/// ### Build an inline feature <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/gherkin/feature/feature.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/gherkin/feature.{but, feature, given, scenario, then, when}
/// import dream_test/gherkin/steps.{type StepContext, get_int}
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/suite.{type TestSuite}
/// import dream_test/types.{type AssertionResult}
/// import gleam/result
///
/// fn step_have_items(_count: Int, context: StepContext) -> Result(Int, String) {
///   get_int(context.captures, 0)
/// }
///
/// fn step_add_items(count: Int, context: StepContext) -> Result(Int, String) {
///   use added <- result.try(get_int(context.captures, 0))
///   Ok(count + added)
/// }
///
/// fn step_should_have(
///   count: Int,
///   context: StepContext,
/// ) -> Result(AssertionResult, String) {
///   use expected <- result.try(get_int(context.captures, 0))
///   count
///   |> should
///   |> be_equal(expected)
///   |> or_fail_with("Cart count mismatch")
/// }
///
/// pub fn shopping_cart_feature() -> TestSuite {
///   let steps =
///     steps.new(initial: 0)
///     |> steps.given("I have {int} items in my cart", step_have_items)
///     |> steps.when("I add {int} more items", step_add_items)
///     |> steps.then("I should have {int} items total", step_should_have)
///
///   feature("Shopping Cart", steps, [
///     scenario("Adding items to cart", [
///       given("I have 3 items in my cart"),
///       when("I add 2 more items"),
///       then("I should have 5 items total"),
///       but("I should have 5 items total"),
///     ]),
///   ])
/// }
/// ```
pub fn feature(
  name name: String,
  registry registry: StepRegistry(state),
  scenarios scenarios: List(InlineScenario),
) -> TestSuite {
  let parsed_scenarios = list.map(scenarios, inline_to_parsed_scenario)
  let parsed_feature =
    gherkin_types.Feature(
      name: name,
      source: None,
      description: None,
      tags: [],
      background: None,
      scenarios: parsed_scenarios,
      rules: [],
    )

  steps.feature_suite(registry: registry, feature: parsed_feature)
}

/// Define an inline scenario.
///
/// ## Parameters
///
/// - `name`: Scenario name
/// - `steps`: List of inline steps
///
/// ## Example
///
/// ### Build an inline scenario <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/gherkin/feature/scenario.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/gherkin/feature.{
///   type InlineScenario, but, given, scenario, then, when,
/// }
///
/// pub fn adding_items_scenario() -> InlineScenario {
///   scenario("Adding items to cart", [
///     given("I have 3 items in my cart"),
///     when("I add 2 more items"),
///     then("I should have 5 items total"),
///     but("I should have 5 items total"),
///   ])
/// }
/// ```
///
pub fn scenario(
  name name: String,
  inline_steps inline_steps: List(InlineStep),
) -> InlineScenario {
  InlineScenario(name: name, steps: inline_steps, tags: [])
}

/// Add tags to a Gherkin scenario for filtering.
///
/// ## Example
///
/// ### Tag a scenario <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/gherkin/feature/with_tags.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/gherkin/feature.{
///   type InlineScenario, given, scenario, then, when, with_tags,
/// }
///
/// pub fn smoke_scenario() -> InlineScenario {
///   scenario("Adding items", [
///     given("the cart is empty"),
///     when("I add 3 items"),
///     then("the cart should have 3 items"),
///   ])
///   |> with_tags(["smoke"])
/// }
/// ```
///
/// ## Note
///
/// This function is for Gherkin scenarios. For unit tests (`it`), use
/// `dream_test/unit.with_tags` instead.
///
pub fn with_tags(
  inline_scenario inline_scenario: InlineScenario,
  tags tags: List(String),
) -> InlineScenario {
  InlineScenario(..inline_scenario, tags: tags)
}

/// Create a Given step for inline DSL.
///
/// ## Example
///
/// ### Write a Given step <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/gherkin/feature/given.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/gherkin/feature.{type InlineStep, given}
///
/// pub fn empty_cart_step() -> InlineStep {
///   given("the cart is empty")
/// }
/// ```
///
pub fn given(text text: String) -> InlineStep {
  InlineStep(keyword: gherkin_types.Given, text: text)
}

/// Create a When step for inline DSL.
///
/// ## Example
///
/// ### Write a When step <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/gherkin/feature/when.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/gherkin/feature.{type InlineStep, when}
///
/// pub fn add_items_step() -> InlineStep {
///   when("I add 3 items")
/// }
/// ```
///
pub fn when(text text: String) -> InlineStep {
  InlineStep(keyword: gherkin_types.When, text: text)
}

/// Create a Then step for inline DSL.
///
/// ## Example
///
/// ### Write a Then step <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/gherkin/feature/then.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/gherkin/feature.{type InlineStep, then}
///
/// pub fn cart_count_step() -> InlineStep {
///   then("the cart should have 3 items")
/// }
/// ```
///
pub fn then(text text: String) -> InlineStep {
  InlineStep(keyword: gherkin_types.Then, text: text)
}

/// Create an And step for inline DSL.
///
/// ## Example
///
/// ### Write an And step <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/gherkin/feature/and.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/gherkin/feature.{type InlineStep, and}
///
/// pub fn add_more_items_step() -> InlineStep {
///   and("I add 3 items")
/// }
/// ```
///
pub fn and(text text: String) -> InlineStep {
  InlineStep(keyword: gherkin_types.And, text: text)
}

/// Create a But step for inline DSL.
///
/// ## Example
///
/// ### Write a But step <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/gherkin/feature/but.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/gherkin/feature.{type InlineStep, but}
///
/// pub fn total_step() -> InlineStep {
///   but("I should have 5 items total")
/// }
/// ```
///
pub fn but(text text: String) -> InlineStep {
  InlineStep(keyword: gherkin_types.But, text: text)
}

/// Create a `*` step for inline DSL.
///
/// A `*` step takes the phase of the step before it, like `and` and `but`.
/// Use it for a list of steps where Given, When or Then reads badly.
///
/// ## Example
///
/// ### Write an asterisk step <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/gherkin/feature/asterisk.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/gherkin/feature.{type InlineStep, asterisk}
///
/// pub fn pack_passport_step() -> InlineStep {
///   asterisk("I pack a passport")
/// }
/// ```
///
pub fn asterisk(text text: String) -> InlineStep {
  InlineStep(keyword: gherkin_types.Asterisk, text: text)
}

fn inline_to_parsed_scenario(inline: InlineScenario) -> gherkin_types.Scenario {
  let parsed_steps = list.map(inline.steps, inline_to_parsed_step)
  gherkin_types.Scenario(
    keyword: gherkin_types.KeywordScenario,
    name: inline.name,
    description: None,
    tags: inline.tags,
    steps: parsed_steps,
    examples: [],
  )
}

fn inline_to_parsed_step(inline: InlineStep) -> gherkin_types.Step {
  gherkin_types.Step(
    keyword: inline.keyword,
    text: inline.text,
    doc_string: None,
    data_table: None,
  )
}

// ============================================================================
// Background Support
// ============================================================================

/// Define a background for inline features.
///
/// Background steps run before each scenario.
///
/// ## Example
///
/// ### Build background steps <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/gherkin/feature/background.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/gherkin/feature.{background, given}
/// import dream_test/gherkin/types.{type Step}
///
/// pub fn server_background() -> List(Step) {
///   background([given("the server is running")])
/// }
/// ```
///
pub fn background(
  inline_steps inline_steps: List(InlineStep),
) -> List(gherkin_types.Step) {
  list.map(inline_steps, inline_to_parsed_step)
}

/// Define a feature with a background.
///
/// ## Parameters
///
/// - `name`: Feature name
/// - `registry`: Step registry
/// - `background_steps`: Steps to run before each scenario
/// - `scenarios`: List of inline scenarios
///
/// ## Example
///
/// ### Build a feature with a background <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/gherkin/feature/feature_with_background.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/gherkin/feature.{
///   and, background, feature_with_background, given, scenario, then, when,
///   with_tags,
/// }
/// import dream_test/gherkin/steps.{type StepContext, get_int}
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/suite.{type TestSuite}
/// import dream_test/types.{type AssertionResult}
/// import gleam/result
///
/// pub type Cart {
///   Cart(server_running: Bool, items: Int)
/// }
///
/// fn step_server_running(
///   cart: Cart,
///   _context: StepContext,
/// ) -> Result(Cart, String) {
///   Ok(Cart(..cart, server_running: True))
/// }
///
/// fn step_empty_cart(cart: Cart, _context: StepContext) -> Result(Cart, String) {
///   Ok(Cart(..cart, items: 0))
/// }
///
/// fn step_add_items(cart: Cart, context: StepContext) -> Result(Cart, String) {
///   use added <- result.try(get_int(context.captures, 0))
///   Ok(Cart(..cart, items: cart.items + added))
/// }
///
/// fn step_verify_count(
///   cart: Cart,
///   context: StepContext,
/// ) -> Result(AssertionResult, String) {
///   use expected <- result.try(get_int(context.captures, 0))
///   cart.items
///   |> should
///   |> be_equal(expected)
///   |> or_fail_with("Cart count mismatch")
/// }
///
/// pub fn shopping_cart_feature() -> TestSuite {
///   let steps =
///     steps.new(initial: Cart(server_running: False, items: 0))
///     |> steps.given("the server is running", step_server_running)
///     |> steps.given("the cart is empty", step_empty_cart)
///     |> steps.when("I add {int} items", step_add_items)
///     |> steps.then("the cart should have {int} items", step_verify_count)
///
///   let bg = background([given("the server is running")])
///
///   feature_with_background("Shopping Cart", steps, bg, [
///     scenario("Adding items", [
///       given("the cart is empty"),
///       when("I add 3 items"),
///       then("the cart should have 3 items"),
///     ])
///       |> with_tags(["smoke"]),
///     scenario("Adding more items", [
///       given("the cart is empty"),
///       when("I add 2 items"),
///       and("I add 3 items"),
///       then("the cart should have 5 items"),
///     ]),
///   ])
/// }
/// ```
pub fn feature_with_background(
  name name: String,
  registry registry: StepRegistry(state),
  background_steps background_steps: List(gherkin_types.Step),
  scenarios scenarios: List(InlineScenario),
) -> TestSuite {
  let parsed_scenarios = list.map(scenarios, inline_to_parsed_scenario)
  let parsed_feature =
    gherkin_types.Feature(
      name: name,
      source: None,
      description: None,
      tags: [],
      background: Some(gherkin_types.Background(
        name: "",
        description: None,
        steps: background_steps,
      )),
      scenarios: parsed_scenarios,
      rules: [],
    )

  steps.feature_suite(registry: registry, feature: parsed_feature)
}
