//// Checks of the code blocks in the Markdown docs of the repository.
////
//// - Every opening code fence has a language, so GitHub highlights it.
//// - Every Gleam block under a heading with a "Tested snippet" badge is
////   the same, byte for byte, as the line range of the snippet file that
////   the badge links to.
//// - Every Gleam file that a "Tested snippet" badge links to is run by a
////   test. A file under `examples/snippets/test/snippets/` is run when its
////   module exports `tests/0`: `snippets_test` discovers
////   `snippets/**.gleam` and runs the `tests()` of each module, and skips
////   a module without it. A snippet module with only a `main` must be in
////   `run_by_snippet_tests`, with a snippet module that exports `tests/0`
////   and imports it. A Gleam file of another example project must be in
////   `run_by_other_projects`.
//// - Every Gleam block under a "2.x code, from tag 2.1.3" badge is the same
////   as that line range at tag 2.1.3. This needs git and the tag; without
////   them the check is skipped, and its name says so.

import dream_test/file
import dream_test/matchers.{be_equal, or_fail_with, should}
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

/// The folder of the snippet modules, from the root. `snippets_test`
/// discovers every module under it.
const snippets_folder = "examples/snippets/test/"

/// Snippet modules with only a `main`, and the snippet module whose tests
/// run them, as paths under `examples/snippets/test/`.
const run_by_snippet_tests = [
  #(
    "snippets/runner/discovery_runner.gleam",
    "snippets/runner/runner_snippets_run.gleam",
  ),
  #(
    "snippets/runner/suite_specific_config.gleam",
    "snippets/runner/runner_snippets_run.gleam",
  ),
]

/// Gleam files of the other example projects that a "Tested snippet" badge
/// links to. `make examples` runs `gleam test` in each project.
/// - `cache_app_test.gleam` is the test main of `cache_app`.
/// - The shopping cart feature and steps run from `shopping_cart_test`.
const run_by_other_projects = [
  "examples/cache_app/test/cache_app_test.gleam",
  "examples/shopping_cart/test/features/shopping_cart.gleam",
  "examples/shopping_cart/test/steps/cart.gleam",
  "examples/shopping_cart/test/steps/cart_world.gleam",
]

/// The tag of the 2.x code that the upgrade guide shows.
const old_tag = "2.1.3"

pub fn tests() {
  describe("Docs code blocks", [
    it("every opening code fence has a language", fn() {
      docs()
      |> list.flat_map(untagged_fences)
      |> should
      |> be_equal([])
      |> or_fail_with("give each opening fence a language, such as ```text")
    }),
    it("every tested snippet block matches its snippet file", fn() {
      check_blocks(CurrentCode)
    }),
    it("every tested snippet file is run by a test", fn() {
      check_snippets_run()
    }),
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

fn check_blocks(code: Code) -> Result(AssertionResult, String) {
  docs()
  |> list.flat_map(linked_blocks)
  |> list.filter(fn(block) { block_code(block.link) == Some(code) })
  |> list.filter_map(mismatch)
  |> should
  |> be_equal([])
  |> or_fail_with("copy each block from its snippet range, or fix the link")
}

/// Each Gleam file that a "Tested snippet" badge links to, which no test
/// runs, is an error.
fn check_snippets_run() -> Result(AssertionResult, String) {
  docs()
  |> list.flat_map(linked_blocks)
  |> list.filter(is_current_code)
  |> list.map(block_path)
  |> list.unique
  |> list.filter(is_not_run)
  |> should
  |> be_equal([])
  |> or_fail_with(
    "give each linked snippet module a pub fn tests(), or list the file in run_by_other_projects",
  )
}

fn is_current_code(block: LinkedBlock) -> Bool {
  block_code(block.link) == Some(CurrentCode)
}

fn block_path(block: LinkedBlock) -> String {
  block.link.path
}

/// Whether no test runs the file at `path`.
fn is_not_run(path: String) -> Bool {
  case string.split_once(path, snippets_folder) {
    Ok(#("", module_path)) -> !is_run_snippet(module_path)
    _ -> !list.contains(run_by_other_projects, path)
  }
}

/// Whether discovery runs the snippet module, or a snippet module that
/// discovery runs imports it.
fn is_run_snippet(module_path: String) -> Bool {
  exports_tests(module_name(module_path))
  || list.key_find(run_by_snippet_tests, module_path)
  |> result.map(runs_module(_, module_path))
  |> result.unwrap(False)
}

/// Whether the snippet module at `runner_path` exports `tests/0` and
/// imports the module at `module_path`. A file that cannot be read does
/// not run it.
fn runs_module(runner_path: String, module_path: String) -> Bool {
  exports_tests(module_name(runner_path))
  && file.read(root <> "/" <> snippets_folder <> runner_path)
  |> result.map(string.contains(_, "import " <> import_path(module_path)))
  |> result.unwrap(False)
}

/// The import path of a Gleam file under `test/`:
/// `snippets/unit/cart.gleam` is `snippets/unit/cart`.
fn import_path(module_path: String) -> String {
  string.replace(module_path, ".gleam", "")
}

/// The Erlang module name of a Gleam file under `test/`:
/// `snippets/unit/cart.gleam` is `snippets@unit@cart`.
fn module_name(module_path: String) -> String {
  module_path
  |> import_path
  |> string.replace("/", "@")
}

// ---------------------------------------------------------------------------
// Docs
// ---------------------------------------------------------------------------

/// A Markdown file: its path from the root and its lines.
type Doc {
  Doc(path: String, lines: List(String))
}

fn docs() -> List(Doc) {
  doc_patterns
  |> list.flat_map(wildcard(_, root))
  |> list.map(read_doc)
}

fn read_doc(path: String) -> Doc {
  let text = file.read(root <> "/" <> path) |> result.unwrap("")
  Doc(path: path, lines: string.split(text, "\n"))
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
      let #(body, after) = list.split_while(rest, fn(line) { line != "```" })
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

@external(erlang, "snippets_doc_blocks_ffi", "git_show")
fn git_show(root: String, spec: String) -> Result(String, Nil)
