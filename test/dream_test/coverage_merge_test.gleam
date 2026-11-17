//// Black-box tests of `coverage.merge_lcov`.

import coverage_fixtures/sample
import dream_test/coverage.{
  type CoverageError, LcovReadFailed, LcovSourceNotFound, MalformedLcov,
  NoLcovFilesMatched,
}
import dream_test/coverage/report.{type CoverageReport, LineCoverage}
import dream_test/coverage_project_support.{measure, with_fixture_lock}
import dream_test/file.{IsDirectory, write}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, group, it}

/// A new, empty directory for one test's LCOV files.
fn merge_directory() -> String {
  "build/coverage/merge_tests/" <> unique_name()
}

@external(erlang, "dream_test_coverage_test_ffi", "unique_name")
fn unique_name() -> String

/// Measure `classify(1)` on the fixtures, merging `<directory>/*.info`.
fn measure_with_merge(
  directory: String,
) -> Result(CoverageReport, CoverageError) {
  with_fixture_lock(fn() {
    measure(
      coverage.new()
        |> coverage.source_directory("test/coverage_fixtures")
        |> coverage.no_lcov()
        |> coverage.merge_lcov(directory <> "/*.info"),
      fn() { sample.classify(1) },
    )
  })
}

/// Merge one LCOV file holding `text`, and return the finish error.
fn merge_error(text: String) -> #(String, Result(CoverageError, String)) {
  let directory = merge_directory()
  let _ = write(directory <> "/part.info", text)
  #(directory, case measure_with_merge(directory) {
    Error(error) -> Ok(error)
    other -> Error(string_of(other))
  })
}

@external(erlang, "dream_test_coverage_test_ffi", "format")
fn string_of(value: a) -> String

fn malformed(
  directory: String,
  line_number: Int,
  line: String,
  problem: String,
) -> Result(CoverageError, String) {
  Ok(MalformedLcov(directory <> "/part.info", line_number, line, problem))
}

pub fn tests() {
  describe("coverage.merge_lcov", [
    group("merging", [
      it("adds counts per file and line from every matching file", fn() {
        let directory = merge_directory()
        let _ =
          write(
            directory <> "/a.info",
            "SF:test/coverage_fixtures/sample.gleam\nDA:9,2\nDA:14,1\nend_of_record\n",
          )
        let _ =
          write(
            directory <> "/b.info",
            "SF:test/coverage_fixtures/sample.gleam\nDA:9,1\nend_of_record\n"
              <> "SF:test/coverage_fixtures/nested/deep.gleam\nDA:4,5\nend_of_record\n"
              <> "SF:src/dream_test/timing.gleam\nDA:1,7\nend_of_record\n",
          )
        measure_with_merge(directory)
        |> should
        |> be_equal(
          Ok(
            report.new([
              report.file("src/dream_test/timing.gleam", [
                LineCoverage(line: 1, calls: 7),
              ]),
              report.file("test/coverage_fixtures/coverage_fixture_ffi.erl", [
                LineCoverage(line: 6, calls: 0),
              ]),
              report.file("test/coverage_fixtures/nested/deep.gleam", [
                LineCoverage(line: 4, calls: 5),
              ]),
              report.file("test/coverage_fixtures/sample.gleam", [
                LineCoverage(line: 7, calls: 1),
                LineCoverage(line: 8, calls: 1),
                LineCoverage(line: 9, calls: 3),
                LineCoverage(line: 14, calls: 1),
              ]),
            ]),
          ),
        )
        |> or_fail_with("expected the summed counts")
      }),
      it("accepts every LCOV line kind it does not use", fn() {
        let directory = merge_directory()
        let _ =
          write(
            directory <> "/all.info",
            "VER:2\nTN:unit\r\n\nSF:test/coverage_fixtures/nested/deep.gleam\n"
              <> "FN:3,answer\nFNDA:1,answer\nFNF:1\nFNH:1\n"
              <> "DA:4,2,abc123\nBRDA:4,0,0,1\nBRF:1\nBRH:1\nLF:1\nLH:1\n"
              <> "end_of_record\n",
          )
        case measure_with_merge(directory) {
          Ok(coverage_report) ->
            Ok(report.total_hit_line_count(coverage_report))
          other -> Error(string_of(other))
        }
        |> should
        |> be_equal(Ok(3))
        |> or_fail_with("expected deep.gleam line 4 to count as hit")
      }),
    ]),

    group("errors", [
      it("returns NoLcovFilesMatched when nothing matches", fn() {
        let directory = merge_directory()
        case measure_with_merge(directory) {
          Error(error) -> Ok(error)
          other -> Error(string_of(other))
        }
        |> should
        |> be_equal(Ok(NoLcovFilesMatched(directory <> "/*.info")))
        |> or_fail_with("expected NoLcovFilesMatched")
      }),
      it("returns LcovReadFailed when a match is a directory", fn() {
        let directory = merge_directory()
        let _ = write(directory <> "/folder.info/inside.txt", "")
        case measure_with_merge(directory) {
          Error(error) -> Ok(error)
          other -> Error(string_of(other))
        }
        |> should
        |> be_equal(
          Ok(LcovReadFailed(
            directory <> "/folder.info",
            IsDirectory(directory <> "/folder.info"),
          )),
        )
        |> or_fail_with("expected LcovReadFailed")
      }),
      it(
        "returns LcovSourceNotFound for a source file that does not exist",
        fn() {
          let #(directory, result) =
            merge_error("SF:src/does_not_exist.gleam\nDA:1,1\nend_of_record\n")
          result
          |> should
          |> be_equal(
            Ok(LcovSourceNotFound(
              directory <> "/part.info",
              "src/does_not_exist.gleam",
            )),
          )
          |> or_fail_with("expected LcovSourceNotFound")
        },
      ),
      it("returns MalformedLcov for a line that is not LCOV", fn() {
        let #(directory, result) = merge_error("TN:\nhello\n")
        result
        |> should
        |> be_equal(malformed(
          directory,
          2,
          "hello",
          "this is not an LCOV line; LCOV lines start with TN:, SF:, DA:, LF:, LH:, FN:, FNDA:, FNF:, FNH:, BRDA:, BRF:, BRH: or VER:, or are end_of_record.",
        ))
        |> or_fail_with("expected MalformedLcov for hello")
      }),
      it("returns MalformedLcov for DA outside a record", fn() {
        let #(directory, result) = merge_error("DA:1,1\n")
        result
        |> should
        |> be_equal(malformed(
          directory,
          1,
          "DA:1,1",
          "DA appears outside a record (no SF line before it).",
        ))
        |> or_fail_with("expected MalformedLcov for DA outside a record")
      }),
      it("returns MalformedLcov for end_of_record without SF", fn() {
        let #(directory, result) = merge_error("end_of_record\n")
        result
        |> should
        |> be_equal(malformed(
          directory,
          1,
          "end_of_record",
          "end_of_record appears without an SF line before it.",
        ))
        |> or_fail_with("expected MalformedLcov for a lone end_of_record")
      }),
      it("returns MalformedLcov for SF inside an open record", fn() {
        let #(directory, result) =
          merge_error(
            "SF:test/coverage_fixtures/sample.gleam\nSF:test/coverage_fixtures/sample.gleam\n",
          )
        result
        |> should
        |> be_equal(malformed(
          directory,
          2,
          "SF:test/coverage_fixtures/sample.gleam",
          "a new SF record starts before the previous one ends with end_of_record.",
        ))
        |> or_fail_with("expected MalformedLcov for a nested SF")
      }),
      it("returns MalformedLcov for SF without a path", fn() {
        let #(directory, result) = merge_error("SF:\n")
        result
        |> should
        |> be_equal(malformed(
          directory,
          1,
          "SF:",
          "SF must be followed by a source file path.",
        ))
        |> or_fail_with("expected MalformedLcov for SF without a path")
      }),
      it("returns MalformedLcov for a DA line that is not two numbers", fn() {
        let #(directory, result) =
          merge_error("SF:test/coverage_fixtures/sample.gleam\nDA:x,1\n")
        result
        |> should
        |> be_equal(malformed(
          directory,
          2,
          "DA:x,1",
          "DA must be DA:line,count (with an optional checksum), where line is 1 or more and count is 0 or more.",
        ))
        |> or_fail_with("expected MalformedLcov for DA:x,1")
      }),
      it(
        "returns MalformedLcov for a DA line with the wrong number of fields",
        fn() {
          let #(directory, result) =
            merge_error("SF:test/coverage_fixtures/sample.gleam\nDA:1\n")
          result
          |> should
          |> be_equal(malformed(
            directory,
            2,
            "DA:1",
            "DA must be DA:line,count (with an optional checksum), where line is 1 or more and count is 0 or more.",
          ))
          |> or_fail_with("expected MalformedLcov for DA:1")
        },
      ),
      it("returns MalformedLcov when the file ends inside a record", fn() {
        let #(directory, result) =
          merge_error("SF:test/coverage_fixtures/sample.gleam\nDA:7,1\n")
        result
        |> should
        |> be_equal(malformed(
          directory,
          1,
          "SF:test/coverage_fixtures/sample.gleam",
          "this record never ends; every SF record must end with end_of_record.",
        ))
        |> or_fail_with("expected MalformedLcov for a missing end_of_record")
      }),
    ]),
  ])
}
