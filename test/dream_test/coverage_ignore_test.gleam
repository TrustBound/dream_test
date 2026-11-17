//// Black-box tests of the coverage:ignore markers, run in a child node.

import coverage_ignore_fixtures/ignored
import dream_test/coverage.{
  type CoverageConfig, type CoverageError, IgnoreEndWithoutStart,
  IgnoreFunctionWithoutFunction, IgnoreStartWithoutEnd, NestedIgnoreStart,
  SourceReadFailed,
}
import dream_test/coverage/report.{type CoverageReport, type LineCoverage}
import dream_test/coverage_child_support.{
  add_source, child_project, compile_source, make_unreadable, measure,
  run_in_child,
}
import dream_test/file.{PermissionDenied, read, write}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, group, it}
import gleam/int
import gleam/list
import gleam/result
import gleam/string

fn project_config() -> CoverageConfig {
  coverage.new() |> coverage.no_lcov()
}

fn merge_config() -> CoverageConfig {
  project_config() |> coverage.merge_lcov("merge.info")
}

fn marked_path() -> String {
  "src/marked.erl"
}

fn outside_path() -> String {
  "lib/outside.gleam"
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

/// Line 7 is ignored. Executable lines 5, 8 and 9 are left.
fn line_marker_body() -> List(String) {
  [
    "    First = Number + 1,",
    "    %% coverage:ignore",
    "    Second = First + 1,",
    "    Third = Second + 1,",
    "    Third.",
  ]
}

/// A Gleam file with an ignore marker on line 2 and code on lines 1 and 3.
fn outside_source(marker: String) -> String {
  "pub fn run() {\n  " <> marker <> "\n  helper()\n}\n"
}

/// In a child: create a project with src/marked.erl, write the files in
/// `extra_files`, measure with `config`, and return the report.
fn measure_marked(
  config: CoverageConfig,
  source: String,
  extra_files: List(#(String, String)),
) -> Result(CoverageReport, String) {
  let _ = child_project("ignore")
  add_source("marked.erl", source)
  compile_source("marked.erl", "debug_info")
  list.each(extra_files, write_extra_file)
  case measure(config, fn() { Nil }) {
    Ok(coverage_report) -> Ok(coverage_report)
    Error(error) -> Error(string_of(error))
  }
}

fn write_extra_file(entry: #(String, String)) -> Nil {
  let assert Ok(Nil) = write(entry.0, entry.1)
  Nil
}

/// The lines of one file of a report measured in a child.
fn file_lines(
  config: CoverageConfig,
  source: String,
  extra_files: List(#(String, String)),
  source_path: String,
) -> Result(List(LineCoverage), String) {
  case
    run_in_child(fn() {
      case measure_marked(config, source, extra_files) {
        Ok(coverage_report) -> Ok(lines_of(coverage_report, source_path))
        Error(message) -> Error(message)
      }
    })
  {
    Ok(result) -> result
    Error(message) -> Error(message)
  }
}

/// The line numbers of src/marked.erl, measured in a child.
fn marked_line_numbers(source: String) -> Result(List(Int), String) {
  case file_lines(project_config(), source, [], marked_path()) {
    Ok(lines) -> Ok(list.map(lines, line_number))
    Error(message) -> Error(message)
  }
}

fn lines_of(
  coverage_report: CoverageReport,
  source_path: String,
) -> List(LineCoverage) {
  case
    list.find(report.files(coverage_report), fn(file) {
      report.source_path(file) == source_path
    })
  {
    Ok(file) -> report.lines(file)
    Error(Nil) -> []
  }
}

fn line_number(line: LineCoverage) -> Int {
  line.line
}

/// In a child: create a project with src/marked.erl and return the error
/// that measuring it gives.
fn measure_error(
  config: CoverageConfig,
  source: String,
  extra_files: List(#(String, String)),
) -> Result(CoverageError, String) {
  case
    run_in_child(fn() {
      let _ = child_project("ignore_error")
      add_source("marked.erl", source)
      compile_source("marked.erl", "debug_info")
      list.each(extra_files, write_extra_file)
      measure(config, fn() { Nil })
    })
  {
    Ok(Error(error)) -> Ok(error)
    Ok(Ok(_)) -> Error("expected coverage to fail")
    Error(message) -> Error(message)
  }
}

fn outside_erlang_path() -> String {
  "lib/outside.erl"
}

/// A merged LCOV record for `path` with a count of 1 on lines 1 to
/// `line_count`.
fn lcov_for_every_line(path: String, line_count: Int) -> String {
  "SF:"
  <> path
  <> "\n"
  <> string.concat(list.map(numbers_to(line_count), da_line))
  <> "end_of_record\n"
}

fn numbers_to(last: Int) -> List(Int) {
  case last {
    0 -> []
    _ -> list.append(numbers_to(last - 1), [last])
  }
}

fn da_line(line: Int) -> String {
  "DA:" <> int.to_string(line) <> ",1\n"
}

/// The lines of the file at `path` with `source_lines` that are left after
/// its ignore markers, when a merged LCOV file counts every line of it.
fn outside_lines_left(
  path: String,
  source_lines: List(String),
) -> Result(List(Int), String) {
  let extra_files = [
    #(path, string.join(source_lines, "\n")),
    #("merge.info", lcov_for_every_line(path, list.length(source_lines))),
  ]
  case
    file_lines(merge_config(), marked_module(plain_body()), extra_files, path)
  {
    Ok(lines) -> Ok(list.map(lines, line_number))
    Error(message) -> Error(message)
  }
}

/// The error that measuring gives when a merged LCOV file covers the file at
/// `path` with `source_lines`.
fn outside_error(
  path: String,
  source_lines: List(String),
) -> Result(CoverageError, String) {
  measure_error(merge_config(), marked_module(plain_body()), [
    #(path, string.join(source_lines, "\n")),
    #("merge.info", lcov_for_every_line(path, 1)),
  ])
}

@external(erlang, "dream_test_coverage_test_ffi", "format")
fn string_of(value: a) -> String

pub fn tests() {
  describe("coverage:ignore markers", [
    group("ignoring", [
      it("measures every executable line when there is no marker", fn() {
        marked_module(plain_body())
        |> marked_line_numbers()
        |> should
        |> be_equal(Ok([5, 6, 7, 8]))
        |> or_fail_with("expected lines 5 to 8")
      }),
      it("leaves out the next code line after a %% coverage:ignore", fn() {
        marked_module(line_marker_body())
        |> marked_line_numbers()
        |> should
        |> be_equal(Ok([5, 8, 9]))
        |> or_fail_with("expected line 7 to be ignored")
      }),
      it(
        "skips blank and comment lines after a % coverage:ignore with text",
        fn() {
          marked_module([
            "    First = Number + 1,",
            "    % coverage:ignore\tonly for old callers",
            "",
            "    % a comment that is not a marker",
            "    Second = First + 1,",
            "    Third = Second + 1,",
            "    Third.",
          ])
          |> marked_line_numbers()
          |> should
          |> be_equal(Ok([5, 10, 11]))
          |> or_fail_with("expected line 9 to be ignored")
        },
      ),
      it("leaves out every line from ignore-start to ignore-end", fn() {
        marked_module([
          "    First = Number + 1,",
          "    %% coverage:ignore-start debug only",
          "    Second = First + 1,",
          "    %% coverage:ignore",
          "    Third = Second + 1,",
          "    %% coverage:ignore-end",
          "    Third.",
        ])
        |> marked_line_numbers()
        |> should
        |> be_equal(Ok([5, 11]))
        |> or_fail_with("expected lines 7 and 9 to be ignored")
      }),
      it("reads // markers in a measured Gleam file", fn() {
        case
          run_in_child(fn() {
            measure(
              project_config()
                |> coverage.source_directory("test/coverage_ignore_fixtures"),
              fn() { ignored.describe(0) },
            )
          })
        {
          Ok(Ok(coverage_report)) ->
            Ok(list.map(
              lines_of(
                coverage_report,
                "test/coverage_ignore_fixtures/ignored.gleam",
              ),
              line_number,
            ))
          Ok(Error(error)) -> Error(string_of(error))
          Error(message) -> Error(message)
        }
        |> should
        |> be_equal(Ok([6, 7, 10]))
        |> or_fail_with("expected lines 9 and 16 to be ignored")
      }),
    ]),
    group("ignoring functions", [
      it("ignores every clause of an Erlang function and its -spec", fn() {
        [
          "-module(marked).",
          "-export([run/1, skipped/1, after_skipped/1]).",
          "",
          "run(Number) ->",
          "    Number + 1.",
          "",
          "%% coverage:ignore-function only old callers use it",
          "-spec skipped(integer()) -> integer().",
          "skipped(0) ->",
          "    0;",
          "skipped(Number) ->",
          "    Number - 1.",
          "",
          "after_skipped(Number) ->",
          "    Number * 2.",
          "",
        ]
        |> string.join("\n")
        |> marked_line_numbers()
        |> should
        |> be_equal(Ok([5, 15]))
        |> or_fail_with("expected lines 7 to 12 to be ignored")
      }),
      it("ignores a Gleam function with a doc comment and an attribute", fn() {
        case
          run_in_child(fn() {
            measure(
              project_config()
                |> coverage.source_directory("test/coverage_ignore_fixtures"),
              fn() { Nil },
            )
          })
        {
          Ok(Ok(coverage_report)) ->
            Ok(list.map(
              lines_of(
                coverage_report,
                "test/coverage_ignore_fixtures/ignored_function.gleam",
              ),
              line_number,
            ))
          Ok(Error(error)) -> Error(string_of(error))
          Error(message) -> Error(message)
        }
        |> should
        |> be_equal(Ok([16]))
        |> or_fail_with("expected lines 5 to 13 to be ignored")
      }),
      it("skips braces in Gleam strings and comments and nested braces", fn() {
        outside_lines_left(outside_path(), [
          "// coverage:ignore-function braces in strings and comments",
          "/// Doc comment.",
          "@internal",
          "pub fn tricky(value: String) -> fn(Int) -> #(Int, option.Option(String)) {",
          "  // a } in a comment",
          "  let text = \"a } \\\" {",
          "b\"",
          "\tfn(number) { #(number, option.Some(text <> value)) }",
          "}",
          "",
          "pub fn after_tricky() {",
          "  1",
          "}",
        ])
        |> should
        |> be_equal(Ok([10, 11, 12, 13]))
        |> or_fail_with("expected lines 1 to 9 to be ignored")
      }),
      it("ends an external Gleam function before the next declaration", fn() {
        outside_lines_left(outside_path(), [
          "// coverage:ignore-function",
          "@external(erlang, \"outside_ffi\", \"now\")",
          "fn now() -> Int",
          "",
          "pub fn run_now() {",
          "  now()",
          "}",
        ])
        |> should
        |> be_equal(Ok([4, 5, 6, 7]))
        |> or_fail_with("expected lines 1 to 3 to be ignored")
      }),
      it("ends an external Gleam function before the next attribute", fn() {
        outside_lines_left(outside_path(), [
          "// coverage:ignore-function",
          "@external(erlang, \"outside_ffi\", \"now\")",
          "pub fn now() -> Int",
          "",
          "@external(erlang, \"outside_ffi\", \"later\")",
          "pub fn later() -> Int",
        ])
        |> should
        |> be_equal(Ok([4, 5, 6]))
        |> or_fail_with("expected lines 1 to 3 to be ignored")
      }),
      it("skips Erlang strings, atoms, characters and inner dots", fn() {
        outside_lines_left(outside_erlang_path(), [
          "-module(outside).",
          "%% coverage:ignore-function",
          "-spec 'odd name'(term()) -> term().",
          "'odd name'($.) ->",
          "    {\"a. b\", 'x. y'};",
          "'odd name'($\\.) ->",
          "    next@fun(1.5) + R#r.f;",
          "'odd name'(_) -> $",
          ". % the dot on this line ends the function",
          "next@fun(Number) -> Number.",
        ])
        |> should
        |> be_equal(Ok([1, 10]))
        |> or_fail_with("expected lines 2 to 9 to be ignored")
      }),
    ]),
    group("merged LCOV and output", [
      it("drops merged counts on an ignored line", fn() {
        file_lines(
          merge_config(),
          marked_module(line_marker_body()),
          [
            #(
              "merge.info",
              "SF:src/marked.erl\nDA:5,2\nDA:7,4\nend_of_record\n",
            ),
          ],
          marked_path(),
        )
        |> should
        |> be_equal(
          Ok([
            report.LineCoverage(line: 5, calls: 2),
            report.LineCoverage(line: 8, calls: 0),
            report.LineCoverage(line: 9, calls: 0),
          ]),
        )
        |> or_fail_with("expected the count on line 7 to be dropped")
      }),
      it("reads markers in a file that only merged LCOV covers", fn() {
        file_lines(
          merge_config(),
          marked_module(plain_body()),
          [
            #(outside_path(), outside_source("// coverage:ignore")),
            #(
              "merge.info",
              "SF:lib/outside.gleam\nDA:1,1\nDA:3,0\nend_of_record\n",
            ),
          ],
          outside_path(),
        )
        |> should
        |> be_equal(Ok([report.LineCoverage(line: 1, calls: 1)]))
        |> or_fail_with("expected line 3 of lib/outside.gleam to be ignored")
      }),
      it("leaves ignored lines out of the LCOV file", fn() {
        run_in_child(fn() {
          let config =
            coverage.new() |> coverage.lcov_path("build/ignored.info")
          case measure_marked(config, marked_module(line_marker_body()), []) {
            Ok(_) -> read("build/ignored.info") |> result.map_error(string_of)
            Error(message) -> Error(message)
          }
        })
        |> should
        |> be_equal(
          Ok(Ok(
            "TN:\nSF:src/marked.erl\nDA:5,0\nDA:8,0\nDA:9,0\nLF:3\nLH:0\nend_of_record\n",
          )),
        )
        |> or_fail_with("expected no DA line for line 7")
      }),
      it("leaves ignored lines out of the minimum", fn() {
        let config = merge_config() |> coverage.minimum_percent(100.0)
        run_in_child(fn() {
          case
            measure_marked(config, marked_module(line_marker_body()), [
              #(
                "merge.info",
                "SF:src/marked.erl\nDA:5,1\nDA:7,0\nDA:8,1\nDA:9,1\nend_of_record\n",
              ),
            ])
          {
            Ok(coverage_report) ->
              Ok(coverage.check_minimum(config, coverage_report))
            Error(message) -> Error(message)
          }
        })
        |> should
        |> be_equal(Ok(Ok(Ok(Nil))))
        |> or_fail_with("expected 100% with line 7 ignored")
      }),
    ]),
    group("errors", [
      it("returns IgnoreStartWithoutEnd for a block with no end", fn() {
        marked_module([
          "    First = Number + 1,",
          "    %% coverage:ignore-start",
          "    First.",
        ])
        |> measure_error(project_config(), _, [])
        |> should
        |> be_equal(Ok(IgnoreStartWithoutEnd("src/marked.erl", 6)))
        |> or_fail_with("expected IgnoreStartWithoutEnd at line 6")
      }),
      it("returns IgnoreEndWithoutStart for an end with no block", fn() {
        marked_module([
          "    First = Number + 1,",
          "    %% coverage:ignore-end",
          "    First.",
        ])
        |> measure_error(project_config(), _, [])
        |> should
        |> be_equal(Ok(IgnoreEndWithoutStart("src/marked.erl", 6)))
        |> or_fail_with("expected IgnoreEndWithoutStart at line 6")
      }),
      it("returns NestedIgnoreStart for a start inside a block", fn() {
        marked_module([
          "    First = Number + 1,",
          "    %% coverage:ignore-start",
          "    Second = First + 1,",
          "    %% coverage:ignore-start",
          "    Second.",
          "    %% coverage:ignore-end",
        ])
        |> measure_error(project_config(), _, [])
        |> should
        |> be_equal(Ok(NestedIgnoreStart("src/marked.erl", 8, 6)))
        |> or_fail_with("expected NestedIgnoreStart at line 8")
      }),
      it(
        "returns a marker error from a file that only merged LCOV covers",
        fn() {
          measure_error(merge_config(), marked_module(plain_body()), [
            #(outside_path(), outside_source("// coverage:ignore-end")),
            #("merge.info", "SF:lib/outside.gleam\nDA:1,1\nend_of_record\n"),
          ])
          |> should
          |> be_equal(Ok(IgnoreEndWithoutStart("lib/outside.gleam", 2)))
          |> or_fail_with("expected IgnoreEndWithoutStart in lib/outside.gleam")
        },
      ),
      it("returns IgnoreFunctionWithoutFunction above a Gleam constant", fn() {
        outside_error(outside_path(), [
          "pub fn run() {",
          "  1",
          "}",
          "// coverage:ignore-function",
          "pub const limit = 10",
        ])
        |> should
        |> be_equal(Ok(IgnoreFunctionWithoutFunction(outside_path(), 4)))
        |> or_fail_with("expected IgnoreFunctionWithoutFunction at line 4")
      }),
      it(
        "returns IgnoreFunctionWithoutFunction when only a comment follows",
        fn() {
          outside_error(outside_path(), [
            "pub fn run() {",
            "  1",
            "}",
            "// coverage:ignore-function",
            "// nothing follows",
          ])
          |> should
          |> be_equal(Ok(IgnoreFunctionWithoutFunction(outside_path(), 4)))
          |> or_fail_with("expected IgnoreFunctionWithoutFunction at line 4")
        },
      ),
      it(
        "returns IgnoreFunctionWithoutFunction when the parameters never close",
        fn() {
          outside_error(outside_path(), [
            "// coverage:ignore-function",
            "pub fn broken(",
          ])
          |> should
          |> be_equal(Ok(IgnoreFunctionWithoutFunction(outside_path(), 1)))
          |> or_fail_with("expected IgnoreFunctionWithoutFunction at line 1")
        },
      ),
      it(
        "returns IgnoreFunctionWithoutFunction when a string never closes",
        fn() {
          outside_error(outside_path(), [
            "// coverage:ignore-function",
            "pub fn broken() {",
            "  \"never closed",
          ])
          |> should
          |> be_equal(Ok(IgnoreFunctionWithoutFunction(outside_path(), 1)))
          |> or_fail_with("expected IgnoreFunctionWithoutFunction at line 1")
        },
      ),
      it(
        "returns IgnoreFunctionWithoutFunction above an Erlang attribute only",
        fn() {
          outside_error(outside_erlang_path(), [
            "-module(outside).",
            "%% coverage:ignore-function",
            "-define(LIMIT, 10).",
          ])
          |> should
          |> be_equal(
            Ok(IgnoreFunctionWithoutFunction(outside_erlang_path(), 2)),
          )
          |> or_fail_with("expected IgnoreFunctionWithoutFunction at line 2")
        },
      ),
      it(
        "returns IgnoreFunctionWithoutFunction when an Erlang function never ends",
        fn() {
          outside_error(outside_erlang_path(), [
            "-module(outside).",
            "%% coverage:ignore-function",
            "broken() ->",
            "    ok",
          ])
          |> should
          |> be_equal(
            Ok(IgnoreFunctionWithoutFunction(outside_erlang_path(), 2)),
          )
          |> or_fail_with("expected IgnoreFunctionWithoutFunction at line 2")
        },
      ),
      it("returns SourceReadFailed when a source file cannot be read", fn() {
        run_in_child(fn() {
          let _ = child_project("unreadable")
          add_source("marked.erl", marked_module(plain_body()))
          compile_source("marked.erl", "debug_info")
          make_unreadable("marked.erl")
          coverage.start(project_config())
        })
        |> should
        |> be_equal(
          Ok(
            Error(SourceReadFailed(
              "src/marked.erl",
              PermissionDenied("src/marked.erl"),
            )),
          ),
        )
        |> or_fail_with("expected SourceReadFailed")
      }),
    ]),
  ])
}
