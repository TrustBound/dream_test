//// Feature execution and TestSuite conversion for Gherkin tests.
////
//// This module converts parsed Gherkin features to dream_test TestSuites
//// and provides an inline DSL for defining features directly in Gleam.
////
//// ## Two Approaches
////
//// 1. **File-based**: Parse `.feature` files with standard Gherkin syntax
//// 2. **Inline DSL**: Define features directly in Gleam code
////
//// Both approaches share the same step definitions and execution engine.
////
//// ## File-Based Usage
////
//// Parse a `.feature` file and convert to TestSuite:
////
//// ```gleam
//// import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
//// import dream_test/gherkin/parser
//// import dream_test/gherkin/steps.{new_registry, given, when_, then_}
//// import dream_test/runner
////
//// pub fn main() {
////   let steps = new_registry()
////   |> given("I have {int} items", have_items)
////   |> when_("I add {int} items", add_items)
////   |> then_("the total is ${float}", check_total)
////
////   let assert Ok(parsed) = parser.parse_file("features/cart.feature")
////   let config = FeatureConfig(feature: parsed, step_registry: steps)
////   
////   to_test_suite("cart_test", config)
////   |> runner.run_suite()
//// }
//// ```
////
//// ## Inline DSL Usage
////
//// Define features directly in Gleam without `.feature` files:
////
//// ```gleam
//// import dream_test/gherkin/feature.{
////   feature, scenario, given, when, then, and, with_tags,
//// }
////
//// pub fn tests() -> TestSuite(Nil) {
////   let steps = cart_steps()
////   
////   feature("Shopping Cart", steps, [
////     scenario("Adding items", [
////       given("I have an empty cart"),
////       when("I add 2 apples to the cart"),
////       then("the cart should contain 2 items"),
////       and("the total should be $3.00"),
////     ])
////     |> with_tags(["happy-path"]),
////   ])
//// }
//// ```
////

import dream_test/gherkin/step_trie.{type StepMatch}
import dream_test/gherkin/steps.{
  type StepContext, type StepHandler, type StepRegistry, StepContext,
}
import dream_test/gherkin/types as gherkin_types
import dream_test/gherkin/world.{type World}
import dream_test/types.{
  type AssertionResult, type SuiteTestCase, type TestSuite, type TestSuiteItem,
  AssertionFailed, AssertionFailure, AssertionOk, GherkinScenario, SuiteTest,
  SuiteTestCase, TestSuite,
}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// ============================================================================
// Types
// ============================================================================

/// Configuration for running a feature.
///
/// Contains the parsed feature and step registry needed to execute it.
///
pub type FeatureConfig {
  FeatureConfig(
    /// The parsed feature to run
    feature: gherkin_types.Feature,
    /// Registry of step definitions
    step_registry: StepRegistry,
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
pub type InlineStep {
  InlineStep(
    /// Step keyword as string ("Given", "When", "Then", "And", "But")
    keyword: String,
    /// Step text after the keyword
    text: String,
  )
}

// ============================================================================
// Feature → TestSuite Conversion
// ============================================================================

/// Convert a Feature to a TestSuite.
///
/// Creates a TestSuite with one test per scenario. Background steps are
/// prepended to each scenario. ScenarioOutlines are expanded based on
/// their examples table.
///
/// ## Parameters
///
/// - `module_name`: Name for the suite (usually the test module name)
/// - `config`: FeatureConfig with feature and step registry
///
/// ## Returns
///
/// A TestSuite that can be run with `runner.run_suite()`
///
pub fn to_test_suite(
  _module_name: String,
  config: FeatureConfig,
) -> TestSuite(Nil) {
  let feature = config.feature
  let items = build_suite_items(feature, config)

  TestSuite(
    name: feature.name,
    before_all: Some(fn() { Ok(Nil) }),
    after_all: [],
    before_each: [],
    after_each: [],
    items: items,
  )
}

/// Convert a Feature to a flat list of TestCases.
///
/// Unlike `to_test_suite`, this flattens the feature to a simple list.
/// Use this when you don't need before_all/after_all hooks.
///
/// ## Parameters
///
/// - `module_name`: Name prefix for test paths
/// - `config`: FeatureConfig with feature and step registry
///
/// ## Returns
///
/// A list of TestCases that can be run with `runner.run_all()`
///
fn build_suite_items(
  feature: gherkin_types.Feature,
  config: FeatureConfig,
) -> List(TestSuiteItem(Nil)) {
  list.flat_map(feature.scenarios, fn(scenario) {
    scenario_to_suite_items(feature, scenario, config)
  })
}

fn scenario_to_suite_items(
  feature: gherkin_types.Feature,
  scenario: gherkin_types.Scenario,
  config: FeatureConfig,
) -> List(TestSuiteItem(Nil)) {
  case scenario {
    gherkin_types.Scenario(name, tags, steps) -> {
      let test_case =
        build_scenario_test_case(feature, name, tags, steps, config, None)
      [SuiteTest(test_case)]
    }
    gherkin_types.ScenarioOutline(name, tags, steps, examples) -> {
      expand_scenario_outline(feature, name, tags, steps, examples, config)
    }
  }
}

fn build_scenario_test_case(
  feature: gherkin_types.Feature,
  scenario_name: String,
  scenario_tags: List(String),
  steps: List(gherkin_types.Step),
  config: FeatureConfig,
  example_suffix: Option(String),
) -> SuiteTestCase(Nil) {
  let full_name = build_full_name(feature.name, scenario_name, example_suffix)
  let scenario_id = string.join(full_name, "::")
  let all_tags = list.append(feature.tags, scenario_tags)

  // Combine background and scenario steps
  let all_steps = case feature.background {
    Some(gherkin_types.Background(background_steps)) ->
      list.append(background_steps, steps)
    None -> steps
  }
  SuiteTestCase(
    name: scenario_name,
    tags: all_tags,
    kind: GherkinScenario(scenario_id),
    run: fn(_) {
      Ok(execute_scenario(scenario_id, all_steps, config.step_registry))
    },
    timeout_ms: None,
  )
}

fn build_full_name(
  feature_name: String,
  scenario_name: String,
  example_suffix: Option(String),
) -> List(String) {
  case example_suffix {
    None -> [feature_name, scenario_name]
    Some(suffix) -> [feature_name, scenario_name <> " " <> suffix]
  }
}

fn expand_scenario_outline(
  feature: gherkin_types.Feature,
  name: String,
  tags: List(String),
  steps: List(gherkin_types.Step),
  examples: gherkin_types.ExamplesTable,
  config: FeatureConfig,
) -> List(TestSuiteItem(Nil)) {
  let headers = examples.headers

  list.index_map(examples.rows, fn(row, index) {
    let substitutions = build_substitution_map(headers, row)
    let expanded_steps = substitute_steps(steps, substitutions)
    let suffix = "(Example " <> int.to_string(index + 1) <> ")"

    let test_case =
      build_scenario_test_case(
        feature,
        name,
        tags,
        expanded_steps,
        config,
        Some(suffix),
      )
    SuiteTest(test_case)
  })
}

fn build_substitution_map(
  headers: List(String),
  values: List(String),
) -> Dict(String, String) {
  list.zip(headers, values)
  |> list.fold(dict.new(), fn(acc, pair) {
    let #(header, value) = pair
    dict.insert(acc, header, value)
  })
}

fn substitute_steps(
  steps: List(gherkin_types.Step),
  substitutions: Dict(String, String),
) -> List(gherkin_types.Step) {
  list.map(steps, fn(step) { substitute_step(step, substitutions) })
}

fn substitute_step(
  step: gherkin_types.Step,
  substitutions: Dict(String, String),
) -> gherkin_types.Step {
  let new_text = substitute_placeholders(step.text, substitutions)
  gherkin_types.Step(
    keyword: step.keyword,
    text: new_text,
    argument: step.argument,
  )
}

fn substitute_placeholders(
  text: String,
  substitutions: Dict(String, String),
) -> String {
  dict.fold(substitutions, text, fn(acc, header, value) {
    let placeholder = "<" <> header <> ">"
    string.replace(acc, placeholder, value)
  })
}

// ============================================================================
// Scenario Execution
// ============================================================================

fn execute_scenario(
  scenario_id: String,
  steps: List(gherkin_types.Step),
  registry: StepRegistry,
) -> AssertionResult {
  // Create world for this scenario
  let the_world = world.new_world(scenario_id)

  // Execute all steps
  let result = execute_steps(steps, registry, the_world, gherkin_types.Given)

  // Clean up world
  world.cleanup(the_world)

  result
}

fn execute_steps(
  steps: List(gherkin_types.Step),
  registry: StepRegistry,
  the_world: World,
  previous_keyword: gherkin_types.StepKeyword,
) -> AssertionResult {
  case steps {
    [] -> AssertionOk
    [step, ..rest] -> {
      case execute_step(step, registry, the_world, previous_keyword) {
        AssertionOk -> {
          let effective_keyword =
            gherkin_types.resolve_keyword(step.keyword, previous_keyword)
          execute_steps(rest, registry, the_world, effective_keyword)
        }
        failure -> failure
      }
    }
  }
}

fn execute_step(
  step: gherkin_types.Step,
  registry: StepRegistry,
  the_world: World,
  previous_keyword: gherkin_types.StepKeyword,
) -> AssertionResult {
  // Resolve And/But to effective keyword
  let effective_keyword =
    gherkin_types.resolve_keyword(step.keyword, previous_keyword)

  // Find matching step definition
  case steps.find_step(registry, effective_keyword, step.text) {
    Ok(match) -> {
      let context = build_step_context(match, step, the_world)
      match.handler(context)
    }
    Error(msg) -> {
      AssertionFailed(AssertionFailure(
        operator: "step",
        message: msg,
        payload: None,
      ))
    }
  }
}

fn build_step_context(
  match: StepMatch(StepHandler),
  step: gherkin_types.Step,
  the_world: World,
) -> StepContext {
  let table = extract_table_from_step(step)
  let doc_string = extract_doc_string_from_step(step)

  StepContext(
    captures: match.captures,
    table: table,
    doc_string: doc_string,
    world: the_world,
  )
}

fn extract_table_from_step(
  step: gherkin_types.Step,
) -> Option(List(List(String))) {
  case step.argument {
    Some(gherkin_types.DataTable(rows)) -> Some(rows)
    _ -> None
  }
}

fn extract_doc_string_from_step(step: gherkin_types.Step) -> Option(String) {
  case step.argument {
    Some(gherkin_types.DocString(content, _)) -> Some(content)
    _ -> None
  }
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
/// A TestSuite that can be run with `runner.run_suite()`
///
/// ## Example
///
/// ```gleam
/// feature("Shopping Cart", steps, [
pub fn feature(
  name: String,
  registry: StepRegistry,
  scenarios: List(InlineScenario),
) -> TestSuite(Nil) {
  let parsed_scenarios = list.map(scenarios, inline_to_parsed_scenario)
  let parsed_feature =
    gherkin_types.Feature(
      name: name,
      description: None,
      tags: [],
      background: None,
      scenarios: parsed_scenarios,
    )

  let config = FeatureConfig(feature: parsed_feature, step_registry: registry)
  to_test_suite(name <> "_test", config)
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
/// scenario("Adding items", [
///   given("I have an empty cart"),
///   when_step("I add 5 items"),
///   then_step("I should have 5 items"),
/// ])
/// ```
///
pub fn scenario(name: String, inline_steps: List(InlineStep)) -> InlineScenario {
  InlineScenario(name: name, steps: inline_steps, tags: [])
}

/// Add tags to a Gherkin scenario for filtering.
///
/// ## Example
///
/// ```gleam
/// scenario("Adding items", [
///   when("I add 2 apples to the cart"),
///   then("the cart should contain 2 items"),
/// ])
/// |> with_tags(["happy-path", "smoke"])
/// ```
///
/// ## Note
///
/// This function is for Gherkin scenarios. For unit tests (`it`), use
/// `dream_test/unit.with_tags` instead.
///
pub fn with_tags(
  inline_scenario: InlineScenario,
  tags: List(String),
) -> InlineScenario {
  InlineScenario(..inline_scenario, tags: tags)
}

/// Create a Given step for inline DSL.
///
/// ## Example
///
/// ```gleam
/// given("I have {int} items in my cart")
/// ```
///
pub fn given(text: String) -> InlineStep {
  InlineStep(keyword: "Given", text: text)
}

/// Create a When step for inline DSL.
///
/// ## Example
///
/// ```gleam
/// when("I add {int} items")
/// ```
///
pub fn when(text: String) -> InlineStep {
  InlineStep(keyword: "When", text: text)
}

/// Create a Then step for inline DSL.
///
/// ## Example
///
/// ```gleam
/// then("I should have {int} items")
/// ```
///
pub fn then(text: String) -> InlineStep {
  InlineStep(keyword: "Then", text: text)
}

/// Create an And step for inline DSL.
///
/// ## Example
///
/// ```gleam
/// and("I have a coupon")
/// ```
///
pub fn and(text: String) -> InlineStep {
  InlineStep(keyword: "And", text: text)
}

/// Create a But step for inline DSL.
///
/// ## Example
///
/// ```gleam
/// but("I should not see errors")
/// ```
///
pub fn but(text: String) -> InlineStep {
  InlineStep(keyword: "But", text: text)
}

fn inline_to_parsed_scenario(inline: InlineScenario) -> gherkin_types.Scenario {
  let parsed_steps = list.map(inline.steps, inline_to_parsed_step)
  gherkin_types.Scenario(
    name: inline.name,
    tags: inline.tags,
    steps: parsed_steps,
  )
}

fn inline_to_parsed_step(inline: InlineStep) -> gherkin_types.Step {
  let keyword = parse_keyword(inline.keyword)
  gherkin_types.Step(keyword: keyword, text: inline.text, argument: None)
}

fn parse_keyword(keyword_str: String) -> gherkin_types.StepKeyword {
  case keyword_str {
    "Given" -> gherkin_types.Given
    "When" -> gherkin_types.When
    "Then" -> gherkin_types.Then
    "And" -> gherkin_types.And
    "But" -> gherkin_types.But
    _ -> gherkin_types.Given
  }
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
/// let bg = background([
///   given("I am logged in"),
///   given("I have an empty cart"),
/// ])
///
/// feature_with_background("Shopping", steps, bg, [...scenarios...])
/// ```
///
pub fn background(inline_steps: List(InlineStep)) -> List(gherkin_types.Step) {
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
pub fn feature_with_background(
  name: String,
  registry: StepRegistry,
  background_steps: List(gherkin_types.Step),
  scenarios: List(InlineScenario),
) -> TestSuite(Nil) {
  let parsed_scenarios = list.map(scenarios, inline_to_parsed_scenario)
  let parsed_feature =
    gherkin_types.Feature(
      name: name,
      description: None,
      tags: [],
      background: Some(gherkin_types.Background(steps: background_steps)),
      scenarios: parsed_scenarios,
    )

  let config = FeatureConfig(feature: parsed_feature, step_registry: registry)
  to_test_suite(name <> "_test", config)
}
