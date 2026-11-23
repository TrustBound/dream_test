//// Checks that the release notes follow the release notes template.
////
//// The check reads `releases/release-<version>.md` for version 3.0.0 and
//// later. Older release notes are history, and they keep their own form.
////
//// The template:
////
//// - The first line is `# <Name> <version> Release Notes`, with the
////   version of the file name.
//// - A `**Release Date:**` line comes before the first `##` section.
//// - Each `##` section is one of the sections of the template, in the
////   order of the template, and only one time.
//// - The required sections are Key Highlights, What's New, Testing,
////   Documentation and Community, and exactly one of Upgrading and
////   Installing.
//// - `## Upgrading` has a `### Migration Guide`.
//// - A heading in a code fence is not a heading.

import dream_test/file
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/list
import gleam/result
import gleam/string

/// The root of the repository, from the snippets project.
const root = "../.."

/// The folder of the release notes, from the root.
const release_notes_folder = "releases"

/// The first version whose release notes must follow the template.
const first_checked_version = [3, 0, 0]

/// The `##` sections of the template, in order.
const template_sections = [
  "Key Highlights", "What's New", "Deprecated", "Removed", "Bug Fixes",
  "Known Limits", "Testing", "Upgrading", "Installing", "Acknowledgements",
  "Documentation", "Community",
]

/// The sections that every release notes file must have.
const required_sections = [
  "Key Highlights", "What's New", "Testing", "Documentation", "Community",
]

pub fn tests() {
  describe("Release notes template", [
    it(
      "every release notes file from 3.0.0 on follows the template",
      check_release_notes_files,
    ),
    it("a file in the form of the template has no problem", fn() {
      // Arrange
      let text = template_example()

      // Act
      let problems = release_notes_problems("1.2.0", text)

      // Assert
      problems
      |> should
      |> be_equal([])
      |> or_fail_with("the template example must have no problem")
    }),
    it("a title with another version is a problem", fn() {
      // Arrange
      let text =
        string.replace(
          template_example(),
          "# My App 1.2.0 Release Notes",
          "# My App 1.1.0 Release Notes",
        )

      // Act
      let problems = release_notes_problems("1.2.0", text)

      // Assert
      problems
      |> should
      |> be_equal([
        "the first line is not \"# <Name> 1.2.0 Release Notes\"",
      ])
      |> or_fail_with("the title must name the version of the file")
    }),
    it("a release date after the first section is a problem", fn() {
      // Arrange
      let text =
        template_example()
        |> string.replace("**Release Date:** 2026-11-20\n\n", "")
        |> string.replace(
          "## Testing\n",
          "## Testing\n\n**Release Date:** 2026-11-20\n",
        )

      // Act
      let problems = release_notes_problems("1.2.0", text)

      // Assert
      problems
      |> should
      |> be_equal([
        "no \"**Release Date:**\" line comes before the first ## section",
      ])
      |> or_fail_with("the release date must come before the first section")
    }),
    it("a section that is not in the template is a problem", fn() {
      // Arrange
      let text =
        string.replace(template_example(), "## Testing\n", "## Tests\n")

      // Act
      let problems = release_notes_problems("1.2.0", text)

      // Assert
      problems
      |> should
      |> be_equal([
        "\"## Tests\" is not a section of the template",
        "the section \"## Testing\" is missing",
      ])
      |> or_fail_with("only the sections of the template are allowed")
    }),
    it("a section out of the template order is a problem", fn() {
      // Arrange
      let text =
        string.replace(
          template_example(),
          "## Key Highlights\n\n- Faster runs.\n\n## What's New\n\n- A new runner.\n",
          "## What's New\n\n- A new runner.\n\n## Key Highlights\n\n- Faster runs.\n",
        )

      // Act
      let problems = release_notes_problems("1.2.0", text)

      // Assert
      problems
      |> should
      |> be_equal([
        "\"## Key Highlights\" comes after \"## What's New\", but the template puts it before",
      ])
      |> or_fail_with("the sections must be in the order of the template")
    }),
    it("a heading in a code fence is not a section", fn() {
      // Arrange
      let text =
        string.replace(
          template_example(),
          "- A new runner.\n",
          "- A new runner.\n\n```markdown\n## Tests\n```\n",
        )

      // Act
      let problems = release_notes_problems("1.2.0", text)

      // Assert
      problems
      |> should
      |> be_equal([])
      |> or_fail_with("a heading in a code fence must not count")
    }),
    it("an Upgrading section with no Migration Guide is a problem", fn() {
      // Arrange
      let text = string.replace(template_example(), "### Migration Guide\n", "")

      // Act
      let problems = release_notes_problems("1.2.0", text)

      // Assert
      problems
      |> should
      |> be_equal(["\"## Upgrading\" has no \"### Migration Guide\""])
      |> or_fail_with("an Upgrading section must have a Migration Guide")
    }),
    it("both Upgrading and Installing is a problem", fn() {
      // Arrange
      let text =
        string.replace(
          template_example(),
          "## Documentation\n",
          "## Installing\n\n- Add the package.\n\n## Documentation\n",
        )

      // Act
      let problems = release_notes_problems("1.2.0", text)

      // Assert
      problems
      |> should
      |> be_equal([
        "the file has both \"## Upgrading\" and \"## Installing\", but the template allows exactly one",
      ])
      |> or_fail_with("exactly one of Upgrading and Installing is allowed")
    }),
  ])
}

/// A release notes file of version 1.2.0 in the form of the template.
fn template_example() -> String {
  "# My App 1.2.0 Release Notes

**Release Date:** 2026-11-20

## Key Highlights

- Faster runs.

## What's New

- A new runner.

## Testing

- 10 tests pass.

## Upgrading

```toml
my_app = \">= 1.2.0 and < 2.0.0\"
```

### Migration Guide

- Nothing to change.

## Documentation

- [my_app](https://hexdocs.pm/my_app)

## Community

- [Issues](https://github.com/me/my_app/issues)
"
}

fn check_release_notes_files() -> Result(AssertionResult, String) {
  use paths <- result.try(checked_release_notes_paths())
  use problems <- result.try(list.try_map(paths, release_notes_file_problems))
  problems
  |> list.flatten
  |> should
  |> be_equal([])
  |> or_fail_with(
    "make each release notes file from 3.0.0 on follow the release notes template",
  )
}

/// The release notes files of version 3.0.0 and later, from the root. An
/// error when there is none, so a run from the wrong folder does not pass.
fn checked_release_notes_paths() -> Result(List(String), String) {
  let paths =
    wildcard(release_notes_folder <> "/release-*.md", root)
    |> list.filter(is_checked_release_notes_path)
  case paths {
    [] ->
      Error(
        "found no release notes file of version 3.0.0 or later under "
        <> root
        <> "/"
        <> release_notes_folder
        <> ": run the tests from examples/snippets",
      )
    _ -> Ok(paths)
  }
}

fn is_checked_release_notes_path(path: String) -> Bool {
  path
  |> release_notes_version
  |> version_parts
  |> is_at_least_first_checked_version
}

/// `releases/release-3.0.0.md` gives `3.0.0`.
fn release_notes_version(path: String) -> String {
  path
  |> string.replace(release_notes_folder <> "/release-", "")
  |> string.replace(".md", "")
}

/// `3.0.0` gives `[3, 0, 0]`. A part that is not a number gives -1.
fn version_parts(version: String) -> List(Int) {
  version
  |> string.split(".")
  |> list.map(fn(part) { int.parse(part) |> result.unwrap(-1) })
}

fn is_at_least_first_checked_version(parts: List(Int)) -> Bool {
  compare_version_parts(parts, first_checked_version) != Lt
}

type Order {
  Lt
  Eq
  Gt
}

fn compare_version_parts(left: List(Int), right: List(Int)) -> Order {
  case left, right {
    [], [] -> Eq
    [], _ -> Lt
    _, [] -> Gt
    [first_left, ..rest_left], [first_right, ..rest_right]
      if first_left == first_right
    -> compare_version_parts(rest_left, rest_right)
    [first_left, ..], [first_right, ..] if first_left < first_right -> Lt
    _, _ -> Gt
  }
}

/// The problems of the release notes file at `path`, each with the path at
/// the start.
fn release_notes_file_problems(path: String) -> Result(List(String), String) {
  use text <- result.try(read_file(path))
  release_notes_problems(release_notes_version(path), text)
  |> list.map(fn(problem) { path <> ": " <> problem })
  |> Ok
}

fn read_file(path: String) -> Result(String, String) {
  file.read(root <> "/" <> path)
  |> result.map_error(fn(error) {
    "could not read " <> path <> ": " <> file.error_to_string(error)
  })
}

/// The problems of a release notes text of version `version`, or `[]`.
fn release_notes_problems(version: String, text: String) -> List(String) {
  let lines = lines_outside_fences(text)
  let sections = section_names(lines)
  list.flatten([
    title_problems(version, lines),
    release_date_problems(lines),
    unknown_section_problems(sections),
    order_problems(sections),
    missing_section_problems(sections),
    upgrade_choice_problems(sections),
    migration_guide_problems(lines),
  ])
}

/// The lines that are not in a code fence. A fence line is dropped too.
fn lines_outside_fences(text: String) -> List(String) {
  let #(_, kept_rev) =
    text
    |> string.split("\n")
    |> list.fold(#(False, []), keep_line_outside_fence)
  list.reverse(kept_rev)
}

fn keep_line_outside_fence(
  state: #(Bool, List(String)),
  line: String,
) -> #(Bool, List(String)) {
  let #(in_fence, kept_rev) = state
  case is_fence_line(line), in_fence {
    True, _ -> #(!in_fence, kept_rev)
    False, True -> #(True, kept_rev)
    False, False -> #(False, [line, ..kept_rev])
  }
}

fn is_fence_line(line: String) -> Bool {
  string.starts_with(string.trim_start(line), "```")
}

fn title_problems(version: String, lines: List(String)) -> List(String) {
  let suffix = " " <> version <> " Release Notes"
  let title = list.first(lines) |> result.unwrap("")
  case is_title(title, suffix) {
    True -> []
    False -> [
      "the first line is not \"# <Name> " <> version <> " Release Notes\"",
    ]
  }
}

fn is_title(line: String, suffix: String) -> Bool {
  string.starts_with(line, "# ")
  && string.ends_with(line, suffix)
  && string.length(line) > string.length("# ") + string.length(suffix)
}

fn release_date_problems(lines: List(String)) -> List(String) {
  let has_date =
    lines
    |> list.take_while(fn(line) { !is_section_line(line) })
    |> list.any(string.starts_with(_, "**Release Date:**"))
  case has_date {
    True -> []
    False -> [
      "no \"**Release Date:**\" line comes before the first ## section",
    ]
  }
}

fn is_section_line(line: String) -> Bool {
  string.starts_with(line, "## ")
}

/// The names of the `##` sections, in order.
fn section_names(lines: List(String)) -> List(String) {
  lines
  |> list.filter(is_section_line)
  |> list.map(fn(line) { string.trim(string.drop_start(line, 3)) })
}

fn unknown_section_problems(sections: List(String)) -> List(String) {
  sections
  |> list.filter(fn(name) { !list.contains(template_sections, name) })
  |> list.map(fn(name) {
    "\"## " <> name <> "\" is not a section of the template"
  })
}

/// A problem for each known section that comes at or before a section
/// before it in the file, so a section that comes two times is a problem
/// too.
fn order_problems(sections: List(String)) -> List(String) {
  let known = list.filter(sections, list.contains(template_sections, _))
  known
  |> list.window_by_2
  |> list.filter(fn(pair) { template_index(pair.1) <= template_index(pair.0) })
  |> list.map(fn(pair) {
    "\"## "
    <> pair.1
    <> "\" comes after \"## "
    <> pair.0
    <> "\", but the template puts it before"
  })
}

fn template_index(name: String) -> Int {
  template_sections
  |> list.index_map(fn(section, index) { #(section, index) })
  |> list.key_find(name)
  |> result.unwrap(-1)
}

fn missing_section_problems(sections: List(String)) -> List(String) {
  required_sections
  |> list.filter(fn(name) { !list.contains(sections, name) })
  |> list.map(fn(name) { "the section \"## " <> name <> "\" is missing" })
}

fn upgrade_choice_problems(sections: List(String)) -> List(String) {
  case
    list.contains(sections, "Upgrading"),
    list.contains(sections, "Installing")
  {
    True, False | False, True -> []
    True, True -> [
      "the file has both \"## Upgrading\" and \"## Installing\", but the template allows exactly one",
    ]
    False, False -> [
      "the file has neither \"## Upgrading\" nor \"## Installing\", but the template needs one",
    ]
  }
}

fn migration_guide_problems(lines: List(String)) -> List(String) {
  let upgrading =
    lines
    |> list.drop_while(fn(line) { line != "## Upgrading" })
    |> list.drop(1)
    |> list.take_while(fn(line) { !is_section_line(line) })
  case
    lines_have_upgrading(lines),
    list.contains(upgrading, "### Migration Guide")
  {
    True, False -> ["\"## Upgrading\" has no \"### Migration Guide\""]
    _, _ -> []
  }
}

fn lines_have_upgrading(lines: List(String)) -> Bool {
  list.contains(lines, "## Upgrading")
}

@external(erlang, "snippets_doc_blocks_ffi", "wildcard")
fn wildcard(pattern: String, root: String) -> List(String)
