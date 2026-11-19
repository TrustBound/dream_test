//// Fast step-definition lookup using Cucumber-Expression-style placeholders.
////
//// This is the data structure behind `dream_test/gherkin/steps`. It finds
//// the step definition for a line of step text.
////
//// ## Words
////
//// Step text and step patterns are split into words by one function,
//// `tokenize_step_text`. A space ends a word. A double-quoted run, such as
//// `"Red Widget"`, stays in one word with its spaces. A quoted run starts
//// only at a double quote at the start of a word, and ends only at a double
//// quote before a space or at the end of the text, so the quote in
//// `O"Brien` or `5"` is an ordinary character. Because both sides use
//// the same split, a pattern without placeholders always matches its own
//// text.
////
//// ## Placeholder syntax
////
//// - `{int}`: an integer, such as `42` or `-5`
//// - `{float}`: a decimal number, such as `3.14` or `-0.5`
//// - `{string}`: a double-quoted string, such as `"hello world"`. The
////   capture does not include the quotes.
//// - `{word}`: a run of characters with no space, such as `alice` or `user42`
//// - `{}`: any text in one word
////
//// A placeholder can have literal text before or after it in the same word.
//// For example, `${float}USD` matches `$19.99USD` and captures `19.99` as a
//// float. A space in a pattern must be a space in the text: `$ {float}` does
//// not match `$19.99`.
////
//// ## Priority
////
//// When more than one pattern matches a step, lookup compares the words from
//// left to right and takes the pattern with the more specific word at the
//// first word where they differ:
////
//// 1. A word with no placeholders comes first.
//// 2. Then a word with more segments (literal text and placeholders) comes
////    first. `{int}%` comes before `{word}`.
//// 3. Then the segments are compared from left to right. Literal text comes
////    before `{string}`, then `{int}`, `{float}`, `{word}` and `{}`. Longer
////    literal text comes before shorter literal text.
////
//// If the most specific word leads to no match for the rest of the step,
//// lookup tries the next word in this order. So lookup finds a match whenever
//// one exists.
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
import gleam/order.{type Order}
import gleam/string

// ============================================================================
// Segment Types
// ============================================================================

/// One segment of a word in a step pattern.
///
/// `parse_step_pattern` splits each word of a pattern into segments. A word
/// without placeholders is one `LiteralText` segment. The word `${float}USD`
/// is `[LiteralText("$"), FloatParam, LiteralText("USD")]`.
///
pub type StepSegment {
  /// Literal text that the step text must contain exactly.
  /// Example: "have" in "I have {int} items"
  LiteralText(String)

  /// Integer parameter capture.
  /// Matches: 42, -5, 0
  IntParam

  /// Float parameter capture.
  /// Matches: 3.14, -0.5, 2.0
  FloatParam

  /// Double-quoted string parameter capture.
  /// Matches: "hello world", "test"
  StringParam

  /// Word parameter capture.
  /// Matches a run of characters with no space
  WordParam

  /// Anonymous capture.
  /// Matches any text in one word
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
/// Each node can store handlers for different phases. It has one child for
/// each literal word and one child for each word with placeholders.
///
pub opaque type StepTrieNode(handler) {
  StepTrieNode(
    /// Handlers at this node, keyed by phase (one handler for each phase)
    handlers: Dict(StepPhase, handler),
    /// Child nodes for words without placeholders, keyed by the word
    literal_children: Dict(String, StepTrieNode(handler)),
    /// Child nodes for words with placeholders, in priority order
    pattern_children: List(#(List(StepSegment), StepTrieNode(handler))),
  )
}

/// Create an empty trie node.
fn empty_node() -> StepTrieNode(handler) {
  StepTrieNode(
    handlers: dict.new(),
    literal_children: dict.new(),
    pattern_children: [],
  )
}

// ============================================================================
// Step Trie
// ============================================================================

/// Trie for fast step lookup.
///
/// The trie is the main data structure holding all step definitions.
/// Patterns are organized by word, so lookup follows the words of the step
/// text.
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
  let words = parse_step_pattern(pattern)
  case insert_into_node(trie.root, phase, words, handler) {
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
  words: List(List(StepSegment)),
  handler: handler,
) -> Result(StepTrieNode(handler), Nil) {
  case words {
    [] -> insert_handler_at_node(node, phase, handler)
    [[LiteralText(word)], ..rest] ->
      insert_literal_word(node, word, phase, rest, handler)
    [segments, ..rest] ->
      insert_pattern_word(node, segments, phase, rest, handler)
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

fn insert_literal_word(
  node: StepTrieNode(handler),
  word: String,
  phase: StepPhase,
  rest: List(List(StepSegment)),
  handler: handler,
) -> Result(StepTrieNode(handler), Nil) {
  let child = existing_or_empty(dict.get(node.literal_children, word))
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

fn insert_pattern_word(
  node: StepTrieNode(handler),
  segments: List(StepSegment),
  phase: StepPhase,
  rest: List(List(StepSegment)),
  handler: handler,
) -> Result(StepTrieNode(handler), Nil) {
  let child = existing_or_empty(list.key_find(node.pattern_children, segments))
  case insert_into_node(child, phase, rest, handler) {
    Ok(updated_child) ->
      Ok(
        StepTrieNode(
          ..node,
          pattern_children: node.pattern_children
            |> list.key_set(segments, updated_child)
            |> list.sort(compare_pattern_children),
        ),
      )
    Error(Nil) -> Error(Nil)
  }
}

fn existing_or_empty(
  found: Result(StepTrieNode(handler), Nil),
) -> StepTrieNode(handler) {
  case found {
    Ok(existing) -> existing
    Error(Nil) -> empty_node()
  }
}

/// Order two pattern children by priority. The child that lookup tries first
/// is `Lt`.
fn compare_pattern_children(
  left: #(List(StepSegment), StepTrieNode(handler)),
  right: #(List(StepSegment), StepTrieNode(handler)),
) -> Order {
  int.compare(list.length(right.0), list.length(left.0))
  |> order.break_tie(compare_segment_lists(left.0, right.0))
}

/// Compare two segment lists of the same length from left to right.
fn compare_segment_lists(
  left: List(StepSegment),
  right: List(StepSegment),
) -> Order {
  case left, right {
    [left_first, ..left_rest], [right_first, ..right_rest] ->
      compare_segments(left_first, right_first)
      |> order.break_tie(compare_segment_lists(left_rest, right_rest))
    _, _ -> order.Eq
  }
}

fn compare_segments(left: StepSegment, right: StepSegment) -> Order {
  let left_text = literal_text(left)
  let right_text = literal_text(right)
  int.compare(segment_rank(left), segment_rank(right))
  |> order.break_tie(int.compare(
    string.length(right_text),
    string.length(left_text),
  ))
  |> order.break_tie(string.compare(left_text, right_text))
}

fn segment_rank(segment: StepSegment) -> Int {
  case segment {
    LiteralText(_) -> 0
    StringParam -> 1
    IntParam -> 2
    FloatParam -> 3
    WordParam -> 4
    AnyParam -> 5
  }
}

fn literal_text(segment: StepSegment) -> String {
  case segment {
    LiteralText(text) -> text
    _ -> ""
  }
}

// ============================================================================
// Pattern Parsing
// ============================================================================

/// Parse a step pattern string into words of segments.
///
/// Splits the pattern into words with `tokenize_step_text`, the same function
/// that splits step text. Then it splits each word into segments.
/// Placeholders like `{int}` become typed parameter segments. The text around
/// them becomes `LiteralText` segments.
///
/// ## Placeholder Syntax
///
/// | Placeholder | Segment Type | Matches |
/// |-------------|--------------|---------|
/// | `{int}` | `IntParam` | Integers like `42`, `-5` |
/// | `{float}` | `FloatParam` | Decimals like `3.14` |
/// | `{string}` | `StringParam` | Double-quoted strings like `"hello"` |
/// | `{word}` | `WordParam` | A run of characters with no space |
/// | `{}` | `AnyParam` | Any text in one word |
///
/// Other text in braces, such as `{name}`, is literal text.
///
/// ## Prefix and Suffix Handling
///
/// A placeholder can have literal text before or after it in the same word:
///
/// - `${float}` → `[LiteralText("$"), FloatParam]`
/// - `{int}%` → `[IntParam, LiteralText("%")]`
/// - `${float}USD` → `[LiteralText("$"), FloatParam, LiteralText("USD")]`
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
///         [step_trie.LiteralText("the")],
///         [step_trie.LiteralText("total")],
///         [step_trie.LiteralText("is")],
///         [
///           step_trie.LiteralText("$"),
///           step_trie.FloatParam,
///           step_trie.LiteralText("USD"),
///         ],
///       ])
///       |> or_fail_with(
///         "expected ${float}USD to split into literal + FloatParam segments",
///       )
/// ```
///
pub fn parse_step_pattern(pattern pattern: String) -> List(List(StepSegment)) {
  pattern
  |> tokenize_step_text
  |> list.map(parse_pattern_word)
}

fn parse_pattern_word(word: String) -> List(StepSegment) {
  parse_segments(word, "", [])
  |> list.reverse
}

/// Walk a pattern word. `literal` holds the literal text since the last
/// placeholder. `segments` holds the finished segments in reverse order.
fn parse_segments(
  remaining: String,
  literal: String,
  segments: List(StepSegment),
) -> List(StepSegment) {
  case string.split_once(remaining, "{") {
    Ok(#(before, after)) ->
      parse_placeholder(after, literal <> before, segments)
    Error(Nil) -> add_literal(segments, literal <> remaining)
  }
}

/// `after` is the text after a `{`.
fn parse_placeholder(
  after: String,
  literal: String,
  segments: List(StepSegment),
) -> List(StepSegment) {
  case after {
    "int}" <> rest ->
      parse_segments(rest, "", [IntParam, ..add_literal(segments, literal)])
    "float}" <> rest ->
      parse_segments(rest, "", [FloatParam, ..add_literal(segments, literal)])
    "string}" <> rest ->
      parse_segments(rest, "", [StringParam, ..add_literal(segments, literal)])
    "word}" <> rest ->
      parse_segments(rest, "", [WordParam, ..add_literal(segments, literal)])
    "}" <> rest ->
      parse_segments(rest, "", [AnyParam, ..add_literal(segments, literal)])
    _ -> parse_segments(after, literal <> "{", segments)
  }
}

fn add_literal(
  segments: List(StepSegment),
  literal: String,
) -> List(StepSegment) {
  case literal {
    "" -> segments
    _ -> [LiteralText(literal), ..segments]
  }
}

// ============================================================================
// Trie Lookup
// ============================================================================

/// Look up a step in the trie.
///
/// Searches for a handler of the given phase that matches the step text.
/// Only handlers of that phase match. If more than one pattern matches,
/// lookup takes the one with the highest priority (see the module
/// documentation).
///
/// Lookup follows the words of the step text through the trie. It goes back
/// and tries another branch only when a branch does not match.
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

/// Split step text, or a step pattern, into words.
///
/// `lookup` uses this function for step text and `parse_step_pattern` uses it
/// for patterns, so both are split in the same way.
///
/// ## Rules
///
/// 1. A space ends a word. Two or more spaces do not make an empty word.
/// 2. A double-quoted run, such as `"Red Widget"`, stays in one word with its
///    spaces and quotes.
/// 3. A quoted run starts only at a double quote at the start of a word,
///    and ends only at a double quote before a space or at the end of the
///    text. Any other double quote is an ordinary character: in
///    `the input 5" is valid` and `O"Brien says "hi"`, the words are
///    `5"` and `O"Brien`.
///
/// ## Example
///
/// ```gleam
///       step_trie.tokenize_step_text("I add \"Red Widget\" and pay $19.99USD")
///       |> should
///       |> be_equal(["I", "add", "\"Red Widget\"", "and", "pay", "$19.99USD"])
///       |> or_fail_with("expected tokenization to keep the quoted run")
/// ```
///
pub fn tokenize_step_text(text text: String) -> List(String) {
  tokenize_preserving_quotes(text, [], "", False)
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

/// A double quote starts a quoted run only at the start of a word, and
/// ends it only before a space or at the end of the text. Any other double
/// quote is an ordinary character of the word.
fn process_char(
  char: String,
  rest: String,
  tokens: List(String),
  current: String,
  in_quotes: Bool,
) -> List(String) {
  let starts_word = current == ""
  let ends_word = rest == "" || string.starts_with(rest, " ")
  case char, in_quotes, starts_word, ends_word {
    "\"", False, True, _ ->
      tokenize_preserving_quotes(rest, tokens, current <> char, True)
    "\"", True, _, True ->
      tokenize_preserving_quotes(rest, tokens, current <> char, False)
    " ", False, _, _ -> {
      let updated_tokens = add_token_if_non_empty(tokens, current)
      tokenize_preserving_quotes(rest, updated_tokens, "", False)
    }
    _, _, _, _ ->
      tokenize_preserving_quotes(rest, tokens, current <> char, in_quotes)
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

/// The state of a lookup at one word of the step text.
type WordLookup {
  WordLookup(
    phase: StepPhase,
    word: String,
    rest: List(String),
    captures: List(CapturedValue),
  )
}

/// Match one word: first the literal child, then the pattern children in
/// priority order.
fn lookup_word(
  node: StepTrieNode(handler),
  phase: StepPhase,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  let search =
    WordLookup(phase: phase, word: word, rest: rest, captures: captures)
  case dict.get(node.literal_children, word) {
    Ok(child) -> lookup_after_literal_word(child, node, search)
    Error(Nil) -> lookup_pattern_children(node.pattern_children, search)
  }
}

fn lookup_after_literal_word(
  child: StepTrieNode(handler),
  node: StepTrieNode(handler),
  search: WordLookup,
) -> Option(StepMatch(handler)) {
  case lookup_in_node(child, search.phase, search.rest, search.captures) {
    Some(found) -> Some(found)
    None -> lookup_pattern_children(node.pattern_children, search)
  }
}

fn lookup_pattern_children(
  children: List(#(List(StepSegment), StepTrieNode(handler))),
  search: WordLookup,
) -> Option(StepMatch(handler)) {
  case children {
    [] -> None
    [#(segments, child), ..others] ->
      lookup_pattern_child(segments, child, others, search)
  }
}

fn lookup_pattern_child(
  segments: List(StepSegment),
  child: StepTrieNode(handler),
  others: List(#(List(StepSegment), StepTrieNode(handler))),
  search: WordLookup,
) -> Option(StepMatch(handler)) {
  case match_segments(segments, search.word, search.captures) {
    Some(captures) -> lookup_after_pattern_word(child, captures, others, search)
    None -> lookup_pattern_children(others, search)
  }
}

fn lookup_after_pattern_word(
  child: StepTrieNode(handler),
  captures: List(CapturedValue),
  others: List(#(List(StepSegment), StepTrieNode(handler))),
  search: WordLookup,
) -> Option(StepMatch(handler)) {
  case lookup_in_node(child, search.phase, search.rest, captures) {
    Some(found) -> Some(found)
    None -> lookup_pattern_children(others, search)
  }
}

// ============================================================================
// Word Matching
// ============================================================================

/// Match the segments of one pattern word against one word of step text.
/// Returns the captures with the new values in front.
fn match_segments(
  segments: List(StepSegment),
  text: String,
  captures: List(CapturedValue),
) -> Option(List(CapturedValue)) {
  case segments {
    [] -> match_end(text, captures)
    [LiteralText(literal), ..rest] ->
      match_literal(literal, rest, text, captures)
    [IntParam, ..rest] ->
      match_placeholder(
        PlaceholderMatch(capture_int, rest, text, captures),
        string.length(text),
      )
    [FloatParam, ..rest] ->
      match_placeholder(
        PlaceholderMatch(capture_float, rest, text, captures),
        string.length(text),
      )
    [StringParam, ..rest] ->
      match_placeholder(
        PlaceholderMatch(capture_string, rest, text, captures),
        string.length(text),
      )
    [WordParam, ..rest] ->
      match_placeholder(
        PlaceholderMatch(capture_word, rest, text, captures),
        string.length(text),
      )
    [AnyParam, ..rest] ->
      match_placeholder(
        PlaceholderMatch(capture_any, rest, text, captures),
        string.length(text),
      )
  }
}

fn match_end(
  text: String,
  captures: List(CapturedValue),
) -> Option(List(CapturedValue)) {
  case text {
    "" -> Some(captures)
    _ -> None
  }
}

fn match_literal(
  literal: String,
  rest: List(StepSegment),
  text: String,
  captures: List(CapturedValue),
) -> Option(List(CapturedValue)) {
  case string.starts_with(text, literal) {
    True ->
      match_segments(
        rest,
        string.drop_start(text, string.length(literal)),
        captures,
      )
    False -> None
  }
}

/// A placeholder at the start of `text`, followed by the `rest` segments.
type PlaceholderMatch {
  PlaceholderMatch(
    capture: fn(String) -> Result(CapturedValue, Nil),
    rest: List(StepSegment),
    text: String,
    captures: List(CapturedValue),
  )
}

/// Try the placeholder on the first `length` characters of the text, then on
/// fewer. The placeholder takes the longest text that lets the rest of the
/// word match.
fn match_placeholder(
  attempt: PlaceholderMatch,
  length: Int,
) -> Option(List(CapturedValue)) {
  case length {
    0 -> None
    _ -> match_placeholder_length(attempt, length)
  }
}

fn match_placeholder_length(
  attempt: PlaceholderMatch,
  length: Int,
) -> Option(List(CapturedValue)) {
  case attempt.capture(string.slice(attempt.text, 0, length)) {
    Ok(value) -> match_after_placeholder(attempt, length, value)
    Error(Nil) -> match_placeholder(attempt, length - 1)
  }
}

fn match_after_placeholder(
  attempt: PlaceholderMatch,
  length: Int,
  value: CapturedValue,
) -> Option(List(CapturedValue)) {
  let after = string.drop_start(attempt.text, length)
  case match_segments(attempt.rest, after, [value, ..attempt.captures]) {
    Some(captures) -> Some(captures)
    None -> match_placeholder(attempt, length - 1)
  }
}

fn capture_int(text: String) -> Result(CapturedValue, Nil) {
  case int.parse(text) {
    Ok(value) -> Ok(CapturedInt(value))
    Error(Nil) -> Error(Nil)
  }
}

/// A float as `float.parse` reads it. The Erlang parser under it also
/// reads a comma as the decimal point, so text with a comma, such as
/// `1,000`, is not a float.
fn capture_float(text: String) -> Result(CapturedValue, Nil) {
  case string.contains(text, ","), float.parse(text) {
    False, Ok(value) -> Ok(CapturedFloat(value))
    _, _ -> Error(Nil)
  }
}

/// A double quote, any text without a double quote, and a double quote.
fn capture_string(text: String) -> Result(CapturedValue, Nil) {
  let inner = text |> string.drop_start(1) |> string.drop_end(1)
  let quoted =
    string.length(text) >= 2
    && string.starts_with(text, "\"")
    && string.ends_with(text, "\"")
    && !string.contains(inner, "\"")
  case quoted {
    True -> Ok(CapturedString(inner))
    False -> Error(Nil)
  }
}

fn capture_word(text: String) -> Result(CapturedValue, Nil) {
  case string.contains(text, " ") {
    True -> Error(Nil)
    False -> Ok(CapturedWord(text))
  }
}

fn capture_any(text: String) -> Result(CapturedValue, Nil) {
  Ok(CapturedWord(text))
}
