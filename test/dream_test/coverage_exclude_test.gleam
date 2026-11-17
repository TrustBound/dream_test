//// Black-box tests of `coverage.exclude`, run in a child node.

import coverage_fixtures/sample
import dream_test/coverage.{
  type CoverageConfig, type CoverageError, EverySourceFileExcluded,
  ExcludeMatchedNothing,
}
import dream_test/coverage/report.{type CoverageReport}
import dream_test/coverage_child_support.{
  add_damaged_beam, add_source, child_project, compile_source, measure,
  run_in_child,
}
import dream_test/file.{read, write}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process.{unique_port}
import dream_test/unit.{describe, group, it}
import gleam/int
import gleam/list

fn fixture_config() -> CoverageConfig {
  coverage.new()
  |> coverage.source_directory("test/coverage_fixtures")
  |> coverage.no_lcov()
}

fn nested_pattern() -> String {
  "test/coverage_fixtures/nested/**"
}

fn ffi_pattern() -> String {
  "test/**/*_ffi.erl"
}

/// A new, empty directory for one test's files.
fn test_directory() -> String {
  "build/coverage/exclude_tests/" <> int.to_string(unique_port())
}

/// Measure `classify(1)` with `config` in a child, and list the paths of the
/// report's files.
fn measured_paths(config: CoverageConfig) -> Result(List(String), String) {
  case run_in_child(fn() { measure(config, fn() { sample.classify(1) }) }) {
    Ok(Ok(coverage_report)) -> Ok(source_paths(coverage_report))
    Ok(Error(error)) -> Error(string_of(error))
    Error(message) -> Error(message)
  }
}

fn source_paths(coverage_report: CoverageReport) -> List(String) {
  list.map(report.files(coverage_report), report.source_path)
}

/// Start coverage with `config` in a child, and return the start error.
fn start_error(config: CoverageConfig) -> Result(CoverageError, String) {
  case run_in_child(fn() { coverage.start(config) }) {
    Ok(Error(error)) -> Ok(error)
    Ok(Ok(_)) -> Error("expected start to fail")
    Error(message) -> Error(message)
  }
}

@external(erlang, "dream_test_coverage_test_ffi", "format")
fn string_of(value: a) -> String

pub fn tests() {
  describe("coverage.exclude", [
    group("excluding", [
      it("leaves files that match a ** pattern out of the report", fn() {
        fixture_config()
        |> coverage.exclude(nested_pattern())
        |> measured_paths()
        |> should
        |> be_equal(
          Ok([
            "test/coverage_fixtures/coverage_fixture_ffi.erl",
            "test/coverage_fixtures/sample.gleam",
          ]),
        )
        |> or_fail_with("expected nested/deep.gleam to be excluded")
      }),
      it("matches file names inside any folder", fn() {
        fixture_config()
        |> coverage.exclude(ffi_pattern())
        |> measured_paths()
        |> should
        |> be_equal(
          Ok([
            "test/coverage_fixtures/nested/deep.gleam",
            "test/coverage_fixtures/sample.gleam",
          ]),
        )
        |> or_fail_with("expected the FFI file to be excluded")
      }),
      it("accepts a pattern that starts with ./", fn() {
        fixture_config()
        |> coverage.exclude("./test/coverage_fixtures/sample.gleam")
        |> measured_paths()
        |> should
        |> be_equal(
          Ok([
            "test/coverage_fixtures/coverage_fixture_ffi.erl",
            "test/coverage_fixtures/nested/deep.gleam",
          ]),
        )
        |> or_fail_with("expected sample.gleam to be excluded")
      }),
      it("excludes the files of every pattern", fn() {
        fixture_config()
        |> coverage.exclude(nested_pattern())
        |> coverage.exclude(ffi_pattern())
        |> measured_paths()
        |> should
        |> be_equal(Ok(["test/coverage_fixtures/sample.gleam"]))
        |> or_fail_with("expected only sample.gleam to be left")
      }),
      it("accepts a pattern whose files an earlier pattern excluded", fn() {
        fixture_config()
        |> coverage.exclude("test/coverage_fixtures/**/*.gleam")
        |> coverage.exclude("test/coverage_fixtures/sample.gleam")
        |> measured_paths()
        |> should
        |> be_equal(Ok(["test/coverage_fixtures/coverage_fixture_ffi.erl"]))
        |> or_fail_with("expected only the FFI file to be left")
      }),
      it("does not instrument an excluded module", fn() {
        run_in_child(fn() {
          let _ = child_project("excluded")
          add_source("kept.erl", "-module(kept).\n")
          compile_source("kept.erl", "debug_info")
          add_source("damaged.erl", "-module(damaged).\n")
          add_damaged_beam("damaged")
          case
            measure(
              coverage.new()
                |> coverage.no_lcov()
                |> coverage.exclude("src/damaged.erl"),
              fn() { Nil },
            )
          {
            Ok(coverage_report) -> Ok(source_paths(coverage_report))
            Error(error) -> Error(string_of(error))
          }
        })
        |> should
        |> be_equal(Ok(Ok(["src/kept.erl"])))
        |> or_fail_with("expected the damaged module to be skipped")
      }),
      it("leaves excluded files out of the LCOV file", fn() {
        let path = test_directory() <> "/lcov.info"
        let _ =
          run_in_child(fn() {
            measure(
              fixture_config()
                |> coverage.lcov_path(path)
                |> coverage.exclude(nested_pattern())
                |> coverage.exclude(ffi_pattern()),
              fn() { sample.classify(1) },
            )
          })
        read(path)
        |> should
        |> be_equal(Ok(
          "TN:\nSF:test/coverage_fixtures/sample.gleam\nDA:7,1\nDA:8,1\nDA:9,0\nDA:14,0\nLF:4\nLH:2\nend_of_record\n",
        ))
        |> or_fail_with("expected only the sample.gleam record")
      }),
      it("leaves excluded files out of the minimum", fn() {
        let config =
          fixture_config()
          |> coverage.minimum_percent(50.0)
          |> coverage.exclude(nested_pattern())
          |> coverage.exclude(ffi_pattern())
        run_in_child(fn() {
          case measure(config, fn() { sample.classify(1) }) {
            Ok(coverage_report) ->
              coverage.check_minimum(config: config, report: coverage_report)
            Error(error) -> Error(error)
          }
        })
        |> should
        |> be_equal(Ok(Ok(Nil)))
        |> or_fail_with("expected 2 of 4 lines to reach 50%")
      }),
      it("drops merged line counts for excluded files", fn() {
        let directory = test_directory()
        let _ =
          write(
            directory <> "/part.info",
            "SF:test/coverage_fixtures/nested/deep.gleam\nDA:4,3\nend_of_record\n",
          )
        fixture_config()
        |> coverage.merge_lcov(directory <> "/*.info")
        |> coverage.exclude(nested_pattern())
        |> measured_paths()
        |> should
        |> be_equal(
          Ok([
            "test/coverage_fixtures/coverage_fixture_ffi.erl",
            "test/coverage_fixtures/sample.gleam",
          ]),
        )
        |> or_fail_with("expected the merged deep.gleam record to be dropped")
      }),
    ]),

    group("errors", [
      it("returns ExcludeMatchedNothing when no file matches", fn() {
        fixture_config()
        |> coverage.exclude("test/coverage_fixtures/generated/**")
        |> start_error()
        |> should
        |> be_equal(
          Ok(ExcludeMatchedNothing(
            "test/coverage_fixtures/generated/**",
            "test/coverage_fixtures",
          )),
        )
        |> or_fail_with("expected ExcludeMatchedNothing")
      }),
      it(
        "returns ExcludeMatchedNothing for a file outside the source directory",
        fn() {
          fixture_config()
          |> coverage.exclude("src/dream_test/coverage.gleam")
          |> start_error()
          |> should
          |> be_equal(
            Ok(ExcludeMatchedNothing(
              "src/dream_test/coverage.gleam",
              "test/coverage_fixtures",
            )),
          )
          |> or_fail_with("expected ExcludeMatchedNothing")
        },
      ),
      it("returns ExcludeMatchedNothing for a folder without **", fn() {
        fixture_config()
        |> coverage.exclude("test/coverage_fixtures/nested")
        |> start_error()
        |> should
        |> be_equal(
          Ok(ExcludeMatchedNothing(
            "test/coverage_fixtures/nested",
            "test/coverage_fixtures",
          )),
        )
        |> or_fail_with("expected ExcludeMatchedNothing")
      }),
      it("checks the patterns before cover starts", fn() {
        run_in_child(fn() {
          let _ =
            fixture_config()
            |> coverage.exclude("test/coverage_fixtures/generated/**")
            |> coverage.start()
          case measure(fixture_config(), fn() { sample.classify(1) }) {
            Ok(coverage_report) ->
              Ok(list.length(report.files(coverage_report)))
            Error(error) -> Error(string_of(error))
          }
        })
        |> should
        |> be_equal(Ok(Ok(3)))
        |> or_fail_with("expected a second start to succeed")
      }),
      it("returns EverySourceFileExcluded when no file is left", fn() {
        fixture_config()
        |> coverage.exclude("test/coverage_fixtures/**")
        |> start_error()
        |> should
        |> be_equal(Ok(EverySourceFileExcluded("test/coverage_fixtures")))
        |> or_fail_with("expected EverySourceFileExcluded")
      }),
    ]),
  ])
}
