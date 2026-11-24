//// Black-box tests of `@external(erlang, ...)` functions in coverage.
////
//// Gleam code never calls the wrapper that Gleam compiles for an Erlang
//// external, so its line is not counted.

import coverage_external_fixtures/external_wrapper
import dream_test/coverage.{type CoverageConfig}
import dream_test/coverage/report.{type CoverageReport, type LineCoverage}
import dream_test/coverage_project_support.{
  type MarkedProject, add_source, compile_outside_source, measure,
  new_marked_project, project_config,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/string

fn fixture_config() -> CoverageConfig {
  coverage.new()
  |> coverage.source_directory("test/coverage_external_fixtures")
  |> coverage.no_lcov()
}

fn fixture_path() -> String {
  "test/coverage_external_fixtures/external_wrapper.gleam"
}

/// The line numbers of one file of a report, or the error as text.
fn line_numbers(
  measured: Result(CoverageReport, coverage.CoverageError),
  source_path: String,
) -> Result(List(Int), String) {
  case measured {
    Ok(coverage_report) -> Ok(file_line_numbers(coverage_report, source_path))
    Error(error) -> Error(string.inspect(error))
  }
}

fn file_line_numbers(
  coverage_report: CoverageReport,
  source_path: String,
) -> List(Int) {
  coverage_report
  |> report.files()
  |> list.filter(has_source_path(_, source_path))
  |> list.flat_map(report.lines)
  |> list.map(line_number)
}

fn has_source_path(file: report.FileCoverage, source_path: String) -> Bool {
  report.source_path(file) == source_path
}

fn line_number(line: LineCoverage) -> Int {
  line.line
}

fn run_fixture() -> Int {
  external_wrapper.quadruple(1) + external_wrapper.double_reference()(1)
}

/// A Gleam source that is not formatted: line 3 is a function on one line
/// whose body calls the external with the same parameter.
fn unformatted_gleam_source() -> String {
  [
    "@external(erlang, \"coverage_fixture_ffi\", \"double\")",
    "pub fn wrapped(number: Int) -> Int",
    "pub fn one_liner(number: Int) -> Int { wrapped(number) }",
    "@external(erlang, \"coverage_fixture_ffi\", \"double\") pub fn changed(number: Int) -> Int",
    "",
  ]
  |> string.join("\n")
}

/// The Erlang code for `unformatted_gleam_source`, one function per line.
/// Lines 2 and 3 have the same code. Line 4 is not a wrapper, as if a
/// compiler gave the external a body of its own.
fn compiled_erlang_source(module: String) -> String {
  [
    "-module('" <> module <> "'). -export([wrapped/1, one_liner/1, changed/1]).",
    "wrapped(Number) -> coverage_fixture_ffi:double(Number).",
    "one_liner(Number) -> coverage_fixture_ffi:double(Number).",
    "changed(Number) -> Number * 2.",
    "",
  ]
  |> string.join("\n")
}

/// The Gleam module name of `wrappers.gleam` in a project's source
/// directory, which starts with `test/..`.
fn gleam_module(project: MarkedProject) -> String {
  project.source_directory
  |> string.drop_start(string.length("test/"))
  |> string.replace("/", "@")
  |> string.append("@wrappers")
}

fn unformatted_line_numbers() -> Result(List(Int), String) {
  let project = new_marked_project("external")
  add_source(
    project.source_directory,
    "wrappers.gleam",
    unformatted_gleam_source(),
  )
  compile_outside_source(
    project.source_directory,
    compiled_erlang_source(gleam_module(project)),
  )
  measure(project_config(project.source_directory), fn() { Nil })
  |> line_numbers(project.source_directory <> "/wrappers.gleam")
}

pub fn tests() {
  describe("coverage of @external functions", [
    it("leaves out the lines of Erlang external wrappers", fn() {
      measure(fixture_config(), run_fixture)
      |> line_numbers(fixture_path())
      |> should
      |> be_equal(Ok([20, 24]))
      |> or_fail_with("expected lines 7 and 12 to have no counter")
    }),
    it("counts a function on one line with the same code as a wrapper", fn() {
      unformatted_line_numbers()
      |> should
      |> be_equal(Ok([3, 4]))
      |> or_fail_with("expected line 2 to have no counter, and 3 and 4 to")
    }),
  ])
}
