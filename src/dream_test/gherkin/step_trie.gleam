//// Step Trie - Fast step definition lookup using Cucumber Expressions.
////
//// Provides O(word count) step matching instead of O(step definitions) linear search.
//// This is the core data structure for efficient Gherkin step matching.
////
//// ## Performance Characteristics
////
//// - **Insert**: O(words in pattern) - typically 5-10 words
//// - **Lookup**: O(words in step text) - independent of total step definitions
//// - **Memory**: O(total words across all patterns)
////
//// ## Placeholder Syntax
////
//// Patterns use Cucumber Expression placeholders:
////
//// | Placeholder | Matches | Captures |
//// |-------------|---------|----------|
//// | `{int}` | Integer like `42`, `-5` | `CapturedInt(Int)` |
//// | `{float}` | Decimal like `3.14`, `0.5` | `CapturedFloat(Float)` |
//// | `{string}` | Quoted text like `"hello"` | `CapturedString(String)` |
//// | `{word}` | Single word like `apple` | `CapturedWord(String)` |
//// | `{}` | Any single token | `CapturedWord(String)` |
////
//// ## Prefix and Suffix Support
////
//// Placeholders can have literal prefixes and suffixes:
////
//// - `${float}` matches `$3.99` and captures `3.99`
//// - `{int}%` matches `50%` and captures `50`
//// - `${float}USD` matches `$19.99USD` and captures `19.99`
////
//// This works by splitting patterns and text at placeholder/numeric boundaries,
//// so `${float}` becomes `["$", "{float}"]` in the trie, and `$3.99` becomes
//// `["$", "3.99"]` during matching.
////
//// ## Matching Priority
////
//// When multiple patterns could match, the trie uses this priority order:
////
//// 1. **Literal words** - exact string match (highest priority)
//// 2. **{string}** - quoted string capture
//// 3. **{int}** - integer capture
//// 4. **{float}** - decimal capture  
//// 5. **{word}** - single word capture
//// 6. **{}** - any word capture (lowest priority)
////
//// This ensures the most specific step definition wins.
////
//// ## Example
////
//// ```gleam
//// let trie = new()
//// |> insert("Given", "I have {int} items", count_handler)
//// |> insert("Given", "I have an empty cart", empty_handler)
//// |> insert("Then", "the total is ${float}", total_handler)
////
//// // Matches empty_handler (literal "an" beats {int})
//// lookup(trie, "Given", "I have an empty cart")
////
//// // Matches count_handler, captures [CapturedInt(42)]
//// lookup(trie, "Given", "I have 42 items")
////
//// // Matches total_handler, captures [CapturedFloat(19.99)]
//// lookup(trie, "Then", "the total is $19.99")
//// ```

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
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
/// Each node can store handlers for different keywords and has children
/// for different segment types. Children are organized by priority.
///
pub opaque type StepTrieNode(handler) {
  StepTrieNode(
    /// Handlers at this node, keyed by keyword (Given, When, Then, *)
    handlers: Dict(String, handler),
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
/// let trie = new()
/// |> insert("Given", "I have {int} items", handler)
/// ```
///
pub fn new() -> StepTrie(handler) {
  StepTrie(root: empty_node())
}

/// Insert a step pattern into the trie.
///
/// Adds a handler at the path specified by the pattern. If a handler already
/// exists for the same keyword and pattern, it is replaced.
///
/// ## Parameters
///
/// - `trie`: The trie to insert into
/// - `keyword`: Step keyword as string ("Given", "When", "Then", or "*" for any)
/// - `pattern`: Step pattern with placeholders (e.g., "I have {int} items")
/// - `handler`: The handler to store
///
/// ## Example
///
/// ```gleam
/// let trie = new()
/// |> insert("Given", "I have {int} items", have_items)
/// |> insert("When", "I add {int} more", add_items)
/// ```
///
pub fn insert(
  trie: StepTrie(handler),
  keyword: String,
  pattern: String,
  handler: handler,
) -> StepTrie(handler) {
  let segments = parse_step_pattern(pattern)
  let updated_root = insert_into_node(trie.root, keyword, segments, handler)
  StepTrie(root: updated_root)
}

fn insert_into_node(
  node: StepTrieNode(handler),
  keyword: String,
  segments: List(StepSegment),
  handler: handler,
) -> StepTrieNode(handler) {
  case segments {
    [] -> insert_handler_at_node(node, keyword, handler)
    [LiteralWord(word), ..rest] ->
      insert_literal_segment(node, word, keyword, rest, handler)
    [IntParam, ..rest] -> insert_int_segment(node, keyword, rest, handler)
    [FloatParam, ..rest] -> insert_float_segment(node, keyword, rest, handler)
    [StringParam, ..rest] -> insert_string_segment(node, keyword, rest, handler)
    [WordParam, ..rest] -> insert_word_segment(node, keyword, rest, handler)
    [AnyParam, ..rest] -> insert_any_segment(node, keyword, rest, handler)
  }
}

fn insert_handler_at_node(
  node: StepTrieNode(handler),
  keyword: String,
  handler: handler,
) -> StepTrieNode(handler) {
  let updated_handlers = dict.insert(node.handlers, keyword, handler)
  StepTrieNode(..node, handlers: updated_handlers)
}

fn insert_literal_segment(
  node: StepTrieNode(handler),
  word: String,
  keyword: String,
  rest: List(StepSegment),
  handler: handler,
) -> StepTrieNode(handler) {
  let child = get_or_create_literal_child(node, word)
  let updated_child = insert_into_node(child, keyword, rest, handler)
  let updated_children = dict.insert(node.literal_children, word, updated_child)
  StepTrieNode(..node, literal_children: updated_children)
}

fn insert_int_segment(
  node: StepTrieNode(handler),
  keyword: String,
  rest: List(StepSegment),
  handler: handler,
) -> StepTrieNode(handler) {
  let child = option.unwrap(node.int_child, empty_node())
  let updated_child = insert_into_node(child, keyword, rest, handler)
  StepTrieNode(..node, int_child: Some(updated_child))
}

fn insert_float_segment(
  node: StepTrieNode(handler),
  keyword: String,
  rest: List(StepSegment),
  handler: handler,
) -> StepTrieNode(handler) {
  let child = option.unwrap(node.float_child, empty_node())
  let updated_child = insert_into_node(child, keyword, rest, handler)
  StepTrieNode(..node, float_child: Some(updated_child))
}

fn insert_string_segment(
  node: StepTrieNode(handler),
  keyword: String,
  rest: List(StepSegment),
  handler: handler,
) -> StepTrieNode(handler) {
  let child = option.unwrap(node.string_child, empty_node())
  let updated_child = insert_into_node(child, keyword, rest, handler)
  StepTrieNode(..node, string_child: Some(updated_child))
}

fn insert_word_segment(
  node: StepTrieNode(handler),
  keyword: String,
  rest: List(StepSegment),
  handler: handler,
) -> StepTrieNode(handler) {
  let child = option.unwrap(node.word_child, empty_node())
  let updated_child = insert_into_node(child, keyword, rest, handler)
  StepTrieNode(..node, word_child: Some(updated_child))
}

fn insert_any_segment(
  node: StepTrieNode(handler),
  keyword: String,
  rest: List(StepSegment),
  handler: handler,
) -> StepTrieNode(handler) {
  let child = option.unwrap(node.any_child, empty_node())
  let updated_child = insert_into_node(child, keyword, rest, handler)
  StepTrieNode(..node, any_child: Some(updated_child))
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
/// ## Examples
///
/// ```gleam
/// parse_step_pattern("I have {int} items")
/// // [LiteralWord("I"), LiteralWord("have"), IntParam, LiteralWord("items")]
///
/// parse_step_pattern("the total is ${float}")
/// // [LiteralWord("the"), LiteralWord("total"), LiteralWord("is"),
/// //  LiteralWord("$"), FloatParam]
///
/// parse_step_pattern("I apply a {int}% discount")
/// // [LiteralWord("I"), LiteralWord("apply"), LiteralWord("a"),
/// //  IntParam, LiteralWord("%"), LiteralWord("discount")]
/// ```
///
pub fn parse_step_pattern(pattern: String) -> List(StepSegment) {
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
    [placeholder, ..rest] -> {
      case string.split_once(word, placeholder) {
        Ok(#(before, after)) -> {
          let parts = []
          let parts = case before {
            "" -> parts
            _ -> list.append(parts, [before])
          }
          let parts = list.append(parts, [placeholder])
          let parts = case after {
            "" -> parts
            _ -> list.append(parts, split_word_around_placeholder(after))
          }
          parts
        }
        Error(_) -> split_on_first_placeholder(word, rest)
      }
    }
  }
}

/// Split a token on boundaries between numeric and non-numeric characters.
/// e.g., "$3.00" -> ["$", "3.00"]
/// e.g., "10%" -> ["10", "%"]
/// e.g., "hello" -> ["hello"]
/// Quoted strings are not split.
fn split_numeric_boundaries(token: String) -> List(String) {
  case is_quoted_string(token) {
    True -> [token]
    False -> do_split_numeric(token)
  }
}

fn do_split_numeric(token: String) -> List(String) {
  case regexp.from_string("(-?[0-9]+\\.?[0-9]*)") {
    Ok(re) -> {
      case regexp.split(re, token) {
        // No match, return as-is
        [only] -> [only]
        parts -> parts |> list.filter(is_non_empty)
      }
    }
    Error(_) -> [token]
  }
}

// ============================================================================
// Trie Lookup
// ============================================================================

/// Look up a step in the trie.
///
/// Searches for a handler matching the given keyword and step text.
/// Returns the matched handler and captured values, or None if no match.
///
/// Lookup is O(word count) - independent of total step definitions.
///
/// ## Parameters
///
/// - `trie`: The trie to search
/// - `keyword`: Step keyword as string ("Given", "When", "Then")
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
/// let result = lookup(trie, "Given", "I have 42 items")
/// case result {
///   Some(StepMatch(handler, captures)) -> {
///     // captures = [CapturedInt(42)]
///   }
///   None -> // No matching step definition
/// }
/// ```
///
pub fn lookup(
  trie: StepTrie(handler),
  keyword: String,
  text: String,
) -> Option(StepMatch(handler)) {
  let words = tokenize_step_text(text)
  lookup_in_node(trie.root, keyword, words, [])
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
/// ## Examples
///
/// ```gleam
/// // Basic tokenization
/// tokenize_step_text("I have 5 items")
/// // ["I", "have", "5", "items"]
///
/// // Quoted strings preserved
/// tokenize_step_text("I add \"Red Widget\" to cart")
/// // ["I", "add", "\"Red Widget\"", "to", "cart"]
///
/// // Currency prefix split from number
/// tokenize_step_text("the total is $19.99")
/// // ["the", "total", "is", "$", "19.99"]
///
/// // Percentage suffix split from number
/// tokenize_step_text("I apply a 15% discount")
/// // ["I", "apply", "a", "15", "%", "discount"]
///
/// // Multiple numeric boundaries
/// tokenize_step_text("price is $99.99USD")
/// // ["price", "is", "$", "99.99", "USD"]
/// ```
///
pub fn tokenize_step_text(text: String) -> List(String) {
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
  keyword: String,
  words: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  case words {
    [] -> lookup_handler_at_node(node, keyword, captures)
    [word, ..rest] -> lookup_word(node, keyword, word, rest, captures)
  }
}

fn lookup_handler_at_node(
  node: StepTrieNode(handler),
  keyword: String,
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  // Try exact keyword first, then wildcard "*"
  let handler_result = case dict.get(node.handlers, keyword) {
    Ok(handler) -> Some(handler)
    Error(_) -> dict.get(node.handlers, "*") |> option.from_result
  }
  case handler_result {
    Some(handler) -> Some(StepMatch(handler, list.reverse(captures)))
    None -> None
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
  keyword: String,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  // 1. Try literal match first (highest priority)
  case dict.get(node.literal_children, word) {
    Ok(child) -> lookup_in_node(child, keyword, rest, captures)
    Error(_) -> try_param_matches(node, keyword, word, rest, captures)
  }
}

fn try_param_matches(
  node: StepTrieNode(handler),
  keyword: String,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  // 2. Try {string} (quoted)
  case try_string_match(node, keyword, word, rest, captures) {
    Some(result) -> Some(result)
    None -> try_numeric_matches(node, keyword, word, rest, captures)
  }
}

fn try_string_match(
  node: StepTrieNode(handler),
  keyword: String,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  case node.string_child, is_quoted_string(word) {
    Some(child), True -> {
      let unquoted = unquote_string(word)
      let updated_captures = [CapturedString(unquoted), ..captures]
      lookup_in_node(child, keyword, rest, updated_captures)
    }
    _, _ -> None
  }
}

fn try_numeric_matches(
  node: StepTrieNode(handler),
  keyword: String,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  // 3. Try {int}
  case try_int_match(node, keyword, word, rest, captures) {
    Some(result) -> Some(result)
    None -> try_float_then_word(node, keyword, word, rest, captures)
  }
}

fn try_int_match(
  node: StepTrieNode(handler),
  keyword: String,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  case node.int_child, int.parse(word) {
    Some(child), Ok(value) -> {
      let updated_captures = [CapturedInt(value), ..captures]
      lookup_in_node(child, keyword, rest, updated_captures)
    }
    _, _ -> None
  }
}

fn try_float_then_word(
  node: StepTrieNode(handler),
  keyword: String,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  // 4. Try {float}
  case try_float_match(node, keyword, word, rest, captures) {
    Some(result) -> Some(result)
    None -> try_word_matches(node, keyword, word, rest, captures)
  }
}

fn try_float_match(
  node: StepTrieNode(handler),
  keyword: String,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  case node.float_child, float.parse(word) {
    Some(child), Ok(value) -> {
      let updated_captures = [CapturedFloat(value), ..captures]
      lookup_in_node(child, keyword, rest, updated_captures)
    }
    _, _ -> None
  }
}

fn try_word_matches(
  node: StepTrieNode(handler),
  keyword: String,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  // 5. Try {word}
  case node.word_child {
    Some(child) -> {
      let updated_captures = [CapturedWord(word), ..captures]
      lookup_in_node(child, keyword, rest, updated_captures)
    }
    None -> try_any_match(node, keyword, word, rest, captures)
  }
}

fn try_any_match(
  node: StepTrieNode(handler),
  keyword: String,
  word: String,
  rest: List(String),
  captures: List(CapturedValue),
) -> Option(StepMatch(handler)) {
  // 6. Try {} (any)
  case node.any_child {
    Some(child) -> {
      let updated_captures = [CapturedWord(word), ..captures]
      lookup_in_node(child, keyword, rest, updated_captures)
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
