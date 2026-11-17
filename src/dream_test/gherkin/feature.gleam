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
////   // Define step handlers
////   let steps =
////     steps.new()
////     |> given("the server is running", step_server_running)
////     |> given("the cart is empty", step_empty_cart)
////     |> when_("I add {int} items", step_add_items)
////     |> then_("the cart should have {int} items", step_verify_count)
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
////     steps.new()
////     |> given("the server is running", step_server_running)
////     |> given("the cart is empty", step_empty_cart)
////     |> when_("I add {int} items", step_add_items)
////     |> then_("the cart should have {int} items", step_verify_count)
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

import dream_test/gherkin/step_trie.{type StepMatch}
import dream_test/gherkin/steps.{
  type StepContext, type StepHandler, type StepRegistry, StepContext,
}
import dream_test/gherkin/types as gherkin_types
import dream_test/gherkin/world.{type World}
import dream_test/types.{
  type AssertionResult, type Node, type TestSuite, AssertionFailed,
  AssertionFailure, AssertionOk, GherkinScenario, Root, Test,
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
/// Creates a TestSuite with one test per scenario. Background steps are
/// prepended to each scenario, so a scenario that starts with `And`, `But` or
/// `*` takes the phase of the last Background step. ScenarioOutlines are expanded based on
/// their examples table.
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
pub fn to_test_suite(config config: FeatureConfig) -> TestSuite(Nil) {
  let feature = config.feature
  let children = build_suite_items(feature, config)

  Root(seed: Nil, name: feature.name, tags: feature.tags, children: children)
}

fn build_suite_items(
  feature: gherkin_types.Feature,
  config: FeatureConfig,
) -> List(Node(Nil)) {
  build_suite_items_loop(feature, feature.scenarios, config, [])
}

fn build_suite_items_loop(
  feature: gherkin_types.Feature,
  scenarios: List(gherkin_types.Scenario),
  config: FeatureConfig,
  acc_rev: List(Node(Nil)),
) -> List(Node(Nil)) {
  case scenarios {
    [] -> list.reverse(acc_rev)
    [scenario, ..rest] -> {
      let items = scenario_to_suite_items(feature, scenario, config)
      build_suite_items_loop(
        feature,
        rest,
        config,
        reverse_append(items, acc_rev),
      )
    }
  }
}

fn reverse_append(items: List(a), acc: List(a)) -> List(a) {
  case items {
    [] -> acc
    [item, ..rest] -> reverse_append(rest, [item, ..acc])
  }
}

fn scenario_to_suite_items(
  feature: gherkin_types.Feature,
  scenario: gherkin_types.Scenario,
  config: FeatureConfig,
) -> List(Node(Nil)) {
  case scenario {
    gherkin_types.Scenario(name, tags, steps) -> {
      let test_node =
        build_scenario_test_node(feature, name, tags, steps, config, None)
      [test_node]
    }
    gherkin_types.ScenarioOutline(name, tags, steps, examples) -> {
      expand_scenario_outline(feature, name, tags, steps, examples, config)
    }
  }
}

fn build_scenario_test_node(
  feature: gherkin_types.Feature,
  scenario_name: String,
  scenario_tags: List(String),
  steps: List(gherkin_types.Step),
  config: FeatureConfig,
  example_suffix: Option(String),
) -> Node(Nil) {
  let full_name = build_full_name(feature.name, scenario_name, example_suffix)
  let scenario_id = string.join(full_name, "::")
  let all_tags = list.append(feature.tags, scenario_tags)

  // Combine background and scenario steps
  let all_steps = case feature.background {
    Some(gherkin_types.Background(background_steps)) ->
      list.append(background_steps, steps)
    None -> steps
  }
  Test(
    name: scenario_name,
    tags: all_tags,
    kind: GherkinScenario(scenario_id),
    run: fn(_nil: Nil) {
      Ok(execute_scenario(scenario_id, all_steps, config.step_registry))
    },
    timeout_ms: None,
    source: feature.source,
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
) -> List(Node(Nil)) {
  let headers = examples.headers

  expand_scenario_outline_rows_loop(
    feature,
    name,
    tags,
    steps,
    config,
    headers,
    examples.rows,
    0,
    [],
  )
}

fn expand_scenario_outline_rows_loop(
  feature: gherkin_types.Feature,
  name: String,
  tags: List(String),
  steps: List(gherkin_types.Step),
  config: FeatureConfig,
  headers: List(String),
  rows: List(List(String)),
  index: Int,
  acc_rev: List(Node(Nil)),
) -> List(Node(Nil)) {
  case rows {
    [] -> list.reverse(acc_rev)
    [row, ..rest] -> {
      let substitutions = build_substitution_map(headers, row)
      let expanded_steps = substitute_steps(steps, substitutions)
      let suffix = "(Example " <> int.to_string(index + 1) <> ")"

      let node =
        build_scenario_test_node(
          feature,
          name,
          tags,
          expanded_steps,
          config,
          Some(suffix),
        )

      expand_scenario_outline_rows_loop(
        feature,
        name,
        tags,
        steps,
        config,
        headers,
        rest,
        index + 1,
        [node, ..acc_rev],
      )
    }
  }
}

fn build_substitution_map(
  headers: List(String),
  values: List(String),
) -> Dict(String, String) {
  build_substitution_map_loop(list.zip(headers, values), dict.new())
}

fn build_substitution_map_loop(
  pairs: List(#(String, String)),
  acc: Dict(String, String),
) -> Dict(String, String) {
  case pairs {
    [] -> acc
    [#(header, value), ..rest] ->
      build_substitution_map_loop(rest, dict.insert(acc, header, value))
  }
}

fn substitute_steps(
  steps: List(gherkin_types.Step),
  substitutions: Dict(String, String),
) -> List(gherkin_types.Step) {
  substitute_steps_loop(steps, substitutions, [])
}

fn substitute_steps_loop(
  steps: List(gherkin_types.Step),
  substitutions: Dict(String, String),
  acc_rev: List(gherkin_types.Step),
) -> List(gherkin_types.Step) {
  case steps {
    [] -> list.reverse(acc_rev)
    [step, ..rest] ->
      substitute_steps_loop(rest, substitutions, [
        substitute_step(step, substitutions),
        ..acc_rev
      ])
  }
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
  substitute_placeholders_loop(dict.to_list(substitutions), text)
}

fn substitute_placeholders_loop(
  pairs: List(#(String, String)),
  acc: String,
) -> String {
  case pairs {
    [] -> acc
    [#(header, value), ..rest] -> {
      let placeholder = "<" <> header <> ">"
      let next = string.replace(acc, placeholder, value)
      substitute_placeholders_loop(rest, next)
    }
  }
}

// ============================================================================
// Scenario Execution
// ============================================================================

fn execute_scenario(
  scenario_id: String,
  steps: List(gherkin_types.Step),
  registry: StepRegistry,
) -> AssertionResult {
  case steps.validate(registry) {
    Ok(Nil) -> resolve_and_execute(scenario_id, steps, registry)
    Error(message) -> step_failure(message)
  }
}

/// Find the phase of every step before any step runs, so a step with no
/// phase fails the scenario before the Background has side effects.
fn resolve_and_execute(
  scenario_id: String,
  steps: List(gherkin_types.Step),
  registry: StepRegistry,
) -> AssertionResult {
  case resolve_phases(steps, None, []) {
    Ok(phased_steps) -> execute_in_world(scenario_id, phased_steps, registry)
    Error(message) -> step_failure(message)
  }
}

fn execute_in_world(
  scenario_id: String,
  phased_steps: List(#(gherkin_types.Step, gherkin_types.StepPhase)),
  registry: StepRegistry,
) -> AssertionResult {
  let the_world = world.new_world(scenario_id)
  let result = execute_steps(phased_steps, registry, the_world)
  world.cleanup(the_world)
  result
}

/// Pair each step with its phase. The Background steps come first in
/// `steps`, so the first scenario step takes the phase of the last
/// Background step.
fn resolve_phases(
  steps: List(gherkin_types.Step),
  previous: Option(gherkin_types.StepPhase),
  phased_newest_first: List(#(gherkin_types.Step, gherkin_types.StepPhase)),
) -> Result(List(#(gherkin_types.Step, gherkin_types.StepPhase)), String) {
  case steps {
    [] -> Ok(list.reverse(phased_newest_first))
    [step, ..rest] ->
      resolve_step_phase(step, rest, previous, phased_newest_first)
  }
}

fn resolve_step_phase(
  step: gherkin_types.Step,
  rest: List(gherkin_types.Step),
  previous: Option(gherkin_types.StepPhase),
  phased_newest_first: List(#(gherkin_types.Step, gherkin_types.StepPhase)),
) -> Result(List(#(gherkin_types.Step, gherkin_types.StepPhase)), String) {
  case gherkin_types.resolve_phase(step.keyword, previous) {
    Ok(phase) ->
      resolve_phases(rest, Some(phase), [#(step, phase), ..phased_newest_first])
    Error(Nil) -> Error(no_previous_step_message(step))
  }
}

fn no_previous_step_message(step: gherkin_types.Step) -> String {
  "\""
  <> gherkin_types.keyword_to_string(step.keyword)
  <> " "
  <> step.text
  <> "\" has no step before it. And, But and * take the phase of the step before them, so the first step of a Background, or of a Scenario with no Background steps, must use Given, When or Then."
}

fn execute_steps(
  phased_steps: List(#(gherkin_types.Step, gherkin_types.StepPhase)),
  registry: StepRegistry,
  the_world: World,
) -> AssertionResult {
  case phased_steps {
    [] -> AssertionOk
    [#(step, phase), ..rest] ->
      continue_after(
        execute_step(step, phase, registry, the_world),
        rest,
        registry,
        the_world,
      )
  }
}

fn continue_after(
  result: AssertionResult,
  rest: List(#(gherkin_types.Step, gherkin_types.StepPhase)),
  registry: StepRegistry,
  the_world: World,
) -> AssertionResult {
  case result {
    AssertionOk -> execute_steps(rest, registry, the_world)
    failure -> failure
  }
}

fn execute_step(
  step: gherkin_types.Step,
  phase: gherkin_types.StepPhase,
  registry: StepRegistry,
  the_world: World,
) -> AssertionResult {
  case steps.find_step(registry, phase, step.text) {
    Ok(match) -> run_handler(match, step, the_world)
    Error(message) -> step_failure(message)
  }
}

fn run_handler(
  match: StepMatch(StepHandler),
  step: gherkin_types.Step,
  the_world: World,
) -> AssertionResult {
  let context = build_step_context(match, step, the_world)
  case match.handler(context) {
    Ok(result) -> result
    Error(message) -> step_failure(message)
  }
}

fn step_failure(message: String) -> AssertionResult {
  AssertionFailed(AssertionFailure(
    operator: "step",
    message: message,
    payload: None,
  ))
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
/// A TestSuite that can be run with `runner.new([suite]) |> runner.run()`.
///
/// ## Example
///
/// ```gleam
/// let steps =
///   steps.new()
///   |> given("I have {int} items in my cart", step_have_items)
///   |> when_("I add {int} more items", step_add_items)
///   |> then_("I should have {int} items total", step_should_have)
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
  registry registry: StepRegistry,
  scenarios scenarios: List(InlineScenario),
) -> TestSuite(Nil) {
  let parsed_scenarios = list.map(scenarios, inline_to_parsed_scenario)
  let parsed_feature =
    gherkin_types.Feature(
      name: name,
      source: None,
      description: None,
      tags: [],
      background: None,
      scenarios: parsed_scenarios,
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
    name: inline.name,
    tags: inline.tags,
    steps: parsed_steps,
  )
}

fn inline_to_parsed_step(inline: InlineStep) -> gherkin_types.Step {
  gherkin_types.Step(keyword: inline.keyword, text: inline.text, argument: None)
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
  registry registry: StepRegistry,
  background_steps background_steps: List(gherkin_types.Step),
  scenarios scenarios: List(InlineScenario),
) -> TestSuite(Nil) {
  let parsed_scenarios = list.map(scenarios, inline_to_parsed_scenario)
  let parsed_feature =
    gherkin_types.Feature(
      name: name,
      source: None,
      description: None,
      tags: [],
      background: Some(gherkin_types.Background(steps: background_steps)),
      scenarios: parsed_scenarios,
    )

  let config = FeatureConfig(feature: parsed_feature, step_registry: registry)
  to_test_suite(config)
}
