//// The coverage tables that the docs show, rendered from a report and
//// compared with the output files under `test/outputs/`.

import dream_test/coverage
import dream_test/coverage/report.{type LineCoverage, LineCoverage}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/coverage as coverage_reporter
import dream_test/unit.{describe, it}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import snippets_outputs

pub fn tests() {
  describe("Coverage output in the docs", [
    it("shows the table with the missing lines", fn() {
      // Act
      let table =
        coverage_reporter.render(
          report: report.new([cart_file()]),
          config: coverage.new() |> coverage.show_missing(),
        )

      // Assert
      Ok(table)
      |> should
      |> be_equal(snippets_outputs.read_after_blank_line(
        "coverage_table_missing",
      ))
      |> or_fail_with("expected test/outputs/coverage_table_missing.txt")
    }),
    it("shows the excluded lines and files", fn() {
      // Act
      let table =
        coverage_reporter.render(
          report: excluded_report(),
          config: coverage.new()
            |> coverage.no_lcov()
            |> coverage.show_excluded(),
        )

      // Assert
      Ok(table)
      |> should
      |> be_equal(snippets_outputs.read_after_blank_line(
        "coverage_table_excluded",
      ))
      |> or_fail_with("expected test/outputs/coverage_table_excluded.txt")
    }),
    it("shows a file with no executable lines", fn() {
      // Act
      let table =
        coverage_reporter.render(
          report: report.new([
            cart_file(),
            report.file("src/app/types.gleam", []),
          ]),
          config: coverage.new(),
        )

      // Assert
      Ok(table)
      |> should
      |> be_equal(snippets_outputs.read_after_blank_line(
        "coverage_table_with_empty_file",
      ))
      |> or_fail_with(
        "expected test/outputs/coverage_table_with_empty_file.txt",
      )
    }),
    it("hides the complete files", fn() {
      // Act
      let table =
        coverage_reporter.render(
          report: report.new([
            complete_file("src/app/a.gleam"),
            complete_file("src/app/b.gleam"),
            cart_file(),
          ]),
          config: coverage.new() |> coverage.hide_complete(),
        )

      // Assert
      Ok(table)
      |> should
      |> be_equal(snippets_outputs.read_after_blank_line(
        "coverage_table_hidden",
      ))
      |> or_fail_with("expected test/outputs/coverage_table_hidden.txt")
    }),
    it("warns about files that a Gleam version before 1.19 built", fn() {
      // Act
      let table =
        coverage_reporter.render(
          report: report.new([cart_file()])
            |> report.add_inexact_line_files(["src/app/cart.gleam"]),
          config: coverage.new(),
        )

      // Assert
      Ok(table)
      |> should
      |> be_equal(snippets_outputs.read_after_blank_line(
        "coverage_table_inexact_lines",
      ))
      |> or_fail_with("expected test/outputs/coverage_table_inexact_lines.txt")
    }),
  ])
}

/// Lines 1 to 20 are executable. Lines 12 and 13 did not run.
fn cart_file() {
  report.file("src/app/cart.gleam", cart_lines())
}

fn cart_lines() -> List(LineCoverage) {
  int.range(from: 1, to: 21, with: [], run: list.prepend)
  |> list.reverse()
  |> list.map(fn(line) {
    case line {
      12 | 13 -> LineCoverage(line: line, calls: 0)
      _ -> LineCoverage(line: line, calls: 1)
    }
  })
}

/// Lines 1 to 20 are executable, and all of them ran.
fn complete_file(source_path: String) {
  report.file(
    source_path,
    int.range(from: 1, to: 21, with: [], run: list.prepend)
      |> list.reverse()
      |> list.map(fn(line) { LineCoverage(line: line, calls: 1) }),
  )
}

fn excluded_report() {
  report.new([
    cart_file()
    |> report.add_ignored_ranges([
      report.ignored_range(
        first_line: 40,
        last_line: 44,
        reason: Some("debug only"),
      ),
      report.ignored_range(first_line: 71, last_line: 71, reason: None),
    ]),
  ])
  |> report.add_excluded_files([
    report.excluded_file(
      source_path: "src/app/generated/db.gleam",
      pattern: "src/app/generated/**",
      reason: Some("generated code"),
    ),
  ])
}
