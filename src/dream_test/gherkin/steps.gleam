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
//// - `{float}`: decimals (e.g. `3.14`, `-0.5`)
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
    /// (`new`) or a set-up (`new_with_set_up`), never both.
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
/// a set-up.
///
/// `set_up` runs once for each feature suite, before the first scenario,
/// and only when at least one scenario of the suite runs. For
/// `gherkin/discover.to_suite`, it runs once for the scenarios of all the
/// files. Each scenario starts from its value, so a change that one
/// scenario makes to its state does not reach the next one. `tear_down`
/// gets the same value after the last scenario.
///
/// The set-up and the tear-down run in one process that lives while the
/// scenarios run, so a server that the set-up starts and links stays
/// alive. When `set_up` returns `Error`, crashes or times out, each
/// scenario is `SetupFailed` with the operator `set_up` and `tear_down`
/// does not run. See `unit_context.describe_with_set_up` for the other
/// cases.
///
/// ## Example
///
/// ```gleam
/// let steps =
///   new_with_set_up(set_up: start_server, tear_down: stop_server)
///   |> given("the server is running", step_server_running)
///   |> when("I ping the server", step_ping)
///   |> then("the reply is {string}", step_reply_is)
/// ```
///
pub fn new_with_set_up(
  set_up set_up: fn() -> Result(state, String),
  tear_down tear_down: fn(state) -> Result(Nil, String),
) -> StepRegistry(state) {
  StepRegistry(
    start: dream_types.ContextFromSetUp(set_up: set_up, tear_down: tear_down),
    actions: step_trie.new(),
    checks: step_trie.new(),
    errors_newest_first: [],
  )
}

/// Where each scenario of the registry gets its starting state.
///
/// `FixedContext(value)` for a registry from `new`, and
/// `ContextFromSetUp(set_up, tear_down)` for a registry from
/// `new_with_set_up`. `gherkin/feature` uses it to make the suite of a
/// feature (see `suite.new`).
///
/// ## Example
///
/// ```gleam
/// steps.suite_context(new(initial: 7))
/// // -> types.FixedContext(7)
/// ```
///
pub fn suite_context(
  registry registry: StepRegistry(state),
) -> dream_types.SuiteContext(state) {
  registry.start
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
