import dream_test/coverage/report.{LineCoverage}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}

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
    it("an empty report has no lines", fn() {
      report.new([])
      |> report.total_executable_line_count()
      |> should
      |> be_equal(0)
      |> or_fail_with("expected 0 lines")
    }),
  ])
}
