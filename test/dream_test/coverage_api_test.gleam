//// Black-box tests of `dream_test/coverage`.
////
//// Tests that start `cover` run in a new peer node, because `cover` runs
//// once per BEAM instance and this test run may already be measuring itself.

import coverage_fixtures/nested/deep
import coverage_fixtures/sample
import dream_test/coverage.{
  type CoverageError, type CoverageSession, type StartCause, BelowMinimumPercent,
  CoverAlreadyRunning, CoverStartFailed, InvalidMinimumPercent, LcovWriteFailed,
  NoSourceFiles, SourceDirectoryNotFound, SourceDirectoryOutsideSourceRoot,
}
import dream_test/coverage/report.{
  type CoverageReport, type LineCoverage, LineCoverage,
}
import dream_test/file.{IsDirectory, read, write}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process.{unique_port}
import dream_test/unit.{describe, group, it}
import gleam/int
import gleam/list
import gleam/option.{None, Some}

@external(erlang, "dream_test_coverage_test_ffi", "run_in_peer")
fn run_in_peer(function: fn() -> a) -> Result(a, String)

fn fixture_config() {
  coverage.new()
  |> coverage.source_directory("test/coverage_fixtures")
  |> coverage.no_lcov()
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

/// Every file of a report as `#(source_path, lines)`.
fn file_lines(
  coverage_report: CoverageReport,
) -> List(#(String, List(LineCoverage))) {
  list.map(report.files(coverage_report), fn(file) {
    #(report.source_path(file), report.lines(file))
  })
}

/// Lines 1..total, where the first `hit` lines ran once.
fn report_with_counts(hit: Int, total: Int) -> CoverageReport {
  report.new([
    report.file("src/app/cart.gleam", counted_lines(1, total, hit, [])),
  ])
}

fn counted_lines(
  line: Int,
  total: Int,
  hit: Int,
  accumulated: List(LineCoverage),
) -> List(LineCoverage) {
  case line > total {
    True -> list.reverse(accumulated)
    False -> {
      let calls = case line <= hit {
        True -> 1
        False -> 0
      }
      counted_lines(line + 1, total, hit, [
        LineCoverage(line: line, calls: calls),
        ..accumulated
      ])
    }
  }
}

/// Start coverage, run `classify(1)`, and finish, all in a new peer node.
fn measure_classify(
  config: coverage.CoverageConfig,
) -> Result(Result(CoverageReport, CoverageError), String) {
  run_in_peer(fn() {
    case coverage.start(config) {
      Ok(session) -> {
        let _ = sample.classify(1)
        coverage.finish(session)
      }
      Error(error) -> Error(error)
    }
  })
}

fn start_cause(error: CoverageError) -> Result(StartCause, String) {
  case error {
    CoverStartFailed(cause, _raw) -> Ok(cause)
    _ -> Error("expected CoverStartFailed")
  }
}

pub fn tests() {
  describe("dream_test/coverage", [
    group("settings", [
      it("new does not show missing lines", fn() {
        coverage.new()
        |> coverage.shows_missing()
        |> should
        |> be_equal(False)
        |> or_fail_with("expected missing lines to be hidden by default")
      }),
      it("new does not show excluded lines and files", fn() {
        coverage.new()
        |> coverage.shows_excluded()
        |> should
        |> be_equal(False)
        |> or_fail_with("expected exclusions to be listed only on request")
      }),
      it("show_excluded turns the Excluded column on", fn() {
        coverage.new()
        |> coverage.show_excluded()
        |> coverage.shows_excluded()
        |> should
        |> be_equal(True)
        |> or_fail_with("expected exclusions to be listed")
      }),
      it("show_missing turns the Missing column on", fn() {
        coverage.new()
        |> coverage.show_missing()
        |> coverage.shows_missing()
        |> should
        |> be_equal(True)
        |> or_fail_with("expected missing lines to be shown")
      }),
      it("new writes LCOV to build/coverage/lcov.info", fn() {
        coverage.new()
        |> coverage.lcov_file()
        |> should
        |> be_equal(Some("build/coverage/lcov.info"))
        |> or_fail_with("expected the default LCOV path")
      }),
      it("lcov_path changes the LCOV file", fn() {
        coverage.new()
        |> coverage.lcov_path("build/coverage/unit.lcov")
        |> coverage.lcov_file()
        |> should
        |> be_equal(Some("build/coverage/unit.lcov"))
        |> or_fail_with("expected the new LCOV path")
      }),
      it("no_lcov turns the LCOV file off", fn() {
        coverage.new()
        |> coverage.no_lcov()
        |> coverage.lcov_file()
        |> should
        |> be_equal(None)
        |> or_fail_with("expected no LCOV file")
      }),
    ]),

    group("start errors", [
      it("returns SourceDirectoryNotFound for a missing directory", fn() {
        coverage.new()
        |> coverage.source_directory("src/no_such_directory")
        |> coverage.start()
        |> start_error()
        |> should
        |> be_equal(Ok(SourceDirectoryNotFound("src/no_such_directory")))
        |> or_fail_with("expected SourceDirectoryNotFound")
      }),
      it(
        "returns SourceDirectoryOutsideSourceRoot outside src, test and dev",
        fn() {
          coverage.new()
          |> coverage.source_directory("examples/snippets/src")
          |> coverage.start()
          |> start_error()
          |> should
          |> be_equal(
            Ok(SourceDirectoryOutsideSourceRoot("examples/snippets/src")),
          )
          |> or_fail_with("expected SourceDirectoryOutsideSourceRoot")
        },
      ),
      it("returns NoSourceFiles for a directory without source files", fn() {
        let directory =
          "test/tmp/coverage_api_test/empty_" <> int.to_string(unique_port())
        let _ = write(directory <> "/notes.txt", "not source")
        coverage.new()
        |> coverage.source_directory(directory)
        |> coverage.start()
        |> start_error()
        |> should
        |> be_equal(Ok(NoSourceFiles(directory)))
        |> or_fail_with("expected NoSourceFiles")
      }),
      it("returns InvalidMinimumPercent for a negative minimum", fn() {
        coverage.new()
        |> coverage.minimum_percent(-1.0)
        |> coverage.start()
        |> start_error()
        |> should
        |> be_equal(Ok(InvalidMinimumPercent(-1.0)))
        |> or_fail_with("expected InvalidMinimumPercent for -1.0")
      }),
      it("returns InvalidMinimumPercent for a minimum above 100", fn() {
        coverage.new()
        |> coverage.minimum_percent(100.5)
        |> coverage.start()
        |> start_error()
        |> should
        |> be_equal(Ok(InvalidMinimumPercent(100.5)))
        |> or_fail_with("expected InvalidMinimumPercent for 100.5")
      }),
      it("returns CoverAlreadyRunning for a second start", fn() {
        run_in_peer(fn() {
          let _ = coverage.start(fixture_config())
          case coverage.start(fixture_config()) {
            Error(error) -> start_cause(error)
            Ok(_) -> Error("expected the second start to fail")
          }
        })
        |> should
        |> be_equal(Ok(Ok(CoverAlreadyRunning)))
        |> or_fail_with("expected CoverAlreadyRunning")
      }),
    ]),

    group("start and finish", [
      it("report every source file with each executable line", fn() {
        case measure_classify(fixture_config()) {
          Ok(Ok(coverage_report)) -> Ok(file_lines(coverage_report))
          other -> Error(other)
        }
        |> should
        |> be_equal(
          Ok([
            #("test/coverage_fixtures/coverage_fixture_ffi.erl", [
              LineCoverage(line: 6, calls: 0),
            ]),
            #("test/coverage_fixtures/nested/deep.gleam", [
              LineCoverage(line: 4, calls: 0),
            ]),
            #("test/coverage_fixtures/sample.gleam", [
              LineCoverage(line: 7, calls: 1),
              LineCoverage(line: 8, calls: 1),
              LineCoverage(line: 9, calls: 0),
              LineCoverage(line: 14, calls: 0),
            ]),
          ]),
        )
        |> or_fail_with("expected the fixture lines")
      }),
      it("measure a folder inside a source root with its module names", fn() {
        run_in_peer(fn() {
          let config =
            fixture_config()
            |> coverage.source_directory("./test/coverage_fixtures/nested/")
          case coverage.start(config) {
            Ok(session) -> {
              let _ = deep.answer()
              coverage.finish(session)
            }
            Error(error) -> Error(error)
          }
        })
        |> should
        |> be_equal(
          Ok(
            Ok(
              report.new([
                report.file("test/coverage_fixtures/nested/deep.gleam", [
                  LineCoverage(line: 4, calls: 1),
                ]),
              ]),
            ),
          ),
        )
        |> or_fail_with("expected nested@deep to be measured")
      }),
      it("write the LCOV file", fn() {
        let path =
          "test/tmp/coverage_api_test/lcov_"
          <> int.to_string(unique_port())
          <> ".info"
        let _ = measure_classify(fixture_config() |> coverage.lcov_path(path))
        read(path)
        |> should
        |> be_equal(Ok(
          "TN:\nSF:test/coverage_fixtures/coverage_fixture_ffi.erl\nDA:6,0\nLF:1\nLH:0\nend_of_record\n"
          <> "TN:\nSF:test/coverage_fixtures/nested/deep.gleam\nDA:4,0\nLF:1\nLH:0\nend_of_record\n"
          <> "TN:\nSF:test/coverage_fixtures/sample.gleam\nDA:7,1\nDA:8,1\nDA:9,0\nDA:14,0\nLF:4\nLH:2\nend_of_record\n",
        ))
        |> or_fail_with("expected the LCOV records")
      }),
      it("return LcovWriteFailed when the LCOV path is a directory", fn() {
        measure_classify(fixture_config() |> coverage.lcov_path("test"))
        |> should
        |> be_equal(Ok(Error(LcovWriteFailed("test", IsDirectory("test")))))
        |> or_fail_with("expected LcovWriteFailed")
      }),
    ]),

    group("check_minimum", [
      it("passes when no minimum is set", fn() {
        coverage.check_minimum(
          config: coverage.new(),
          report: report_with_counts(1, 10),
        )
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("expected Ok without a minimum")
      }),
      it("passes when coverage equals the minimum exactly", fn() {
        coverage.check_minimum(
          config: coverage.new() |> coverage.minimum_percent(80.0),
          report: report_with_counts(4, 5),
        )
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("expected 80.0% to pass a minimum of 80.0")
      }),
      it("fails when coverage is just below the minimum", fn() {
        coverage.check_minimum(
          config: coverage.new() |> coverage.minimum_percent(80.0),
          report: report_with_counts(1999, 2500),
        )
        |> should
        |> be_equal(
          Error(BelowMinimumPercent(
            hit: 1999,
            total: 2500,
            minimum_percent: 80.0,
            lines_needed: 2000,
          )),
        )
        |> or_fail_with("expected 79.96% to fail a minimum of 80.0")
      }),
      it("rounds the minimum to one decimal place", fn() {
        coverage.check_minimum(
          config: coverage.new() |> coverage.minimum_percent(72.56),
          report: report_with_counts(725, 1000),
        )
        |> should
        |> be_equal(
          Error(BelowMinimumPercent(
            hit: 725,
            total: 1000,
            minimum_percent: 72.6,
            lines_needed: 726,
          )),
        )
        |> or_fail_with("expected the minimum 72.56 to round to 72.6")
      }),
      it("passes when there are no executable lines", fn() {
        coverage.check_minimum(
          config: coverage.new() |> coverage.minimum_percent(80.0),
          report: report.new([]),
        )
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("expected Ok with no executable lines")
      }),
      it("returns InvalidMinimumPercent for a minimum out of range", fn() {
        coverage.check_minimum(
          config: coverage.new() |> coverage.minimum_percent(120.0),
          report: report_with_counts(1, 1),
        )
        |> should
        |> be_equal(Error(InvalidMinimumPercent(120.0)))
        |> or_fail_with("expected InvalidMinimumPercent")
      }),
    ]),
  ])
}
