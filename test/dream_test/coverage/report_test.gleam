import dream_test/coverage/report.{LineCoverage}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}

fn cart_file() {
  report.file("src/app/cart.gleam", [
    LineCoverage(line: 9, calls: 1),
    LineCoverage(line: 3, calls: 2),
    LineCoverage(line: 4, calls: 0),
  ])
}

fn types_file() {
  report.file("src/app/types.gleam", [])
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

pub fn tests() {
  describe("dream_test/coverage/report", [
    it("files returns the files in the order given", fn() {
      report.new([types_file(), cart_file()])
      |> report.files()
      |> should
      |> be_equal([types_file(), cart_file()])
      |> or_fail_with("expected the files in the order given")
    }),
    it("source_path returns the path given to file", fn() {
      report.source_path(cart_file())
      |> should
      |> be_equal("src/app/cart.gleam")
      |> or_fail_with("expected src/app/cart.gleam")
    }),
    it("missed_ranges merges consecutive missed lines", fn() {
      report.file("src/a.gleam", [
        LineCoverage(line: 5, calls: 0),
        LineCoverage(line: 1, calls: 0),
        LineCoverage(line: 2, calls: 0),
        LineCoverage(line: 3, calls: 1),
        LineCoverage(line: 7, calls: 0),
        LineCoverage(line: 8, calls: 0),
      ])
      |> report.missed_ranges()
      |> should
      |> be_equal([#(1, 2), #(5, 5), #(7, 8)])
      |> or_fail_with("expected 1-2, 5 and 7-8")
    }),
    it("missed_ranges is empty when every line ran", fn() {
      report.missed_ranges(types_file())
      |> should
      |> be_equal([])
      |> or_fail_with("expected no ranges")
    }),
    it("lines returns the lines sorted by line number", fn() {
      report.lines(cart_file())
      |> should
      |> be_equal([
        LineCoverage(line: 3, calls: 2),
        LineCoverage(line: 4, calls: 0),
        LineCoverage(line: 9, calls: 1),
      ])
      |> or_fail_with("expected lines 3, 4, 9")
    }),
    it("hit_line_count counts lines that ran at least once", fn() {
      report.hit_line_count(cart_file())
      |> should
      |> be_equal(2)
      |> or_fail_with("expected 2 hit lines")
    }),
    it("executable_line_count counts every line", fn() {
      report.executable_line_count(cart_file())
      |> should
      |> be_equal(3)
      |> or_fail_with("expected 3 executable lines")
    }),
    it("total_hit_line_count adds up every file", fn() {
      report.new([cart_file(), types_file(), cart_file()])
      |> report.total_hit_line_count()
      |> should
      |> be_equal(4)
      |> or_fail_with("expected 4 hit lines in total")
    }),
    it("total_executable_line_count adds up every file", fn() {
      report.new([cart_file(), types_file(), cart_file()])
      |> report.total_executable_line_count()
      |> should
      |> be_equal(6)
      |> or_fail_with("expected 6 executable lines in total")
    }),
    it("a file built with file has no ignored ranges", fn() {
      report.ignored_ranges(cart_file())
      |> should
      |> be_equal([])
      |> or_fail_with("expected no ignored ranges")
    }),
    it("add_ignored_ranges adds ranges sorted by first line", fn() {
      cart_file()
      |> report.add_ignored_ranges([single_range()])
      |> report.add_ignored_ranges([debug_range()])
      |> report.ignored_ranges()
      |> should
      |> be_equal([debug_range(), single_range()])
      |> or_fail_with("expected 40-44, then 71")
    }),
    it("add_ignored_ranges does not change the counts", fn() {
      cart_file()
      |> report.add_ignored_ranges([debug_range()])
      |> report.executable_line_count()
      |> should
      |> be_equal(3)
      |> or_fail_with("expected 3 executable lines")
    }),
    it("a report built with new has no excluded files", fn() {
      report.new([cart_file()])
      |> report.excluded_files()
      |> should
      |> be_equal([])
      |> or_fail_with("expected no excluded files")
    }),
    it("add_excluded_files adds files in the order given", fn() {
      report.new([cart_file()])
      |> report.add_excluded_files([generated_file()])
      |> report.add_excluded_files([ffi_file()])
      |> report.excluded_files()
      |> should
      |> be_equal([generated_file(), ffi_file()])
      |> or_fail_with("expected the generated file, then the FFI file")
    }),
    it("a report built with new has no inexact line files", fn() {
      report.new([cart_file()])
      |> report.inexact_line_files()
      |> should
      |> be_equal([])
      |> or_fail_with("expected no inexact line files")
    }),
    it("add_inexact_line_files adds files in the order given", fn() {
      report.new([cart_file()])
      |> report.add_inexact_line_files(["src/app/cart.gleam"])
      |> report.add_inexact_line_files(["src/app/a.gleam", "src/app/b.gleam"])
      |> report.inexact_line_files()
      |> should
      |> be_equal(["src/app/cart.gleam", "src/app/a.gleam", "src/app/b.gleam"])
      |> or_fail_with("expected the cart file, then a, then b")
    }),
    it("ignored_first_line returns the first line given", fn() {
      report.ignored_first_line(debug_range())
      |> should
      |> be_equal(40)
      |> or_fail_with("expected first line 40")
    }),
    it("ignored_last_line returns the last line given", fn() {
      report.ignored_last_line(debug_range())
      |> should
      |> be_equal(44)
      |> or_fail_with("expected last line 44")
    }),
    it("ignored_reason returns the reason given", fn() {
      report.ignored_reason(debug_range())
      |> should
      |> be_equal(Some("debug only"))
      |> or_fail_with("expected Some(\"debug only\")")
    }),
    it("ignored_reason returns None for a marker with no text", fn() {
      report.ignored_reason(single_range())
      |> should
      |> be_equal(None)
      |> or_fail_with("expected None")
    }),
    it("excluded_source_path returns the path given", fn() {
      report.excluded_source_path(generated_file())
      |> should
      |> be_equal("src/app/generated/db.gleam")
      |> or_fail_with("expected src/app/generated/db.gleam")
    }),
    it("excluded_pattern returns the pattern given", fn() {
      report.excluded_pattern(generated_file())
      |> should
      |> be_equal("src/app/generated/**")
      |> or_fail_with("expected src/app/generated/**")
    }),
    it("excluded_reason returns the reason given", fn() {
      report.excluded_reason(generated_file())
      |> should
      |> be_equal(Some("generated code"))
      |> or_fail_with("expected Some(\"generated code\")")
    }),
    it("excluded_reason returns None for a pattern with no reason", fn() {
      report.excluded_reason(ffi_file())
      |> should
      |> be_equal(None)
      |> or_fail_with("expected None")
    }),
    it("an empty report has no lines", fn() {
      report.new([])
      |> report.total_executable_line_count()
      |> should
      |> be_equal(0)
      |> or_fail_with("expected 0 lines")
    }),
  ])
}
