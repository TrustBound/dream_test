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

import dream_test/gherkin/step_trie.{type StepMatch}
import dream_test/gherkin/steps.{
  type StepContext, type StepDefinition, type StepRegistry, Action, Check,
  StepContext,
}
import dream_test/gherkin/types as gherkin_types
import dream_test/types.{
  type AssertionResult, type Node, type TestSuite, AssertionFailed,
  AssertionFailure, AssertionOk, GherkinScenario, Group, NoInput, Root, Test,
}
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
pub fn to_test_suite(config config: FeatureConfig(state)) -> TestSuite(Nil) {
  let feature = config.feature
  let scope =
    ScenarioScope(
      feature_name: feature.name,
      source: feature.source,
      registry: config.step_registry,
      rule_groups: [],
      background_steps: background_steps(feature.background),
    )
  let scenario_nodes = scenarios_to_nodes(scope, feature.scenarios, [])
  let rule_nodes = rules_to_nodes(scope, feature.rules, [])

  Root(
    seed: Nil,
    name: feature.name,
    tags: feature.tags,
    children: list.append(scenario_nodes, rule_nodes),
  )
}

/// What the scenarios of a Feature or a Rule share.
type ScenarioScope(state) {
  ScenarioScope(
    feature_name: String,
    source: Option(String),
    registry: StepRegistry(state),
    rule_groups: List(String),
    background_steps: List(gherkin_types.Step),
  )
}

fn background_steps(
  background: Option(gherkin_types.Background),
) -> List(gherkin_types.Step) {
  case background {
    Some(background) -> background.steps
    None -> []
  }
}

fn rules_to_nodes(
  scope: ScenarioScope(state),
  rules: List(gherkin_types.Rule),
  nodes_newest_first: List(Node(Nil)),
) -> List(Node(Nil)) {
  case rules {
    [] -> list.reverse(nodes_newest_first)
    [rule, ..rest] ->
      rules_to_nodes(scope, rest, [
        rule_to_node(scope, rule),
        ..nodes_newest_first
      ])
  }
}

fn rule_to_node(
  scope: ScenarioScope(state),
  rule: gherkin_types.Rule,
) -> Node(Nil) {
  let group_name = string.trim_end("Rule: " <> rule.name)
  let rule_scope =
    ScenarioScope(
      ..scope,
      rule_groups: [group_name],
      background_steps: list.append(
        scope.background_steps,
        background_steps(rule.background),
      ),
    )
  Group(
    name: group_name,
    tags: rule.tags,
    children: scenarios_to_nodes(rule_scope, rule.scenarios, []),
  )
}

fn scenarios_to_nodes(
  scope: ScenarioScope(state),
  scenarios: List(gherkin_types.Scenario),
  nodes_newest_first: List(Node(Nil)),
) -> List(Node(Nil)) {
  case scenarios {
    [] -> list.reverse(nodes_newest_first)
    [scenario, ..rest] ->
      scenarios_to_nodes(
        scope,
        rest,
        reverse_append(scenario_to_nodes(scope, scenario), nodes_newest_first),
      )
  }
}

fn reverse_append(items: List(a), acc: List(a)) -> List(a) {
  case items {
    [] -> acc
    [item, ..rest] -> reverse_append(rest, [item, ..acc])
  }
}

fn scenario_to_nodes(
  scope: ScenarioScope(state),
  scenario: gherkin_types.Scenario,
) -> List(Node(Nil)) {
  case scenario.examples {
    [] -> [
      scenario_node(
        scope,
        ScenarioRun(
          name: scenario.name,
          tags: scenario.tags,
          steps: scenario.steps,
        ),
      ),
    ]
    examples -> examples_to_nodes(scope, scenario, examples, 1, [])
  }
}

/// One test to build: its name, its own tags and its steps.
type ScenarioRun {
  ScenarioRun(name: String, tags: List(String), steps: List(gherkin_types.Step))
}

fn scenario_node(scope: ScenarioScope(state), run: ScenarioRun) -> Node(Nil) {
  let full_name =
    list.flatten([[scope.feature_name], scope.rule_groups, [run.name]])
  let scenario_id = string.join(full_name, "::")
  let all_steps = with_background(scope.background_steps, run.steps)
  let registry = scope.registry

  Test(
    name: run.name,
    tags: run.tags,
    kind: GherkinScenario(scenario_id),
    run: NoInput(fn() { execute_scenario(scenario_id, all_steps, registry) }),
    timeout_ms: None,
    source: scope.source,
  )
}

/// The steps of a test: the Background steps, then the scenario steps. A
/// scenario with no steps runs no Background steps, as in the official
/// Gherkin compiler.
fn with_background(
  background_steps: List(gherkin_types.Step),
  scenario_steps: List(gherkin_types.Step),
) -> List(gherkin_types.Step) {
  case scenario_steps {
    [] -> []
    _ -> list.append(background_steps, scenario_steps)
  }
}

/// Build the tests of every row of every Examples table. `index` counts the
/// rows of all tables of the scenario, from 1.
fn examples_to_nodes(
  scope: ScenarioScope(state),
  scenario: gherkin_types.Scenario,
  examples: List(gherkin_types.Examples),
  index: Int,
  nodes_newest_first: List(Node(Nil)),
) -> List(Node(Nil)) {
  case examples {
    [] -> list.reverse(nodes_newest_first)
    [gherkin_types.Examples(table: None, ..), ..rest] ->
      examples_to_nodes(scope, scenario, rest, index, nodes_newest_first)
    [gherkin_types.Examples(table: Some(table), ..) as section, ..rest] -> {
      let rows =
        ExampleRows(
          scenario: scenario,
          section: section,
          headers: table.headers,
        )
      let #(next_index, nodes) =
        rows_to_nodes(scope, rows, table.rows, index, nodes_newest_first)
      examples_to_nodes(scope, scenario, rest, next_index, nodes)
    }
  }
}

/// The rows of one Examples table, with the scenario they expand.
type ExampleRows {
  ExampleRows(
    scenario: gherkin_types.Scenario,
    section: gherkin_types.Examples,
    headers: List(String),
  )
}

fn rows_to_nodes(
  scope: ScenarioScope(state),
  rows: ExampleRows,
  values: List(List(String)),
  index: Int,
  nodes_newest_first: List(Node(Nil)),
) -> #(Int, List(Node(Nil))) {
  case values {
    [] -> #(index, nodes_newest_first)
    [row, ..rest] -> {
      let substitutions = list.zip(rows.headers, row)
      let run =
        ScenarioRun(
          name: substitute_placeholders(rows.scenario.name, substitutions)
            <> " ("
            <> example_label(rows, index)
            <> ")",
          tags: list.append(rows.scenario.tags, rows.section.tags),
          steps: substitute_steps(rows.scenario.steps, substitutions),
        )
      rows_to_nodes(scope, rows, rest, index + 1, [
        scenario_node(scope, run),
        ..nodes_newest_first
      ])
    }
  }
}

fn example_label(rows: ExampleRows, index: Int) -> String {
  case rows.section.name {
    "" -> "Example " <> int.to_string(index)
    name -> name <> ", Example " <> int.to_string(index)
  }
}

// Example values replace `<header>` placeholders in the scenario name, the
// step texts, the DocStrings and the DataTable cells. The headers replace in
// column order, as in the official Gherkin compiler.

fn substitute_steps(
  steps: List(gherkin_types.Step),
  substitutions: List(#(String, String)),
) -> List(gherkin_types.Step) {
  substitute_steps_loop(steps, substitutions, [])
}

fn substitute_steps_loop(
  steps: List(gherkin_types.Step),
  substitutions: List(#(String, String)),
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
  substitutions: List(#(String, String)),
) -> gherkin_types.Step {
  gherkin_types.Step(
    keyword: step.keyword,
    text: substitute_placeholders(step.text, substitutions),
    doc_string: substitute_doc_string(step.doc_string, substitutions),
    data_table: substitute_data_table(step.data_table, substitutions),
  )
}

fn substitute_doc_string(
  doc_string: Option(gherkin_types.DocString),
  substitutions: List(#(String, String)),
) -> Option(gherkin_types.DocString) {
  case doc_string {
    Some(gherkin_types.DocString(content, content_type)) ->
      Some(gherkin_types.DocString(
        content: substitute_placeholders(content, substitutions),
        content_type: substitute_content_type(content_type, substitutions),
      ))
    None -> None
  }
}

fn substitute_content_type(
  content_type: Option(String),
  substitutions: List(#(String, String)),
) -> Option(String) {
  case content_type {
    Some(media_type) -> Some(substitute_placeholders(media_type, substitutions))
    None -> None
  }
}

fn substitute_data_table(
  data_table: Option(gherkin_types.DataTable),
  substitutions: List(#(String, String)),
) -> Option(gherkin_types.DataTable) {
  case data_table {
    Some(gherkin_types.DataTable(rows)) ->
      Some(
        gherkin_types.DataTable(rows: substitute_rows(rows, substitutions, [])),
      )
    None -> None
  }
}

fn substitute_rows(
  rows: List(List(String)),
  substitutions: List(#(String, String)),
  rows_newest_first: List(List(String)),
) -> List(List(String)) {
  case rows {
    [] -> list.reverse(rows_newest_first)
    [row, ..rest] ->
      substitute_rows(rest, substitutions, [
        substitute_cells(row, substitutions, []),
        ..rows_newest_first
      ])
  }
}

fn substitute_cells(
  cells: List(String),
  substitutions: List(#(String, String)),
  cells_newest_first: List(String),
) -> List(String) {
  case cells {
    [] -> list.reverse(cells_newest_first)
    [cell, ..rest] ->
      substitute_cells(rest, substitutions, [
        substitute_placeholders(cell, substitutions),
        ..cells_newest_first
      ])
  }
}

fn substitute_placeholders(
  text: String,
  substitutions: List(#(String, String)),
) -> String {
  case substitutions {
    [] -> text
    [#(header, value), ..rest] ->
      substitute_placeholders(
        string.replace(text, "<" <> header <> ">", value),
        rest,
      )
  }
}

// ============================================================================
// Scenario Execution
// ============================================================================

fn execute_scenario(
  scenario_id: String,
  steps: List(gherkin_types.Step),
  registry: StepRegistry(state),
) -> Result(AssertionResult, String) {
  case steps.validate(registry) {
    Ok(Nil) -> Ok(resolve_and_execute(scenario_id, steps, registry))
    Error(message) -> Ok(step_failure(message))
  }
}

fn resolve_and_execute(
  scenario_id: String,
  steps: List(gherkin_types.Step),
  registry: StepRegistry(state),
) -> AssertionResult {
  case resolve_phases(steps, None, []) {
    Ok(phased_steps) ->
      execute_steps(
        ScenarioExecution(scenario_id: scenario_id, registry: registry),
        phased_steps,
        steps.initial_state(registry),
      )
    Error(message) -> step_failure(message)
  }
}

/// The data that stays the same for every step of one scenario.
type ScenarioExecution(state) {
  ScenarioExecution(scenario_id: String, registry: StepRegistry(state))
}

/// The result of one step: run the next step with this state, or stop the
/// scenario with this result.
type StepOutcome(state) {
  Continue(state: state)
  Stop(result: AssertionResult)
}

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
  execution: ScenarioExecution(state),
  phased_steps: List(#(gherkin_types.Step, gherkin_types.StepPhase)),
  state: state,
) -> AssertionResult {
  case phased_steps {
    [] -> AssertionOk
    [#(step, phase), ..rest] ->
      continue_after(
        execution,
        execute_step(execution, step, phase, state),
        rest,
      )
  }
}

fn continue_after(
  execution: ScenarioExecution(state),
  outcome: StepOutcome(state),
  rest: List(#(gherkin_types.Step, gherkin_types.StepPhase)),
) -> AssertionResult {
  case outcome {
    Continue(state) -> execute_steps(execution, rest, state)
    Stop(result) -> result
  }
}

fn execute_step(
  execution: ScenarioExecution(state),
  step: gherkin_types.Step,
  phase: gherkin_types.StepPhase,
  state: state,
) -> StepOutcome(state) {
  case steps.find_step(execution.registry, phase, step.text) {
    Ok(match) ->
      run_definition(
        match.handler,
        build_step_context(execution, match, step),
        state,
      )
    Error(message) -> Stop(step_failure(message))
  }
}

fn run_definition(
  definition: StepDefinition(state),
  context: StepContext,
  state: state,
) -> StepOutcome(state) {
  case definition {
    Action(run) -> action_outcome(run(state, context))
    Check(run) -> check_outcome(run(state, context), state)
  }
}

fn action_outcome(result: Result(state, String)) -> StepOutcome(state) {
  case result {
    Ok(new_state) -> Continue(new_state)
    Error(message) -> Stop(step_failure(message))
  }
}

fn check_outcome(
  result: Result(AssertionResult, String),
  state: state,
) -> StepOutcome(state) {
  case result {
    Ok(AssertionOk) -> Continue(state)
    Ok(failure) -> Stop(failure)
    Error(message) -> Stop(step_failure(message))
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
  execution: ScenarioExecution(state),
  match: StepMatch(StepDefinition(state)),
  step: gherkin_types.Step,
) -> StepContext {
  StepContext(
    captures: match.captures,
    table: extract_table_from_step(step),
    doc_string: extract_doc_string_from_step(step),
    scenario_id: execution.scenario_id,
  )
}

fn extract_table_from_step(
  step: gherkin_types.Step,
) -> Option(List(List(String))) {
  case step.data_table {
    Some(gherkin_types.DataTable(rows)) -> Some(rows)
    None -> None
  }
}

fn extract_doc_string_from_step(step: gherkin_types.Step) -> Option(String) {
  case step.doc_string {
    Some(gherkin_types.DocString(content, _)) -> Some(content)
    None -> None
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
) -> TestSuite(Nil) {
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
