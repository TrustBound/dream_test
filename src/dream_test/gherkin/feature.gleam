//// Convert Gherkin features into runnable `TestSuite`s.
////
//// This module does two related jobs:
//// - **Execute parsed `.feature` files**: turn a parsed `gherkin/types.Feature`
////   into a `TestSuite` using a step registry (your Given/When/Then handlers).
//// - **Provide an inline DSL**: build features directly in Gleam when you don’t
////   want to keep `.feature` files on disk.
////
//// ## Example (file-based)
////
//// ```gleam
//// pub fn tests() {
////   // Define the steps and the state each scenario starts from
////   let steps =
////     steps.new(initial: Cart(server_running: False, items: 0))
////     |> given("the server is running", step_server_running)
////     |> given("the cart is empty", step_empty_cart)
////     |> when("I add {int} items", step_add_items)
////     |> then("the cart should have {int} items", step_verify_count)
////
////   // Parse the .feature file
////   let assert Ok(feature) = parser.parse_file("test/cart.feature")
////
////   // Convert to TestSuite and run
////   let config = FeatureConfig(feature: feature, step_registry: steps)
////   to_test_suite(config)
//// }
//// ```
////
//// ## Example (inline DSL)
////
//// ```gleam
//// pub fn tests() {
////   let steps =
////     steps.new(initial: Cart(server_running: False, items: 0))
////     |> given("the server is running", step_server_running)
////     |> given("the cart is empty", step_empty_cart)
////     |> when("I add {int} items", step_add_items)
////     |> then("the cart should have {int} items", step_verify_count)
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

/// Configuration for running a feature.
///
/// Contains the parsed feature and step registry needed to execute it.
/// `state` is the scenario state type of the step registry.
///
pub type FeatureConfig(state) {
  FeatureConfig(
    /// The parsed feature to run
    feature: gherkin_types.Feature,
    /// Registry of step definitions
    step_registry: StepRegistry(state),
  )
}

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
/// ```gleam
/// InlineStep(keyword: gherkin_types.When, text: "I add 3 items")
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
// Feature → TestSuite Conversion
// ============================================================================
/// Convert a Feature to a TestSuite.
///
/// Creates a TestSuite with one test per scenario, and one test per example
/// row of a scenario with `Examples`. Each Rule becomes a group named
/// `Rule: <name>` (or `Rule:` when the Rule has no name), so the full name of
/// a scenario in a Rule is `Feature > Rule: <name> > Scenario`.
///
/// The steps of the Feature Background run first, then the steps of the Rule
/// Background, then the scenario steps. So a scenario that starts with `And`,
/// `But` or `*` takes the phase of the last Background step.
///
/// An example row test is named `<scenario> (Example N)`, or
/// `<scenario> (<examples name>, Example N)` when its `Examples` section has
/// a name. N counts the rows of all `Examples` sections of the scenario, from
/// 1.
///
/// Tags follow Gherkin: a scenario inherits the Feature tags and the Rule
/// tags. The suite root holds the Feature tags, a Rule group holds the Rule
/// tags, and a test holds the scenario tags, then the `Examples` tags. The
/// runner adds the tags of the groups of a test in front of its own tags.
/// So the tags of a test result, and the tags that a `runner.filter_tests`
/// predicate sees, are the Feature tags, then the Rule tags, then the
/// scenario tags, then the `Examples` tags, each one time.
///
/// ## Parameters
///
/// - `config`: FeatureConfig with feature and step registry
///
/// ## Returns
///
/// A TestSuite that can be run with `runner.new([suite]) |> runner.run()`.
///
/// ## Example
///
/// ```gleam
/// let config = FeatureConfig(feature: feature, step_registry: steps)
/// to_test_suite(config)
/// ```
pub fn to_test_suite(config config: FeatureConfig(state)) -> TestSuite {
  let feature = config.feature
  steps.to_suite(
    registry: config.step_registry,
    name: feature.name,
    tags: feature.tags,
    children: [steps.Scenarios(feature: feature)],
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
/// ```gleam
/// let steps =
///   steps.new(initial: 0)
///   |> given("I have {int} items in my cart", step_have_items)
///   |> when("I add {int} more items", step_add_items)
///   |> then("I should have {int} items total", step_should_have)
///
/// feature("Shopping Cart", steps, [
///   scenario("Adding items to cart", [
///     given("I have 3 items in my cart"),
///     when("I add 2 more items"),
///     then("I should have 5 items total"),
///     but("I should have 5 items total"),
///   ]),
/// ])
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

  let config = FeatureConfig(feature: parsed_feature, step_registry: registry)
  to_test_suite(config)
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
/// ```gleam
/// scenario("Adding items to cart", [
///       given("I have 3 items in my cart"),
///       when("I add 2 more items"),
///       then("I should have 5 items total"),
///       but("I should have 5 items total"),
///     ]),
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
/// ```gleam
/// scenario("Adding items", [
///       given("the cart is empty"),
///       when("I add 3 items"),
///       then("the cart should have 3 items"),
///     ])
///       |> with_tags(["smoke"]),
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
/// ```gleam
///       given("the cart is empty"),
/// ```
///
pub fn given(text text: String) -> InlineStep {
  InlineStep(keyword: gherkin_types.Given, text: text)
}

/// Create a When step for inline DSL.
///
/// ## Example
///
/// ```gleam
///       when("I add 3 items"),
/// ```
///
pub fn when(text text: String) -> InlineStep {
  InlineStep(keyword: gherkin_types.When, text: text)
}

/// Create a Then step for inline DSL.
///
/// ## Example
///
/// ```gleam
///       then("the cart should have 3 items"),
/// ```
///
pub fn then(text text: String) -> InlineStep {
  InlineStep(keyword: gherkin_types.Then, text: text)
}

/// Create an And step for inline DSL.
///
/// ## Example
///
/// ```gleam
///       and("I add 3 items"),
/// ```
///
pub fn and(text text: String) -> InlineStep {
  InlineStep(keyword: gherkin_types.And, text: text)
}

/// Create a But step for inline DSL.
///
/// ## Example
///
/// ```gleam
///       but("I should have 5 items total"),
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
/// ```gleam
///       asterisk("I pack a passport"),
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
/// ```gleam
/// let bg = background([given("the server is running")])
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
/// ```gleam
/// let bg = background([given("the server is running")])
///
/// feature_with_background("Shopping Cart", steps, bg, [
///   scenario("Adding items", [
///     given("the cart is empty"),
///     when("I add 3 items"),
///     then("the cart should have 3 items"),
///   ])
///     |> with_tags(["smoke"]),
///   scenario("Adding more items", [
///     given("the cart is empty"),
///     when("I add 2 items"),
///     and("I add 3 items"),
///     then("the cart should have 5 items"),
///   ]),
/// ])
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

  let config = FeatureConfig(feature: parsed_feature, step_registry: registry)
  to_test_suite(config)
}
