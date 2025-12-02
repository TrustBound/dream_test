//// Step definition registry for Gherkin scenarios.
////
//// This module provides the user-facing API for defining step definitions
//// that match Gherkin steps (Given/When/Then) to Gleam handler functions.
////
//// ## Quick Start
////
//// ```gleam
//// import dream_test/gherkin/steps.{
////   type StepContext, given, new_registry, then_, when_, get_int, get_float,
//// }
////
//// pub fn cart_steps() -> StepRegistry {
////   new_registry()
////   |> given("I have {int} items in my cart", have_items)
////   |> when_("I add {int} items of {word}", add_items)
////   |> then_("the total should be ${float}", check_total)
//// }
////
//// fn have_items(context: StepContext) -> AssertionResult {
////   case get_int(context.captures, 0) {
////     Ok(count) -> {
////       world.put(context.world, "count", count)
////       AssertionOk
////     }
////     Error(msg) -> fail_with(msg)
////   }
//// }
//// ```
////
//// ## Pattern Syntax
////
//// Step patterns use Cucumber Expression syntax with typed placeholders:
////
//// | Placeholder | Matches               | Example        |
//// |-------------|-----------------------|----------------|
//// | `{int}`     | Integers              | `42`, `-5`     |
//// | `{float}`   | Decimals              | `3.14`, `-0.5` |
//// | `{string}`  | Quoted strings        | `"hello"`      |
//// | `{word}`    | Single unquoted word  | `apple`        |
//// | `{}`        | Any single token      | (anonymous)    |
////
//// ## Prefix and Suffix Support
////
//// Placeholders can have literal prefixes and suffixes attached:
////
//// | Pattern | Matches | Captures |
//// |---------|---------|----------|
//// | `${float}` | `$19.99` | `19.99` as Float |
//// | `{int}%` | `50%` | `50` as Int |
//// | `${float}USD` | `$99.99USD` | `99.99` as Float |
////
//// This is useful for currency, percentages, and other formatted values.
////
//// ## Capture Extraction
////
//// Use the typed extraction helpers to get captured values:
////
//// ```gleam
//// fn check_total(context: StepContext) -> AssertionResult {
////   // Pattern was "the total should be ${float}"
////   // Step text was "the total should be $19.99"
////   case get_float(context.captures, 0) {
////     Ok(amount) -> {
////       // amount is 19.99 (the $ prefix was matched but not captured)
////       AssertionOk
////     }
////     Error(msg) -> fail_with(msg)
////   }
//// }
//// ```

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
/// and return an AssertionResult.
///
pub type StepHandler =
  fn(StepContext) -> dream_types.AssertionResult

/// Step registry backed by radix trie.
///
/// Stores step definitions and provides O(words) lookup.
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
/// let steps = new_registry()
/// |> given("I have {int} items", have_items)
/// |> when_("I add {int} more", add_items)
/// |> then_("I should have {int} total", check_total)
/// ```
///
pub fn new_registry() -> StepRegistry {
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
/// ## Example
///
/// ```gleam
/// new_registry()
/// |> given("I have {int} items in my cart", have_items)
/// |> given("I am logged in as {string}", logged_in_as)
/// ```
///
pub fn given(
  registry: StepRegistry,
  pattern: String,
  handler: StepHandler,
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
/// ## Example
///
/// ```gleam
/// new_registry()
/// |> when_("I add {int} items of {string}", add_items)
/// |> when_("I click the {string} button", click_button)
/// ```
///
pub fn when_(
  registry: StepRegistry,
  pattern: String,
  handler: StepHandler,
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
/// ## Example
///
/// ```gleam
/// new_registry()
/// |> then_("my cart should have {int} items", check_count)
/// |> then_("I should see {string}", check_text)
/// ```
///
pub fn then_(
  registry: StepRegistry,
  pattern: String,
  handler: StepHandler,
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
/// ## Example
///
/// ```gleam
/// new_registry()
/// |> step("I wait {int} seconds", wait_seconds)
/// ```
///
pub fn step(
  registry: StepRegistry,
  pattern: String,
  handler: StepHandler,
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
/// This is O(words in step text), not O(number of step definitions).
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
pub fn find_step(
  registry: StepRegistry,
  keyword: StepKeyword,
  text: String,
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
/// // Pattern: "I have {int} items"
/// // Step: "I have 42 items"
/// case get_int(context.captures, 0) {
///   Ok(count) -> // count = 42
///   Error(msg) -> fail_with(msg)
/// }
/// ```
///
pub fn get_int(captures: List(CapturedValue), index: Int) -> Result(Int, String) {
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
/// // Pattern: "the price is {float} dollars"
/// // Step: "the price is 19.99 dollars"
/// case get_float(context.captures, 0) {
///   Ok(price) -> // price = 19.99
///   Error(msg) -> fail_with(msg)
/// }
/// ```
///
pub fn get_float(
  captures: List(CapturedValue),
  index: Int,
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
/// // Pattern: "I add items of {string}"
/// // Step: "I add items of \"Red Widget\""
/// case get_string(context.captures, 0) {
///   Ok(product) -> // product = "Red Widget"
///   Error(msg) -> fail_with(msg)
/// }
/// ```
///
pub fn get_string(
  captures: List(CapturedValue),
  index: Int,
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
/// // Pattern: "the user {word} exists"
/// // Step: "the user alice exists"
/// case get_word(context.captures, 0) {
///   Ok(username) -> // username = "alice"
///   Error(msg) -> fail_with(msg)
/// }
/// ```
///
pub fn get_word(
  captures: List(CapturedValue),
  index: Int,
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
/// let count = capture_count(context.captures)
/// // For "I add {int} items of {string}", count would be 2
/// ```
///
pub fn capture_count(captures: List(CapturedValue)) -> Int {
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
