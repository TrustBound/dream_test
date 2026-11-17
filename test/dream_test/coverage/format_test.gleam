import dream_test/coverage/format
import dream_test/coverage/report.{LineCoverage}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}

fn missed_file() {
  report.file("src/app/cart.gleam", [
    LineCoverage(line: 12, calls: 0),
    LineCoverage(line: 13, calls: 0),
    LineCoverage(line: 15, calls: 1),
    LineCoverage(line: 20, calls: 0),
  ])
}

fn ignored_file(ranges) {
  report.file("src/app/cart.gleam", [])
  |> report.add_ignored_ranges(ranges)
}

fn generated_file() {
  report.excluded_file(
    source_path: "src/app/generated/db.gleam",
    pattern: "src/app/generated/**",
    reason: Some("generated code"),
  )
}

fn ffi_file() {
  report.excluded_file(
    source_path: "src/app_ffi.erl",
    pattern: "src/**/*_ffi.erl",
    reason: None,
  )
}

fn debug_range() {
  report.ignored_range(
    first_line: 40,
    last_line: 44,
    reason: Some("debug only"),
  )
}

fn single_range() {
  report.ignored_range(first_line: 71, last_line: 71, reason: None)
}

pub fn tests() {
  describe("dream_test/coverage/format", [
    it("percent rounds down to one decimal place", fn() {
      format.percent(hit: 58, total: 60)
      |> should
      |> be_equal("96.6%")
      |> or_fail_with("expected 96.6%")
    }),
    it("percent is - with no executable lines", fn() {
      format.percent(hit: 0, total: 0)
      |> should
      |> be_equal("-")
      |> or_fail_with("expected -")
    }),
    it("line_counts writes hit/total", fn() {
      format.line_counts(hit: 18, total: 20)
      |> should
      |> be_equal("18/20")
      |> or_fail_with("expected 18/20")
    }),
    it("file_count writes one file without an s", fn() {
      format.file_count(1)
      |> should
      |> be_equal("1 file")
      |> or_fail_with("expected 1 file")
    }),
    it("file_count writes more files with an s", fn() {
      format.file_count(2)
      |> should
      |> be_equal("2 files")
      |> or_fail_with("expected 2 files")
    }),
    it("line_range writes first-last", fn() {
      format.line_range(first: 12, last: 13)
      |> should
      |> be_equal("12-13")
      |> or_fail_with("expected 12-13")
    }),
    it("line_range writes one number for one line", fn() {
      format.line_range(first: 7, last: 7)
      |> should
      |> be_equal("7")
      |> or_fail_with("expected 7")
    }),
    it("missed_lines writes the missed ranges in line order", fn() {
      format.missed_lines(missed_file())
      |> should
      |> be_equal(["12-13", "20"])
      |> or_fail_with("expected 12-13 and 20")
    }),
    it("ignored_range adds the reason in parentheses", fn() {
      format.ignored_range(debug_range())
      |> should
      |> be_equal("40-44 (debug only)")
      |> or_fail_with("expected the range and the reason")
    }),
    it("ignored_range writes only the range without a reason", fn() {
      format.ignored_range(single_range())
      |> should
      |> be_equal("71")
      |> or_fail_with("expected 71")
    }),
    it("excluded_file names the pattern and the reason", fn() {
      format.excluded_file(generated_file())
      |> should
      |> be_equal("excluded: matches src/app/generated/** (generated code)")
      |> or_fail_with("expected the pattern and the reason")
    }),
    it("excluded_file names only the pattern without a reason", fn() {
      format.excluded_file(ffi_file())
      |> should
      |> be_equal("excluded: matches src/**/*_ffi.erl")
      |> or_fail_with("expected the pattern")
    }),
    it("excluded_summary is None when nothing is left out", fn() {
      format.excluded_summary(report.new([missed_file()]))
      |> should
      |> be_equal(None)
      |> or_fail_with("expected None")
    }),
    it("excluded_summary counts excluded files only", fn() {
      report.new([missed_file()])
      |> report.add_excluded_files([generated_file(), ffi_file()])
      |> format.excluded_summary()
      |> should
      |> be_equal(Some("Excluded: 2 files"))
      |> or_fail_with("expected 2 files")
    }),
    it("excluded_summary counts ignored lines only", fn() {
      report.new([ignored_file([single_range()])])
      |> format.excluded_summary()
      |> should
      |> be_equal(Some("Excluded: 1 line in 1 file"))
      |> or_fail_with("expected 1 line in 1 file")
    }),
    it("excluded_summary counts files and lines", fn() {
      report.new([ignored_file([debug_range(), single_range()])])
      |> report.add_excluded_files([generated_file()])
      |> format.excluded_summary()
      |> should
      |> be_equal(Some("Excluded: 1 file, 6 lines in 1 file"))
      |> or_fail_with("expected 1 file and 6 lines")
    }),
  ])
}
