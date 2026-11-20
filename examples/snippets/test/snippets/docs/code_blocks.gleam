//// Checks of the code blocks in the Markdown docs of the repository.
////
//// - Every opening code fence has a language, so GitHub highlights it.
//// - Every Gleam block under a heading with a "Tested snippet" badge is
////   the same, byte for byte, as the line range of the snippet file that
////   the badge links to.
//// - Every Gleam block with a "Tested snippet" badge that shows a
////   `pub fn main()` of a snippet module has that `main` run in a new BEAM.
////   The `main` must end with exit status 0, or the way that
////   `mains_with_other_end` gives: exit status 0 with a given line in its
////   output, or a given status with a given line in its output and a
////   given last line.
//// - Every Gleam file that a "Tested snippet" badge links to is run by a
////   test. A file under `examples/snippets/test/snippets/` is run when its
////   module exports `tests/0`, because `snippets_test` discovers
////   `snippets/**.gleam` and runs the `tests()` of each module. It is also
////   run when a block shows its `main`, because the check above runs that
////   `main`. A Gleam file of another example project must be in
////   `run_by_other_projects`.
//// - Every Gleam block under a "2.x code, from tag 2.1.3" badge is the same
////   as that line range at tag 2.1.3. This needs git and the tag; without
////   them the check is skipped, and its name says so.
////
//// A check fails when a doc cannot be read, or when it finds no block to
//// check, so a run from the wrong folder does not pass with nothing
//// checked.

import dream_test/file
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/parallel
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it, skip}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/string

/// The root of the repository, from the snippets project.
const root = "../.."

/// The Markdown files whose code blocks are checked.
const doc_patterns = [
  "README.md", "CHANGELOG.md", "documentation/*.md", "releases/*.md",
  "examples/*/README.md",
]

/// The folder that `snippets_test` discovers (`snippets/**.gleam`), from
/// the root.
const discovered_folder = "examples/snippets/test/snippets/"

/// The folder of the coverage snippets, from the root. Their `main`
/// functions write files under `build/coverage`, so they run one at a time.
const coverage_folder = "examples/snippets/test/snippets/coverage/"

/// How a shown `main` must end.
type MainEnd {
  /// Exit status 0.
  EndsWithStatusZero
  /// Exit status 0, with `line` as a line of the output.
  EndsWithStatusZeroAndLine(line: String)
  /// Exit status `status`, with `line` as a line of the output and
  /// `last_line` as the last line that is not blank.
  EndsWith(status: Int, line: String, last_line: String)
}

/// Snippet files whose `main` must end with more than exit status 0, and
/// how it ends.
/// - `custom_post_run_reporter.gleam` prints the line that its doc shows.
/// - `coverage_badge.gleam` sets a minimum of 80.0%, and the snippets
///   project measures its own `src`, which no snippet test covers.
/// - `coverage_server.gleam` merges the LCOV files of servers, and no
///   server runs, so no file matches.
const mains_with_other_end = [
  #(
    "examples/snippets/test/snippets/reporters/custom_post_run_reporter.gleam",
    EndsWithStatusZeroAndLine(
      line: "MyReport: 3 total; 3 passed; 0 failed; 0 teardown failed; 0 setup stopped",
    ),
  ),
  #(
    "examples/snippets/test/snippets/coverage/coverage_badge.gleam",
    EndsWith(
      status: 1,
      line: "Coverage failed",
      last_line: "Tests: 1 passed. Exit status 1, because coverage is below the minimum.",
    ),
  ),
  #(
    "examples/snippets/test/snippets/coverage/coverage_server.gleam",
    EndsWith(
      status: 1,
      line: "  No LCOV files match \"build/coverage/servers/*.info\".",
      last_line: "Tests: 1 passed. Exit status 1, because coverage was requested and did not complete.",
    ),
  ),
]

/// The time that one `main` in a new BEAM gets, from its start to its
/// end. Then the BEAM is killed. Starting a BEAM takes longer than the
/// default test timeout when many start at the same time.
const main_deadline_ms = 50_000

/// The time that a test gets after the deadline of its `main`, to kill the
/// BEAM and give its result.
const kill_margin_ms = 10_000

/// Gleam files of the other example projects that a "Tested snippet" badge
/// links to. `make examples` runs `gleam test` in each project.
/// - `cache_app_test.gleam` is the test main of `cache_app`.
/// - The shopping cart feature and steps run from `shopping_cart_test`.
const run_by_other_projects = [
  "examples/cache_app/test/cache_app_test.gleam",
  "examples/shopping_cart/test/features/shopping_cart.gleam",
  "examples/shopping_cart/test/steps/cart.gleam",
  "examples/shopping_cart/test/steps/cart_state.gleam",
]

/// The tag of the 2.x code that the upgrade guide shows.
const old_tag = "2.1.3"

pub fn tests() {
  describe("Docs code blocks", [
    it("every opening code fence has a language", check_fences),
    it("every tested snippet block matches its snippet file", fn() {
      check_blocks(CurrentCode)
    }),
    it(
      "every tested snippet file is run by discovery, by its shown main or by another example project",
      fn() { check_snippets_run() },
    ),
    unit.group(
      "every shown main of a snippet ends with the expected exit status and output lines",
      main_tests(result.try(docs(), shown_mains)),
    ),
    old_code_test(git_show(root, old_tag <> ":gleam.toml")),
  ])
}

/// The check of the 2.x blocks, or a skipped test when the tag cannot be
/// read.
fn old_code_test(tag: Result(String, Nil)) -> unit.UnitNode {
  case tag {
    Ok(_) ->
      it("every 2.x block matches tag " <> old_tag, fn() {
        check_blocks(OldCode)
      })
    Error(Nil) ->
      skip(
        "every 2.x block matches tag "
          <> old_tag
          <> " (not compared: git or the tag is not available)",
        fn() { check_blocks(OldCode) },
      )
  }
}

/// Which linked blocks a check compares.
type Code {
  /// Blocks with a "Tested snippet" badge: the current files.
  CurrentCode
  /// Blocks with a "2.x code, from tag 2.1.3" badge: the files at the tag.
  OldCode
}

fn check_fences() -> Result(AssertionResult, String) {
  use docs <- result.try(docs())
  docs
  |> list.flat_map(untagged_fences)
  |> should
  |> be_equal([])
  |> or_fail_with("give each opening fence a language, such as ```text")
}

fn check_blocks(code: Code) -> Result(AssertionResult, String) {
  use docs <- result.try(docs())
  use blocks <- result.try(
    docs
    |> list.flat_map(linked_blocks)
    |> list.filter(has_code(_, code))
    |> some_or("found no linked Gleam block of this kind in the docs"),
  )
  blocks
  |> list.filter_map(mismatch)
  |> should
  |> be_equal([])
  |> or_fail_with("copy each block from its snippet range, or fix the link")
}

fn has_code(block: LinkedBlock, code: Code) -> Bool {
  block_code(block.link) == Some(code)
}

/// `Ok(items)`, or `Error(message)` when `items` is empty.
fn some_or(items: List(a), message: String) -> Result(List(a), String) {
  case items {
    [] -> Error(message)
    _ -> Ok(items)
  }
}

/// Each Gleam file that a "Tested snippet" badge links to, which no test
/// runs, is an error.
fn check_snippets_run() -> Result(AssertionResult, String) {
  use docs <- result.try(docs())
  use mains <- result.try(shown_mains(docs))
  docs
  |> list.flat_map(linked_blocks)
  |> list.filter(is_current_code)
  |> list.map(block_path)
  |> list.unique
  |> list.filter(is_not_run(_, mains))
  |> should
  |> be_equal([])
  |> or_fail_with(
    "give each linked snippet module a pub fn tests(), show its pub fn main() in a block, or list the file in run_by_other_projects",
  )
}

fn is_current_code(block: LinkedBlock) -> Bool {
  block_code(block.link) == Some(CurrentCode)
}

fn block_path(block: LinkedBlock) -> String {
  block.link.path
}

/// Whether no test runs the file at `path`. `mains` are the snippet files
/// whose `main` the main check runs.
fn is_not_run(path: String, mains: List(String)) -> Bool {
  case string.split_once(path, discovered_folder) {
    Ok(#("", module_path)) ->
      !exports_tests(module_name("snippets/" <> module_path))
      && !list.contains(mains, path)
    _ -> !list.contains(run_by_other_projects, path)
  }
}

/// The Erlang module name of a Gleam file under `test/`:
/// `snippets/unit/cart.gleam` is `snippets@unit@cart`.
fn module_name(module_path: String) -> String {
  module_path
  |> string.replace(".gleam", "")
  |> string.replace("/", "@")
}

// ---------------------------------------------------------------------------
// Shown mains
// ---------------------------------------------------------------------------

/// The snippet files under the discovered folder that a "Tested snippet"
/// block shows the `main` of, in order, each one time. An error when there
/// is none.
fn shown_mains(docs: List(Doc)) -> Result(List(String), String) {
  docs
  |> list.flat_map(linked_blocks)
  |> list.filter(is_current_code)
  |> list.filter(shows_main)
  |> list.map(block_path)
  |> list.filter(string.starts_with(_, discovered_folder))
  |> list.unique
  |> some_or("found no shown main of a snippet in the docs")
}

/// A test for each shown main, or one failing test when the shown mains
/// cannot be found.
fn main_tests(mains: Result(List(String), String)) -> List(unit.UnitNode) {
  case mains {
    Ok(paths) -> list.map(paths, main_test)
    Error(message) -> [
      it("the shown mains can be found", fn() { fail_with(message) }),
    ]
  }
}

fn fail_with(message: String) -> Result(AssertionResult, String) {
  Error(message)
}

fn shows_main(block: LinkedBlock) -> Bool {
  list.contains(string.split(block.text, "\n"), "pub fn main() {")
}

/// A test that runs the `main` of the snippet file at `path` in a new BEAM,
/// with the timeout of `main_test_timeout_ms`.
fn main_test(path: String) -> unit.UnitNode {
  types.Test(
    name: path,
    tags: [],
    kind: types.Unit,
    run: types.NoInput(fn() { check_main(path) }),
    timeout_ms: Some(main_test_timeout_ms(path)),
    source: None,
  )
}

/// The timeout of the test of a shown main. A coverage main first waits
/// for the coverage lock, and its deadline starts when it has the lock.
/// The lock goes to the tests in the order that they ask. The snippets
/// run uses `parallel.default_config()`, so at most `max_concurrency - 1`
/// other tests ask before it. Each one holds the lock for at most
/// `main_deadline_ms`: a main is killed then, and an in-process coverage
/// test has the default timeout, which is shorter.
fn main_test_timeout_ms(path: String) -> Int {
  let parallel.ParallelConfig(
    max_concurrency: concurrency,
    default_timeout_ms: _,
  ) = parallel.default_config()
  case string.starts_with(path, coverage_folder) {
    True -> concurrency * main_deadline_ms + kill_margin_ms
    False -> main_deadline_ms + kill_margin_ms
  }
}

/// Run the `main` of the snippet file at `path` in a new BEAM, and compare
/// how it ended with `expected_end`. The coverage snippets run one at a
/// time.
fn check_main(path: String) -> Result(AssertionResult, String) {
  let module =
    module_name("snippets/" <> string.replace(path, discovered_folder, ""))
  let #(status, output) = case string.starts_with(path, coverage_folder) {
    True -> run_main_in_new_vm_with_coverage_lock(module, main_deadline_ms)
    False -> run_main_in_new_vm(module, main_deadline_ms)
  }
  end_problems(expected_end(path), status, output)
  |> should
  |> be_equal([])
  |> or_fail_with(path <> ": main ended with this output:\n" <> output)
}

fn expected_end(path: String) -> MainEnd {
  list.key_find(mains_with_other_end, path)
  |> result.unwrap(EndsWithStatusZero)
}

/// The differences between how a main ended and `expected`, or `[]`.
fn end_problems(
  expected: MainEnd,
  status: Int,
  output: String,
) -> List(String) {
  case expected {
    EndsWithStatusZero -> status_problem(0, status)
    EndsWithStatusZeroAndLine(line: line) ->
      list.append(
        status_problem(0, status),
        line_problem(line, string.split(output, "\n")),
      )
    EndsWith(status: expected_status, line: line, last_line: last_line) -> {
      let lines = string.split(output, "\n")
      list.flatten([
        status_problem(expected_status, status),
        line_problem(line, lines),
        last_line_problem(last_line, last_text_line(lines)),
      ])
    }
  }
}

fn status_problem(expected: Int, status: Int) -> List(String) {
  case status == expected {
    True -> []
    False -> [
      "exit status "
      <> int.to_string(status)
      <> ", expected "
      <> int.to_string(expected),
    ]
  }
}

fn line_problem(line: String, lines: List(String)) -> List(String) {
  case list.contains(lines, line) {
    True -> []
    False -> ["no output line is " <> string.inspect(line)]
  }
}

fn last_line_problem(expected: String, last_line: String) -> List(String) {
  case last_line == expected {
    True -> []
    False -> [
      "the last line is "
      <> string.inspect(last_line)
      <> ", expected "
      <> string.inspect(expected),
    ]
  }
}

/// The last line that is not blank, or `""` when every line is blank.
fn last_text_line(lines: List(String)) -> String {
  lines
  |> list.reverse
  |> list.find(is_not_blank)
  |> result.unwrap("")
}

fn is_not_blank(line: String) -> Bool {
  string.trim(line) != ""
}

// ---------------------------------------------------------------------------
// Docs
// ---------------------------------------------------------------------------

/// A Markdown file: its path from the root and its lines.
type Doc {
  Doc(path: String, lines: List(String))
}

/// The docs, or an error when no doc is found or a doc cannot be read.
fn docs() -> Result(List(Doc), String) {
  doc_patterns
  |> list.flat_map(wildcard(_, root))
  |> some_or(
    "found no Markdown file under "
    <> root
    <> ": run the tests from examples/snippets",
  )
  |> result.try(list.try_map(_, read_doc))
}

fn read_doc(path: String) -> Result(Doc, String) {
  case file.read(root <> "/" <> path) {
    Ok(text) -> Ok(Doc(path: path, lines: string.split(text, "\n")))
    Error(error) ->
      Error("could not read " <> path <> ": " <> file.error_to_string(error))
  }
}

// ---------------------------------------------------------------------------
// Fences
// ---------------------------------------------------------------------------

/// `<path>:<line>` of each opening fence with no language.
fn untagged_fences(doc: Doc) -> List(String) {
  fence_errors(doc.path, doc.lines, 1, False, [])
}

fn fence_errors(
  path: String,
  lines: List(String),
  number: Int,
  in_block: Bool,
  errors_rev: List(String),
) -> List(String) {
  case lines {
    [] -> list.reverse(errors_rev)
    [line, ..rest] ->
      fence_line(path, rest, number, in_block, errors_rev, fence_info(line))
  }
}

fn fence_line(
  path: String,
  rest: List(String),
  number: Int,
  in_block: Bool,
  errors_rev: List(String),
  info: Option(String),
) -> List(String) {
  case info, in_block {
    None, _ -> fence_errors(path, rest, number + 1, in_block, errors_rev)
    Some(""), False ->
      fence_errors(path, rest, number + 1, True, [
        path <> ":" <> int.to_string(number),
        ..errors_rev
      ])
    Some(""), True -> fence_errors(path, rest, number + 1, False, errors_rev)
    Some(_language), False ->
      fence_errors(path, rest, number + 1, True, errors_rev)
    Some(_text), True -> fence_errors(path, rest, number + 1, True, errors_rev)
  }
}

/// The text after the backticks of a fence line, or `None` for a line
/// that is not a fence.
fn fence_info(line: String) -> Option(String) {
  let trimmed = string.trim_start(line)
  case string.starts_with(trimmed, "```") {
    True -> Some(string.trim(drop_backticks(trimmed)))
    False -> None
  }
}

fn drop_backticks(text: String) -> String {
  case text {
    "`" <> rest -> drop_backticks(rest)
    _ -> text
  }
}

// ---------------------------------------------------------------------------
// Linked blocks
// ---------------------------------------------------------------------------

/// A badge link: the version in the URL, the file, the line range and the
/// alt text of the badge.
type Link {
  Link(version: String, path: String, range: Option(#(Int, Int)), alt: String)
}

/// A Gleam block, the line of its opening fence, and the link of the
/// heading right above it.
type LinkedBlock {
  LinkedBlock(doc: String, line: Int, link: Link, text: String)
}

fn block_code(link: Link) -> Option(Code) {
  case link.version, link.alt {
    _, "2.x, not compiled" -> None
    "2.1.3", _ -> Some(OldCode)
    _, _ -> Some(CurrentCode)
  }
}

fn linked_blocks(doc: Doc) -> List(LinkedBlock) {
  scan_lines(doc.path, doc.lines, 0, None, [])
}

/// Walk the lines. `last` is the badge link of the last heading and the
/// index of its line. A Gleam block at most 3 lines below it is linked.
fn scan_lines(
  path: String,
  lines: List(String),
  index: Int,
  last: Option(#(Link, Int)),
  found_rev: List(LinkedBlock),
) -> List(LinkedBlock) {
  case lines {
    [] -> list.reverse(found_rev)
    ["```gleam", ..rest] -> {
      let #(body, after) = list.split_while(rest, is_not_closing_fence)
      let text = string.join(body, "\n") <> "\n"
      scan_lines(
        path,
        list.drop(after, 1),
        index + list.length(body) + 2,
        None,
        add_linked_block(path, index, last, text, found_rev),
      )
    }
    [line, ..rest] ->
      scan_lines(
        path,
        rest,
        index + 1,
        heading_link(line, index, last),
        found_rev,
      )
  }
}

fn is_not_closing_fence(line: String) -> Bool {
  line != "```"
}

/// Add the block at line index `index` when a heading with a badge link
/// is at most 3 lines above it.
fn add_linked_block(
  path: String,
  index: Int,
  last: Option(#(Link, Int)),
  text: String,
  found_rev: List(LinkedBlock),
) -> List(LinkedBlock) {
  case last {
    Some(#(link, heading)) if index - heading <= 3 -> [
      LinkedBlock(doc: path, line: index + 1, link: link, text: text),
      ..found_rev
    ]
    _ -> found_rev
  }
}

fn heading_link(
  line: String,
  index: Int,
  last: Option(#(Link, Int)),
) -> Option(#(Link, Int)) {
  case string.starts_with(line, "#"), parse_link(line) {
    True, Some(link) -> Some(#(link, index))
    _, _ -> last
  }
}

fn parse_link(line: String) -> Option(Link) {
  let assert Ok(pattern) =
    regexp.from_string(
      "<a href=\"https://github\\.com/TrustBound/dream_test/blob/([^/]+)/([^\"#]+)(?:#L(\\d+)-L(\\d+))?\"><img[^>]*alt=\"([^\"]+)\"",
    )
  case regexp.scan(pattern, line) {
    [
      regexp.Match(
        submatches: [Some(version), Some(path), first, last, Some(alt)],
        ..,
      ),
      ..
    ] ->
      Some(Link(
        version: version,
        path: path,
        range: range(first, last),
        alt: alt,
      ))
    _ -> None
  }
}

fn range(first: Option(String), last: Option(String)) -> Option(#(Int, Int)) {
  case first, last {
    Some(first), Some(last) -> parsed_range(int.parse(first), int.parse(last))
    _, _ -> None
  }
}

fn parsed_range(
  first: Result(Int, Nil),
  last: Result(Int, Nil),
) -> Option(#(Int, Int)) {
  case first, last {
    Ok(first), Ok(last) -> Some(#(first, last))
    _, _ -> None
  }
}

/// The text of a mismatch, or `Error(Nil)` when the block matches.
fn mismatch(block: LinkedBlock) -> Result(String, Nil) {
  case matches(block, source(block.link)) {
    True -> Error(Nil)
    False ->
      Ok(
        block.doc
        <> ":"
        <> int.to_string(block.line)
        <> " does not match "
        <> block.link.version
        <> ":"
        <> block.link.path
        <> range_text(block.link.range),
      )
  }
}

fn matches(block: LinkedBlock, source: Result(String, Nil)) -> Bool {
  case source, block.link.range {
    Error(Nil), _ -> False
    Ok(text), Some(#(first, last)) ->
      lines_text(text, first, last) == block.text
    Ok(text), None -> string.contains(text, block.text)
  }
}

fn lines_text(text: String, first: Int, last: Int) -> String {
  string.split(text, "\n")
  |> list.drop(first - 1)
  |> list.take(last - first + 1)
  |> string.join("\n")
  <> "\n"
}

fn range_text(range: Option(#(Int, Int))) -> String {
  case range {
    Some(#(first, last)) ->
      "#L" <> int.to_string(first) <> "-L" <> int.to_string(last)
    None -> ""
  }
}

fn source(link: Link) -> Result(String, Nil) {
  case link.version {
    "2.1.3" -> git_show(root, old_tag <> ":" <> link.path)
    _ -> file.read(root <> "/" <> link.path) |> result.replace_error(Nil)
  }
}

@external(erlang, "snippets_doc_blocks_ffi", "wildcard")
fn wildcard(pattern: String, root: String) -> List(String)

@external(erlang, "snippets_doc_blocks_ffi", "exports_tests")
fn exports_tests(module: String) -> Bool

/// Run `module:main()` in a new `erl` process with the code path of this
/// test run. Returns the exit status and the output (stdout and stderr).
/// The process is killed, with status -1, when it does not stop in
/// `deadline_ms`, or when the test process stops first.
@external(erlang, "snippets_doc_blocks_ffi", "run_main_in_new_vm")
fn run_main_in_new_vm(module: String, deadline_ms: Int) -> #(Int, String)

/// `run_main_in_new_vm`, while no other snippet test holds the coverage
/// lock of `snippets/utils/coverage_lock`. The deadline starts when this
/// test has the lock.
@external(erlang, "snippets_doc_blocks_ffi", "run_main_in_new_vm_with_coverage_lock")
fn run_main_in_new_vm_with_coverage_lock(
  module: String,
  deadline_ms: Int,
) -> #(Int, String)

@external(erlang, "snippets_doc_blocks_ffi", "git_show")
fn git_show(root: String, spec: String) -> Result(String, Nil)
