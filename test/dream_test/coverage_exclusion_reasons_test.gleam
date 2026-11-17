//// Black-box tests of what `coverage.finish` reports as excluded, and of
//// `coverage.require_exclusion_reasons`, run in a child node.

import dream_test/coverage.{
  type CoverageConfig, type CoverageError, ExcludeWithoutReason,
  IgnoreMarkerWithoutReason,
}
import dream_test/coverage/report.{
  type CoverageReport, ExcludedFile, IgnoredRange,
}
import dream_test/coverage_child_support.{
  add_source, child_project, compile_source, measure, run_in_child,
}
import dream_test/file.{write}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, group, it}
import gleam/list
import gleam/option.{None, Some}
import gleam/string

fn project_config() -> CoverageConfig {
  coverage.new() |> coverage.no_lcov()
}

fn merge_config() -> CoverageConfig {
  project_config() |> coverage.merge_lcov("merge.info")
}

fn generated_pattern() -> String {
  "src/gen*.erl"
}

/// An Erlang module whose body is `body`, from line 5 on.
fn marked_module(body: List(String)) -> String {
  ["-module(marked).", "-export([run/1]).", "", "run(Number) ->", ..body]
  |> string.join("\n")
  |> string.append("\n")
}

/// Executable lines 5, 6, 7 and 8, and no markers.
fn plain_body() -> List(String) {
  [
    "    First = Number + 1,",
    "    Second = First + 1,",
    "    Third = Second + 1,",
    "    Third.",
  ]
}

/// Line 7 ignored by a marker without text, lines 8 to 10 by a block with
/// the text "debug only".
fn marked_body(line_marker: String) -> List(String) {
  [
    "    First = Number + 1,",
    "    " <> line_marker,
    "    Second = First + 1,",
    "    %% coverage:ignore-start debug only",
    "    Third = Second + 1,",
    "    %% coverage:ignore-end",
    "    Third.",
  ]
}

/// A Gleam file with an ignore marker on line 2 and code on lines 1 and 3.
fn outside_source(marker: String) -> String {
  "pub fn run() {\n  " <> marker <> "\n  helper()\n}\n"
}

fn outside_files(marker: String) -> List(#(String, String)) {
  [
    #("lib/outside.gleam", outside_source(marker)),
    #("merge.info", "SF:lib/outside.gleam\nDA:1,1\nDA:3,0\nend_of_record\n"),
  ]
}

fn generated_files() -> List(#(String, String)) {
  [#("src/generated.erl", "-module(generated).\n")]
}

/// In a child: create a project with src/marked.erl and the files in
/// `extra_files`, then measure with `config`.
fn measure_in_child(
  config: CoverageConfig,
  source: String,
  extra_files: List(#(String, String)),
) -> Result(Result(CoverageReport, CoverageError), String) {
  run_in_child(fn() {
    let _ = child_project("exclusion_reasons")
    add_source("marked.erl", source)
    compile_source("marked.erl", "debug_info")
    list.each(extra_files, write_extra_file)
    measure(config, fn() { Nil })
  })
}

fn write_extra_file(entry: #(String, String)) -> Nil {
  let assert Ok(Nil) = write(entry.0, entry.1)
  Nil
}

fn measured_report(
  config: CoverageConfig,
  source: String,
  extra_files: List(#(String, String)),
) -> Result(CoverageReport, String) {
  case measure_in_child(config, source, extra_files) {
    Ok(Ok(coverage_report)) -> Ok(coverage_report)
    Ok(Error(error)) -> Error(string_of(error))
    Error(message) -> Error(message)
  }
}

fn measure_error(
  config: CoverageConfig,
  source: String,
  extra_files: List(#(String, String)),
) -> Result(CoverageError, String) {
  case measure_in_child(config, source, extra_files) {
    Ok(Error(error)) -> Ok(error)
    Ok(Ok(_)) -> Error("expected coverage to fail")
    Error(message) -> Error(message)
  }
}

/// The ignored ranges of the file at `source_path` in a measured report.
fn ranges_of(
  config: CoverageConfig,
  source: String,
  extra_files: List(#(String, String)),
  source_path: String,
) -> Result(List(report.IgnoredRange), String) {
  case measured_report(config, source, extra_files) {
    Ok(coverage_report) -> Ok(file_ranges(coverage_report, source_path))
    Error(message) -> Error(message)
  }
}

fn file_ranges(
  coverage_report: CoverageReport,
  source_path: String,
) -> List(report.IgnoredRange) {
  case
    list.find(report.files(coverage_report), fn(file) {
      report.source_path(file) == source_path
    })
  {
    Ok(file) -> report.ignored_ranges(file)
    Error(Nil) -> []
  }
}

fn excluded_files_of(
  config: CoverageConfig,
) -> Result(List(report.ExcludedFile), String) {
  case measured_report(config, marked_module(plain_body()), generated_files()) {
    Ok(coverage_report) -> Ok(report.excluded_files(coverage_report))
    Error(message) -> Error(message)
  }
}

@external(erlang, "dream_test_coverage_test_ffi", "format")
fn string_of(value: a) -> String

pub fn tests() {
  describe("coverage exclusions in the report", [
    group("ignored ranges", [
      it("lists the ignored ranges of a measured file with their text", fn() {
        ranges_of(
          project_config(),
          marked_module(marked_body("%% coverage:ignore")),
          [],
          "src/marked.erl",
        )
        |> should
        |> be_equal(
          Ok([
            IgnoredRange(first_line: 7, last_line: 7, reason: None),
            IgnoredRange(
              first_line: 8,
              last_line: 10,
              reason: Some("debug only"),
            ),
          ]),
        )
        |> or_fail_with("expected line 7 without a reason and 8-10 with one")
      }),
      it("lists the ignored ranges of a file only merged LCOV covers", fn() {
        ranges_of(
          merge_config(),
          marked_module(plain_body()),
          outside_files("// coverage:ignore merged only"),
          "lib/outside.gleam",
        )
        |> should
        |> be_equal(
          Ok([
            IgnoredRange(
              first_line: 3,
              last_line: 3,
              reason: Some("merged only"),
            ),
          ]),
        )
        |> or_fail_with("expected line 3 of lib/outside.gleam with its reason")
      }),
    ]),
    group("excluded files", [
      it("lists an excluded file with its pattern and reason", fn() {
        project_config()
        |> coverage.exclude_with_reason(
          pattern: generated_pattern(),
          reason: " generated code ",
        )
        |> excluded_files_of()
        |> should
        |> be_equal(
          Ok([
            ExcludedFile(
              source_path: "src/generated.erl",
              pattern: generated_pattern(),
              reason: Some("generated code"),
            ),
          ]),
        )
        |> or_fail_with("expected src/generated.erl with the trimmed reason")
      }),
      it("keeps the first pattern that matches a file", fn() {
        project_config()
        |> coverage.exclude("src/generated.erl")
        |> coverage.exclude_with_reason(
          pattern: generated_pattern(),
          reason: "generated code",
        )
        |> excluded_files_of()
        |> should
        |> be_equal(
          Ok([
            ExcludedFile(
              source_path: "src/generated.erl",
              pattern: "src/generated.erl",
              reason: None,
            ),
          ]),
        )
        |> or_fail_with("expected the first pattern, without a reason")
      }),
    ]),
    group("require_exclusion_reasons", [
      it("returns ExcludeWithoutReason for a pattern from exclude", fn() {
        measure_error(
          project_config()
            |> coverage.exclude(generated_pattern())
            |> coverage.require_exclusion_reasons(),
          marked_module(plain_body()),
          generated_files(),
        )
        |> should
        |> be_equal(Ok(ExcludeWithoutReason(pattern: generated_pattern())))
        |> or_fail_with("expected ExcludeWithoutReason")
      }),
      it("returns ExcludeWithoutReason for a blank reason", fn() {
        measure_error(
          project_config()
            |> coverage.exclude_with_reason(
              pattern: generated_pattern(),
              reason: "  ",
            )
            |> coverage.require_exclusion_reasons(),
          marked_module(plain_body()),
          generated_files(),
        )
        |> should
        |> be_equal(Ok(ExcludeWithoutReason(pattern: generated_pattern())))
        |> or_fail_with("expected a blank reason to count as no reason")
      }),
      it("passes when every pattern and marker has a reason", fn() {
        ranges_of(
          project_config()
            |> coverage.exclude_with_reason(
              pattern: generated_pattern(),
              reason: "generated code",
            )
            |> coverage.require_exclusion_reasons(),
          marked_module(marked_body("%% coverage:ignore old callers")),
          generated_files(),
          "src/marked.erl",
        )
        |> should
        |> be_equal(
          Ok([
            IgnoredRange(
              first_line: 7,
              last_line: 7,
              reason: Some("old callers"),
            ),
            IgnoredRange(
              first_line: 8,
              last_line: 10,
              reason: Some("debug only"),
            ),
          ]),
        )
        |> or_fail_with("expected the run to pass with every reason given")
      }),
      it("returns IgnoreMarkerWithoutReason for a measured file", fn() {
        measure_error(
          project_config() |> coverage.require_exclusion_reasons(),
          marked_module(marked_body("%% coverage:ignore")),
          [],
        )
        |> should
        |> be_equal(
          Ok(IgnoreMarkerWithoutReason(
            source_path: "src/marked.erl",
            line_number: 6,
            marker: "coverage:ignore",
          )),
        )
        |> or_fail_with("expected the marker on line 6")
      }),
      it("returns IgnoreMarkerWithoutReason for a merged-only file", fn() {
        measure_error(
          merge_config() |> coverage.require_exclusion_reasons(),
          marked_module(plain_body()),
          outside_files("// coverage:ignore-function"),
        )
        |> should
        |> be_equal(
          Ok(IgnoreMarkerWithoutReason(
            source_path: "lib/outside.gleam",
            line_number: 2,
            marker: "coverage:ignore-function",
          )),
        )
        |> or_fail_with("expected the marker on line 2 of lib/outside.gleam")
      }),
    ]),
  ])
}
