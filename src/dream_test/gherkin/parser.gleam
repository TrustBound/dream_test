//// Parse Gherkin `.feature` files into `gherkin/types.Feature`.
////
//// Use this when you have Gherkin text (from a file on disk, a fixture, or a
//// string literal) and you want a structured representation. Turn it into
//// runnable tests with `steps.feature_suite`, or load `.feature` files by a
//// pattern with `dream_test/gherkin/discover`.
////
//// The parser follows the official Gherkin grammar for English:
//// `Feature` (and its synonyms `Business Need` and `Ability`), `Rule`,
//// `Background`, `Scenario` / `Example`, `Scenario Outline` /
//// `Scenario Template`, `Examples` / `Scenarios`, steps (`Given`, `When`,
//// `Then`, `And`, `But` and `*`), tags (`@tag`), comments (`#`), DocStrings
//// (`"""` and ```` ``` ````), DataTables (`| ... |`) and free-text
//// descriptions below each header line.
////
//// The parser works in two stages. First it turns each line into a token.
//// Then a small state machine reads the tokens in the order that the grammar
//// sets. A line that the grammar does not permit at its position is an
//// error. Each error is a `ParseError` with the line number and a
//// `ParseProblem` that tells what is wrong.
////
//// dream_test differs from the official grammar in two ways:
////
//// - `And`, `But` and `*` take the phase of the step before them. The first
////   step of a Background, or of a scenario with no Background steps before
////   it, must use `Given`, `When` or `Then`.
//// - A file must contain a Feature. Only English is supported, so a
////   `# language:` line must name `en`.

import dream_test/file.{type FileError}
import dream_test/gherkin/types.{
  type Background, type DocString, type Examples, type Feature, type Rule,
  type Scenario, type ScenarioKeyword, type Step, type StepKeyword, And,
  Asterisk, Background, But, DataTable, DocString, Examples, ExamplesTable,
  Feature, Given, KeywordExample, KeywordScenario, KeywordScenarioOutline,
  KeywordScenarioTemplate, Rule, Scenario, Step, Then, When,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// ============================================================================
// Public Types
// ============================================================================

/// A kind of line that the grammar can expect at a position.
///
/// `UnexpectedLine` and `UnexpectedEndOfFile` list the kinds of line that the
/// grammar permits at the position of the error.
///
/// ## Example
///
/// ```gleam
/// parser.token_kind_to_string(parser.ScenarioLine)
/// |> should
/// |> be_equal("a Scenario line")
/// |> or_fail_with("expected the Scenario line description")
/// ```
///
pub type TokenKind {
  /// A `Feature:` line
  FeatureLine
  /// A `Rule:` line
  RuleLine
  /// A `Background:` line
  BackgroundLine
  /// A `Scenario:`, `Example:`, `Scenario Outline:` or `Scenario Template:` line
  ScenarioLine
  /// An `Examples:` or `Scenarios:` line
  ExamplesLine
  /// A step line (`Given`, `When`, `Then`, `And`, `But` or `*`)
  StepLine
  /// A table row (`| ... |`)
  TableRow
  /// A DocString separator (`"""` or ```` ``` ````)
  DocStringSeparator
  /// A line of tags (`@tag`)
  TagLine
  /// The end of the file
  EndOfFile
}

/// What is wrong with a feature file.
///
/// Use `problem_to_string` to get a human-readable message.
///
/// ## Example
///
/// ```gleam
/// parser.parse_string("Feature: F\n  Scenario: S\n    And a step\n")
/// |> should
/// |> be_equal(Error(parser.ParseError(
///   line: 3,
///   problem: parser.MissingPreviousStep(keyword: gherkin_types.And, text: "a step"),
/// )))
/// |> or_fail_with("expected a missing previous step error")
/// ```
///
pub type ParseProblem {
  /// The file holds only empty lines and comments (a `# language: en`
  /// line included). The official Gherkin parser accepts such a file as an
  /// empty document. dream_test rejects it, so that a wrong file does not
  /// pass with no tests. A file with any other line before its `Feature:`
  /// line gives `UnexpectedLine`, and a file with tags and no `Feature:`
  /// line gives `UnexpectedEndOfFile`.
  MissingFeature
  /// The grammar does not permit this line at this position.
  UnexpectedLine(text: String, expected: List(TokenKind))
  /// The file ends at a position where the grammar expects more lines.
  UnexpectedEndOfFile(expected: List(TokenKind))
  /// A DocString starts on `opened_on_line` and the file ends before the
  /// closing separator.
  UnclosedDocString(opened_on_line: Int)
  /// A table row has a different number of cells than the first row of its
  /// table.
  InconsistentCellCount(expected_cells: Int, found_cells: Int)
  /// A tag contains whitespace (for example `@a tag`).
  TagContainsWhitespace(tag: String)
  /// A `# language:` line names a language other than `en`.
  UnsupportedLanguage(language: String)
  /// A step has more than one DocString.
  RepeatedDocString
  /// An `And`, `But` or `*` step has no step before it.
  MissingPreviousStep(keyword: StepKeyword, text: String)
}

/// A parse error: the line where the parser stopped, and the problem.
///
/// The line is 1-based. When the problem is at the end of the file, the line
/// is one more than the number of lines in the file.
///
/// ## Example
///
/// ```gleam
/// parser.parse_error_to_string(parser.ParseError(
///   line: 3,
///   problem: parser.RepeatedDocString,
/// ))
/// |> should
/// |> be_equal("line 3: Step cannot have more than one DocString")
/// |> or_fail_with("expected the rendered parse error")
/// ```
///
pub type ParseError {
  ParseError(line: Int, problem: ParseProblem)
}

/// Why `parse_file` could not give a Feature.
///
/// ## Example
///
/// ```gleam
/// parser.parse_file("test/missing.feature")
/// |> should
/// |> be_equal(Error(parser.UnreadableFeatureFile(
///   error: file.NotFound("test/missing.feature"),
/// )))
/// |> or_fail_with("expected an unreadable file error")
/// ```
///
pub type FeatureFileError {
  /// The file could not be read.
  UnreadableFeatureFile(error: FileError)
  /// The file was read, but its content is not valid Gherkin.
  InvalidFeatureFile(path: String, error: ParseError)
  /// No file matches the glob pattern of a feature discovery.
  /// `discover.load` and `discover.to_suite` give this error.
  NoMatchingFeatureFiles(pattern: String)
  /// The glob pattern of a feature discovery cannot be searched, for
  /// example `features/{a.feature` with no closing brace. `reason` is
  /// `<class>:<reason>` from the search. `discover.load` and
  /// `discover.to_suite` give this error.
  InvalidFeatureFilePattern(pattern: String, reason: String)
}

// ============================================================================
// Public API
// ============================================================================

/// Parse a `.feature` file from disk.
///
/// Reads the file and parses its contents into a Feature. The `source` field
/// of the Feature is the path.
///
/// ## Parameters
///
/// - `path`: Path to the `.feature` file
///
/// ## Returns
///
/// - `Ok(Feature)`: Successfully parsed feature
/// - `Error(UnreadableFeatureFile(..))`: The file could not be read
/// - `Error(InvalidFeatureFile(..))`: The content is not valid Gherkin
///
/// ## Example
///
/// ```gleam
///   let assert Ok(feature) = parser.parse_file("test/cart.feature")
/// ```
///
pub fn parse_file(path path: String) -> Result(Feature, FeatureFileError) {
  case file.read(path) {
    Ok(content) -> parse_file_content(path, content)
    Error(error) -> Error(UnreadableFeatureFile(error: error))
  }
}

fn parse_file_content(
  path: String,
  content: String,
) -> Result(Feature, FeatureFileError) {
  case parse_string(content) {
    Ok(feature) -> Ok(Feature(..feature, source: Some(path)))
    Error(error) -> Error(InvalidFeatureFile(path: path, error: error))
  }
}

/// Parse Gherkin content from a string.
///
/// ## Parameters
///
/// - `content`: Gherkin content as a string
///
/// ## Returns
///
/// - `Ok(Feature)`: Successfully parsed feature
/// - `Error(ParseError)`: The line and the problem of the first error
///
/// ## Example
///
/// ```gleam
///       let content =
///         "@smoke\n"
///         <> "Feature: Demo\n"
///         <> "\n"
///         <> "  Scenario: One\n"
///         <> "    Given a thing\n"
///
///       let assert Ok(feature) = parser.parse_string(content)
///
///       feature.name
///       |> should
///       |> be_equal("Demo")
///       |> or_fail_with("expected feature name Demo")
/// ```
///
pub fn parse_string(content content: String) -> Result(Feature, ParseError) {
  content
  |> tokenize
  |> parse_document
}

/// Describe a `TokenKind` in words, for error messages.
///
/// ## Example
///
/// ```gleam
/// parser.token_kind_to_string(parser.EndOfFile)
/// |> should
/// |> be_equal("the end of the file")
/// |> or_fail_with("expected the end of file description")
/// ```
///
pub fn token_kind_to_string(kind kind: TokenKind) -> String {
  case kind {
    FeatureLine -> "a Feature line"
    RuleLine -> "a Rule line"
    BackgroundLine -> "a Background line"
    ScenarioLine -> "a Scenario line"
    ExamplesLine -> "an Examples line"
    StepLine -> "a step"
    TableRow -> "a table row"
    DocStringSeparator -> "a DocString separator"
    TagLine -> "a tag line"
    EndOfFile -> "the end of the file"
  }
}

/// Render a `ParseProblem` as a human-readable message.
///
/// ## Example
///
/// ```gleam
/// parser.problem_to_string(parser.RepeatedDocString)
/// |> should
/// |> be_equal("Step cannot have more than one DocString")
/// |> or_fail_with("expected the repeated DocString message")
/// ```
///
pub fn problem_to_string(problem problem: ParseProblem) -> String {
  case problem {
    MissingFeature -> "No Feature found in content"
    UnexpectedLine(text, expected) ->
      "Found \"" <> text <> "\", but expected " <> join_or(expected) <> "."
    UnexpectedEndOfFile(expected) ->
      "The file ends here, but expected " <> join_or(expected) <> "."
    UnclosedDocString(opened_on_line) ->
      "The DocString that starts on line "
      <> int.to_string(opened_on_line)
      <> " is not closed"
    InconsistentCellCount(expected_cells, found_cells) ->
      "This table row has "
      <> int.to_string(found_cells)
      <> " cells, but the first row of the table has "
      <> int.to_string(expected_cells)
      <> " cells"
    TagContainsWhitespace(tag) ->
      "The tag \"@"
      <> tag
      <> "\" contains whitespace. A tag cannot contain whitespace."
    UnsupportedLanguage(language) ->
      "The language \""
      <> language
      <> "\" is not supported. dream_test supports only English (\"en\")."
    RepeatedDocString -> "Step cannot have more than one DocString"
    MissingPreviousStep(keyword, text) ->
      "\""
      <> types.keyword_to_string(keyword)
      <> " "
      <> text
      <> "\" has no step before it. And, But and * take the phase of the step before them, so the first step of a Background, or of a Scenario with no Background steps, must use Given, When or Then."
  }
}

/// Render a `ParseError` as `line N: <problem>`.
///
/// ## Example
///
/// ```gleam
/// parser.parse_error_to_string(parser.ParseError(
///   line: 1,
///   problem: parser.MissingFeature,
/// ))
/// |> should
/// |> be_equal("line 1: No Feature found in content")
/// |> or_fail_with("expected the rendered parse error")
/// ```
///
pub fn parse_error_to_string(error error: ParseError) -> String {
  "line "
  <> int.to_string(error.line)
  <> ": "
  <> problem_to_string(error.problem)
}

/// Render a `FeatureFileError` as a human-readable message.
///
/// An invalid file gives `<path>: line N: <problem>`. An unreadable file
/// gives `Failed to read feature file: <reason>`. A pattern without files
/// gives `No feature files match the pattern "<pattern>"`. A pattern that
/// cannot be searched gives
/// `Cannot search for feature files with the pattern "<pattern>": <reason>`.
///
/// ## Example
///
/// ```gleam
/// parser.feature_file_error_to_string(parser.InvalidFeatureFile(
///   path: "test/cart.feature",
///   error: parser.ParseError(line: 1, problem: parser.MissingFeature),
/// ))
/// |> should
/// |> be_equal("test/cart.feature: line 1: No Feature found in content")
/// |> or_fail_with("expected the rendered file error")
/// ```
///
pub fn feature_file_error_to_string(error error: FeatureFileError) -> String {
  case error {
    UnreadableFeatureFile(error) ->
      "Failed to read feature file: " <> file.error_to_string(error)
    InvalidFeatureFile(path, error) ->
      path <> ": " <> parse_error_to_string(error)
    NoMatchingFeatureFiles(pattern) ->
      "No feature files match the pattern \"" <> pattern <> "\""
    InvalidFeatureFilePattern(pattern, reason) ->
      "Cannot search for feature files with the pattern \""
      <> pattern
      <> "\": "
      <> reason
  }
}

fn join_or(kinds: List(TokenKind)) -> String {
  case kinds {
    [] -> "nothing"
    [only] -> token_kind_to_string(only)
    [first, last] ->
      token_kind_to_string(first) <> " or " <> token_kind_to_string(last)
    [first, ..rest] -> token_kind_to_string(first) <> ", " <> join_or(rest)
  }
}

// ============================================================================
// Tokens
// ============================================================================

type Token {
  Token(line: Int, text: String, kind: Kind)
}

type Kind {
  Empty
  Comment
  Tags
  FeatureHeader(name: String)
  RuleHeader(name: String)
  BackgroundHeader(name: String)
  ScenarioHeader(keyword: ScenarioKeyword, name: String)
  ExamplesHeader(name: String)
  StepToken(keyword: StepKeyword, text: String)
  DocStringToken(separator: String, media_type: String)
  TableToken(cells: List(String))
  Other
}

/// The tokens of a file. The stream always ends with `End`, which holds the
/// line number after the last line.
type Stream {
  Next(token: Token, rest: Stream)
  End(line: Int)
}

fn tokenize(content: String) -> Stream {
  let lines =
    content
    |> string.split("\n")
    |> list.map(drop_carriage_return)
    |> list.reverse
    |> drop_blank_last_line
  build_stream(lines, End(line: list.length(lines) + 1))
}

fn drop_carriage_return(line: String) -> String {
  case string.ends_with(line, "\r") {
    True -> string.drop_end(line, 1)
    False -> line
  }
}

/// Takes the lines newest first and gives them in file order.
fn drop_blank_last_line(lines_newest_first: List(String)) -> List(String) {
  case lines_newest_first {
    [last, ..rest] if last == "" -> list.reverse(rest)
    _ -> list.reverse(lines_newest_first)
  }
}

fn build_stream(lines: List(String), end: Stream) -> Stream {
  build_stream_loop(list.reverse(lines), list.length(lines), end)
}

fn build_stream_loop(
  lines_newest_first: List(String),
  line_number: Int,
  stream: Stream,
) -> Stream {
  case lines_newest_first {
    [] -> stream
    [text, ..rest] ->
      build_stream_loop(
        rest,
        line_number - 1,
        Next(token: Token(line_number, text, classify(text)), rest: stream),
      )
  }
}

fn classify(text: String) -> Kind {
  let trimmed = string.trim_start(text)
  case trimmed {
    "" -> Empty
    "#" <> _ -> Comment
    "@" <> _ -> Tags
    "|" <> _ -> TableToken(cells: table_cells(trimmed))
    "\"\"\"" <> rest -> DocStringToken("\"\"\"", string.trim(rest))
    "```" <> rest -> DocStringToken("```", string.trim(rest))
    "Feature:" <> rest -> FeatureHeader(string.trim(rest))
    "Business Need:" <> rest -> FeatureHeader(string.trim(rest))
    "Ability:" <> rest -> FeatureHeader(string.trim(rest))
    "Rule:" <> rest -> RuleHeader(string.trim(rest))
    "Background:" <> rest -> BackgroundHeader(string.trim(rest))
    "Scenario Outline:" <> rest ->
      ScenarioHeader(KeywordScenarioOutline, string.trim(rest))
    "Scenario Template:" <> rest ->
      ScenarioHeader(KeywordScenarioTemplate, string.trim(rest))
    "Scenario:" <> rest -> ScenarioHeader(KeywordScenario, string.trim(rest))
    "Example:" <> rest -> ScenarioHeader(KeywordExample, string.trim(rest))
    "Examples:" <> rest -> ExamplesHeader(string.trim(rest))
    "Scenarios:" <> rest -> ExamplesHeader(string.trim(rest))
    "Given " <> rest -> StepToken(Given, string.trim(rest))
    "When " <> rest -> StepToken(When, string.trim(rest))
    "Then " <> rest -> StepToken(Then, string.trim(rest))
    "And " <> rest -> StepToken(And, string.trim(rest))
    "But " <> rest -> StepToken(But, string.trim(rest))
    "* " <> rest -> StepToken(Asterisk, string.trim(rest))
    _ -> Other
  }
}

fn skip_ignored(stream: Stream) -> Stream {
  case stream {
    Next(Token(kind: Empty, ..), rest) -> skip_ignored(rest)
    Next(Token(kind: Comment, ..), rest) -> skip_ignored(rest)
    _ -> stream
  }
}

// ============================================================================
// Table Cells
// ============================================================================

type CellScan {
  CellScan(
    inside_table: Bool,
    cell_newest_first: List(String),
    cells_newest_first: List(String),
  )
}

/// Split a table row into cells. The text before the first `|` and after the
/// last `|` is not part of the table. `\|`, `\\` and `\n` are escapes.
fn table_cells(row: String) -> List(String) {
  scan_cells(string.to_graphemes(row), CellScan(False, [], []))
}

fn scan_cells(characters: List(String), scan: CellScan) -> List(String) {
  case characters {
    [] -> list.reverse(scan.cells_newest_first)
    ["|", ..rest] -> scan_cells(rest, close_cell(scan))
    ["\\", "n", ..rest] -> scan_cells(rest, add_to_cell(scan, "\n"))
    ["\\", "|", ..rest] -> scan_cells(rest, add_to_cell(scan, "|"))
    ["\\", "\\", ..rest] -> scan_cells(rest, add_to_cell(scan, "\\"))
    [character, ..rest] -> scan_cells(rest, add_to_cell(scan, character))
  }
}

fn add_to_cell(scan: CellScan, text: String) -> CellScan {
  CellScan(..scan, cell_newest_first: [text, ..scan.cell_newest_first])
}

fn close_cell(scan: CellScan) -> CellScan {
  case scan.inside_table {
    False -> CellScan(True, [], [])
    True ->
      CellScan(True, [], [
        finish_cell(scan.cell_newest_first),
        ..scan.cells_newest_first
      ])
  }
}

fn finish_cell(cell_newest_first: List(String)) -> String {
  cell_newest_first
  |> list.drop_while(is_cell_space)
  |> list.reverse
  |> list.drop_while(is_cell_space)
  |> string.concat
}

fn is_cell_space(character: String) -> Bool {
  case character {
    " " | "\t" | "\u{000B}" | "\u{000C}" | "\r" | "\u{0085}" | "\u{00A0}" ->
      True
    _ -> False
  }
}

// ============================================================================
// Tags
// ============================================================================

fn parse_tag_line(token: Token) -> Result(List(String), ParseError) {
  token.text
  |> string.trim_start
  |> string.replace("\t#", " #")
  |> remove_tag_comment
  |> string.split("@")
  |> list.map(string.trim_end)
  |> list.filter(is_not_empty)
  |> check_tags(token.line, [])
}

fn remove_tag_comment(text: String) -> String {
  case string.split_once(text, " #") {
    Ok(#(tags, _comment)) -> tags
    Error(Nil) -> text
  }
}

fn is_not_empty(text: String) -> Bool {
  text != ""
}

fn check_tags(
  tags: List(String),
  line: Int,
  checked_newest_first: List(String),
) -> Result(List(String), ParseError) {
  case tags {
    [] -> Ok(list.reverse(checked_newest_first))
    [tag, ..rest] ->
      check_tag(tag, string.contains(tag, " ") || string.contains(tag, "\t"))
      |> add_checked_tag(rest, line, checked_newest_first)
  }
}

fn check_tag(tag: String, has_whitespace: Bool) -> Result(String, String) {
  case has_whitespace {
    True -> Error(tag)
    False -> Ok(tag)
  }
}

fn add_checked_tag(
  checked: Result(String, String),
  rest: List(String),
  line: Int,
  checked_newest_first: List(String),
) -> Result(List(String), ParseError) {
  case checked {
    Ok(tag) -> check_tags(rest, line, [tag, ..checked_newest_first])
    Error(tag) -> Error(ParseError(line, TagContainsWhitespace(tag)))
  }
}

/// Read tag lines, with empty lines and comments between them.
fn take_tags(
  stream: Stream,
  collected: List(String),
) -> Result(#(List(String), Stream), ParseError) {
  case skip_ignored(stream) {
    Next(Token(kind: Tags, ..) as token, rest) ->
      parse_tag_line(token) |> add_tags(rest, collected)
    other -> Ok(#(collected, other))
  }
}

fn add_tags(
  tags: Result(List(String), ParseError),
  rest: Stream,
  collected: List(String),
) -> Result(#(List(String), Stream), ParseError) {
  case tags {
    Ok(tags) -> take_tags(rest, list.append(collected, tags))
    Error(error) -> Error(error)
  }
}

// ============================================================================
// Language
// ============================================================================

/// Read the empty lines and comments before the first tag or Feature line.
/// A `# language:` comment there must name `en`.
fn check_preamble(stream: Stream) -> Result(Stream, ParseError) {
  case stream {
    Next(Token(kind: Empty, ..), rest) -> check_preamble(rest)
    Next(Token(kind: Comment, ..) as token, rest) ->
      check_language(token, language_name(token.text), rest)
    _ -> Ok(stream)
  }
}

fn check_language(
  token: Token,
  language: Result(String, Nil),
  rest: Stream,
) -> Result(Stream, ParseError) {
  case language {
    Ok("en") -> check_preamble(rest)
    Ok(other) -> Error(ParseError(token.line, UnsupportedLanguage(other)))
    Error(Nil) -> check_preamble(rest)
  }
}

/// The language of a `# language: xx` comment.
fn language_name(comment: String) -> Result(String, Nil) {
  comment
  |> string.trim
  |> drop_prefix("#")
  |> drop_prefix_after_space("language")
  |> drop_prefix_after_space(":")
  |> language_code
}

fn drop_prefix(text: String, prefix: String) -> Result(String, Nil) {
  case string.starts_with(text, prefix) {
    True -> Ok(string.drop_start(text, string.length(prefix)))
    False -> Error(Nil)
  }
}

fn drop_prefix_after_space(
  text: Result(String, Nil),
  prefix: String,
) -> Result(String, Nil) {
  case text {
    Ok(text) -> drop_prefix(string.trim_start(text), prefix)
    Error(Nil) -> Error(Nil)
  }
}

fn language_code(text: Result(String, Nil)) -> Result(String, Nil) {
  case text {
    Ok(text) -> valid_language_code(string.trim(text))
    Error(Nil) -> Error(Nil)
  }
}

fn valid_language_code(code: String) -> Result(String, Nil) {
  case
    code != "" && list.all(string.to_graphemes(code), is_language_character)
  {
    True -> Ok(code)
    False -> Error(Nil)
  }
}

fn is_language_character(character: String) -> Bool {
  string.contains(
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_",
    character,
  )
}

// ============================================================================
// Descriptions
// ============================================================================

type DescriptionOwner {
  FeatureOwner
  RuleOwner
  BackgroundOwner
  ScenarioOwner
  ExamplesOwner
}

/// Read the free text below a header line. Comments are not part of it.
/// Empty lines between text lines are part of it.
fn take_description(
  stream: Stream,
  owner: DescriptionOwner,
) -> #(Option(String), Stream) {
  collect_description(skip_ignored(stream), owner, [])
}

fn collect_description(
  stream: Stream,
  owner: DescriptionOwner,
  lines_newest_first: List(String),
) -> #(Option(String), Stream) {
  case stream {
    Next(token, rest) ->
      description_token(token, rest, owner, lines_newest_first)
    End(_) -> #(finish_description(lines_newest_first), stream)
  }
}

fn description_token(
  token: Token,
  rest: Stream,
  owner: DescriptionOwner,
  lines_newest_first: List(String),
) -> #(Option(String), Stream) {
  case ends_description(owner, token.kind), token.kind {
    True, _ -> #(finish_description(lines_newest_first), Next(token, rest))
    False, Comment -> collect_description(rest, owner, lines_newest_first)
    False, _ ->
      collect_description(rest, owner, [token.text, ..lines_newest_first])
  }
}

fn ends_description(owner: DescriptionOwner, kind: Kind) -> Bool {
  case owner, kind {
    _, Tags -> True
    _, ScenarioHeader(..) -> True
    _, RuleHeader(_) -> True
    FeatureOwner, BackgroundHeader(_) -> True
    RuleOwner, BackgroundHeader(_) -> True
    BackgroundOwner, StepToken(..) -> True
    ScenarioOwner, StepToken(..) -> True
    ScenarioOwner, ExamplesHeader(_) -> True
    ExamplesOwner, ExamplesHeader(_) -> True
    ExamplesOwner, TableToken(_) -> True
    _, _ -> False
  }
}

fn finish_description(lines_newest_first: List(String)) -> Option(String) {
  case list.drop_while(lines_newest_first, is_blank) {
    [] -> None
    lines -> Some(string.join(list.reverse(lines), "\n"))
  }
}

fn is_blank(line: String) -> Bool {
  string.trim(line) == ""
}

// ============================================================================
// Steps and Step Arguments
// ============================================================================

/// Read the steps of a Background or a scenario. `has_previous_step` is
/// `True` when Background steps run before these steps.
fn parse_steps(
  stream: Stream,
  has_previous_step: Bool,
  steps_newest_first: List(Step),
) -> Result(#(List(Step), Stream), ParseError) {
  case skip_ignored(stream) {
    Next(Token(kind: StepToken(keyword, text), line: line, ..), rest) ->
      check_first_step(
        Step(keyword: keyword, text: text, doc_string: None, data_table: None),
        line,
        has_previous_step || steps_newest_first != [],
      )
      |> add_step(rest, has_previous_step, steps_newest_first)
    other -> Ok(#(list.reverse(steps_newest_first), other))
  }
}

fn check_first_step(
  step: Step,
  line: Int,
  has_previous_step: Bool,
) -> Result(Step, ParseError) {
  case has_previous_step, types.resolve_phase(step.keyword, None) {
    False, Error(Nil) ->
      Error(ParseError(line, MissingPreviousStep(step.keyword, step.text)))
    _, _ -> Ok(step)
  }
}

fn add_step(
  checked: Result(Step, ParseError),
  rest: Stream,
  has_previous_step: Bool,
  steps_newest_first: List(Step),
) -> Result(#(List(Step), Stream), ParseError) {
  case checked {
    Ok(step) ->
      parse_step_argument(step, rest)
      |> continue_steps(has_previous_step, steps_newest_first)
    Error(error) -> Error(error)
  }
}

fn continue_steps(
  parsed: Result(#(Step, Stream), ParseError),
  has_previous_step: Bool,
  steps_newest_first: List(Step),
) -> Result(#(List(Step), Stream), ParseError) {
  case parsed {
    Ok(#(step, rest)) ->
      parse_steps(rest, has_previous_step, [step, ..steps_newest_first])
    Error(error) -> Error(error)
  }
}

/// Read the arguments of a step: a DataTable, a DocString, or both in either
/// order. A step cannot have a second DocString. A table row after the
/// DataTable and the DocString is not a step argument, so the grammar
/// reports it as an unexpected line.
fn parse_step_argument(
  step: Step,
  stream: Stream,
) -> Result(#(Step, Stream), ParseError) {
  case skip_ignored(stream) {
    Next(Token(kind: TableToken(cells), ..), rest) ->
      take_table_rows(rest, list.length(cells), [cells])
      |> after_data_table(step)
    Next(Token(kind: DocStringToken(separator, media_type), ..) as token, rest) ->
      take_doc_string(rest, doc_string_draft(token, separator, media_type))
      |> after_doc_string(step)
    other -> Ok(#(step, other))
  }
}

fn after_data_table(
  table: Result(#(List(List(String)), Stream), ParseError),
  step: Step,
) -> Result(#(Step, Stream), ParseError) {
  case table {
    Ok(#(rows, rest)) ->
      doc_string_after_data_table(
        Step(..step, data_table: Some(DataTable(rows: rows))),
        skip_ignored(rest),
      )
    Error(error) -> Error(error)
  }
}

fn doc_string_after_data_table(
  step: Step,
  stream: Stream,
) -> Result(#(Step, Stream), ParseError) {
  case stream {
    Next(Token(kind: DocStringToken(separator, media_type), ..) as token, rest) ->
      take_doc_string(rest, doc_string_draft(token, separator, media_type))
      |> after_last_doc_string(step)
    _ -> Ok(#(step, stream))
  }
}

fn after_doc_string(
  doc_string: Result(#(DocString, Stream), ParseError),
  step: Step,
) -> Result(#(Step, Stream), ParseError) {
  case doc_string {
    Ok(#(doc_string, rest)) ->
      data_table_after_doc_string(
        Step(..step, doc_string: Some(doc_string)),
        skip_ignored(rest),
      )
    Error(error) -> Error(error)
  }
}

fn data_table_after_doc_string(
  step: Step,
  stream: Stream,
) -> Result(#(Step, Stream), ParseError) {
  case stream {
    Next(Token(kind: DocStringToken(..), line: line, ..), _) ->
      Error(ParseError(line, RepeatedDocString))
    Next(Token(kind: TableToken(cells), ..), rest) ->
      take_table_rows(rest, list.length(cells), [cells])
      |> after_last_data_table(step)
    _ -> Ok(#(step, stream))
  }
}

fn after_last_doc_string(
  doc_string: Result(#(DocString, Stream), ParseError),
  step: Step,
) -> Result(#(Step, Stream), ParseError) {
  case doc_string {
    Ok(#(doc_string, rest)) ->
      reject_repeated_doc_string(
        Step(..step, doc_string: Some(doc_string)),
        skip_ignored(rest),
      )
    Error(error) -> Error(error)
  }
}

fn after_last_data_table(
  table: Result(#(List(List(String)), Stream), ParseError),
  step: Step,
) -> Result(#(Step, Stream), ParseError) {
  case table {
    Ok(#(rows, rest)) ->
      reject_repeated_doc_string(
        Step(..step, data_table: Some(DataTable(rows: rows))),
        skip_ignored(rest),
      )
    Error(error) -> Error(error)
  }
}

fn reject_repeated_doc_string(
  step: Step,
  stream: Stream,
) -> Result(#(Step, Stream), ParseError) {
  case stream {
    Next(Token(kind: DocStringToken(..), line: line, ..), _) ->
      Error(ParseError(line, RepeatedDocString))
    _ -> Ok(#(step, stream))
  }
}

// ============================================================================
// Tables
// ============================================================================

/// Read table rows, with empty lines and comments between them. Every row
/// must have `width` cells.
fn take_table_rows(
  stream: Stream,
  width: Int,
  rows_newest_first: List(List(String)),
) -> Result(#(List(List(String)), Stream), ParseError) {
  case skip_ignored(stream) {
    Next(Token(kind: TableToken(cells), line: line, ..), rest) ->
      add_table_row(cells, line, rest, width, rows_newest_first)
    other -> Ok(#(list.reverse(rows_newest_first), other))
  }
}

fn add_table_row(
  cells: List(String),
  line: Int,
  rest: Stream,
  width: Int,
  rows_newest_first: List(List(String)),
) -> Result(#(List(List(String)), Stream), ParseError) {
  let found = list.length(cells)
  case found == width {
    True -> take_table_rows(rest, width, [cells, ..rows_newest_first])
    False -> Error(ParseError(line, InconsistentCellCount(width, found)))
  }
}

// ============================================================================
// DocStrings
// ============================================================================

type DocStringDraft {
  DocStringDraft(
    separator: String,
    media_type: String,
    indentation: Int,
    opened_on_line: Int,
    lines_newest_first: List(String),
  )
}

fn doc_string_draft(
  token: Token,
  separator: String,
  media_type: String,
) -> DocStringDraft {
  DocStringDraft(
    separator: separator,
    media_type: media_type,
    indentation: indentation_of(token.text),
    opened_on_line: token.line,
    lines_newest_first: [],
  )
}

fn take_doc_string(
  stream: Stream,
  draft: DocStringDraft,
) -> Result(#(DocString, Stream), ParseError) {
  case stream {
    Next(token, rest) ->
      doc_string_line(
        token,
        rest,
        draft,
        string.starts_with(string.trim_start(token.text), draft.separator),
      )
    End(line) ->
      Error(ParseError(line, UnclosedDocString(draft.opened_on_line)))
  }
}

fn doc_string_line(
  token: Token,
  rest: Stream,
  draft: DocStringDraft,
  closes: Bool,
) -> Result(#(DocString, Stream), ParseError) {
  case closes {
    True -> Ok(#(finish_doc_string(draft), rest))
    False ->
      take_doc_string(
        rest,
        DocStringDraft(..draft, lines_newest_first: [
          doc_string_content(token.text, draft),
          ..draft.lines_newest_first
        ]),
      )
  }
}

fn finish_doc_string(draft: DocStringDraft) -> DocString {
  DocString(
    content: string.join(list.reverse(draft.lines_newest_first), "\n"),
    content_type: media_type_option(draft.media_type),
  )
}

fn media_type_option(media_type: String) -> Option(String) {
  case media_type {
    "" -> None
    _ -> Some(media_type)
  }
}

/// Remove the indentation of the opening separator, then unescape every
/// escaped separator (`\"\"\"` or `` \`\`\` ``), as the official Java
/// parser does.
fn doc_string_content(line: String, draft: DocStringDraft) -> String {
  line
  |> remove_indentation(draft.indentation)
  |> unescape_separator(escaped_separator(draft.separator), draft.separator)
}

fn remove_indentation(line: String, indentation: Int) -> String {
  case indentation_of(line) >= indentation {
    True -> string.drop_start(line, indentation)
    False -> string.trim_start(line)
  }
}

fn indentation_of(line: String) -> Int {
  string.length(line) - string.length(string.trim_start(line))
}

fn escaped_separator(separator: String) -> String {
  separator
  |> string.to_graphemes
  |> list.map(escape_character)
  |> string.concat
}

fn escape_character(character: String) -> String {
  "\\" <> character
}

fn unescape_separator(
  line: String,
  escaped: String,
  separator: String,
) -> String {
  string.replace(in: line, each: escaped, with: separator)
}

// ============================================================================
// Grammar
// ============================================================================

/// The position after a section: the tags that wait for their header, the
/// stream at the first line after those tags, and the kinds of line that the
/// grammar permits there (for the error message).
type Pending {
  Pending(tags: List(String), stream: Stream, expected: List(TokenKind))
}

const after_background = [StepLine, TagLine, ScenarioLine, RuleLine, EndOfFile]

const after_steps = [
  StepLine,
  TagLine,
  ExamplesLine,
  ScenarioLine,
  RuleLine,
  EndOfFile,
]

const after_examples = [
  TableRow,
  TagLine,
  ExamplesLine,
  ScenarioLine,
  RuleLine,
  EndOfFile,
]

const after_tags = [TagLine, ScenarioLine, RuleLine]

const after_tags_in_scenario = [TagLine, ExamplesLine, ScenarioLine, RuleLine]

const after_header = [BackgroundLine, TagLine, ScenarioLine, RuleLine, EndOfFile]

fn pending_after(
  stream: Stream,
  expected: List(TokenKind),
  expected_after_tags: List(TokenKind),
) -> Result(Pending, ParseError) {
  case take_tags(stream, []) {
    Ok(#([], rest)) -> Ok(Pending(tags: [], stream: rest, expected: expected))
    Ok(#(tags, rest)) ->
      Ok(Pending(tags: tags, stream: rest, expected: expected_after_tags))
    Error(error) -> Error(error)
  }
}

fn unexpected(stream: Stream, expected: List(TokenKind)) -> ParseError {
  case stream {
    Next(token, _) ->
      ParseError(
        token.line,
        UnexpectedLine(text: string.trim(token.text), expected: expected),
      )
    End(line) -> ParseError(line, UnexpectedEndOfFile(expected: expected))
  }
}

// ---------------------------------------------------------------------------
// Document and Feature
// ---------------------------------------------------------------------------

fn parse_document(stream: Stream) -> Result(Feature, ParseError) {
  case check_preamble(stream) {
    Ok(rest) -> take_tags(rest, []) |> parse_feature_header
    Error(error) -> Error(error)
  }
}

fn parse_feature_header(
  tagged: Result(#(List(String), Stream), ParseError),
) -> Result(Feature, ParseError) {
  case tagged {
    Ok(#(tags, Next(Token(kind: FeatureHeader(name), ..), rest))) ->
      parse_feature_body(name, tags, take_description(rest, FeatureOwner))
    Ok(#([], End(line))) -> Error(ParseError(line, MissingFeature))
    Ok(#(_, stream)) -> Error(unexpected(stream, [TagLine, FeatureLine]))
    Error(error) -> Error(error)
  }
}

type FeatureDraft {
  FeatureDraft(
    name: String,
    tags: List(String),
    description: Option(String),
    background: Option(Background),
  )
}

fn parse_feature_body(
  name: String,
  tags: List(String),
  described: #(Option(String), Stream),
) -> Result(Feature, ParseError) {
  let #(description, rest) = described
  let draft =
    FeatureDraft(
      name: name,
      tags: tags,
      description: description,
      background: None,
    )
  parse_optional_background(rest, False)
  |> parse_feature_scenarios(draft)
}

fn parse_feature_scenarios(
  background: Result(#(Option(Background), Pending), ParseError),
  draft: FeatureDraft,
) -> Result(Feature, ParseError) {
  case background {
    Ok(#(background, pending)) ->
      parse_scenario_list(pending, has_steps(background), [])
      |> parse_feature_rules(FeatureDraft(..draft, background: background))
    Error(error) -> Error(error)
  }
}

fn parse_feature_rules(
  scenarios: Result(#(List(Scenario), Pending), ParseError),
  draft: FeatureDraft,
) -> Result(Feature, ParseError) {
  case scenarios {
    Ok(#(scenarios, pending)) ->
      parse_rule_list(pending, has_steps(draft.background), [])
      |> finish_feature(draft, scenarios)
    Error(error) -> Error(error)
  }
}

fn finish_feature(
  rules: Result(#(List(Rule), Pending), ParseError),
  draft: FeatureDraft,
  scenarios: List(Scenario),
) -> Result(Feature, ParseError) {
  case rules {
    Ok(#(rules, Pending(tags: [], stream: End(_), ..))) ->
      Ok(Feature(
        name: draft.name,
        source: None,
        description: draft.description,
        tags: draft.tags,
        background: draft.background,
        scenarios: scenarios,
        rules: rules,
      ))
    Ok(#(_, pending)) -> Error(unexpected(pending.stream, pending.expected))
    Error(error) -> Error(error)
  }
}

fn has_steps(background: Option(Background)) -> Bool {
  case background {
    Some(Background(steps: [_, ..], ..)) -> True
    _ -> False
  }
}

// ---------------------------------------------------------------------------
// Background
// ---------------------------------------------------------------------------

/// Read a Background if the next line starts one. `has_previous_step` is
/// `True` in a Rule when the Feature Background has steps.
fn parse_optional_background(
  stream: Stream,
  has_previous_step: Bool,
) -> Result(#(Option(Background), Pending), ParseError) {
  case stream {
    Next(Token(kind: BackgroundHeader(name), ..), rest) ->
      parse_background(name, take_description(rest, BackgroundOwner))
      |> parse_background_steps(has_previous_step)
    _ -> pending_after(stream, after_header, after_tags) |> without_background
  }
}

fn without_background(
  pending: Result(Pending, ParseError),
) -> Result(#(Option(Background), Pending), ParseError) {
  case pending {
    Ok(pending) -> Ok(#(None, pending))
    Error(error) -> Error(error)
  }
}

fn parse_background(
  name: String,
  described: #(Option(String), Stream),
) -> #(Background, Stream) {
  let #(description, rest) = described
  #(Background(name: name, description: description, steps: []), rest)
}

fn parse_background_steps(
  draft: #(Background, Stream),
  has_previous_step: Bool,
) -> Result(#(Option(Background), Pending), ParseError) {
  let #(background, rest) = draft
  parse_steps(rest, has_previous_step, [])
  |> finish_background(background)
}

fn finish_background(
  steps: Result(#(List(Step), Stream), ParseError),
  background: Background,
) -> Result(#(Option(Background), Pending), ParseError) {
  case steps {
    Ok(#(steps, rest)) ->
      pending_after(rest, after_background, after_tags)
      |> with_background(Background(..background, steps: steps))
    Error(error) -> Error(error)
  }
}

fn with_background(
  pending: Result(Pending, ParseError),
  background: Background,
) -> Result(#(Option(Background), Pending), ParseError) {
  case pending {
    Ok(pending) -> Ok(#(Some(background), pending))
    Error(error) -> Error(error)
  }
}

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

/// Read scenarios while the next header is a scenario line.
/// `has_previous_step` is `True` when Background steps run before them.
fn parse_scenario_list(
  pending: Pending,
  has_previous_step: Bool,
  scenarios_newest_first: List(Scenario),
) -> Result(#(List(Scenario), Pending), ParseError) {
  case pending.stream {
    Next(Token(kind: ScenarioHeader(keyword, name), ..), rest) ->
      parse_scenario(
        ScenarioDraft(
          keyword: keyword,
          name: name,
          tags: pending.tags,
          description: None,
          steps: [],
        ),
        rest,
        has_previous_step,
      )
      |> continue_scenarios(has_previous_step, scenarios_newest_first)
    _ -> Ok(#(list.reverse(scenarios_newest_first), pending))
  }
}

fn continue_scenarios(
  parsed: Result(#(Scenario, Pending), ParseError),
  has_previous_step: Bool,
  scenarios_newest_first: List(Scenario),
) -> Result(#(List(Scenario), Pending), ParseError) {
  case parsed {
    Ok(#(scenario, pending)) ->
      parse_scenario_list(pending, has_previous_step, [
        scenario,
        ..scenarios_newest_first
      ])
    Error(error) -> Error(error)
  }
}

type ScenarioDraft {
  ScenarioDraft(
    keyword: ScenarioKeyword,
    name: String,
    tags: List(String),
    description: Option(String),
    steps: List(Step),
  )
}

fn parse_scenario(
  draft: ScenarioDraft,
  stream: Stream,
  has_previous_step: Bool,
) -> Result(#(Scenario, Pending), ParseError) {
  let #(description, rest) = take_description(stream, ScenarioOwner)
  parse_steps(rest, has_previous_step, [])
  |> parse_scenario_examples(ScenarioDraft(..draft, description: description))
}

fn parse_scenario_examples(
  steps: Result(#(List(Step), Stream), ParseError),
  draft: ScenarioDraft,
) -> Result(#(Scenario, Pending), ParseError) {
  case steps {
    Ok(#(steps, rest)) ->
      pending_after(rest, after_steps, after_tags_in_scenario)
      |> parse_examples_list(ScenarioDraft(..draft, steps: steps), [])
    Error(error) -> Error(error)
  }
}

/// Read Examples sections while the next header is an Examples line.
fn parse_examples_list(
  pending: Result(Pending, ParseError),
  draft: ScenarioDraft,
  examples_newest_first: List(Examples),
) -> Result(#(Scenario, Pending), ParseError) {
  case pending {
    Ok(Pending(
      tags: tags,
      stream: Next(Token(kind: ExamplesHeader(name), ..), rest),
      ..,
    )) -> {
      let examples =
        parse_examples(name, tags, take_description(rest, ExamplesOwner))
      parse_examples_list(examples.1, draft, [
        examples.0,
        ..examples_newest_first
      ])
    }
    Ok(pending) -> Ok(#(finish_scenario(draft, examples_newest_first), pending))
    Error(error) -> Error(error)
  }
}

fn finish_scenario(
  draft: ScenarioDraft,
  examples_newest_first: List(Examples),
) -> Scenario {
  Scenario(
    keyword: draft.keyword,
    name: draft.name,
    description: draft.description,
    tags: draft.tags,
    steps: draft.steps,
    examples: list.reverse(examples_newest_first),
  )
}

fn parse_examples(
  name: String,
  tags: List(String),
  described: #(Option(String), Stream),
) -> #(Examples, Result(Pending, ParseError)) {
  let #(description, rest) = described
  let examples =
    Examples(name: name, description: description, tags: tags, table: None)
  case rest {
    Next(Token(kind: TableToken(header), ..), after_header_row) ->
      examples_table(
        examples,
        header,
        take_table_rows(after_header_row, list.length(header), []),
      )
    _ -> #(
      examples,
      pending_after(rest, after_examples, after_tags_in_scenario),
    )
  }
}

fn examples_table(
  examples: Examples,
  header: List(String),
  rows: Result(#(List(List(String)), Stream), ParseError),
) -> #(Examples, Result(Pending, ParseError)) {
  case rows {
    Ok(#(rows, rest)) -> #(
      Examples(
        ..examples,
        table: Some(ExamplesTable(headers: header, rows: rows)),
      ),
      pending_after(rest, after_examples, after_tags_in_scenario),
    )
    Error(error) -> #(examples, Error(error))
  }
}

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

/// Read Rules while the next header is a Rule line.
/// `feature_has_steps` is `True` when the Feature Background has steps.
fn parse_rule_list(
  pending: Pending,
  feature_has_steps: Bool,
  rules_newest_first: List(Rule),
) -> Result(#(List(Rule), Pending), ParseError) {
  case pending.stream {
    Next(Token(kind: RuleHeader(name), ..), rest) ->
      parse_rule(name, pending.tags, rest, feature_has_steps)
      |> continue_rules(feature_has_steps, rules_newest_first)
    _ -> Ok(#(list.reverse(rules_newest_first), pending))
  }
}

fn continue_rules(
  parsed: Result(#(Rule, Pending), ParseError),
  feature_has_steps: Bool,
  rules_newest_first: List(Rule),
) -> Result(#(List(Rule), Pending), ParseError) {
  case parsed {
    Ok(#(rule, pending)) ->
      parse_rule_list(pending, feature_has_steps, [rule, ..rules_newest_first])
    Error(error) -> Error(error)
  }
}

fn parse_rule(
  name: String,
  tags: List(String),
  stream: Stream,
  feature_has_steps: Bool,
) -> Result(#(Rule, Pending), ParseError) {
  let #(description, rest) = take_description(stream, RuleOwner)
  let rule =
    Rule(
      name: name,
      description: description,
      tags: tags,
      background: None,
      scenarios: [],
    )
  parse_optional_background(rest, feature_has_steps)
  |> parse_rule_scenarios(rule, feature_has_steps)
}

fn parse_rule_scenarios(
  background: Result(#(Option(Background), Pending), ParseError),
  rule: Rule,
  feature_has_steps: Bool,
) -> Result(#(Rule, Pending), ParseError) {
  case background {
    Ok(#(background, pending)) ->
      parse_scenario_list(
        pending,
        feature_has_steps || has_steps(background),
        [],
      )
      |> finish_rule(Rule(..rule, background: background))
    Error(error) -> Error(error)
  }
}

fn finish_rule(
  scenarios: Result(#(List(Scenario), Pending), ParseError),
  rule: Rule,
) -> Result(#(Rule, Pending), ParseError) {
  case scenarios {
    Ok(#(scenarios, pending)) ->
      Ok(#(Rule(..rule, scenarios: scenarios), pending))
    Error(error) -> Error(error)
  }
}
