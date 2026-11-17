import dream_test/coverage/report.{ExcludedFile, IgnoredRange, LineCoverage}
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
  IgnoredRange(first_line: 40, last_line: 44, reason: Some("debug only"))
}

fn single_range() {
  IgnoredRange(first_line: 71, last_line: 71, reason: None)
}

fn generated_file() {
  ExcludedFile(
    source_path: "src/app/generated/db.gleam",
    pattern: "src/app/generated/**",
    reason: Some("generated code"),
  )
}

fn ffi_file() {
  ExcludedFile(
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
    it("an empty report has no lines", fn() {
      report.new([])
      |> report.total_executable_line_count()
      |> should
      |> be_equal(0)
      |> or_fail_with("expected 0 lines")
    }),
  ])
}
