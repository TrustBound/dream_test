//// Checks the guide badges of the README examples.
////
//// A README example is a heading with a "Tested snippet" badge. Its line
//// ends with the tested snippet badge, one space and the guide badge:
////
//// ```markdown
//// ### A unit test file <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/readme/unit_tests.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a> <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/docs/guides/quick-start.md#a-unit-test-file-"><img align="right" alt="Guide" src="https://img.shields.io/badge/%F0%9F%93%96_read-guide-blue.svg?style=flat-square"></a>
//// ```
////
//// - The guide badge links at the tag of the `version` in `gleam.toml`.
//// - The guide file is a `.md` file under `docs/guides`, and it exists.
//// - The anchor is the GitHub anchor of a heading of the guide. The guide
////   heading has a tested snippet badge, so its anchor ends with a hyphen.
//// - The guide has a heading with a "Tested snippet" badge that links to
////   the same snippet file. The line range can be different.
//// - Only the README has guide badges.

import dream_test/file
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/regexp
import gleam/result
import gleam/string

/// The root of the repository, from the snippets project.
const root = "../.."

/// The docs that must have no guide badge, from the root.
const docs_without_guide_badges = [
  "CHANGELOG.md", "docs/**/*.md", "releases/*.md", "examples/*/README.md",
  "src/**/*.gleam",
]

/// The start of a guide badge link, at any tag.
const guide_badge_alt = "alt=\"Guide\""

/// A README example heading with a guide badge in the exact form.
type GuideBadge {
  GuideBadge(
    line: Int,
    snippet_path: String,
    tag: String,
    guide_path: String,
    anchor: String,
  )
}

/// A README line: its number and its text.
type NumberedLine {
  NumberedLine(number: Int, text: String)
}

pub fn tests() {
  describe("README guide badges", [
    it(
      "every README example heading has a guide badge in the exact form",
      check_badge_forms,
    ),
    it(
      "every guide badge links at the tag of the version in gleam.toml",
      check_badge_tags,
    ),
    it("every guide badge links to a guide file that exists", check_guide_files),
    it(
      "every guide badge anchor is the anchor of a heading of its guide",
      check_guide_anchors,
    ),
    it(
      "every guide shows the snippet file of its README example",
      check_guide_snippets,
    ),
    it("no doc outside the README has a guide badge", check_no_other_badges),
    it("a README example heading with no guide badge is a problem", fn() {
      // Arrange
      let lines = [
        NumberedLine(
          number: 3,
          text: "### An example <a href=\"https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/readme/unit_tests.gleam\"><img align=\"right\" alt=\"Tested snippet\" src=\"https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square\"></a>",
        ),
      ]

      // Act
      let problems = form_problems(lines)

      // Assert
      problems
      |> should
      |> be_equal([
        "README.md:3: the example heading has no guide badge in the exact form after its tested snippet badge",
      ])
      |> or_fail_with("an example heading needs the guide badge")
    }),
    it("the anchor of What's New is whats-new", fn() {
      // Arrange
      let headings = ["## What's New"]

      // Act
      let anchors = heading_anchors(headings)

      // Assert
      anchors
      |> should
      |> be_equal(["whats-new"])
      |> or_fail_with("an apostrophe must be dropped from the anchor")
    }),
    it("the anchor of a heading with a code span and a badge", fn() {
      // Arrange
      let headings = [
        "#### The `RequestBody` type <a href=\"https://example.com\"><img alt=\"Tested snippet\"></a>",
      ]

      // Act
      let anchors = heading_anchors(headings)

      // Assert
      anchors
      |> should
      |> be_equal(["the-requestbody-type-"])
      |> or_fail_with(
        "a code span keeps its text, a tag is dropped and the space before it stays",
      )
    }),
    it("the second and third headings with the same anchor get -1 and -2", fn() {
      // Arrange
      let headings = ["## Setup", "### Setup", "#### Setup"]

      // Act
      let anchors = heading_anchors(headings)

      // Assert
      anchors
      |> should
      |> be_equal(["setup", "setup-1", "setup-2"])
      |> or_fail_with("a repeated anchor must get a number")
    }),
    it("the anchors that GitHub gives to headings with badges", fn() {
      // Arrange
      let snippet_badge =
        "<a href=\"https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/readme/unit_tests.gleam\"><img align=\"right\" alt=\"Tested snippet\" src=\"https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square\"></a>"
      let guide_badge =
        "<a href=\"https://github.com/TrustBound/dream_test/blob/3.0.0/docs/guides/quick-start.md#a-unit-test-file-\"><img align=\"right\" alt=\"Guide\" src=\"https://img.shields.io/badge/%F0%9F%93%96_read-guide-blue.svg?style=flat-square\"></a>"
      let headings = [
        "## Check one document",
        "### Check one document " <> snippet_badge,
        "### Check a project and read what the command prints " <> snippet_badge,
        "### Read the settings from the text of a `gleam.toml` "
          <> snippet_badge,
        "### Check a project and read what the command prints "
          <> snippet_badge
          <> " "
          <> guide_badge,
      ]

      // Act
      let anchors = heading_anchors(headings)

      // Assert
      anchors
      |> should
      |> be_equal([
        "check-one-document",
        "check-one-document-",
        "check-a-project-and-read-what-the-command-prints-",
        "read-the-settings-from-the-text-of-a-gleamtoml-",
        "check-a-project-and-read-what-the-command-prints--",
      ])
      |> or_fail_with("each space before a badge must give a hyphen")
    }),
  ])
}

// ---------------------------------------------------------------------------
// Checks
// ---------------------------------------------------------------------------

fn check_badge_forms() -> Result(AssertionResult, String) {
  use examples <- result.try(readme_example_lines())
  examples
  |> form_problems
  |> should
  |> be_equal([])
  |> or_fail_with(
    "end each README example heading with the tested snippet badge, one space and the guide badge",
  )
}

fn check_badge_tags() -> Result(AssertionResult, String) {
  use badges <- result.try(readme_guide_badges())
  use version <- result.try(package_version())
  badges
  |> list.filter(fn(badge) { badge.tag != version })
  |> list.map(fn(badge) {
    readme_location(badge.line)
    <> "the guide badge links at tag "
    <> badge.tag
    <> ", but gleam.toml has version "
    <> version
  })
  |> should
  |> be_equal([])
  |> or_fail_with("link each guide badge at the tag of the version")
}

fn check_guide_files() -> Result(AssertionResult, String) {
  use badges <- result.try(readme_guide_badges())
  badges
  |> list.filter(fn(badge) { result.is_error(read_file(badge.guide_path)) })
  |> list.map(fn(badge) {
    readme_location(badge.line) <> badge.guide_path <> " does not exist"
  })
  |> should
  |> be_equal([])
  |> or_fail_with("link each guide badge to a guide under docs/guides")
}

fn check_guide_anchors() -> Result(AssertionResult, String) {
  use badges <- result.try(readme_guide_badges())
  let guides = read_guides(badges)
  badges
  |> list.filter(fn(badge) {
    !list.contains(guide_anchors(guides, badge.guide_path), badge.anchor)
  })
  |> list.map(fn(badge) {
    readme_location(badge.line)
    <> badge.guide_path
    <> " has no heading with the anchor #"
    <> badge.anchor
  })
  |> should
  |> be_equal([])
  |> or_fail_with("link each guide badge to the anchor of a guide heading")
}

fn check_guide_snippets() -> Result(AssertionResult, String) {
  use badges <- result.try(readme_guide_badges())
  let guides = read_guides(badges)
  badges
  |> list.filter(fn(badge) {
    !list.contains(
      guide_snippet_paths(guides, badge.guide_path),
      badge.snippet_path,
    )
  })
  |> list.map(fn(badge) {
    readme_location(badge.line)
    <> badge.guide_path
    <> " has no tested snippet badge that links to "
    <> badge.snippet_path
  })
  |> should
  |> be_equal([])
  |> or_fail_with(
    "show the README example in its guide, with a tested snippet badge to the same file",
  )
}

fn check_no_other_badges() -> Result(AssertionResult, String) {
  use paths <- result.try(other_doc_paths())
  use texts <- result.try(list.try_map(paths, read_file))
  list.zip(paths, texts)
  |> list.flat_map(fn(pair) { guide_badge_locations(pair.0, pair.1) })
  |> should
  |> be_equal([])
  |> or_fail_with("remove the guide badge: only the README has guide badges")
}

// ---------------------------------------------------------------------------
// The README
// ---------------------------------------------------------------------------

/// The README example headings, outside code fences. An error when the
/// README cannot be read or has no example, so a run from the wrong folder
/// does not pass.
fn readme_example_lines() -> Result(List(NumberedLine), String) {
  use text <- result.try(read_file("README.md"))
  let examples =
    text
    |> numbered_lines_outside_fences
    |> list.filter(is_example_heading)
  case examples {
    [] -> Error("found no example heading in " <> root <> "/README.md")
    _ -> Ok(examples)
  }
}

fn is_example_heading(line: NumberedLine) -> Bool {
  string.starts_with(line.text, "#")
  && string.contains(line.text, "alt=\"Tested snippet\"")
}

/// A problem for each example heading whose line does not end with the
/// tested snippet badge, one space and the guide badge.
fn form_problems(examples: List(NumberedLine)) -> List(String) {
  examples
  |> list.filter(fn(line) { result.is_error(parse_guide_badge(line)) })
  |> list.map(fn(line) {
    readme_location(line.number)
    <> "the example heading has no guide badge in the exact form after its tested snippet badge"
  })
}

/// The guide badges of the README examples in the exact form.
fn readme_guide_badges() -> Result(List(GuideBadge), String) {
  use examples <- result.try(readme_example_lines())
  Ok(list.filter_map(examples, parse_guide_badge))
}

fn parse_guide_badge(line: NumberedLine) -> Result(GuideBadge, Nil) {
  let assert Ok(pattern) =
    regexp.from_string(
      "^#+ \\S.* <a href=\"https://github\\.com/TrustBound/dream_test/blob/[^/\"]+/([^\"#]+)(?:#L\\d+-L\\d+)?\"><img align=\"right\" alt=\"Tested snippet\" src=\"https://img\\.shields\\.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen\\.svg\\?style=flat-square\"></a> <a href=\"https://github\\.com/TrustBound/dream_test/blob/([^/\"]+)/(docs/guides/[^\"#]+\\.md)#([^\"]+)\"><img align=\"right\" alt=\"Guide\" src=\"https://img\\.shields\\.io/badge/%F0%9F%93%96_read-guide-blue\\.svg\\?style=flat-square\"></a>$",
    )
  case regexp.scan(pattern, line.text) {
    [
      regexp.Match(
        submatches: [
          Some(snippet_path),
          Some(tag),
          Some(guide_path),
          Some(anchor),
        ],
        ..,
      ),
    ] ->
      Ok(GuideBadge(
        line: line.number,
        snippet_path: snippet_path,
        tag: tag,
        guide_path: guide_path,
        anchor: anchor,
      ))
    _ -> Error(Nil)
  }
}

fn readme_location(line: Int) -> String {
  "README.md:" <> int.to_string(line) <> ": "
}

/// The `version` of the root `gleam.toml`.
fn package_version() -> Result(String, String) {
  use text <- result.try(read_file("gleam.toml"))
  text
  |> string.split("\n")
  |> list.find(string.starts_with(_, "version = \""))
  |> result.map(fn(line) {
    line
    |> string.replace("version = \"", "")
    |> string.replace("\"", "")
    |> string.trim
  })
  |> result.replace_error("found no version line in " <> root <> "/gleam.toml")
}

// ---------------------------------------------------------------------------
// The guides
// ---------------------------------------------------------------------------

/// The text of each guide that a badge links to and that can be read.
fn read_guides(badges: List(GuideBadge)) -> Dict(String, String) {
  badges
  |> list.map(fn(badge) { badge.guide_path })
  |> list.unique
  |> list.filter_map(fn(path) {
    read_file(path)
    |> result.map(fn(text) { #(path, text) })
    |> result.replace_error(Nil)
  })
  |> dict.from_list
}

fn guide_headings(guides: Dict(String, String), path: String) -> List(String) {
  guides
  |> dict.get(path)
  |> result.unwrap("")
  |> numbered_lines_outside_fences
  |> list.map(fn(line) { line.text })
  |> list.filter(is_heading)
}

fn is_heading(text: String) -> Bool {
  let assert Ok(pattern) = regexp.from_string("^#{1,6} ")
  regexp.check(pattern, text)
}

fn guide_anchors(guides: Dict(String, String), path: String) -> List(String) {
  heading_anchors(guide_headings(guides, path))
}

/// The snippet files that the tested snippet badges of the guide headings
/// link to, with no line range.
fn guide_snippet_paths(
  guides: Dict(String, String),
  path: String,
) -> List(String) {
  let assert Ok(pattern) =
    regexp.from_string(
      "<a href=\"https://github\\.com/TrustBound/dream_test/blob/[^/\"]+/([^\"#]+)(?:#L\\d+-L\\d+)?\"><img align=\"right\" alt=\"Tested snippet\"",
    )
  guide_headings(guides, path)
  |> list.flat_map(regexp.scan(pattern, _))
  |> list.flat_map(fn(match) { option.values(match.submatches) })
}

/// The GitHub anchors of the headings, in order. A repeated anchor gets
/// `-1`, then `-2`, and so on.
fn heading_anchors(headings: List(String)) -> List(String) {
  let #(_, anchors_rev) =
    list.fold(headings, #(dict.new(), []), fn(state, heading) {
      let #(seen, anchors_rev) = state
      let anchor = heading_slug(heading)
      let count = dict.get(seen, anchor) |> result.unwrap(0)
      #(dict.insert(seen, anchor, count + 1), [
        numbered_anchor(anchor, count),
        ..anchors_rev
      ])
    })
  list.reverse(anchors_rev)
}

fn numbered_anchor(anchor: String, count: Int) -> String {
  case count {
    0 -> anchor
    _ -> anchor <> "-" <> int.to_string(count)
  }
}

/// The anchor that GitHub makes for a heading line: the `#` marks removed,
/// the spaces at the start and the end of the heading text removed, inline
/// tags and Markdown marks removed, a link keeps its text, the text in
/// lowercase, each character that is not a letter, a digit, a space, a
/// hyphen or an underscore removed, and each space changed to a hyphen.
///
/// The spaces around a tag stay, and the text is not trimmed again after
/// the tags are removed. So the space before a badge at the end of a
/// heading gives a hyphen at the end of the anchor:
/// `### Check one document <a ...><img ...></a>` gets
/// `check-one-document-`.
fn heading_slug(heading: String) -> String {
  let assert Ok(marks) = regexp.from_string("^#+ ")
  let assert Ok(tags) = regexp.from_string("<[^>]*>")
  let assert Ok(links) = regexp.from_string("\\[([^\\]]*)\\]\\([^)]*\\)")
  let assert Ok(other) = regexp.from_string("[^\\p{L}\\p{N} _-]")
  heading
  |> regexp.replace(marks, _, "")
  |> string.trim
  |> regexp.replace(tags, _, "")
  |> regexp.match_map(links, _, link_text)
  |> string.lowercase
  |> regexp.replace(other, _, "")
  |> string.replace(" ", "-")
}

fn link_text(match: regexp.Match) -> String {
  match.submatches
  |> option.values
  |> string.concat
}

// ---------------------------------------------------------------------------
// Other docs
// ---------------------------------------------------------------------------

fn other_doc_paths() -> Result(List(String), String) {
  let paths =
    docs_without_guide_badges
    |> list.flat_map(wildcard(_, root))
    |> list.unique
  case paths {
    [] -> Error("found no doc under " <> root <> ": run from examples/snippets")
    _ -> Ok(paths)
  }
}

/// `<path>:<line>` of each line with a guide badge.
fn guide_badge_locations(path: String, text: String) -> List(String) {
  text
  |> string.split("\n")
  |> list.index_map(fn(line, index) { NumberedLine(index + 1, line) })
  |> list.filter(fn(line) { string.contains(line.text, guide_badge_alt) })
  |> list.map(fn(line) { path <> ":" <> int.to_string(line.number) })
}

// ---------------------------------------------------------------------------
// Files and fences
// ---------------------------------------------------------------------------

fn read_file(path: String) -> Result(String, String) {
  file.read(root <> "/" <> path)
  |> result.map_error(fn(error) {
    "could not read " <> path <> ": " <> file.error_to_string(error)
  })
}

/// The lines that are not in a code fence, with their numbers. A fence
/// line is dropped too.
fn numbered_lines_outside_fences(text: String) -> List(NumberedLine) {
  let #(_, kept_rev) =
    text
    |> string.split("\n")
    |> list.index_map(fn(line, index) { NumberedLine(index + 1, line) })
    |> list.fold(#(False, []), keep_line_outside_fence)
  list.reverse(kept_rev)
}

fn keep_line_outside_fence(
  state: #(Bool, List(NumberedLine)),
  line: NumberedLine,
) -> #(Bool, List(NumberedLine)) {
  let #(in_fence, kept_rev) = state
  case is_fence_line(line.text), in_fence {
    True, _ -> #(!in_fence, kept_rev)
    False, True -> #(True, kept_rev)
    False, False -> #(False, [line, ..kept_rev])
  }
}

fn is_fence_line(text: String) -> Bool {
  string.starts_with(string.trim_start(text), "```")
}

@external(erlang, "snippets_doc_blocks_ffi", "wildcard")
fn wildcard(pattern: String, root: String) -> List(String)
