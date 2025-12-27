//// Step definition registry for Gherkin scenarios.
////
//// Use this module to:
////
//// - Build a `StepRegistry` by registering patterns and handlers.
//// - Match step text against registered patterns (including typed placeholders).
//// - Extract typed captures (`{int}`, `{float}`, `{string}`, `{word}`, `{}`).
////
//// ## Example
////
//// ```gleam
////   let steps =
////     new()
////     |> step("I have {int} items in my cart", step_have_items)
////     |> step("I add {int} more items", step_add_items)
////     |> step("I should have {int} items total", step_should_have)
//// ```
////
//// ## Placeholder types
////
//// Step patterns use typed placeholders:
////
//// - `{int}`: integers (e.g. `42`, `-5`)
//// - `{float}`: decimals (e.g. `3.14`, `-0.5`)
//// - `{string}`: quoted strings (e.g. `"hello world"`)
//// - `{word}`: a single unquoted word (e.g. `alice`)
//// - `{}`: any single token
////
//// Placeholders can include literal prefixes/suffixes. For example, `${float}`
//// matches `$19.99` but captures `19.99` as a `Float`.

import dream_test/gherkin/step_trie.{
  type CapturedValue, type StepMatch, type StepTrie, CapturedFloat, CapturedInt,
  CapturedString, CapturedWord,
}
import dream_test/gherkin/types.{type StepKeyword, And, But, Given, Then, When}
import dream_test/gherkin/world.{type World}
import dream_test/types as dream_types
import gleam/list
import gleam/option.{type Option, None, Some}

// ============================================================================
// Types
// ============================================================================

/// Context passed to every step handler.
///
/// Contains everything a step needs to execute:
/// - `captures` - Values captured from pattern placeholders
/// - `table` - Optional DataTable argument from the step
/// - `doc_string` - Optional DocString argument from the step
/// - `world` - Mutable scenario state
///
pub type StepContext {
  StepContext(
    /// Values captured from pattern placeholders, in order
    captures: List(CapturedValue),
    /// Optional DataTable attached to the step
    table: Option(List(List(String))),
    /// Optional DocString attached to the step
    doc_string: Option(String),
    /// Mutable scenario state for sharing data between steps
    world: World,
  )
}

/// Type alias for step handler functions.
///
/// All step handlers have the same signature: they receive a StepContext
/// and return `Result(AssertionResult, String)`, just like unit test bodies.
///
/// This means you can use the exact same assertion style inside steps:
///
/// ```gleam
/// fn step_should_have(context: StepContext) {
///   let expected = get_int(context.captures, 0) |> result.unwrap(0)
///   get_or(context.world, "cart", 0)
///   |> should
///   |> be_equal(expected)
///   |> or_fail_with("Cart count mismatch")
/// }
/// ```
///
pub type StepHandler =
  fn(StepContext) -> Result(dream_types.AssertionResult, String)

/// Step registry backed by radix trie.
///
/// Stores step definitions and provides fast lookup.
///
/// “Fast” here means lookup cost grows with the **length of the step text**,
/// not with how many step definitions you’ve registered.
///
pub opaque type StepRegistry {
  StepRegistry(trie: StepTrie(StepHandler))
}

// ============================================================================
// Registry Construction
// ============================================================================

/// Create an empty step registry.
///
/// Start with this and chain `given`, `when_`, `then_` calls to add steps.
///
/// ## Example
///
/// ```gleam
/// let steps =
///   new()
///   |> step("I have {int} items", step_int)
///   |> step("the price is ${float}", step_float)
///   |> step("the message is {string}", step_string)
///   |> step("the user is {word}", step_word)
///   |> step("everything works", step_pass)
/// ```
///
pub fn new() -> StepRegistry {
  StepRegistry(trie: step_trie.new())
}

/// Register a Given step definition.
///
/// Given steps describe initial context or preconditions.
///
/// ## Parameters
///
/// - `registry`: The registry to add to
/// - `pattern`: Step pattern with placeholders
/// - `handler`: Handler function to execute
///
/// ## Returns
///
/// A new registry containing the added step.
///
/// ## Example
///
/// ```gleam
///       let registry = new() |> given("I have {int} items", step_pass)
/// ```
///
pub fn given(
  registry registry: StepRegistry,
  pattern pattern: String,
  handler handler: StepHandler,
) -> StepRegistry {
  let updated = step_trie.insert(registry.trie, "Given", pattern, handler)
  StepRegistry(trie: updated)
}

/// Register a When step definition.
///
/// When steps describe an action or event.
///
/// Note: Named `when_` with trailing underscore because `when` is reserved.
///
/// ## Parameters
///
/// - `registry`: The registry to add to
/// - `pattern`: Step pattern with placeholders
/// - `handler`: Handler function to execute
///
/// ## Returns
///
/// A new registry containing the added step.
///
/// ## Example
///
/// ```gleam
///       let registry = new() |> when_("I add {int} items", step_pass)
/// ```
///
pub fn when_(
  registry registry: StepRegistry,
  pattern pattern: String,
  handler handler: StepHandler,
) -> StepRegistry {
  let updated = step_trie.insert(registry.trie, "When", pattern, handler)
  StepRegistry(trie: updated)
}

/// Register a Then step definition.
///
/// Then steps describe expected outcomes or assertions.
///
/// Note: Named `then_` with trailing underscore because `then` is reserved.
///
/// ## Parameters
///
/// - `registry`: The registry to add to
/// - `pattern`: Step pattern with placeholders
/// - `handler`: Handler function to execute
///
/// ## Returns
///
/// A new registry containing the added step.
///
/// ## Example
///
/// ```gleam
///       let registry = new() |> then_("I should have {int} items", step_pass)
/// ```
///
pub fn then_(
  registry registry: StepRegistry,
  pattern pattern: String,
  handler handler: StepHandler,
) -> StepRegistry {
  let updated = step_trie.insert(registry.trie, "Then", pattern, handler)
  StepRegistry(trie: updated)
}

/// Register a step that matches any keyword.
///
/// Use this for steps that work regardless of Given/When/Then context.
///
/// ## Parameters
///
/// - `registry`: The registry to add to
/// - `pattern`: Step pattern with placeholders
/// - `handler`: Handler function to execute
///
/// ## Returns
///
/// A new registry containing the added step.
///
/// ## Example
///
/// ```gleam
/// let steps =
///     new()
///     |> step("I have {int} items in my cart", step_have_items)
///     |> step("I add {int} more items", step_add_items)
///     |> step("I should have {int} items total", step_should_have)
/// ```
///
pub fn step(
  registry registry: StepRegistry,
  pattern pattern: String,
  handler handler: StepHandler,
) -> StepRegistry {
  let updated = step_trie.insert(registry.trie, "*", pattern, handler)
  StepRegistry(trie: updated)
}

// ============================================================================
// Step Lookup
// ============================================================================

/// Find a matching step definition.
///
/// Searches the registry for a handler matching the given keyword and text.
/// Returns the handler and captured values on success, or an error message.
///
/// ## Performance
///
/// Lookup cost scales with the number of **tokens** in the step text after
/// tokenization (the same tokenization used by the step trie).
///
/// Concretely: this is the **total number of tokens** in the input step text,
/// not the number of *unique* words.
///
/// In practice:
/// - Tokens are usually “words” separated by spaces.
/// - Quoted strings are treated as a single token.
/// - Some punctuation/number boundaries are split so patterns like `{int}%` or
///   `${float}USD` can match predictably.
///
/// Examples:
/// - `"I add 2 items"` → 4 tokens (`["I", "add", "2", "items"]`)
/// - `"the message is \"hello world\""` → 4 tokens (`["the", "message", "is", "\"hello world\""]`)
///
/// This does **not** scale with the number of registered steps: you can register
/// hundreds of steps and lookup still stays proportional to the tokenized input.
///
/// ## Parameters
///
/// - `registry`: The registry to search
/// - `keyword`: Step keyword (Given, When, Then, And, But)
/// - `text`: Step text to match
///
/// ## Returns
///
/// - `Ok(StepMatch)`: Contains matched handler and captured values
/// - `Error(String)`: Error message if no match found
///
/// ## Example
///
/// ```gleam
///       let registry = new() |> given("I have {int} items", step_pass)
///
///       use matched <- result.try(find_step(registry, Given, "I have 3 items"))
///
///       capture_count(matched.captures)
///       |> should
///       |> be_equal(1)
///       |> or_fail_with("expected exactly one capture")
/// ```
///
pub fn find_step(
  registry registry: StepRegistry,
  keyword keyword: StepKeyword,
  text text: String,
) -> Result(StepMatch(StepHandler), String) {
  let keyword_str = keyword_to_string(keyword)
  case step_trie.lookup(registry.trie, keyword_str, text) {
    Some(match) -> Ok(match)
    None -> Error("Undefined step: " <> keyword_str <> " " <> text)
  }
}

fn keyword_to_string(keyword: StepKeyword) -> String {
  case keyword {
    Given -> "Given"
    When -> "When"
    Then -> "Then"
    And -> "And"
    But -> "But"
  }
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
/// fn step_int(context: StepContext) {
///   let value = get_int(context.captures, 0) |> result.unwrap(0)
///   put(context.world, "int", value)
///   Ok(succeed())
/// }
/// ```
///
pub fn get_int(
  captures captures: List(CapturedValue),
  index index: Int,
) -> Result(Int, String) {
  case list_at(captures, index) {
    Some(CapturedInt(value)) -> Ok(value)
    Some(_) -> Error("Capture at index is not an integer")
    None -> Error("No capture at index")
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
/// fn step_float(context: StepContext) {
///   let value = get_float(context.captures, 0) |> result.unwrap(0.0)
///   put(context.world, "float", value)
///   Ok(succeed())
/// }
/// ```
///
pub fn get_float(
  captures captures: List(CapturedValue),
  index index: Int,
) -> Result(Float, String) {
  case list_at(captures, index) {
    Some(CapturedFloat(value)) -> Ok(value)
    Some(_) -> Error("Capture at index is not a float")
    None -> Error("No capture at index")
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
/// fn step_string(context: StepContext) {
///   let value = get_string(context.captures, 0) |> result.unwrap("")
///   put(context.world, "string", value)
///   Ok(succeed())
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
    Some(_) -> Error("Capture at index is not a string")
    None -> Error("No capture at index")
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
/// fn step_word(context: StepContext) {
///   let value = get_word(context.captures, 0) |> result.unwrap("")
///   put(context.world, "word", value)
///   Ok(succeed())
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
    Some(_) -> Error("Capture at index is not a word")
    None -> Error("No capture at index")
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
