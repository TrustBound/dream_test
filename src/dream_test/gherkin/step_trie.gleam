//// Fast step-definition lookup using Cucumber-Expression-style placeholders.
////
//// This is the data structure behind `dream_test/gherkin/steps`. It matches step
//// text in time proportional to the **number of tokens in the step text**, not
//// the number of registered step definitions.
////
//// ## Placeholder syntax
////
//// - `{int}`: integers like `42`, `-5`
//// - `{float}`: decimals like `3.14`, `-0.5`
//// - `{string}`: quoted strings like `"hello world"`
//// - `{word}` / `{}`: a single token
////
//// Prefix/suffix text can be attached to placeholders. For example,
//// `${float}USD` matches `$19.99USD` and captures `19.99` as a float.
////
//// ## Example
////
//// ```gleam
////       step_trie.lookup(trie, ThenPhase, "the total is $19.99USD")
////       |> should
////       |> be_equal(
////         Some(
////           step_trie.StepMatch(handler: "total_usd", captures: [
////             step_trie.CapturedFloat(19.99),
////           ]),
////         ),
////       )
////       |> or_fail_with("expected float capture for $19.99USD")
//// ```

import dream_test/gherkin/types.{type StepPhase}
import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// ============================================================================
// Segment Types
// ============================================================================

/// Segment types for step patterns.
///
/// Each segment type has different matching behavior and priority:
/// - `LiteralWord`: Exact word match, highest priority
/// - `StringParam`: Matches quoted strings
/// - `IntParam`: Matches integers
/// - `FloatParam`: Matches decimal numbers
/// - `WordParam`: Matches a single unquoted word
/// - `AnyParam`: Matches any single word (lowest priority)
///
pub type StepSegment {
  /// Literal word requiring exact match.
  /// Example: "have" in "I have {int} items"
  LiteralWord(String)

  /// Integer parameter capture.
  /// Matches: 42, -5, 0
  IntParam

  /// Float parameter capture.
  /// Matches: 3.14, -0.5, 2.0
  FloatParam

  /// Quoted string parameter capture.
  /// Matches: "hello world", "test"
  StringParam

  /// Single unquoted word capture.
  /// Matches any non-whitespace word
  WordParam

  /// Anonymous capture (matches any single word).
  /// Lowest priority among params
  AnyParam
}

// ============================================================================
// Captured Values
// ============================================================================

/// A value captured from step text during matching.
///
/// Each captured placeholder produces a typed value.
///
pub type CapturedValue {
  /// Integer value from {int}
  CapturedInt(Int)
  /// Float value from {float}
  CapturedFloat(Float)
  /// String value from {string} (without quotes)
  CapturedString(String)
  /// Word value from {word} or {}
  CapturedWord(String)
}

// ============================================================================
// Trie Node
// ============================================================================

/// A node in the step trie.
///
/// Each node can store handlers for different phases and has children
/// for different segment types. Children are organized by priority.
///
pub opaque type StepTrieNode(handler) {
  StepTrieNode(
    /// Handlers at this node, keyed by phase (one handler for each phase)
    handlers: Dict(StepPhase, handler),
    /// Child nodes for literal words (exact matches, highest priority)
    literal_children: Dict(String, StepTrieNode(handler)),
    /// Child node for {string} parameter
    string_child: Option(StepTrieNode(handler)),
    /// Child node for {int} parameter
    int_child: Option(StepTrieNode(handler)),
    /// Child node for {float} parameter
    float_child: Option(StepTrieNode(handler)),
    /// Child node for {word} parameter
    word_child: Option(StepTrieNode(handler)),
    /// Child node for {} anonymous parameter (lowest priority)
    any_child: Option(StepTrieNode(handler)),
  )
}

/// Create an empty trie node.
fn empty_node() -> StepTrieNode(handler) {
  StepTrieNode(
    handlers: dict.new(),
    literal_children: dict.new(),
    string_child: None,
    int_child: None,
    float_child: None,
    word_child: None,
    any_child: None,
  )
}

// ============================================================================
// Step Trie
// ============================================================================

/// Radix trie for fast step lookup.
///
/// The trie is the main data structure holding all step definitions.
/// Patterns are organized by word segments for efficient O(words) lookup.
///
pub opaque type StepTrie(handler) {
  StepTrie(root: StepTrieNode(handler))
}

/// Result of a successful step match.
///
/// Contains the matched handler and captured values.
///
pub type StepMatch(handler) {
  StepMatch(
    /// The handler that matched
    handler: handler,
    /// Captured values in order of appearance
    captures: List(CapturedValue),
  )
}

// ============================================================================
// Trie Construction
// ============================================================================

/// Create a new empty step trie.
///
/// Returns a trie with no step definitions.
///
/// ## Example
///
/// ```gleam
///       let trie =
///         step_trie.new()
///         |> step_trie.insert(
///           phase: GivenPhase,
///           pattern: "I have an empty cart",
///           handler: "empty",
///         )
/// ```
///
pub fn new() -> StepTrie(handler) {
  StepTrie(root: empty_node())
}

/// Insert a step pattern into the trie.
///
/// Adds a handler for one phase at the path specified by the pattern. Each
/// pattern can have one handler for each phase. The same pattern in a
/// different phase is a different step definition.
///
/// ## Parameters
///
/// - `trie`: The trie to insert into
/// - `phase`: The phase of the step definition (`GivenPhase`, `WhenPhase` or
///   `ThenPhase`)
/// - `pattern`: Step pattern with placeholders (e.g., "I have {int} items")
/// - `handler`: The handler to store
///
/// ## Returns
///
/// - `Ok(StepTrie)`: The trie with the new step definition
/// - `Error(String)`: The trie already has a handler for this phase and a
///   pattern with the same segments. The message names the phase and the
///   pattern.
///
/// ## Example
///
/// ```gleam
///       step_trie.new()
///       |> step_trie.insert(
///         phase: GivenPhase,
///         pattern: "I have {int} items",
///         handler: "count",
///       )
/// ```
///
pub fn insert(
  trie trie: StepTrie(handler),
  phase phase: StepPhase,
  pattern pattern: String,
  handler handler: handler,
) -> Result(StepTrie(handler), String) {
  let segments = parse_step_pattern(pattern)
  case insert_into_node(trie.root, phase, segments, handler) {
    Ok(updated_root) -> Ok(StepTrie(root: updated_root))
    Error(Nil) -> Error(duplicate_definition_message(phase, pattern))
  }
}

fn duplicate_definition_message(phase: StepPhase, pattern: String) -> String {
  "Duplicate step definition: "
  <> types.phase_to_string(phase)
  <> " \""
  <> pattern
  <> "\" is already defined. Each pattern can have one definition for each of Given, When and Then."
}

fn insert_into_node(
  node: StepTrieNode(handler),
  phase: StepPhase,
  segments: List(StepSegment),
  handler: handler,
) -> Result(StepTrieNode(handler), Nil) {
  case segments {
    [] -> insert_handler_at_node(node, phase, handler)
    [LiteralWord(word), ..rest] ->
      insert_literal_segment(node, word, phase, rest, handler)
    [IntParam, ..rest] -> insert_int_segment(node, phase, rest, handler)
    [FloatParam, ..rest] -> insert_float_segment(node, phase, rest, handler)
    [StringParam, ..rest] -> insert_string_segment(node, phase, rest, handler)
    [WordParam, ..rest] -> insert_word_segment(node, phase, rest, handler)
    [AnyParam, ..rest] -> insert_any_segment(node, phase, rest, handler)
  }
}

/// A node holds one handler for each phase. A second handler for the same
/// phase is a duplicate step definition.
fn insert_handler_at_node(
  node: StepTrieNode(handler),
  phase: StepPhase,
  handler: handler,
) -> Result(StepTrieNode(handler), Nil) {
  case dict.has_key(node.handlers, phase) {
    True -> Error(Nil)
    False ->
      Ok(
        StepTrieNode(
          ..node,
          handlers: dict.insert(node.handlers, phase, handler),
        ),
      )
  }
}

fn insert_literal_segment(
  node: StepTrieNode(handler),
  word: String,
  phase: StepPhase,
  rest: List(StepSegment),
  handler: handler,
) -> Result(StepTrieNode(handler), Nil) {
  let child = get_or_create_literal_child(node, word)
  case insert_into_node(child, phase, rest, handler) {
    Ok(updated_child) ->
      Ok(
        StepTrieNode(
          ..node,
          literal_children: dict.insert(
            node.literal_children,
            word,
            updated_child,
          ),
        ),
      )
    Error(Nil) -> Error(Nil)
  }
}

fn insert_int_segment(
  node: StepTrieNode(handler),
  phase: StepPhase,
  rest: List(StepSegment),
  handler: handler,
) -> Result(StepTrieNode(handler), Nil) {
  let child = option.unwrap(node.int_child, empty_node())
  case insert_into_node(child, phase, rest, handler) {
    Ok(updated_child) ->
      Ok(StepTrieNode(..node, int_child: Some(updated_child)))
    Error(Nil) -> Error(Nil)
  }
}

fn insert_float_segment(
  node: StepTrieNode(handler),
  phase: StepPhase,
  rest: List(StepSegment),
  handler: handler,
) -> Result(StepTrieNode(handler), Nil) {
  let child = option.unwrap(node.float_child, empty_node())
  case insert_into_node(child, phase, rest, handler) {
    Ok(updated_child) ->
      Ok(StepTrieNode(..node, float_child: Some(updated_child)))
    Error(Nil) -> Error(Nil)
  }
}

fn insert_string_segment(
  node: StepTrieNode(handler),
  phase: StepPhase,
  rest: List(StepSegment),
  handler: handler,
) -> Result(StepTrieNode(handler), Nil) {
  let child = option.unwrap(node.string_child, empty_node())
  case insert_into_node(child, phase, rest, handler) {
    Ok(updated_child) ->
      Ok(StepTrieNode(..node, string_child: Some(updated_child)))
    Error(Nil) -> Error(Nil)
  }
}

fn insert_word_segment(
  node: StepTrieNode(handler),
  phase: StepPhase,
  rest: List(StepSegment),
  handler: handler,
) -> Result(StepTrieNode(handler), Nil) {
  let child = option.unwrap(node.word_child, empty_node())
  case insert_into_node(child, phase, rest, handler) {
    Ok(updated_child) ->
      Ok(StepTrieNode(..node, word_child: Some(updated_child)))
    Error(Nil) -> Error(Nil)
  }
}

fn insert_any_segment(
  node: StepTrieNode(handler),
  phase: StepPhase,
  rest: List(StepSegment),
  handler: handler,
) -> Result(StepTrieNode(handler), Nil) {
  let child = option.unwrap(node.any_child, empty_node())
  case insert_into_node(child, phase, rest, handler) {
    Ok(updated_child) ->
      Ok(StepTrieNode(..node, any_child: Some(updated_child)))
    Error(Nil) -> Error(Nil)
  }
}

fn get_or_create_literal_child(
  node: StepTrieNode(handler),
  word: String,
) -> StepTrieNode(handler) {
  case dict.get(node.literal_children, word) {
    Ok(existing) -> existing
    Error(_) -> empty_node()
  }
}

// ============================================================================
// Pattern Parsing
// ============================================================================

/// Parse a step pattern string into segments.
///
/// Splits the pattern by whitespace and converts each token into a `StepSegment`.
/// Placeholders like `{int}` become typed parameter segments, while other tokens
/// become literal word segments.
///
/// ## Placeholder Syntax
///
/// | Placeholder | Segment Type | Matches |
/// |-------------|--------------|---------|
/// | `{int}` | `IntParam` | Integers like `42`, `-5` |
/// | `{float}` | `FloatParam` | Decimals like `3.14` |
/// | `{string}` | `StringParam` | Quoted strings like `"hello"` |
/// | `{word}` | `WordParam` | Single unquoted words |
/// | `{}` | `AnyParam` | Any single token |
///
/// ## Prefix and Suffix Handling
///
/// Placeholders can have literal prefixes and/or suffixes attached. The parser
/// automatically splits these into separate segments:
///
/// - `${float}` → `[LiteralWord("$"), FloatParam]`
/// - `{int}%` → `[IntParam, LiteralWord("%")]`
/// - `${float}USD` → `[LiteralWord("$"), FloatParam, LiteralWord("USD")]`
///
/// This enables patterns like `"the price is ${float}"` to match text like
/// `"the price is $19.99"` and capture `19.99` as the float value.
///
/// ## Example
///
/// ```gleam
///       step_trie.parse_step_pattern("the total is ${float}USD")
///       |> should
///       |> be_equal([
///         step_trie.LiteralWord("the"),
///         step_trie.LiteralWord("total"),
///         step_trie.LiteralWord("is"),
///         step_trie.LiteralWord("$"),
///         step_trie.FloatParam,
///         step_trie.LiteralWord("USD"),
///       ])
///       |> or_fail_with(
///         "expected ${float}USD to split into literal + FloatParam segments",
///       )
/// ```
///
pub fn parse_step_pattern(pattern pattern: String) -> List(StepSegment) {
  pattern
  |> string.split(" ")
  |> list.filter(is_non_empty)
  |> list.flat_map(split_word_around_placeholder)
  |> list.map(parse_pattern_word)
}

fn is_non_empty(word: String) -> Bool {
  word != ""
}

fn parse_pattern_word(word: String) -> StepSegment {
  case word {
    "{int}" -> IntParam
    "{float}" -> FloatParam
    "{string}" -> StringParam
    "{word}" -> WordParam
    "{}" -> AnyParam
    _ -> LiteralWord(word)
  }
}

/// Split a word around any placeholder it contains.
/// e.g., "${float}" -> ["$", "{float}"]
/// e.g., "{int}%" -> ["{int}", "%"]
/// e.g., "hello" -> ["hello"]
fn split_word_around_placeholder(word: String) -> List(String) {
  let placeholders = ["{int}", "{float}", "{string}", "{word}", "{}"]
  split_on_first_placeholder(word, placeholders)
}

fn split_on_first_placeholder(
  word: String,
  placeholders: List(String),
) -> List(String) {
  case placeholders {
    [] -> [word]
    [placeholder, ..rest] ->
      case try_split_on_placeholder(word, placeholder) {
        Some(parts) -> parts
        None -> split_on_first_placeholder(word, rest)
      }
  }
}

fn try_split_on_placeholder(
  word: String,
  placeholder: String,
) -> Option(List(String)) {
  case string.split_once(word, placeholder) {
    Ok(#(before, after)) ->
      Some(append_placeholder_parts(before, placeholder, after))
    Error(_) -> None
  }
}

fn append_placeholder_parts(
  before: String,
  placeholder: String,
  after: String,
) -> List(String) {
  []
  |> append_if_non_empty(before)
  |> list.append([placeholder])
  |> append_list(split_after(after))
}

fn append_if_non_empty(parts: List(String), value: String) -> List(String) {
  case value {
    "" -> parts
    _ -> list.append(parts, [value])
  }
}

fn split_after(after: String) -> List(String) {
  case after {
    "" -> []
    _ -> split_word_around_placeholder(after)
  }
}

fn append_list(parts: List(String), extra: List(String)) -> List(String) {
  list.append(parts, extra)
}

/// Split a token on boundaries between numeric and non-numeric characters.
/// e.g., "$3.00" -> ["$", "3.00"]
/// e.g., "10%" -> ["10", "%"]
/// e.g., "hello" -> ["hello"]
/// Quoted strings are not split.
///
/// A number is an optional `-`, one or more digits, then an optional `.`
/// and zero or more digits. The first number that starts at a position
/// takes as many characters as it can.
fn split_numeric_boundaries(token: String) -> List(String) {
  case is_quoted_string(token) {
    True -> [token]
    False -> split_numbers(string.to_graphemes(token), "", [])
  }
}

/// A number read from the start of a list of graphemes, and the graphemes
/// after it.
type NumberRead {
  NumberRead(number: String, rest: List(String))
}

/// Walk the graphemes. `text` holds the non-numeric characters since the
/// last number. `parts` holds the finished parts in reverse order.
fn split_numbers(
  graphemes: List(String),
  text: String,
  parts: List(String),
) -> List(String) {
  case graphemes {
    [] -> finalize_tokens(parts, text)
    [first, ..rest] -> split_at_grapheme(first, rest, text, parts)
  }
}

fn split_at_grapheme(
  first: String,
  rest: List(String),
  text: String,
  parts: List(String),
) -> List(String) {
  case read_number(first, rest) {
    Some(NumberRead(number: number, rest: after)) ->
      split_numbers(after, "", [number, ..add_token_if_non_empty(parts, text)])
    None -> split_numbers(rest, text <> first, parts)
  }
}

fn read_number(first: String, rest: List(String)) -> Option(NumberRead) {
  case first, rest {
    "-", [second, ..after] -> read_integer_part("-", second, after)
    _, _ -> read_integer_part("", first, rest)
  }
}

fn read_integer_part(
  sign: String,
  first: String,
  rest: List(String),
) -> Option(NumberRead) {
  case is_digit(first) {
    True -> Some(read_fraction(take_digits(rest, sign <> first)))
    False -> None
  }
}

fn read_fraction(integer_part: NumberRead) -> NumberRead {
  case integer_part.rest {
    [".", ..after] -> take_digits(after, integer_part.number <> ".")
    _ -> integer_part
  }
}

fn take_digits(graphemes: List(String), collected: String) -> NumberRead {
  let #(digits, rest) = list.split_while(graphemes, is_digit)
  NumberRead(number: collected <> string.concat(digits), rest: rest)
}

fn is_digit(grapheme: String) -> Bool {
  case grapheme {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

// ============================================================================
// Trie Lookup
// ============================================================================

/// Look up a step in the trie.
///
/// Searches for a handler of the given phase that matches the step text.
/// Only handlers of that phase match.
/// Returns the matched handler and captured values, or None if no match.
///
/// Lookup is O(word count) - independent of total step definitions.
///
/// ## Parameters
///
/// - `trie`: The trie to search
/// - `phase`: The phase of the step (`GivenPhase`, `WhenPhase` or `ThenPhase`)
/// - `text`: Step text to match (e.g., "I have 42 items")
///
/// ## Returns
///
/// - `Some(StepMatch)`: Contains matched handler and captured values
/// - `None`: No step definition matched
///
/// ## Example
///
/// ```gleam
///       step_trie.lookup(trie, ThenPhase, "the total is $19.99USD")
///       |> should
///       |> be_equal(
///         Some(
///           step_trie.StepMatch(handler: "total_usd", captures: [
///             step_trie.CapturedFloat(19.99),
///           ]),
///         ),
///       )
///       |> or_fail_with("expected float capture for $19.99USD")
/// ```
///
pub fn lookup(
  trie trie: StepTrie(handler),
  phase phase: StepPhase,
  text text: String,
) -> Option(StepMatch(handler)) {
  let words = tokenize_step_text(text)
  lookup_in_node(trie.root, phase, words, [])
}

/// Tokenize step text for matching.
///
/// Prepares step text for trie lookup by splitting it into tokens that align
/// with how patterns are parsed. This enables matching patterns with prefixed
/// or suffixed placeholders.
///
/// ## Tokenization Rules
///
/// 1. **Whitespace splitting**: Text is split on spaces
/// 2. **Quote preservation**: Quoted strings like `"Red Widget"` stay as one token
/// 3. **Numeric boundary splitting**: Tokens are split at boundaries between
///    numeric and non-numeric characters
///
/// The numeric boundary splitting is key for prefix/suffix support. When a
/// pattern like `${float}` is parsed, it becomes `["$", "{float}"]`. For
/// matching to work, the text `$19.99` must also become `["$", "19.99"]`.
///
/// ## Example
///
/// ```gleam
///       step_trie.tokenize_step_text("I add \"Red Widget\" and pay $19.99USD")
///       |> should
///       |> be_equal([
///         "I",
///         "add",
///         "\"Red Widget\"",
///         "and",
///         "pay",
///         "$",
///         "19.99",
///         "USD",
///       ])
///       |> or_fail_with(
///         "expected tokenization to preserve quotes and split $19.99USD",
///       )
/// ```
///
pub fn tokenize_step_text(text text: String) -> List(String) {
  text
  |> tokenize_preserving_quotes([], "", False)
  |> list.flat_map(split_numeric_boundaries)
}

fn tokenize_preserving_quotes(
  remaining: String,
  tokens: List(String),
  current: String,
  in_quotes: Bool,
) -> List(String) {
  case string.pop_grapheme(remaining) {
    Error(_) -> finalize_tokens(tokens, current)
    Ok(#(char, rest)) -> process_char(char, rest, tokens, current, in_quotes)
  }
}

fn process_char(
  char: String,
  rest: String,
  tokens: List(String),
  current: String,
  in_quotes: Bool,
) -> List(String) {
  case char, in_quotes {
    "\"", False ->
      tokenize_preserving_quotes(rest, tokens, current <> char, True)
    "\"", True ->
      tokenize_preserving_quotes(rest, tokens, current <> char, False)
    " ", False -> {
      let updated_tokens = add_token_if_non_empty(tokens, current)
      tokenize_preserving_quotes(rest, updated_tokens, "", False)
    }
    _, _ -> tokenize_preserving_quotes(rest, tokens, current <> char, in_quotes)
  }
}

fn finalize_tokens(tokens: List(String), current: String) -> List(String) {
  add_token_if_non_empty(tokens, current)
  |> list.reverse
}

fn add_token_if_non_empty(tokens: List(String), token: String) -> List(String) {
  case token {
    "" -> tokens
    _ -> [token, ..tokens]
  }
}

fn lookup_in_node(
  node: StepTrieNode(handler),
  phase: StepPhase,
  words: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  case words {
    [] -> lookup_handler_at_node(node, phase, captures)
    [word, ..rest] -> lookup_word(node, phase, word, rest, captures)
  }
}

fn lookup_handler_at_node(
  node: StepTrieNode(handler),
  phase: StepPhase,
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  case dict.get(node.handlers, phase) {
    Ok(handler) -> Some(StepMatch(handler, list.reverse(captures)))
    Error(Nil) -> None
  }
}

/// Match a single word against the node's children.
///
/// Priority order:
/// 1. Literal match (exact word)
/// 2. {string} (quoted string)
/// 3. {int} (integer)
/// 4. {float} (decimal)
/// 5. {word} (unquoted single word)
/// 6. {} (any word)
///
fn lookup_word(
  node: StepTrieNode(handler),
  phase: StepPhase,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  // 1. Try literal match first (highest priority)
  case dict.get(node.literal_children, word) {
    Ok(child) -> lookup_in_node(child, phase, rest, captures)
    Error(_) -> try_param_matches(node, phase, word, rest, captures)
  }
}

fn try_param_matches(
  node: StepTrieNode(handler),
  phase: StepPhase,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  // 2. Try {string} (quoted)
  case try_string_match(node, phase, word, rest, captures) {
    Some(result) -> Some(result)
    None -> try_numeric_matches(node, phase, word, rest, captures)
  }
}

fn try_string_match(
  node: StepTrieNode(handler),
  phase: StepPhase,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  case node.string_child, is_quoted_string(word) {
    Some(child), True -> {
      let unquoted = unquote_string(word)
      let updated_captures = [CapturedString(unquoted), ..captures]
      lookup_in_node(child, phase, rest, updated_captures)
    }
    _, _ -> None
  }
}

fn try_numeric_matches(
  node: StepTrieNode(handler),
  phase: StepPhase,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  // 3. Try {int}
  case try_int_match(node, phase, word, rest, captures) {
    Some(result) -> Some(result)
    None -> try_float_then_word(node, phase, word, rest, captures)
  }
}

fn try_int_match(
  node: StepTrieNode(handler),
  phase: StepPhase,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  case node.int_child, int.parse(word) {
    Some(child), Ok(value) -> {
      let updated_captures = [CapturedInt(value), ..captures]
      lookup_in_node(child, phase, rest, updated_captures)
    }
    _, _ -> None
  }
}

fn try_float_then_word(
  node: StepTrieNode(handler),
  phase: StepPhase,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  // 4. Try {float}
  case try_float_match(node, phase, word, rest, captures) {
    Some(result) -> Some(result)
    None -> try_word_matches(node, phase, word, rest, captures)
  }
}

fn try_float_match(
  node: StepTrieNode(handler),
  phase: StepPhase,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  case node.float_child, float.parse(word) {
    Some(child), Ok(value) -> {
      let updated_captures = [CapturedFloat(value), ..captures]
      lookup_in_node(child, phase, rest, updated_captures)
    }
    _, _ -> None
  }
}

fn try_word_matches(
  node: StepTrieNode(handler),
  phase: StepPhase,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  // 5. Try {word}
  case node.word_child {
    Some(child) -> {
      let updated_captures = [CapturedWord(word), ..captures]
      lookup_in_node(child, phase, rest, updated_captures)
    }
    None -> try_any_match(node, phase, word, rest, captures)
  }
}

fn try_any_match(
  node: StepTrieNode(handler),
  phase: StepPhase,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  // 6. Try {} (any)
  case node.any_child {
    Some(child) -> {
      let updated_captures = [CapturedWord(word), ..captures]
      lookup_in_node(child, phase, rest, updated_captures)
    }
    None -> None
  }
}

fn is_quoted_string(word: String) -> Bool {
  string.starts_with(word, "\"") && string.ends_with(word, "\"")
}

fn unquote_string(quoted: String) -> String {
  quoted
  |> string.drop_start(1)
  |> string.drop_end(1)
}
