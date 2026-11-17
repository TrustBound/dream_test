//// The coverage tables that the README shows, rendered from a report.

import dream_test/coverage
import dream_test/coverage/report.{type LineCoverage, LineCoverage}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/coverage as coverage_reporter
import dream_test/unit.{describe, it}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string

pub fn tests() {
  describe("README coverage output", [
    it("shows the table with the missing lines", fn() {
      coverage_reporter.render(
        report: report.new([cart_file()]),
        config: coverage.new() |> coverage.show_missing(),
      )
      |> should
      |> be_equal(missing_table())
      |> or_fail_with("expected the table in the README")
    }),
    it("shows the excluded lines and files", fn() {
      coverage_reporter.render(
        report: excluded_report(),
        config: coverage.new() |> coverage.no_lcov() |> coverage.show_excluded(),
      )
      |> should
      |> be_equal(excluded_table())
      |> or_fail_with("expected the excluded table in the README")
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

fn missing_table() {
  string.join(
    [
      "",
      "Coverage",
      "File                Lines  Cover  Missing",
      "src/app/cart.gleam  18/20  90.0%  12-13",
      "Total               18/20  90.0%",
      "LCOV: build/coverage/lcov.info",
      "",
    ],
    "\n",
  )
}

fn excluded_table() {
  string.join(
    [
      "",
      "Coverage",
      "File                        Lines  Cover  Excluded",
      "src/app/cart.gleam          18/20  90.0%  40-44 (debug only), 71",
      "src/app/generated/db.gleam  excluded: matches src/app/generated/** (generated code)",
      "Total                       18/20  90.0%",
      "Excluded: 1 file, 6 lines in 1 file",
      "",
    ],
    "\n",
  )
}
