//// Line diffs of an expected text and an actual text.
////
//// The BDD and Gherkin reporters show a failure whose expected or actual
//// text has more than one line as a line diff, in place of the `Expected:`
//// and `Actual:` lines. A custom reporter can do the same with this module.
////
//// A diff line starts with `-` for a line of the expected text only, `+`
//// for a line of the actual text only, and two spaces for a line in both.
//// Lines more than 3 lines from a change are hidden behind one
//// `... N unchanged lines` line.
////
//// ### A diff in a failure report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/diff/module.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/reporters/diff
////
//// pub fn receipt_diff() -> String {
////   diff.format(
////     expected: "coffee 3.50\ncroissant 2.75\nTOTAL 6.25",
////     actual: "coffee 3.50\ncroissant 2.95\nTOTAL 6.45",
////     indent: "",
////     color: False,
////   )
////   // -> "Diff (- expected, + actual):\n    coffee 3.50\n  - croissant 2.75\n  - TOTAL 6.25\n  + croissant 2.95\n  + TOTAL 6.45\n"
//// }
//// ```
////
//// ## Limits
////
//// - The diff is a longest common subsequence of the lines. The common
////   lines at the start and at the end are matched first. When the lines
////   between them make more than 1,000,000 pairs (for example 1,001
////   changed lines against 1,000), they are not matched one by one: they
////   show as removed lines, then added lines, and `format` says so.
//// - `format` shows at most 100 diff lines, then one
////   `... N more lines of the diff` line.

import dream_test/reporters/ansi
import gleam/int
import gleam/list
import gleam/result
import gleam/string

/// One line of a diff.
///
/// ## Variants
///
/// - `Same(text)`: a line of both texts
/// - `Removed(text)`: a line of the expected text only
/// - `Added(text)`: a line of the actual text only
/// - `NoNewlineAtEnd`: the line before it is the last line of its text, and
///   that text has no newline at its end while the other text has one. It
///   shows a difference that is only a final newline.
///
/// ## Example
///
/// ### Read the lines of a diff <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/diff/diff_line.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/diff.{type DiffLine}
///
/// pub fn final_newline_lines() -> List(DiffLine) {
///   diff.lines(expected: "a\nb\n", actual: "a\nb")
///   // -> [Same("a"), Removed("b"), Added("b"), NoNewlineAtEnd]
/// }
/// ```
pub type DiffLine {
  Same(text: String)
  Removed(text: String)
  Added(text: String)
  NoNewlineAtEnd
}

/// The lines more than this many lines from a change are hidden.
const context_lines = 3

/// Above this many pairs of changed lines, the lines are not matched.
const max_compared_pairs = 1_000_000

/// `format` shows at most this many diff lines.
const max_shown_lines = 100

/// A line of a text, and whether a newline ends it. `newline` is `False`
/// only for the last line of a text with no final newline, and only when
/// the other text ends with a newline.
type Token {
  Token(text: String, newline: Bool)
}

/// The diff lines, and whether the changed lines were matched one by one.
type Comparison {
  Comparison(lines: List(DiffLine), matched: Bool)
}

/// The line diff of `expected` against `actual`.
///
/// A newline separates two lines, and a newline at the end of a text ends
/// its last line, so `"a\nb"` and `"a\nb\n"` both have the lines `a` and
/// `b`. When only one of the two texts ends with a newline, its last line
/// differs from the last line of the other text, and `NoNewlineAtEnd`
/// follows the line that has no newline. Trailing whitespace is part of a
/// line, so `"a "` and `"a"` differ.
///
/// The removed lines of a change come before its added lines.
///
/// ## Parameters
///
/// - `expected`: the text that the test expected
/// - `actual`: the text that the test got
///
/// ## Returns
///
/// Every line of both texts, in order, with no line hidden.
///
/// ## Example
///
/// ### Diff two texts <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/diff/lines.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/diff.{type DiffLine}
///
/// pub fn one_changed_line() -> List(DiffLine) {
///   diff.lines(expected: "a\nb\nc", actual: "a\nB\nc")
///   // -> [Same("a"), Removed("b"), Added("B"), Same("c")]
/// }
/// ```
pub fn lines(
  expected expected: String,
  actual actual: String,
) -> List(DiffLine) {
  compare(expected, actual).lines
}

/// Whether a reporter shows `expected` and `actual` as a diff: when either
/// text has more than one line, or when the two texts differ only in
/// whitespace at their ends, which the `Expected:` and `Actual:` lines do
/// not show.
///
/// ## Parameters
///
/// - `expected`: the text that the test expected
/// - `actual`: the text that the test got
///
/// ## Returns
///
/// `True` when a diff shows the difference better than two lines do.
///
/// ## Example
///
/// ### Choose between a diff and two lines <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/diff/should_diff.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/diff
///
/// pub fn two_lines_show_as_a_diff() -> Bool {
///   diff.should_diff(expected: "a\nb", actual: "a\nc")
///   // -> True
/// }
///
/// pub fn one_line_shows_as_two_lines() -> Bool {
///   diff.should_diff(expected: "1", actual: "2")
///   // -> False
/// }
/// ```
pub fn should_diff(expected expected: String, actual actual: String) -> Bool {
  string.contains(expected, "\n")
  || string.contains(actual, "\n")
  || {
    expected != actual && string.trim_end(expected) == string.trim_end(actual)
  }
}

/// The diff of `expected` against `actual` as report text.
///
/// The first line is `Diff (- expected, + actual):` at `indent`. Each diff
/// line follows at `indent` and two more spaces: `- ` and the line for a
/// removed line, `+ ` and the line for an added line, two spaces and the
/// line for a line in both texts. Same lines more than 3 lines from a
/// change are hidden behind one `... N unchanged lines` line. A removed or
/// added line shows its trailing spaces as `·`, tabs as `→` and carriage
/// returns as `␍`. `\ No newline at end of text` follows a last line that
/// has no newline when the other text has one.
///
/// At most 100 diff lines show, then `... N more lines of the diff`. When
/// the changed lines are too many to match one by one, a note under the
/// first line says so. Every line ends with a newline.
///
/// With `color`, the first line and the hidden lines are dim, removed lines
/// are green and added lines are red, as the `Expected` and `Actual` values
/// of the reporters. The `-` and `+` marks make the text clear with no
/// color.
///
/// ## Parameters
///
/// - `expected`: the text that the test expected
/// - `actual`: the text that the test got
/// - `indent`: the text in front of the first line
/// - `color`: whether to add ANSI colors
///
/// ## Returns
///
/// The diff as lines of text.
///
/// ## Example
///
/// ### Format a diff with a missing final newline <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/diff/format.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/diff
///
/// pub fn final_newline_diff() -> String {
///   diff.format(expected: "a\nb\n", actual: "a\nb", indent: "", color: False)
///   // -> "Diff (- expected, + actual):\n    a\n  - b\n  + b\n  \\ No newline at end of text\n"
/// }
/// ```
pub fn format(
  expected expected: String,
  actual actual: String,
  indent indent: String,
  color color: Bool,
) -> String {
  let comparison = compare(expected, actual)
  let line_indent = indent <> "  "
  let entries = collapse(comparison.lines)
  let shown = list.take(entries, max_shown_lines)
  let more_count = list.length(entries) - list.length(shown)
  string.concat([
    indent,
    ansi.apply_if(color, ansi.dim, "Diff (- expected, + actual):"),
    "\n",
    match_note(comparison.matched, line_indent, color),
    string.concat(list.map(shown, render_entry(_, line_indent, color))),
    more_lines_note(more_count, line_indent, color),
  ])
}

// ============================================================================
// Comparing
// ============================================================================

fn compare(expected: String, actual: String) -> Comparison {
  let newline_matters =
    string.ends_with(expected, "\n") != string.ends_with(actual, "\n")
  let expected_tokens = tokens(expected, newline_matters)
  let actual_tokens = tokens(actual, newline_matters)
  let #(prefix, expected_after, actual_after) =
    common_start(expected_tokens, actual_tokens, [])
  let #(suffix_reversed, expected_middle_reversed, actual_middle_reversed) =
    common_start(list.reverse(expected_after), list.reverse(actual_after), [])
  let expected_middle = list.reverse(expected_middle_reversed)
  let actual_middle = list.reverse(actual_middle_reversed)
  let pairs = list.length(expected_middle) * list.length(actual_middle)
  let matched = pairs <= max_compared_pairs
  let middle = case matched {
    True -> match_middle(expected_middle, actual_middle)
    False ->
      list.append(
        list.flat_map(expected_middle, removed_lines),
        list.flat_map(actual_middle, added_lines),
      )
  }
  Comparison(
    lines: list.flatten([
      list.map(prefix, same_line),
      middle,
      list.map(list.reverse(suffix_reversed), same_line),
    ]),
    matched: matched,
  )
}

fn tokens(text: String, newline_matters: Bool) -> List(Token) {
  case text, string.ends_with(text, "\n") {
    "", _ -> []
    _, True ->
      string.drop_end(text, 1)
      |> string.split("\n")
      |> list.map(Token(_, True))
    _, False -> last_without_newline(string.split(text, "\n"), newline_matters)
  }
}

/// The tokens of the lines of a text with no final newline: only the last
/// line has no newline, and only when the newline matters.
fn last_without_newline(
  parts: List(String),
  newline_matters: Bool,
) -> List(Token) {
  let last_index = list.length(parts) - 1
  list.index_map(parts, fn(part, index) {
    Token(part, index != last_index || !newline_matters)
  })
}

/// The tokens that both lists start with, newest first, and the rest of
/// each list.
fn common_start(
  expected: List(Token),
  actual: List(Token),
  common_newest_first: List(Token),
) -> #(List(Token), List(Token), List(Token)) {
  case expected, actual {
    [expected_token, ..expected_rest], [actual_token, ..actual_rest]
      if expected_token == actual_token
    ->
      common_start(expected_rest, actual_rest, [
        expected_token,
        ..common_newest_first
      ])
    _, _ -> #(list.reverse(common_newest_first), expected, actual)
  }
}

fn same_line(token: Token) -> DiffLine {
  Same(token.text)
}

fn removed_lines(token: Token) -> List(DiffLine) {
  [Removed(token.text), ..newline_marker(token)]
}

fn added_lines(token: Token) -> List(DiffLine) {
  [Added(token.text), ..newline_marker(token)]
}

fn newline_marker(token: Token) -> List(DiffLine) {
  case token.newline {
    True -> []
    False -> [NoNewlineAtEnd]
  }
}

// ============================================================================
// Longest common subsequence
// ============================================================================

/// The diff of two lists of tokens, from a table of the lengths of the
/// longest common subsequences of their ends. Row `i` holds, for each `j`,
/// the length for `expected` from `i` and `actual` from `j`.
fn match_middle(expected: List(Token), actual: List(Token)) -> List(DiffLine) {
  let actual_reversed = list.reverse(actual)
  let last_row = list.repeat(0, list.length(actual) + 1)
  let rows =
    list.fold(list.reverse(expected), [last_row], fn(rows_below, token) {
      [row_above(token, actual_reversed, below_row(rows_below)), ..rows_below]
    })
  walk(
    expected,
    actual,
    Walk(
      row_here: first_row(rows),
      row_below: first_row(list.drop(rows, 1)),
      rows_after: list.drop(rows, 2),
      column: 0,
    ),
    [],
  )
}

fn below_row(rows: List(List(Int))) -> List(Int) {
  list.reverse(first_row(rows))
}

fn first_row(rows: List(List(Int))) -> List(Int) {
  list.first(rows)
  |> result.unwrap([])
}

/// The row for `token`, from the row below it, both read from the last
/// column to the first. `below_reversed` starts with the value of the last
/// column, which is 0.
fn row_above(
  token: Token,
  actual_reversed: List(Token),
  below_reversed: List(Int),
) -> List(Int) {
  row_loop(token, actual_reversed, below_reversed, 0, [0])
}

fn row_loop(
  token: Token,
  actual_reversed: List(Token),
  below_reversed: List(Int),
  right: Int,
  row: List(Int),
) -> List(Int) {
  case actual_reversed, below_reversed {
    [actual_token, ..actual_rest], [diagonal, down, ..below_rest] -> {
      let value = cell(token == actual_token, diagonal, down, right)
      row_loop(token, actual_rest, [down, ..below_rest], value, [value, ..row])
    }
    _, _ -> row
  }
}

fn cell(same: Bool, diagonal: Int, down: Int, right: Int) -> Int {
  case same {
    True -> diagonal + 1
    False -> int.max(down, right)
  }
}

/// Where the walk through the table is: the rest of the row of the current
/// expected token and of the row below it, from the current column, and
/// the rows after them.
type Walk {
  Walk(
    row_here: List(Int),
    row_below: List(Int),
    rows_after: List(List(Int)),
    column: Int,
  )
}

fn walk(
  expected: List(Token),
  actual: List(Token),
  position: Walk,
  lines_newest_first: List(DiffLine),
) -> List(DiffLine) {
  case expected, actual {
    [], _ ->
      list.append(
        list.reverse(lines_newest_first),
        list.flat_map(actual, added_lines),
      )
    _, [] ->
      list.append(
        list.reverse(lines_newest_first),
        list.flat_map(expected, removed_lines),
      )
    [expected_token, ..expected_rest], [actual_token, ..actual_rest] ->
      walk_step(
        WalkStep(
          expected_token: expected_token,
          expected_rest: expected_rest,
          actual_token: actual_token,
          actual_rest: actual_rest,
        ),
        expected,
        actual,
        position,
        lines_newest_first,
      )
  }
}

type WalkStep {
  WalkStep(
    expected_token: Token,
    expected_rest: List(Token),
    actual_token: Token,
    actual_rest: List(Token),
  )
}

fn walk_step(
  step: WalkStep,
  expected: List(Token),
  actual: List(Token),
  position: Walk,
  lines_newest_first: List(DiffLine),
) -> List(DiffLine) {
  let down = first_value(position.row_below)
  let right = first_value(list.drop(position.row_here, 1))
  case step.expected_token == step.actual_token, down >= right {
    True, _ ->
      walk(
        step.expected_rest,
        step.actual_rest,
        move_right(move_down(position)),
        [same_line(step.expected_token), ..lines_newest_first],
      )
    False, True ->
      walk(
        step.expected_rest,
        actual,
        move_down(position),
        list.append(
          list.reverse(removed_lines(step.expected_token)),
          lines_newest_first,
        ),
      )
    False, False ->
      walk(
        expected,
        step.actual_rest,
        move_right(position),
        list.append(
          list.reverse(added_lines(step.actual_token)),
          lines_newest_first,
        ),
      )
  }
}

fn first_value(row: List(Int)) -> Int {
  list.first(row)
  |> result.unwrap(0)
}

fn move_down(position: Walk) -> Walk {
  Walk(
    row_here: position.row_below,
    row_below: list.drop(first_row(position.rows_after), position.column),
    rows_after: list.drop(position.rows_after, 1),
    column: position.column,
  )
}

fn move_right(position: Walk) -> Walk {
  Walk(
    row_here: list.drop(position.row_here, 1),
    row_below: list.drop(position.row_below, 1),
    rows_after: position.rows_after,
    column: position.column + 1,
  )
}

// ============================================================================
// Formatting
// ============================================================================

/// A line of the formatted diff: a diff line, or a count of hidden same
/// lines.
type Entry {
  Shown(line: DiffLine)
  Hidden(count: Int)
}

/// Hide the same lines more than `context_lines` lines from a change.
fn collapse(lines: List(DiffLine)) -> List(Entry) {
  let after_change = distances(lines, context_lines + 1, [])
  let before_change =
    list.reverse(distances(list.reverse(lines), context_lines + 1, []))
  list.zip(lines, list.zip(after_change, before_change))
  |> list.fold([], add_entry)
  |> list.reverse
}

/// For each line, how many lines it is from the nearest change before it,
/// at most `context_lines + 1`. A change is 0 lines from itself.
fn distances(
  lines: List(DiffLine),
  previous: Int,
  distances_newest_first: List(Int),
) -> List(Int) {
  case lines {
    [] -> list.reverse(distances_newest_first)
    [Same(_), ..rest] -> {
      let distance = int.min(previous + 1, context_lines + 1)
      distances(rest, distance, [distance, ..distances_newest_first])
    }
    [_, ..rest] -> distances(rest, 0, [0, ..distances_newest_first])
  }
}

fn add_entry(
  entries_newest_first: List(Entry),
  line_and_distances: #(DiffLine, #(Int, Int)),
) -> List(Entry) {
  let #(line, #(after_change, before_change)) = line_and_distances
  let shown = int.min(after_change, before_change) <= context_lines
  case shown, entries_newest_first {
    True, _ -> [Shown(line), ..entries_newest_first]
    False, [Hidden(count), ..rest] -> [Hidden(count + 1), ..rest]
    False, _ -> [Hidden(1), ..entries_newest_first]
  }
}

/// A diff line with its indent. An empty same line is an empty line, so
/// the report has no trailing spaces.
fn render_entry(entry: Entry, line_indent: String, color: Bool) -> String {
  let #(text, style) = entry_text(entry)
  case string.trim_end(text) {
    "" -> "\n"
    trimmed -> line_indent <> styled(color, style, trimmed) <> "\n"
  }
}

/// The style of a line of the formatted diff.
type Style {
  Plain
  Dim
  ExpectedStyle
  ActualStyle
}

fn styled(color: Bool, style: Style, text: String) -> String {
  case style {
    Plain -> text
    Dim -> ansi.apply_if(color, ansi.dim, text)
    ExpectedStyle -> ansi.apply_if(color, ansi.green, text)
    ActualStyle -> ansi.apply_if(color, ansi.red, text)
  }
}

fn entry_text(entry: Entry) -> #(String, Style) {
  case entry {
    Shown(Same(text)) -> #("  " <> text, Plain)
    Shown(Removed(text)) -> #(
      "- " <> show_trailing_whitespace(text),
      ExpectedStyle,
    )
    Shown(Added(text)) -> #("+ " <> show_trailing_whitespace(text), ActualStyle)
    Shown(NoNewlineAtEnd) -> #("\\ No newline at end of text", Dim)
    Hidden(count) -> #("... " <> count_lines(count, "unchanged line"), Dim)
  }
}

fn count_lines(count: Int, noun: String) -> String {
  case count {
    1 -> "1 " <> noun
    _ -> int.to_string(count) <> " " <> noun <> "s"
  }
}

fn match_note(matched: Bool, line_indent: String, color: Bool) -> String {
  case matched {
    True -> ""
    False ->
      line_indent
      <> ansi.apply_if(
        color,
        ansi.dim,
        "(too large to match line by line: the changed lines show as removed, then added)",
      )
      <> "\n"
  }
}

fn more_lines_note(count: Int, line_indent: String, color: Bool) -> String {
  case count {
    0 -> ""
    _ ->
      line_indent
      <> ansi.apply_if(
        color,
        ansi.dim,
        "... " <> int.to_string(count) <> " more lines of the diff",
      )
      <> "\n"
  }
}

/// The text with its trailing spaces, tabs and carriage returns shown as
/// `·`, `→` and `␍`.
fn show_trailing_whitespace(text: String) -> String {
  let #(trailing, rest_reversed) =
    split_trailing_whitespace(list.reverse(string.to_graphemes(text)), [])
  string.concat(list.reverse(rest_reversed)) <> string.concat(trailing)
}

/// The visible marks of the whitespace at the start of `reversed`, in
/// text order, and the rest of `reversed`.
fn split_trailing_whitespace(
  reversed: List(String),
  marks: List(String),
) -> #(List(String), List(String)) {
  case reversed {
    [" ", ..rest] -> split_trailing_whitespace(rest, ["·", ..marks])
    ["\t", ..rest] -> split_trailing_whitespace(rest, ["→", ..marks])
    ["\r", ..rest] -> split_trailing_whitespace(rest, ["␍", ..marks])
    _ -> #(marks, reversed)
  }
}
