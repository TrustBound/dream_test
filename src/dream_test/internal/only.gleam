//// The `--only` option of the command line: `gleam test -- --only "<path>"`.
////
//// A path is the names of a test, from the suite name to the test name,
//// joined with `/`. The path of a group or a suite stops at its name and
//// selects all the tests inside it. In a name, `\/` is a `/` and `\\` is a
//// `\`.
////
//// The runner reads the option, and the text reporters print the command
//// that runs one failed test alone.

import gleam/int
import gleam/list
import gleam/order
import gleam/result
import gleam/string

/// One `--only` path: the text from the command line and the names in it.
pub type OnlyPath {
  OnlyPath(text: String, names: List(String))
}

/// The usage line of the errors.
const usage = "gleam test -- --only \"Suite/group/test\""

/// The most closest paths that the error of an unknown path shows.
const closest_count = 3

/// The `--only` paths in `arguments`, in their order. Other arguments
/// are not for the runner, so this ignores them.
pub fn parse_arguments(
  arguments: List(String),
) -> Result(List(OnlyPath), String) {
  parse_arguments_loop(arguments, [])
}

fn parse_arguments_loop(
  arguments: List(String),
  paths_rev: List(OnlyPath),
) -> Result(List(OnlyPath), String) {
  case arguments {
    [] -> Ok(list.reverse(paths_rev))
    ["--only"] ->
      Error(missing_path_error("The command line ends after --only."))
    ["--only", text, ..rest] ->
      add_parsed_path(text, parse_path(text), rest, paths_rev)
    [_other, ..rest] -> parse_arguments_loop(rest, paths_rev)
  }
}

fn add_parsed_path(
  text: String,
  parsed: Result(List(String), String),
  rest: List(String),
  paths_rev: List(OnlyPath),
) -> Result(List(OnlyPath), String) {
  case parsed {
    Ok(names) ->
      parse_arguments_loop(rest, [
        OnlyPath(text: text, names: names),
        ..paths_rev
      ])
    Error(error) -> Error(error)
  }
}

/// The names in the path `text`, or the error text.
pub fn parse_path(text: String) -> Result(List(String), String) {
  case text {
    "" -> Error(missing_path_error("The path after --only is empty."))
    _ -> parse_names(text, string.to_graphemes(text), "", [])
  }
}

fn parse_names(
  text: String,
  characters: List(String),
  name: String,
  names_rev: List(String),
) -> Result(List(String), String) {
  case characters {
    [] -> Ok(list.reverse([name, ..names_rev]))
    ["\\", "/", ..rest] -> parse_names(text, rest, name <> "/", names_rev)
    ["\\", "\\", ..rest] -> parse_names(text, rest, name <> "\\", names_rev)
    ["\\", ..] -> Error(escape_error(text))
    ["/", ..rest] -> parse_names(text, rest, "", [name, ..names_rev])
    [character, ..rest] -> parse_names(text, rest, name <> character, names_rev)
  }
}

fn missing_path_error(reason: String) -> String {
  "\n--only needs a path\n"
  <> "  "
  <> reason
  <> "\n"
  <> "  Fix: put the path of a test, a group or a suite after --only, for example: "
  <> usage
  <> "\n\n"
}

fn escape_error(text: String) -> String {
  "\n--only path is not correct: "
  <> shell_quote(text)
  <> "\n"
  <> "  Reason: a \\ in a path must come before a / or a \\.\n"
  <> "  Fix: write a / in a name as \\/, and a \\ in a name as \\\\.\n\n"
}

/// The path of the names: each name with `\` and `/` escaped, joined
/// with `/`.
pub fn path(names: List(String)) -> String {
  names
  |> list.map(escape_name)
  |> string.join("/")
}

fn escape_name(name: String) -> String {
  name
  |> string.replace("\\", "\\\\")
  |> string.replace("/", "\\/")
}

/// The command that runs only the test, group or suite with these names.
pub fn command(names: List(String)) -> String {
  "gleam test -- --only " <> shell_quote(path(names))
}

/// `text` as one word of a POSIX shell. Text with no `"`, `$`, `` ` ``,
/// `\` or `!` goes in double quotes. Other text goes in single quotes,
/// and each `'` in it becomes `'\''`.
pub fn shell_quote(text: String) -> String {
  case list.any(string.to_graphemes(text), is_special_in_double_quotes) {
    True -> "'" <> string.replace(text, "'", "'\\''") <> "'"
    False -> "\"" <> text <> "\""
  }
}

fn is_special_in_double_quotes(character: String) -> Bool {
  list.contains(["\"", "$", "`", "\\", "!"], character)
}

/// Whether one of the paths selects the test with these names: the path
/// is the names of the test, or of a group or suite around it.
pub fn selects(paths: List(OnlyPath), names: List(String)) -> Bool {
  case paths {
    [] -> False
    [only_path, ..rest] ->
      path_selects(only_path, names) || selects(rest, names)
  }
}

/// Whether the path is the names of the test, or of a group or suite
/// around it.
fn path_selects(only_path: OnlyPath, names: List(String)) -> Bool {
  list.take(names, list.length(only_path.names)) == only_path.names
}

/// The `--only` paths in `arguments`, when each one selects at least one
/// of the tests, else the error text. `tests` holds the names of each
/// test, before any filter.
pub fn checked_paths(
  arguments: List(String),
  tests: List(List(String)),
) -> Result(List(OnlyPath), String) {
  case parse_arguments(arguments) {
    Ok(paths) -> result.replace(check_paths(paths, tests), paths)
    Error(text) -> Error(text)
  }
}

/// `Ok(Nil)` when each path selects at least one of the tests, else the
/// error text for each path that selects no test. `tests` holds the
/// names of each test, before any filter.
pub fn check_paths(
  paths: List(OnlyPath),
  tests: List(List(String)),
) -> Result(Nil, String) {
  case unknown_path_errors(paths, tests, []) {
    [] -> Ok(Nil)
    errors -> Error(string.concat(errors))
  }
}

fn unknown_path_errors(
  paths: List(OnlyPath),
  tests: List(List(String)),
  errors_rev: List(String),
) -> List(String) {
  case paths {
    [] -> list.reverse(errors_rev)
    [only_path, ..rest] ->
      unknown_path_errors(
        rest,
        tests,
        add_unknown_path_error(only_path, tests, errors_rev),
      )
  }
}

fn add_unknown_path_error(
  only_path: OnlyPath,
  tests: List(List(String)),
  errors_rev: List(String),
) -> List(String) {
  case selects_a_test(only_path, tests) {
    True -> errors_rev
    False -> [unknown_path_error(only_path, tests), ..errors_rev]
  }
}

fn selects_a_test(only_path: OnlyPath, tests: List(List(String))) -> Bool {
  case tests {
    [] -> False
    [names, ..rest] ->
      path_selects(only_path, names) || selects_a_test(only_path, rest)
  }
}

fn unknown_path_error(
  only_path: OnlyPath,
  tests: List(List(String)),
) -> String {
  "\nNo test has the --only path "
  <> shell_quote(only_path.text)
  <> "\n"
  <> closest_lines(closest_paths(only_path.text, tests))
  <> "  Fix: use the full path: the suite name, the group names and the test name, joined with /. Write a / in a name as \\/.\n\n"
}

fn closest_lines(closest: List(List(String))) -> String {
  case closest {
    [] -> "  The run has no tests.\n"
    _ -> "  Closest paths:\n" <> string.concat(list.map(closest, closest_line))
  }
}

fn closest_line(names: List(String)) -> String {
  "    " <> command(names) <> "\n"
}

/// The paths of the tests, groups and suites nearest to `text`, nearest
/// first. Paths at the same distance keep the order of the run.
fn closest_paths(
  text: String,
  tests: List(List(String)),
) -> List(List(String)) {
  let candidates =
    tests
    |> list.flat_map(name_prefixes)
    |> list.unique
  with_distances(text, candidates, [])
  |> list.sort(by_distance)
  |> list.take(closest_count)
  |> list.map(names_of_pair)
}

/// The names of each suite and group around a test, then the test.
fn name_prefixes(names: List(String)) -> List(List(String)) {
  name_prefixes_loop(names, [], [])
}

fn name_prefixes_loop(
  names: List(String),
  prefix_rev: List(String),
  prefixes_rev: List(List(String)),
) -> List(List(String)) {
  case names {
    [] -> list.reverse(prefixes_rev)
    [name, ..rest] -> {
      let next_prefix_rev = [name, ..prefix_rev]
      name_prefixes_loop(rest, next_prefix_rev, [
        list.reverse(next_prefix_rev),
        ..prefixes_rev
      ])
    }
  }
}

/// Each path with its distance to `text`.
fn with_distances(
  text: String,
  candidates: List(List(String)),
  pairs_rev: List(#(Int, List(String))),
) -> List(#(Int, List(String))) {
  case candidates {
    [] -> list.reverse(pairs_rev)
    [names, ..rest] ->
      with_distances(text, rest, [
        #(distance(text, path(names)), names),
        ..pairs_rev
      ])
  }
}

fn by_distance(
  first: #(Int, List(String)),
  second: #(Int, List(String)),
) -> order.Order {
  int.compare(first.0, second.0)
}

fn names_of_pair(pair: #(Int, List(String))) -> List(String) {
  pair.1
}

/// The edit distance (Levenshtein) between two texts, in graphemes.
fn distance(first: String, second: String) -> Int {
  let second_characters = string.to_graphemes(second)
  let first_row = numbers_down_to_zero(list.length(second_characters), [])
  distance_rows(string.to_graphemes(first), second_characters, first_row, 1)
}

fn distance_rows(
  first_characters: List(String),
  second_characters: List(String),
  row: List(Int),
  row_number: Int,
) -> Int {
  case first_characters {
    [] -> last_of_row(row)
    [character, ..rest] ->
      distance_rows(
        rest,
        second_characters,
        next_row(row, second_characters, character, row_number, [row_number]),
        row_number + 1,
      )
  }
}

/// The next row of the distance table, from the row above it.
fn next_row(
  above: List(Int),
  second_characters: List(String),
  character: String,
  left: Int,
  row_rev: List(Int),
) -> List(Int) {
  case above, second_characters {
    [diagonal, up, ..above_rest], [second_character, ..second_rest] -> {
      let value =
        int.min(
          int.min(up + 1, left + 1),
          diagonal + change_cost(character, second_character),
        )
      next_row([up, ..above_rest], second_rest, character, value, [
        value,
        ..row_rev
      ])
    }
    _, _ -> list.reverse(row_rev)
  }
}

/// The numbers from 0 to `number`, in order.
fn numbers_down_to_zero(number: Int, numbers: List(Int)) -> List(Int) {
  case number < 0 {
    True -> numbers
    False -> numbers_down_to_zero(number - 1, [number, ..numbers])
  }
}

fn change_cost(first: String, second: String) -> Int {
  case first == second {
    True -> 0
    False -> 1
  }
}

/// The last number of a row. A row is never empty.
fn last_of_row(row: List(Int)) -> Int {
  list.fold(row, 0, keep_second)
}

fn keep_second(_first: Int, second: Int) -> Int {
  second
}
