//// Black-box tests of what `coverage.finish` reports as excluded, and of
//// `coverage.require_exclusion_reasons`. Each test gets its own project
//// with a module named `reasons_<n>` (see
//// `coverage_project_support.new_marked_project`).

import dream_test/coverage.{
  type CoverageConfig, type CoverageError, ExcludeWithoutReason,
  IgnoreMarkerWithoutReason,
}
import dream_test/coverage/report.{type CoverageReport}
import dream_test/coverage_project_support.{
  type MarkedProject, add_marked_module, add_project_file, from_project, measure,
  new_marked_project, to_project,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, group, it}
import gleam/list
import gleam/option.{None, Some}
import gleam/string

/// The settings for a project: its source directory, no LCOV file.
fn project_config(project: MarkedProject) -> CoverageConfig {
  coverage.new()
  |> coverage.source_directory(project.source_directory)
  |> coverage.no_lcov()
}

/// The project settings, merging the project's merge.info.
fn merge_config(project: MarkedProject) -> CoverageConfig {
  project_config(project)
  |> coverage.merge_lcov(project.root <> "/merge.info")
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

/// Create a project with src/marked.erl and the files in `extra_files`,
/// then measure with the settings that `settings` gives. Paths in the result
/// are short paths.
fn measure_project(
  settings: fn(MarkedProject) -> CoverageConfig,
  source: String,
  extra_files: List(#(String, String)),
) -> Result(CoverageReport, CoverageError) {
  let project = new_marked_project("reasons")
  add_marked_module(project, source)
  list.each(extra_files, add_project_file(project, _))
  case measure(settings(project), fn() { Nil }) {
    Ok(coverage_report) -> Ok(report_from_project(project, coverage_report))
    Error(error) -> Error(error_from_project(project, error))
  }
}

/// The report with short paths in its files and excluded files.
fn report_from_project(
  project: MarkedProject,
  coverage_report: CoverageReport,
) -> CoverageReport {
  report.new(
    list.map(report.files(coverage_report), file_from_project(project, _)),
  )
  |> report.add_excluded_files(
    list.map(report.excluded_files(coverage_report), excluded_from_project(
      project,
      _,
    )),
  )
}

fn file_from_project(
  project: MarkedProject,
  file: report.FileCoverage,
) -> report.FileCoverage {
  report.file(
    from_project(project, report.source_path(file)),
    report.lines(file),
  )
  |> report.add_ignored_ranges(report.ignored_ranges(file))
}

fn excluded_from_project(
  project: MarkedProject,
  file: report.ExcludedFile,
) -> report.ExcludedFile {
  report.excluded_file(
    source_path: from_project(project, report.excluded_source_path(file)),
    pattern: from_project(project, report.excluded_pattern(file)),
    reason: report.excluded_reason(file),
  )
}

fn error_from_project(
  project: MarkedProject,
  error: CoverageError,
) -> CoverageError {
  case error {
    ExcludeWithoutReason(pattern) ->
      ExcludeWithoutReason(from_project(project, pattern))
    IgnoreMarkerWithoutReason(source_path, line_number, marker) ->
      IgnoreMarkerWithoutReason(
        from_project(project, source_path),
        line_number,
        marker,
      )
    other -> other
  }
}

fn measured_report(
  settings: fn(MarkedProject) -> CoverageConfig,
  source: String,
  extra_files: List(#(String, String)),
) -> Result(CoverageReport, String) {
  case measure_project(settings, source, extra_files) {
    Ok(coverage_report) -> Ok(coverage_report)
    Error(error) -> Error(string_of(error))
  }
}

fn measure_error(
  settings: fn(MarkedProject) -> CoverageConfig,
  source: String,
  extra_files: List(#(String, String)),
) -> Result(CoverageError, String) {
  case measure_project(settings, source, extra_files) {
    Error(error) -> Ok(error)
    Ok(_) -> Error("expected coverage to fail")
  }
}

/// The ignored ranges of the file at `source_path` in a measured report.
fn ranges_of(
  settings: fn(MarkedProject) -> CoverageConfig,
  source: String,
  extra_files: List(#(String, String)),
  source_path: String,
) -> Result(List(report.IgnoredRange), String) {
  case measured_report(settings, source, extra_files) {
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
  settings: fn(MarkedProject) -> CoverageConfig,
) -> Result(List(report.ExcludedFile), String) {
  case
    measured_report(settings, marked_module(plain_body()), generated_files())
  {
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
          project_config,
          marked_module(marked_body("%% coverage:ignore")),
          [],
          "src/marked.erl",
        )
        |> should
        |> be_equal(
          Ok([
            report.ignored_range(first_line: 7, last_line: 7, reason: None),
            report.ignored_range(
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
          merge_config,
          marked_module(plain_body()),
          outside_files("// coverage:ignore merged only"),
          "lib/outside.gleam",
        )
        |> should
        |> be_equal(
          Ok([
            report.ignored_range(
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
        excluded_files_of(fn(project) {
          project_config(project)
          |> coverage.exclude_with_reason(
            pattern: to_project(project, generated_pattern()),
            reason: " generated code ",
          )
        })
        |> should
        |> be_equal(
          Ok([
            report.excluded_file(
              source_path: "src/generated.erl",
              pattern: generated_pattern(),
              reason: Some("generated code"),
            ),
          ]),
        )
        |> or_fail_with("expected src/generated.erl with the trimmed reason")
      }),
      it("keeps the first pattern that matches a file", fn() {
        excluded_files_of(fn(project) {
          project_config(project)
          |> coverage.exclude(to_project(project, "src/generated.erl"))
          |> coverage.exclude_with_reason(
            pattern: to_project(project, generated_pattern()),
            reason: "generated code",
          )
        })
        |> should
        |> be_equal(
          Ok([
            report.excluded_file(
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
          fn(project) {
            project_config(project)
            |> coverage.exclude(to_project(project, generated_pattern()))
            |> coverage.require_exclusion_reasons()
          },
          marked_module(plain_body()),
          generated_files(),
        )
        |> should
        |> be_equal(Ok(ExcludeWithoutReason(pattern: generated_pattern())))
        |> or_fail_with("expected ExcludeWithoutReason")
      }),
      it("returns ExcludeWithoutReason for a blank reason", fn() {
        measure_error(
          fn(project) {
            project_config(project)
            |> coverage.exclude_with_reason(
              pattern: to_project(project, generated_pattern()),
              reason: "  ",
            )
            |> coverage.require_exclusion_reasons()
          },
          marked_module(plain_body()),
          generated_files(),
        )
        |> should
        |> be_equal(Ok(ExcludeWithoutReason(pattern: generated_pattern())))
        |> or_fail_with("expected a blank reason to count as no reason")
      }),
      it("passes when every pattern and marker has a reason", fn() {
        ranges_of(
          fn(project) {
            project_config(project)
            |> coverage.exclude_with_reason(
              pattern: to_project(project, generated_pattern()),
              reason: "generated code",
            )
            |> coverage.require_exclusion_reasons()
          },
          marked_module(marked_body("%% coverage:ignore old callers")),
          generated_files(),
          "src/marked.erl",
        )
        |> should
        |> be_equal(
          Ok([
            report.ignored_range(
              first_line: 7,
              last_line: 7,
              reason: Some("old callers"),
            ),
            report.ignored_range(
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
          fn(project) {
            project_config(project) |> coverage.require_exclusion_reasons()
          },
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
          fn(project) {
            merge_config(project) |> coverage.require_exclusion_reasons()
          },
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
