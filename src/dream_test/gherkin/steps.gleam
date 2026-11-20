//// Step definition registry for Gherkin scenarios.
////
//// Use this module to:
////
//// - Build a `StepRegistry(state)` with the state type of your feature, its
////   initial value, and one step definition for each pattern.
//// - Match step text against registered patterns (including typed placeholders).
//// - Extract typed captures (`{int}`, `{float}`, `{string}`, `{word}`, `{}`).
////
//// ## Scenario state
////
//// Each feature has one state type that you choose, for example a record with
//// a cart and a checkout result. `new(initial:)` gets its initial value. Each
//// scenario starts from the initial value in its own process. The steps of the
//// scenario then pass the value from one step to the next:
////
//// - A `given` or `when` step is an action. It gets the state and returns the
////   new state, or an error.
//// - A `then` step is a check. It gets the state and returns an assertion
////   result. It cannot change the state.
////
//// The state is an immutable value, so two scenarios cannot share it, and
//// nothing needs cleanup after a scenario.
////
//// ## Example
////
//// ```gleam
//// fn step_have_items(_count: Int, context: StepContext) {
////   get_int(context.captures, 0)
//// }
////
//// fn step_add_items(count: Int, context: StepContext) {
////   use added <- result.try(get_int(context.captures, 0))
////   Ok(count + added)
//// }
////
//// fn step_should_have(count: Int, context: StepContext) {
////   use expected <- result.try(get_int(context.captures, 0))
////   count
////   |> should
////   |> be_equal(expected)
////   |> or_fail_with("Cart count mismatch")
//// }
////
//// let steps =
////   new(initial: 0)
////   |> given("I have {int} items in my cart", step_have_items)
////   |> when("I add {int} more items", step_add_items)
////   |> then("I should have {int} items total", step_should_have)
//// ```
////
//// ## Phases
////
//// Every step definition belongs to exactly one phase: `given` (Arrange),
//// `when` (Act) or `then` (Assert). A step matches only the definitions of
//// its phase. `And`, `But` and `*` steps take the phase of the step before
//// them. The phase sets what a definition can do: a `given` or `when`
//// definition is an action that changes the state, and a `then` definition
//// is a check that cannot change it.
////
//// Each pattern can have one definition for each phase. A second definition
//// of the same pattern in the same phase is an error: `find_step` and
//// `validate` return it, and every scenario that uses the registry fails with
//// it.
////
//// ## Placeholder types
////
//// Step patterns use typed placeholders:
////
//// - `{int}`: integers (e.g. `42`, `-5`)
//// - `{float}`: numbers as Cucumber reads them (e.g. `3.14`, `-0.5`, `20`, `1e5`)
//// - `{string}`: double-quoted strings (e.g. `"hello world"`)
//// - `{word}`: a run of characters with no space (e.g. `alice`, `user42`)
//// - `{}`: any text in one word
////
//// Placeholders can include literal prefixes/suffixes. For example, `${float}`
//// matches `$19.99` but captures `19.99` as a `Float`.
////
//// Step text and patterns are split into words in the same way: at spaces,
//// with a double-quoted run kept in one word. So a pattern without
//// placeholders always matches its own text. When more than one pattern
//// matches, a literal word wins over a placeholder. See
//// `dream_test/gherkin/step_trie` for the full priority rules.
////
//// ## Capture errors
////
//// The capture helpers return a `Result`. Pass the error on with
//// `result.try`, so the scenario fails with a message that names the capture,
//// for example `Capture 0 is the word "apples", not an integer`. Do not hide
//// the error with `result.unwrap`: the scenario then runs with a wrong value.

import dream_test/gherkin/step_trie.{
  type CapturedValue, type StepMatch, type StepTrie, CapturedFloat, CapturedInt,
  CapturedString, CapturedWord, StepMatch,
}
import dream_test/gherkin/types.{
  type StepPhase, GivenPhase, ThenPhase, WhenPhase,
}
import dream_test/suite.{type TestSuite}
import dream_test/types as dream_types
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// ============================================================================
// Types
// ============================================================================

/// The data of the step that runs, apart from the scenario state.
///
/// - `captures` - Values captured from pattern placeholders
/// - `table` - Optional DataTable argument from the step
/// - `doc_string` - Optional DocString argument from the step
/// - `scenario_id` - The id of the scenario, unique in the run
///
/// ## Example
///
/// ```gleam
/// fn step_order_name(_order: Order, context: StepContext) {
///   Ok(Order(name: context.scenario_id))
/// }
/// ```
///
pub type StepContext {
  StepContext(
    /// Values captured from pattern placeholders, in order
    captures: List(CapturedValue),
    /// Optional DataTable attached to the step
    table: Option(List(List(String))),
    /// Optional DocString attached to the step
    doc_string: Option(String),
    /// The scenario id: the Feature name, the Rule group (if any) and the
    /// scenario name, joined with `::`, then `#` and a number, for
    /// example `"Shopping Cart::Adding items#12"`. The id is unique in the
    /// run, also for two scenarios with the same name. Use it to make names
    /// (for example database rows or files) that no other scenario uses.
    /// The number after `#` changes between runs, so do not use the id to
    /// key data that you keep between runs.
    scenario_id: String,
  )
}

/// A step definition that `find_step` found.
///
/// The phase of the definition sets its kind:
///
/// - `Action(run)`: a `given` or `when` definition. `run` gets the state and
///   the step context, and returns the new state. An `Error(message)` fails
///   the scenario with `message`, and the steps after it do not run.
/// - `Check(run)`: a `then` definition. `run` gets the state and the step
///   context, and returns an assertion result, like a unit test body. A
///   failed assertion or an `Error(message)` fails the scenario, and the
///   steps after it do not run. The next step gets the same state.
///
/// You do not make a `StepDefinition`: `given`, `when` and `then` take your
/// function directly.
///
/// ## Example
///
/// ```gleam
///       let registry =
///         steps.new(initial: 0)
///         |> then("I should have {int} items", step_should_have)
///
///       use matched <- result.try(find_step(
///         registry,
///         ThenPhase,
///         "I should have 3 items",
///       ))
///
///       case matched.handler {
///         Action(_) -> Ok(fail_with("a Then definition is never an action"))
///         Check(_) -> Ok(succeed())
///       }
/// ```
///
pub type StepDefinition(state) {
  /// A `given` or `when` definition. It changes the state.
  Action(run: StepAction(state))
  /// A `then` definition. It makes sure the state is correct.
  Check(run: StepCheck(state))
}

/// The function of a `given` or `when` step: it gets the state and the step
/// context, and returns the new state or an error message.
type StepAction(state) =
  fn(state, StepContext) -> Result(state, String)

/// The function of a `then` step: it gets the state and the step context,
/// and returns an assertion result or an error message.
type StepCheck(state) =
  fn(state, StepContext) -> Result(dream_types.AssertionResult, String)

/// Step registry backed by radix trie.
///
/// Stores where each scenario gets its starting state and the step
/// definitions, and provides fast lookup.
///
/// “Fast” here means lookup cost grows with the **length of the step text**,
/// not with how many step definitions you’ve registered.
///
pub opaque type StepRegistry(state) {
  StepRegistry(
    /// Where each scenario gets its starting state: a fixed value
    /// (`new`) or a setup (`new_with_setup`), never both.
    start: dream_types.SuiteContext(state),
    /// The `given` and `when` definitions.
    actions: StepTrie(StepAction(state)),
    /// The `then` definitions.
    checks: StepTrie(StepCheck(state)),
    /// Duplicate step definition errors, newest first.
    errors_newest_first: List(String),
  )
}

// ============================================================================
// Registry Construction
// ============================================================================

/// Create an empty step registry with the initial scenario state.
///
/// Each scenario that runs with this registry starts from `initial`. Chain
/// `given`, `when` and `then` calls to add steps.
///
/// ## Example
///
/// ```gleam
/// let steps =
///   new(initial: 0)
///   |> given("I have {int} items", step_have_items)
///   |> then("I should have {int} items", step_should_have)
/// ```
///
pub fn new(initial initial: state) -> StepRegistry(state) {
  StepRegistry(
    start: dream_types.FixedContext(initial),
    actions: step_trie.new(),
    checks: step_trie.new(),
    errors_newest_first: [],
  )
}

/// Create an empty step registry whose scenarios start from the value of
/// a setup.
///
/// `setup` runs once for each tree that the registry builds, that is for
/// each suite that `feature.to_suite`, `steps.to_suite` or
/// `gherkin/discover.to_suite` makes from it. It runs before the first
/// scenario of that tree, and only when at least one of its scenarios
/// runs. `gherkin/discover.to_suite` makes one tree for the scenarios of
/// all the files, so the setup runs once for all of them. Each scenario starts from its value, so a change that one
/// scenario makes to its state does not reach the next one. `teardown`
/// gets the same value after the last scenario.
///
/// The setup and the teardown run in one process that lives while the
/// scenarios run, so a server that the setup starts and links stays
/// alive. When `setup` returns `Error`, crashes or times out, each
/// scenario is `SetupFailed` with the operator `context setup` and `teardown`
/// does not run. See `unit_context.describe_with_setup` for the other
/// cases.
///
/// ## Example
///
/// ```gleam
/// let steps =
///   new_with_setup(setup: start_server, teardown: stop_server)
///   |> given("the server is running", step_server_running)
///   |> when("I ping the server", step_ping)
///   |> then("the reply is {string}", step_reply_is)
/// ```
///
pub fn new_with_setup(
  setup setup: fn() -> Result(state, String),
  teardown teardown: fn(state) -> Result(Nil, String),
) -> StepRegistry(state) {
  StepRegistry(
    start: dream_types.ContextFromSetup(setup: setup, teardown: teardown),
    actions: step_trie.new(),
    checks: step_trie.new(),
    errors_newest_first: [],
  )
}

/// One child of the suite of `to_suite`.
///
/// `Group` and `Feature` have the same names as `dream_test/types.Group`
/// and `dream_test/gherkin/types.Feature`. When a module imports two of
/// these names unqualified, the compiler reports the clash as an error.
/// Then write the child qualified, for example `steps.Feature(cart)` or
/// `steps.Group(...)`.
///
/// - `Feature(feature)`: a group named after the Feature, with its tags and
///   a test for each scenario, as in `feature.to_suite`. The scenarios
///   run with the steps of the registry of `to_suite`. A Feature gets its
///   tests only here, so it cannot run with the steps of one registry and
///   the start of another.
/// - `Scenarios(feature)`: the tests of the scenarios of a Feature, and a
///   group for each Rule, with no group for the Feature. The tags of the
///   Feature itself are not on these tests.
/// - `Group(name, tags, children)`: a group of your own, for example with a
///   tag, that holds more children.
/// - `Node(node)`: a test, a hook or a group that you make, for example
///   with `unit_context.it` or `unit_context.before_each`. It gets the same
///   start as the scenarios.
pub type SuiteChild(state) {
  Feature(feature: types.Feature)
  Scenarios(feature: types.Feature)
  Group(name: String, tags: List(String), children: List(SuiteChild(state)))
  Node(node: dream_types.Node(state))
}

/// Make a suite whose tests start as the registry says: from the state of
/// `new`, or from the value of the setup of `new_with_setup`. The setup
/// runs one time for all the children, and only when at least one of
/// their tests runs.
///
/// `feature.to_suite` and `gherkin/discover.to_suite` use it. Use it
/// to run several Features with one start, for example one server for all
/// of them. The scenarios of every `Feature` and `Scenarios` child run with
/// the steps of `registry`.
///
/// ## Parameters
///
/// - `registry`: the steps, and where each test starts
/// - `name`: the name of the top-level group
/// - `tags`: the tags of the top-level group
/// - `children`: the Features, groups, tests and hooks (see `SuiteChild`)
///
/// ## Example
///
/// ```gleam
/// to_suite(registry: steps, name: "Shop", tags: [], children: [
///   Feature(cart),
///   Group(name: "Billing", tags: ["billing"], children: [
///     Feature(invoice),
///   ]),
///   Node(unit_context.it("the server answers", answers)),
/// ])
/// ```
///
pub fn to_suite(
  registry registry: StepRegistry(state),
  name name: String,
  tags tags: List(String),
  children children: List(SuiteChild(state)),
) -> TestSuite {
  suite.new(
    name: name,
    tags: tags,
    children: children_to_nodes(children, registry),
    context: registry.start,
  )
}

/// The suite of one Feature, for `feature.to_suite`: the top-level group of
/// the suite is the group of the Feature, so its scenarios have
/// `feature: Some(feature.name)`. With `to_suite` and `Scenarios` they
/// would have `None`, and with `Feature` the Feature group would be
/// inside one more group.
@internal
pub fn feature_suite(
  registry registry: StepRegistry(state),
  feature feature: types.Feature,
) -> TestSuite {
  suite.new(
    name: feature.name,
    tags: feature.tags,
    children: feature_children(feature, registry, Some(feature.name)),
    context: registry.start,
  )
}

fn children_to_nodes(
  children: List(SuiteChild(state)),
  registry: StepRegistry(state),
) -> List(dream_types.Node(state)) {
  case children {
    [] -> []
    [child, ..rest] ->
      list.append(
        child_to_nodes(child, registry),
        children_to_nodes(rest, registry),
      )
  }
}

fn child_to_nodes(
  child: SuiteChild(state),
  registry: StepRegistry(state),
) -> List(dream_types.Node(state)) {
  case child {
    Feature(feature) -> [
      dream_types.Group(
        name: feature.name,
        tags: feature.tags,
        children: feature_children(feature, registry, Some(feature.name)),
      ),
    ]
    Scenarios(feature) -> feature_children(feature, registry, None)
    Group(name: name, tags: tags, children: children) -> [
      dream_types.Group(
        name: name,
        tags: tags,
        children: children_to_nodes(children, registry),
      ),
    ]
    Node(node) -> [node]
  }
}

/// Register a Given step definition.
///
/// Given steps arrange the initial context. A Given step is an action: it
/// gets the state and returns the new state.
///
/// ## Parameters
///
/// - `registry`: The registry to add to
/// - `pattern`: Step pattern with placeholders
/// - `action`: Gets the state and the step context, and returns the new
///   state, or an error message that fails the scenario
///
/// ## Returns
///
/// A new registry containing the added step.
///
/// ## Example
///
/// ```gleam
///       let registry =
///         new(initial: 0) |> given("I have {int} items", step_count)
/// ```
///
pub fn given(
  registry registry: StepRegistry(state),
  pattern pattern: String,
  action action: fn(state, StepContext) -> Result(state, String),
) -> StepRegistry(state) {
  register_action(registry, GivenPhase, pattern, action)
}

/// Register a When step definition.
///
/// When steps do the action or event under test. A When step is an action:
/// it gets the state and returns the new state.
///
/// ## Parameters
///
/// - `registry`: The registry to add to
/// - `pattern`: Step pattern with placeholders
/// - `action`: Gets the state and the step context, and returns the new
///   state, or an error message that fails the scenario
///
/// ## Returns
///
/// A new registry containing the added step.
///
/// ## Example
///
/// ```gleam
///       let registry =
///         new(initial: 0) |> when("I add {int} items", step_add)
/// ```
///
pub fn when(
  registry registry: StepRegistry(state),
  pattern pattern: String,
  action action: fn(state, StepContext) -> Result(state, String),
) -> StepRegistry(state) {
  register_action(registry, WhenPhase, pattern, action)
}

/// Register a Then step definition.
///
/// Then steps assert the expected outcome. A Then step is a check: it gets
/// the state and returns an assertion result. It cannot change the state,
/// so the next step gets the same state.
///
/// ## Parameters
///
/// - `registry`: The registry to add to
/// - `pattern`: Step pattern with placeholders
/// - `check`: Gets the state and the step context, and returns an assertion
///   result, or an error message that fails the scenario
///
/// ## Returns
///
/// A new registry containing the added step.
///
/// ## Example
///
/// ```gleam
///       let registry =
///         new(initial: 0)
///         |> then("I should have {int} items", step_should_have)
/// ```
///
pub fn then(
  registry registry: StepRegistry(state),
  pattern pattern: String,
  check check: fn(state, StepContext) ->
    Result(dream_types.AssertionResult, String),
) -> StepRegistry(state) {
  case step_trie.insert(registry.checks, ThenPhase, pattern, check) {
    Ok(updated) -> StepRegistry(..registry, checks: updated)
    Error(message) -> record_error(registry, message)
  }
}

/// Add a Given or When step definition, or record a duplicate step
/// definition error.
fn register_action(
  registry: StepRegistry(state),
  phase: StepPhase,
  pattern: String,
  action: StepAction(state),
) -> StepRegistry(state) {
  case step_trie.insert(registry.actions, phase, pattern, action) {
    Ok(updated) -> StepRegistry(..registry, actions: updated)
    Error(message) -> record_error(registry, message)
  }
}

fn record_error(
  registry: StepRegistry(state),
  message: String,
) -> StepRegistry(state) {
  StepRegistry(..registry, errors_newest_first: [
    message,
    ..registry.errors_newest_first
  ])
}

/// Check a registry for duplicate step definitions.
///
/// Registering the same pattern twice in one phase (for example two `given`
/// calls with `"I have {int} items"`) is an error. The builder functions keep
/// the first definition and record the error. `validate` returns the
/// recorded errors, one per line. Every scenario that runs with a registry
/// that has errors fails with this message, so a duplicate cannot be missed.
///
/// The same pattern in different phases (for example `given` and `then`) is
/// not a duplicate.
///
/// ## Returns
///
/// - `Ok(Nil)`: The registry has no duplicate step definitions
/// - `Error(String)`: One line for each duplicate step definition
///
/// ## Example
///
/// ```gleam
///       new(initial: 0)
///       |> given("I have {int} items", step_count)
///       |> given("I have {int} items", step_count)
///       |> validate
///       |> should
///       |> be_equal(Error(
///         "Duplicate step definition: Given \"I have {int} items\" is already defined. Each pattern can have one definition for each of Given, When and Then.",
///       ))
///       |> or_fail_with("expected a duplicate step definition error")
/// ```
///
pub fn validate(registry registry: StepRegistry(state)) -> Result(Nil, String) {
  case registry.errors_newest_first {
    [] -> Ok(Nil)
    errors -> Error(string.join(list.reverse(errors), "\n"))
  }
}

// ============================================================================
// Step Lookup
// ============================================================================

/// Find a matching step definition.
///
/// Searches the registry for a definition of the given phase that matches
/// the text. Returns the definition (as `handler`) and captured values on
/// success, or an error
/// message. A registry with duplicate step definitions gives the error of
/// `validate`.
///
/// ## Performance
///
/// Lookup follows the words of the step text through a trie, so its cost
/// depends on the number of words in the step text, not on the number of
/// registered steps. When a branch of the trie does not match, lookup goes
/// back and tries the next branch. Each branch that it tries adds to the
/// cost.
///
/// Words are separated by spaces. A double-quoted string is one word:
/// - `"I add 2 items"` → 4 words (`["I", "add", "2", "items"]`)
/// - `"the message is \"hello world\""` → 4 words (`["the", "message", "is", "\"hello world\""]`)
///
/// ## Parameters
///
/// - `registry`: The registry to search
/// - `phase`: The phase of the step (`GivenPhase`, `WhenPhase` or
///   `ThenPhase`). Resolve `And`, `But` and `*` steps with
///   `types.resolve_phase` first.
/// - `text`: Step text to match
///
/// ## Returns
///
/// - `Ok(StepMatch)`: Contains the matched definition and captured values
/// - `Error(String)`: Error message if no match found
///
/// ## Example
///
/// ```gleam
///       let registry =
///         new(initial: 0) |> given("I have {int} items", step_count)
///
///       use matched <- result.try(find_step(registry, GivenPhase, "I have 3 items"))
///
///       capture_count(matched.captures)
///       |> should
///       |> be_equal(1)
///       |> or_fail_with("expected exactly one capture")
/// ```
///
pub fn find_step(
  registry registry: StepRegistry(state),
  phase phase: StepPhase,
  text text: String,
) -> Result(StepMatch(StepDefinition(state)), String) {
  case validate(registry) {
    Ok(Nil) -> lookup_step(registry, phase, text)
    Error(message) -> Error(message)
  }
}

fn lookup_step(
  registry: StepRegistry(state),
  phase: StepPhase,
  text: String,
) -> Result(StepMatch(StepDefinition(state)), String) {
  case phase {
    ThenPhase -> lookup_check(registry, text)
    GivenPhase | WhenPhase -> lookup_action(registry, phase, text)
  }
}

fn lookup_action(
  registry: StepRegistry(state),
  phase: StepPhase,
  text: String,
) -> Result(StepMatch(StepDefinition(state)), String) {
  case step_trie.lookup(registry.actions, phase, text) {
    Some(StepMatch(handler: action, captures: captures)) ->
      Ok(StepMatch(handler: Action(action), captures: captures))
    None -> Error(undefined_step_message(phase, text))
  }
}

fn lookup_check(
  registry: StepRegistry(state),
  text: String,
) -> Result(StepMatch(StepDefinition(state)), String) {
  case step_trie.lookup(registry.checks, ThenPhase, text) {
    Some(StepMatch(handler: check, captures: captures)) ->
      Ok(StepMatch(handler: Check(check), captures: captures))
    None -> Error(undefined_step_message(ThenPhase, text))
  }
}

fn undefined_step_message(phase: StepPhase, text: String) -> String {
  "Undefined step: " <> types.phase_to_string(phase) <> " " <> text
}

// ============================================================================
// Capture Extraction Helpers
// ============================================================================

/// Get an Int capture by index (0-based).
///
/// Returns the captured integer value at the given index, or an error
/// if the index is out of bounds or the value isn't an integer.
///
/// ## Parameters
///
/// - `captures`: List of captured values from StepContext
/// - `index`: 0-based index of the capture to retrieve
///
/// ## Example
///
/// ```gleam
/// fn step_int(_value: Int, context: StepContext) {
///   get_int(context.captures, 0)
/// }
/// ```
///
pub fn get_int(
  captures captures: List(CapturedValue),
  index index: Int,
) -> Result(Int, String) {
  case list_at(captures, index) {
    Some(CapturedInt(value)) -> Ok(value)
    Some(other) -> Error(wrong_capture_message(index, other, "an integer"))
    None -> Error(missing_capture_message(captures, index))
  }
}

/// Get a Float capture by index (0-based).
///
/// Returns the captured float value at the given index, or an error
/// if the index is out of bounds or the value isn't a float.
///
/// ## Parameters
///
/// - `captures`: List of captured values from StepContext
/// - `index`: 0-based index of the capture to retrieve
///
/// ## Example
///
/// ```gleam
/// fn step_float(_value: Float, context: StepContext) {
///   get_float(context.captures, 0)
/// }
/// ```
///
pub fn get_float(
  captures captures: List(CapturedValue),
  index index: Int,
) -> Result(Float, String) {
  case list_at(captures, index) {
    Some(CapturedFloat(value)) -> Ok(value)
    Some(other) -> Error(wrong_capture_message(index, other, "a float"))
    None -> Error(missing_capture_message(captures, index))
  }
}

/// Get a String capture by index (0-based).
///
/// Returns the captured string value at the given index. Works for
/// both {string} (quoted) and {word} captures.
///
/// ## Parameters
///
/// - `captures`: List of captured values from StepContext
/// - `index`: 0-based index of the capture to retrieve
///
/// ## Example
///
/// ```gleam
/// fn step_string(_value: String, context: StepContext) {
///   get_string(context.captures, 0)
/// }
/// ```
///
pub fn get_string(
  captures captures: List(CapturedValue),
  index index: Int,
) -> Result(String, String) {
  case list_at(captures, index) {
    Some(CapturedString(value)) -> Ok(value)
    Some(CapturedWord(value)) -> Ok(value)
    Some(other) -> Error(wrong_capture_message(index, other, "a string"))
    None -> Error(missing_capture_message(captures, index))
  }
}

/// Get a word capture by index (0-based).
///
/// Returns the captured word value at the given index. Works for
/// both {word} and {} (anonymous) captures.
///
/// ## Parameters
///
/// - `captures`: List of captured values from StepContext
/// - `index`: 0-based index of the capture to retrieve
///
/// ## Example
///
/// ```gleam
/// fn step_word(_value: String, context: StepContext) {
///   get_word(context.captures, 0)
/// }
/// ```
///
pub fn get_word(
  captures captures: List(CapturedValue),
  index index: Int,
) -> Result(String, String) {
  case list_at(captures, index) {
    Some(CapturedWord(value)) -> Ok(value)
    Some(CapturedString(value)) -> Ok(value)
    Some(other) -> Error(wrong_capture_message(index, other, "a word"))
    None -> Error(missing_capture_message(captures, index))
  }
}

/// Get the number of captures.
///
/// Returns the total number of values captured from placeholders.
///
/// ## Parameters
///
/// - `captures`: List of captured values from StepContext
///
/// ## Example
///
/// ```gleam
///       capture_count(matched.captures)
///       |> should
///       |> be_equal(1)
///       |> or_fail_with("expected exactly one capture")
/// ```
///
pub fn capture_count(captures captures: List(CapturedValue)) -> Int {
  list.length(captures)
}

// ============================================================================
// Internal Helpers
// ============================================================================

fn wrong_capture_message(
  index: Int,
  captured: CapturedValue,
  expected: String,
) -> String {
  "Capture "
  <> int.to_string(index)
  <> " is "
  <> describe_capture(captured)
  <> ", not "
  <> expected
}

fn describe_capture(captured: CapturedValue) -> String {
  case captured {
    CapturedInt(value) -> "the integer " <> int.to_string(value)
    CapturedFloat(value) -> "the float " <> float.to_string(value)
    CapturedString(value) -> "the string " <> string.inspect(value)
    CapturedWord(value) -> "the word " <> string.inspect(value)
  }
}

fn missing_capture_message(
  captures: List(CapturedValue),
  index: Int,
) -> String {
  "No capture at index "
  <> int.to_string(index)
  <> ": the step has "
  <> capture_count_text(list.length(captures))
}

fn capture_count_text(count: Int) -> String {
  case count {
    0 -> "no captures"
    1 -> "1 capture"
    _ -> int.to_string(count) <> " captures"
  }
}

fn list_at(items: List(a), index: Int) -> Option(a) {
  list_at_loop(items, index, 0)
}

fn list_at_loop(items: List(a), target: Int, current: Int) -> Option(a) {
  case items {
    [] -> None
    [head, ..tail] ->
      case current == target {
        True -> Some(head)
        False -> list_at_loop(tail, target, current + 1)
      }
  }
}

// ============================================================================
// Scenario tests
// ============================================================================

/// The tests of the scenarios of `feature`, and a group for each Rule.
/// `feature_group` is the name of the Feature when these nodes go into the
/// group of the Feature, and `None` when they go into another group.
fn feature_children(
  feature: types.Feature,
  registry: StepRegistry(state),
  feature_group: Option(String),
) -> List(dream_types.Node(state)) {
  let scope =
    ScenarioScope(
      feature_name: feature.name,
      feature_group: feature_group,
      source: feature.source,
      registry: registry,
      rule_group: None,
      background_steps: background_steps(feature.background),
    )
  let scenario_nodes = scenarios_to_nodes(scope, feature.scenarios, [])
  let rule_nodes = rules_to_nodes(scope, feature.rules, [])
  list.append(scenario_nodes, rule_nodes)
}

/// What the scenarios of a Feature or a Rule share.
type ScenarioScope(state) {
  ScenarioScope(
    feature_name: String,
    /// The name of the Feature when the scenarios are in the group of the
    /// Feature, or `None` for the scenarios of `Scenarios`.
    feature_group: Option(String),
    source: Option(String),
    registry: StepRegistry(state),
    /// The name of the Rule group (`Rule: <name>`) for the scenarios of a
    /// Rule, or `None` for the scenarios outside a Rule.
    rule_group: Option(String),
    background_steps: List(types.Step),
  )
}

fn background_steps(background: Option(types.Background)) -> List(types.Step) {
  case background {
    Some(background) -> background.steps
    None -> []
  }
}

fn rules_to_nodes(
  scope: ScenarioScope(state),
  rules: List(types.Rule),
  nodes_newest_first: List(dream_types.Node(state)),
) -> List(dream_types.Node(state)) {
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
  rule: types.Rule,
) -> dream_types.Node(state) {
  let group_name = string.trim_end("Rule: " <> rule.name)
  let rule_scope =
    ScenarioScope(
      ..scope,
      rule_group: Some(group_name),
      background_steps: list.append(
        scope.background_steps,
        background_steps(rule.background),
      ),
    )
  dream_types.Group(
    name: group_name,
    tags: rule.tags,
    children: scenarios_to_nodes(rule_scope, rule.scenarios, []),
  )
}

fn scenarios_to_nodes(
  scope: ScenarioScope(state),
  scenarios: List(types.Scenario),
  nodes_newest_first: List(dream_types.Node(state)),
) -> List(dream_types.Node(state)) {
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
  scenario: types.Scenario,
) -> List(dream_types.Node(state)) {
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

/// A number that no other scenario in the BEAM instance gets: each call
/// gives a new, larger number. It makes the scenario id unique in the run,
/// also across separately built suites.
fn scenario_number() -> String {
  int.to_string(unique_integer([Positive, Monotonic]))
}

/// The options of `erlang:unique_integer/1`. Gleam gives them to Erlang as
/// the atoms `positive` and `monotonic`.
type UniqueIntegerOption {
  Positive
  Monotonic
}

@external(erlang, "erlang", "unique_integer")
fn unique_integer(options: List(UniqueIntegerOption)) -> Int

/// One test to build: its name, its own tags and its steps.
type ScenarioRun {
  ScenarioRun(name: String, tags: List(String), steps: List(types.Step))
}

fn scenario_node(
  scope: ScenarioScope(state),
  run: ScenarioRun,
) -> dream_types.Node(state) {
  let full_name =
    list.flatten([
      [scope.feature_name],
      option.values([scope.rule_group]),
      [run.name],
    ])
  let scenario_id = string.join(full_name, "::") <> "#" <> scenario_number()
  let all_steps = with_background(scope.background_steps, run.steps)
  let registry = scope.registry

  dream_types.Test(
    name: run.name,
    tags: run.tags,
    kind: dream_types.GherkinScenario(
      scenario_id: scenario_id,
      feature: scope.feature_group,
      rule: scope.rule_group,
    ),
    run: dream_types.WithInput(fn(start) {
      execute_scenario(scenario_id, all_steps, registry, start)
    }),
    timeout_ms: None,
    source: scope.source,
  )
}

/// The steps of a test: the Background steps, then the scenario steps. A
/// scenario with no steps runs no Background steps, as in the official
/// Gherkin compiler.
fn with_background(
  background_steps: List(types.Step),
  scenario_steps: List(types.Step),
) -> List(types.Step) {
  case scenario_steps {
    [] -> []
    _ -> list.append(background_steps, scenario_steps)
  }
}

/// Build the tests of every row of every Examples table. `index` counts the
/// rows of all tables of the scenario, from 1.
fn examples_to_nodes(
  scope: ScenarioScope(state),
  scenario: types.Scenario,
  examples: List(types.Examples),
  index: Int,
  nodes_newest_first: List(dream_types.Node(state)),
) -> List(dream_types.Node(state)) {
  case examples {
    [] -> list.reverse(nodes_newest_first)
    [types.Examples(table: None, ..), ..rest] ->
      examples_to_nodes(scope, scenario, rest, index, nodes_newest_first)
    [types.Examples(table: Some(table), ..) as section, ..rest] -> {
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
    scenario: types.Scenario,
    section: types.Examples,
    headers: List(String),
  )
}

fn rows_to_nodes(
  scope: ScenarioScope(state),
  rows: ExampleRows,
  values: List(List(String)),
  index: Int,
  nodes_newest_first: List(dream_types.Node(state)),
) -> #(Int, List(dream_types.Node(state))) {
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
  steps: List(types.Step),
  substitutions: List(#(String, String)),
) -> List(types.Step) {
  substitute_steps_loop(steps, substitutions, [])
}

fn substitute_steps_loop(
  steps: List(types.Step),
  substitutions: List(#(String, String)),
  acc_rev: List(types.Step),
) -> List(types.Step) {
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
  step: types.Step,
  substitutions: List(#(String, String)),
) -> types.Step {
  types.Step(
    keyword: step.keyword,
    text: substitute_placeholders(step.text, substitutions),
    doc_string: substitute_doc_string(step.doc_string, substitutions),
    data_table: substitute_data_table(step.data_table, substitutions),
  )
}

fn substitute_doc_string(
  doc_string: Option(types.DocString),
  substitutions: List(#(String, String)),
) -> Option(types.DocString) {
  case doc_string {
    Some(types.DocString(content, content_type)) ->
      Some(types.DocString(
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
  data_table: Option(types.DataTable),
  substitutions: List(#(String, String)),
) -> Option(types.DataTable) {
  case data_table {
    Some(types.DataTable(rows)) ->
      Some(types.DataTable(rows: substitute_rows(rows, substitutions, [])))
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
  steps: List(types.Step),
  registry: StepRegistry(state),
  start: state,
) -> Result(dream_types.AssertionResult, String) {
  case validate(registry) {
    Ok(Nil) -> Ok(resolve_and_execute(scenario_id, steps, registry, start))
    Error(message) -> Ok(step_failure(message))
  }
}

fn resolve_and_execute(
  scenario_id: String,
  steps: List(types.Step),
  registry: StepRegistry(state),
  start: state,
) -> dream_types.AssertionResult {
  case resolve_phases(steps, None, []) {
    Ok(phased_steps) ->
      execute_steps(
        ScenarioExecution(scenario_id: scenario_id, registry: registry),
        phased_steps,
        start,
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
  Stop(result: dream_types.AssertionResult)
}

fn resolve_phases(
  steps: List(types.Step),
  previous: Option(types.StepPhase),
  phased_newest_first: List(#(types.Step, types.StepPhase)),
) -> Result(List(#(types.Step, types.StepPhase)), String) {
  case steps {
    [] -> Ok(list.reverse(phased_newest_first))
    [step, ..rest] ->
      resolve_step_phase(step, rest, previous, phased_newest_first)
  }
}

fn resolve_step_phase(
  step: types.Step,
  rest: List(types.Step),
  previous: Option(types.StepPhase),
  phased_newest_first: List(#(types.Step, types.StepPhase)),
) -> Result(List(#(types.Step, types.StepPhase)), String) {
  case types.resolve_phase(step.keyword, previous) {
    Ok(phase) ->
      resolve_phases(rest, Some(phase), [#(step, phase), ..phased_newest_first])
    Error(Nil) -> Error(no_previous_step_message(step))
  }
}

fn no_previous_step_message(step: types.Step) -> String {
  "\""
  <> types.keyword_to_string(step.keyword)
  <> " "
  <> step.text
  <> "\" has no step before it. And, But and * take the phase of the step before them, so the first step of a Background, or of a Scenario with no Background steps, must use Given, When or Then."
}

fn execute_steps(
  execution: ScenarioExecution(state),
  phased_steps: List(#(types.Step, types.StepPhase)),
  state: state,
) -> dream_types.AssertionResult {
  case phased_steps {
    [] -> dream_types.AssertionOk
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
  rest: List(#(types.Step, types.StepPhase)),
) -> dream_types.AssertionResult {
  case outcome {
    Continue(state) -> execute_steps(execution, rest, state)
    Stop(result) -> result
  }
}

fn execute_step(
  execution: ScenarioExecution(state),
  step: types.Step,
  phase: types.StepPhase,
  state: state,
) -> StepOutcome(state) {
  case find_step(execution.registry, phase, step.text) {
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
  result: Result(dream_types.AssertionResult, String),
  state: state,
) -> StepOutcome(state) {
  case result {
    Ok(dream_types.AssertionOk) -> Continue(state)
    Ok(failure) -> Stop(failure)
    Error(message) -> Stop(step_failure(message))
  }
}

fn step_failure(message: String) -> dream_types.AssertionResult {
  dream_types.AssertionFailed(dream_types.AssertionFailure(
    operator: "step",
    message: message,
    payload: None,
  ))
}

fn build_step_context(
  execution: ScenarioExecution(state),
  match: StepMatch(StepDefinition(state)),
  step: types.Step,
) -> StepContext {
  StepContext(
    captures: match.captures,
    table: extract_table_from_step(step),
    doc_string: extract_doc_string_from_step(step),
    scenario_id: execution.scenario_id,
  )
}

fn extract_table_from_step(step: types.Step) -> Option(List(List(String))) {
  case step.data_table {
    Some(types.DataTable(rows)) -> Some(rows)
    None -> None
  }
}

fn extract_doc_string_from_step(step: types.Step) -> Option(String) {
  case step.doc_string {
    Some(types.DocString(content, _)) -> Some(content)
    None -> None
  }
}
