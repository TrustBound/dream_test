//// Black-box tests of `coverage.minimum_percent_per_file`: the setting, the
//// check, the colours of the table and the failure message. The runner's
//// output and exit status are in runner_coverage_test.gleam.

import coverage_fixtures/sample
import dream_test/coverage.{
  type CoverageError, type CoverageSession, FileBelowMinimum,
  FilesBelowMinimumPercent, InvalidMinimumPercentPerFile,
}
import dream_test/coverage/report.{type LineCoverage, LineCoverage}
import dream_test/coverage_child_support.{run_in_child}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/coverage.{RunOutcome} as coverage_reporter
import dream_test/unit.{describe, group, it}
import gleam/option.{None, Some}
import gleam/result

/// A file with `hit` of `total` lines run.
fn counted_file(path: String, hit: Int, total: Int) {
  report.file(path, counted_lines(1, hit, total, []))
}

fn counted_lines(
  line: Int,
  hit: Int,
  total: Int,
  lines: List(LineCoverage),
) -> List(LineCoverage) {
  case line > total {
    True -> lines
    False ->
      counted_lines(line + 1, hit, total, [
        LineCoverage(line: line, calls: call_count(line, hit)),
        ..lines
      ])
  }
}

fn call_count(line: Int, hit: Int) -> Int {
  case line <= hit {
    True -> 1
    False -> 0
  }
}

fn per_file_config(percent: Float) {
  coverage.new() |> coverage.minimum_percent_per_file(percent)
}

/// The start error, or a message when start unexpectedly succeeded.
fn start_error(
  result: Result(CoverageSession, CoverageError),
) -> Result(CoverageError, String) {
  case result {
    Error(error) -> Ok(error)
    Ok(_) -> Error("expected start to fail")
  }
}

fn red(text: String) -> String {
  "\u{1b}[31m" <> text <> "\u{1b}[0m"
}

fn yellow(text: String) -> String {
  "\u{1b}[33m" <> text <> "\u{1b}[0m"
}

fn green(text: String) -> String {
  "\u{1b}[32m" <> text <> "\u{1b}[0m"
}

fn colour_report() {
  report.new([
    counted_file("src/a_full.gleam", 2, 2),
    counted_file("src/b_half.gleam", 1, 2),
    counted_file("src/c_low.gleam", 1, 4),
  ])
}

fn render_failure_for(error: CoverageError) -> String {
  coverage_reporter.render_failure(
    error: error,
    outcome: RunOutcome(passed: 3, failed: 0, exit_on_failure: True),
  )
}

/// In a child node: measure the fixtures while one test calls
/// `sample.classify(1)`, then check the per-file minimum of 50.0.
fn check_fixtures_in_child() -> Result(Nil, CoverageError) {
  let config =
    coverage.new()
    |> coverage.source_directory("test/coverage_fixtures")
    |> coverage.no_lcov()
    |> coverage.minimum_percent_per_file(50.0)
  use session <- result.try(coverage.start(config))
  let _ = sample.classify(1)
  use coverage_report <- result.try(coverage.finish(session))
  coverage.check_minimum_per_file(config: config, report: coverage_report)
}

pub fn tests() {
  describe("coverage.minimum_percent_per_file", [
    group("settings", [
      it("new sets no per-file minimum", fn() {
        coverage.new()
        |> coverage.minimum_per_file()
        |> should
        |> be_equal(None)
        |> or_fail_with("expected no per-file minimum")
      }),
      it("minimum_per_file returns the value given", fn() {
        per_file_config(70.0)
        |> coverage.minimum_per_file()
        |> should
        |> be_equal(Some(70.0))
        |> or_fail_with("expected 70.0")
      }),
      it("does not change the total minimum", fn() {
        per_file_config(70.0)
        |> coverage.minimum()
        |> should
        |> be_equal(None)
        |> or_fail_with("expected no total minimum")
      }),
    ]),
    group("start errors", [
      it("returns InvalidMinimumPercentPerFile for a negative minimum", fn() {
        per_file_config(-0.5)
        |> coverage.start()
        |> start_error()
        |> should
        |> be_equal(Ok(InvalidMinimumPercentPerFile(-0.5)))
        |> or_fail_with("expected InvalidMinimumPercentPerFile for -0.5")
      }),
      it("returns InvalidMinimumPercentPerFile above 100", fn() {
        per_file_config(100.1)
        |> coverage.start()
        |> start_error()
        |> should
        |> be_equal(Ok(InvalidMinimumPercentPerFile(100.1)))
        |> or_fail_with("expected InvalidMinimumPercentPerFile for 100.1")
      }),
    ]),
    group("check_minimum_per_file", [
      it("passes when no per-file minimum is set", fn() {
        coverage.check_minimum_per_file(
          config: coverage.new(),
          report: report.new([counted_file("src/a.gleam", 0, 4)]),
        )
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("expected Ok without a per-file minimum")
      }),
      it("passes when every file equals the minimum or is above it", fn() {
        coverage.check_minimum_per_file(
          config: per_file_config(80.0),
          report: report.new([
            counted_file("src/a.gleam", 4, 5),
            counted_file("src/b.gleam", 5, 5),
          ]),
        )
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("expected 80.0% and 100.0% to pass 80.0")
      }),
      it("passes a file with no executable lines", fn() {
        coverage.check_minimum_per_file(
          config: per_file_config(100.0),
          report: report.new([counted_file("src/types.gleam", 0, 0)]),
        )
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("expected a file with no lines to pass")
      }),
      it("lists every file below the minimum, sorted by path", fn() {
        coverage.check_minimum_per_file(
          config: per_file_config(80.0),
          report: report.new([
            counted_file("src/z.gleam", 1999, 2500),
            counted_file("src/m.gleam", 5, 5),
            counted_file("src/a.gleam", 0, 3),
          ]),
        )
        |> should
        |> be_equal(
          Error(
            FilesBelowMinimumPercent(minimum_percent: 80.0, files: [
              FileBelowMinimum(
                source_path: "src/a.gleam",
                hit: 0,
                total: 3,
                lines_needed: 3,
              ),
              FileBelowMinimum(
                source_path: "src/z.gleam",
                hit: 1999,
                total: 2500,
                lines_needed: 2000,
              ),
            ]),
          ),
        )
        |> or_fail_with("expected a.gleam and z.gleam below 80.0")
      }),
      it("rounds the minimum to one decimal place", fn() {
        coverage.check_minimum_per_file(
          config: per_file_config(72.56),
          report: report.new([counted_file("src/a.gleam", 725, 1000)]),
        )
        |> should
        |> be_equal(
          Error(
            FilesBelowMinimumPercent(minimum_percent: 72.6, files: [
              FileBelowMinimum(
                source_path: "src/a.gleam",
                hit: 725,
                total: 1000,
                lines_needed: 726,
              ),
            ]),
          ),
        )
        |> or_fail_with("expected the minimum 72.56 to round to 72.6")
      }),
      it("returns InvalidMinimumPercentPerFile out of range", fn() {
        coverage.check_minimum_per_file(
          config: per_file_config(120.0),
          report: report.new([counted_file("src/a.gleam", 1, 1)]),
        )
        |> should
        |> be_equal(Error(InvalidMinimumPercentPerFile(120.0)))
        |> or_fail_with("expected InvalidMinimumPercentPerFile")
      }),
      it("checks the files that coverage measured", fn() {
        run_in_child(check_fixtures_in_child)
        |> should
        |> be_equal(
          Ok(
            Error(
              FilesBelowMinimumPercent(minimum_percent: 50.0, files: [
                FileBelowMinimum(
                  source_path: "test/coverage_fixtures/coverage_fixture_ffi.erl",
                  hit: 0,
                  total: 1,
                  lines_needed: 1,
                ),
                FileBelowMinimum(
                  source_path: "test/coverage_fixtures/nested/deep.gleam",
                  hit: 0,
                  total: 1,
                  lines_needed: 1,
                ),
              ]),
            ),
          ),
        )
        |> or_fail_with("expected the two fixture files that did not run")
      }),
    ]),
    group("table colours", [
      it(
        "paints file rows by the per-file minimum, the total by the total minimum",
        fn() {
          coverage_reporter.render(
            report: colour_report(),
            config: coverage.new()
              |> coverage.no_lcov()
              |> coverage.minimum_percent(60.0)
              |> coverage.minimum_percent_per_file(50.0)
              |> coverage.color(),
          )
          |> should
          |> be_equal(
            "\nCoverage\n"
            <> "File              Lines  Cover\n"
            <> "src/a_full.gleam  2/2    "
            <> green("100.0%")
            <> "\n"
            <> "src/b_half.gleam  1/2    "
            <> yellow("50.0%")
            <> "\n"
            <> "src/c_low.gleam   1/4    "
            <> red("25.0%")
            <> "\n"
            <> "Total             4/8    "
            <> red("50.0%")
            <> "\n",
          )
          |> or_fail_with("expected yellow at the per-file minimum, red total")
        },
      ),
      it(
        "paints file rows by the fixed rule with an invalid per-file minimum",
        fn() {
          coverage_reporter.render(
            report: colour_report(),
            config: coverage.new()
              |> coverage.no_lcov()
              |> coverage.minimum_percent_per_file(150.0)
              |> coverage.color(),
          )
          |> should
          |> be_equal(
            "\nCoverage\n"
            <> "File              Lines  Cover\n"
            <> "src/a_full.gleam  2/2    "
            <> green("100.0%")
            <> "\n"
            <> "src/b_half.gleam  1/2    "
            <> yellow("50.0%")
            <> "\n"
            <> "src/c_low.gleam   1/4    "
            <> red("25.0%")
            <> "\n"
            <> "Total             4/8    "
            <> yellow("50.0%")
            <> "\n",
          )
          |> or_fail_with("expected the fixed rule colours")
        },
      ),
    ]),
    group("render_failure", [
      it("describes InvalidMinimumPercentPerFile", fn() {
        render_failure_for(InvalidMinimumPercentPerFile(120.0))
        |> should
        |> be_equal(
          "\nCoverage failed\n"
          <> "  The per-file coverage minimum 120.0 is not a percent.\n"
          <> "  Reason: coverage.minimum_percent_per_file(...) takes a value from 0.0 to 100.0.\n"
          <> "  Fix: pass a value from 0.0 to 100.0, for example coverage.minimum_percent_per_file(70.0).\n"
          <> "\nTests: 3 passed. Exit status 1, because coverage was requested and did not complete.\n",
        )
        |> or_fail_with("expected the InvalidMinimumPercentPerFile message")
      }),
      it("lists every file of FilesBelowMinimumPercent", fn() {
        render_failure_for(
          FilesBelowMinimumPercent(minimum_percent: 80.0, files: [
            FileBelowMinimum(
              source_path: "src/a.gleam",
              hit: 0,
              total: 3,
              lines_needed: 3,
            ),
            FileBelowMinimum(
              source_path: "src/z.gleam",
              hit: 1999,
              total: 2500,
              lines_needed: 2000,
            ),
          ]),
        )
        |> should
        |> be_equal(
          "\nCoverage failed\n"
          <> "  Coverage of 2 files is below the per-file minimum 80.0%:\n"
          <> "    src/a.gleam 0.0%, 0 of 3 lines ran (needs 3 more lines)\n"
          <> "    src/z.gleam 79.9%, 1999 of 2500 lines ran (needs 1 more line)\n"
          <> "  Reason: coverage.minimum_percent_per_file(...) needs each measured file to reach the minimum, and too few executable lines ran in these files.\n"
          <> "  Fix: add tests for the lines that did not run in these files (coverage.show_missing() lists them), or lower coverage.minimum_percent_per_file(...).\n"
          <> "\nTests: 3 passed. Exit status 1, because coverage is below the minimum.\n",
        )
        |> or_fail_with("expected the FilesBelowMinimumPercent message")
      }),
      it("says 1 file for one file below the minimum", fn() {
        render_failure_for(
          FilesBelowMinimumPercent(minimum_percent: 50.0, files: [
            FileBelowMinimum(
              source_path: "src/a.gleam",
              hit: 0,
              total: 1,
              lines_needed: 1,
            ),
          ]),
        )
        |> should
        |> be_equal(
          "\nCoverage failed\n"
          <> "  Coverage of 1 file is below the per-file minimum 50.0%:\n"
          <> "    src/a.gleam 0.0%, 0 of 1 lines ran (needs 1 more line)\n"
          <> "  Reason: coverage.minimum_percent_per_file(...) needs each measured file to reach the minimum, and too few executable lines ran in these files.\n"
          <> "  Fix: add tests for the lines that did not run in these files (coverage.show_missing() lists them), or lower coverage.minimum_percent_per_file(...).\n"
          <> "\nTests: 3 passed. Exit status 1, because coverage is below the minimum.\n",
        )
        |> or_fail_with("expected the one-file message")
      }),
    ]),
  ])
}
