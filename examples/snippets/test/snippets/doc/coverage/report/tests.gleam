import dream_test/coverage/report.{LineCoverage}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}
import snippets/doc/coverage/report/add_excluded_files
import snippets/doc/coverage/report/add_ignored_ranges
import snippets/doc/coverage/report/add_inexact_line_files
import snippets/doc/coverage/report/excluded_file
import snippets/doc/coverage/report/excluded_files
import snippets/doc/coverage/report/excluded_pattern
import snippets/doc/coverage/report/excluded_reason
import snippets/doc/coverage/report/excluded_source_path
import snippets/doc/coverage/report/executable_line_count
import snippets/doc/coverage/report/file
import snippets/doc/coverage/report/files
import snippets/doc/coverage/report/hit_line_count
import snippets/doc/coverage/report/ignored_first_line
import snippets/doc/coverage/report/ignored_last_line
import snippets/doc/coverage/report/ignored_range
import snippets/doc/coverage/report/ignored_ranges
import snippets/doc/coverage/report/ignored_reason
import snippets/doc/coverage/report/inexact_line_files
import snippets/doc/coverage/report/lines
import snippets/doc/coverage/report/missed_ranges
import snippets/doc/coverage/report/module
import snippets/doc/coverage/report/module_import_style
import snippets/doc/coverage/report/new
import snippets/doc/coverage/report/source_path
import snippets/doc/coverage/report/total_executable_line_count
import snippets/doc/coverage/report/total_hit_line_count
import snippets_child_vm.{ChildRun, it_runs_in_child_vm}

pub fn tests() {
  describe("Doc examples: coverage/report", [
    it_runs_in_child_vm("print_summary prints one line for each file", fn() {
      // Act
      let result =
        snippets_child_vm.run(
          "snippets/doc/coverage/report/tests",
          "print_summary_of_two_files",
        )

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: "src/app/cart.gleam: 2/3\nsrc/app/order.gleam: 0/1\n",
          error_output: "",
        )),
      )
      |> or_fail_with("expected the lines that ran in each file")
    }),
    it("cart_report gives the documented result", fn() {
      // Act
      let result = module_import_style.cart_report()

      // Assert
      result
      |> should
      |> be_equal(
        report.new([
          report.file("src/app/cart.gleam", [LineCoverage(line: 3, calls: 1)]),
        ]),
      )
      |> or_fail_with("expected cart_report to give the documented result")
    }),
    it("debug_only_range keeps the first line", fn() {
      // Arrange
      let range = ignored_range.debug_only_range()

      // Act
      let result = report.ignored_first_line(range)

      // Assert
      result
      |> should
      |> be_equal(40)
      |> or_fail_with("expected debug_only_range to start at line 40")
    }),
    it("debug_only_range keeps the reason", fn() {
      // Arrange
      let range = ignored_range.debug_only_range()

      // Act
      let result = report.ignored_reason(range)

      // Assert
      result
      |> should
      |> be_equal(Some("debug only"))
      |> or_fail_with("expected debug_only_range to keep its reason")
    }),
    it("range_starts_at_line_forty gives the documented result", fn() {
      // Act
      let result = ignored_first_line.range_starts_at_line_forty()

      // Assert
      result
      |> should
      |> be_equal(40)
      |> or_fail_with(
        "expected range_starts_at_line_forty to give the documented result",
      )
    }),
    it("range_ends_at_line_forty_four gives the documented result", fn() {
      // Act
      let result = ignored_last_line.range_ends_at_line_forty_four()

      // Assert
      result
      |> should
      |> be_equal(44)
      |> or_fail_with(
        "expected range_ends_at_line_forty_four to give the documented result",
      )
    }),
    it("range_reason_is_debug_only gives the documented result", fn() {
      // Act
      let result = ignored_reason.range_reason_is_debug_only()

      // Assert
      result
      |> should
      |> be_equal(Some("debug only"))
      |> or_fail_with(
        "expected range_reason_is_debug_only to give the documented result",
      )
    }),
    it("generated_database_file holds the expected value", fn() {
      // Arrange
      let value = excluded_file.generated_database_file()

      // Act
      let result = report.excluded_reason(value)

      // Assert
      result
      |> should
      |> be_equal(Some("generated code"))
      |> or_fail_with(
        "expected generated_database_file to hold the expected value",
      )
    }),
    it("excluded_path_is_generated_database gives the documented result", fn() {
      // Act
      let result = excluded_source_path.excluded_path_is_generated_database()

      // Assert
      result
      |> should
      |> be_equal("src/app/generated/db.gleam")
      |> or_fail_with(
        "expected excluded_path_is_generated_database to give the documented result",
      )
    }),
    it("excluded_pattern_is_generated_folder gives the documented result", fn() {
      // Act
      let result = excluded_pattern.excluded_pattern_is_generated_folder()

      // Assert
      result
      |> should
      |> be_equal("src/app/generated/**")
      |> or_fail_with(
        "expected excluded_pattern_is_generated_folder to give the documented result",
      )
    }),
    it("excluded_reason_is_generated_code gives the documented result", fn() {
      // Act
      let result = excluded_reason.excluded_reason_is_generated_code()

      // Assert
      result
      |> should
      |> be_equal(Some("generated code"))
      |> or_fail_with(
        "expected excluded_reason_is_generated_code to give the documented result",
      )
    }),
    it("report_with_one_file holds the expected value", fn() {
      // Arrange
      let value = new.report_with_one_file()

      // Act
      let result = report.files(value)

      // Assert
      result
      |> should
      |> be_equal([
        report.file("src/app/cart.gleam", [LineCoverage(line: 3, calls: 1)]),
      ])
      |> or_fail_with(
        "expected report_with_one_file to hold the expected value",
      )
    }),
    it("cart_file_with_sorted_lines holds the expected value", fn() {
      // Arrange
      let value = file.cart_file_with_sorted_lines()

      // Act
      let result = report.lines(value)

      // Assert
      result
      |> should
      |> be_equal([
        LineCoverage(line: 3, calls: 2),
        LineCoverage(line: 4, calls: 0),
      ])
      |> or_fail_with(
        "expected cart_file_with_sorted_lines to hold the expected value",
      )
    }),
    it("cart_file_with_debug_lines_ignored holds the expected value", fn() {
      // Arrange
      let value = add_ignored_ranges.cart_file_with_debug_lines_ignored()

      // Act
      let result = report.ignored_ranges(value)

      // Assert
      result
      |> should
      |> be_equal([
        report.ignored_range(
          first_line: 40,
          last_line: 44,
          reason: Some("debug only"),
        ),
      ])
      |> or_fail_with(
        "expected cart_file_with_debug_lines_ignored to hold the expected value",
      )
    }),
    it("ignored_ranges_of_cart_file gives the documented result", fn() {
      // Act
      let result = ignored_ranges.ignored_ranges_of_cart_file()

      // Assert
      result
      |> should
      |> be_equal([
        report.ignored_range(first_line: 71, last_line: 71, reason: None),
      ])
      |> or_fail_with(
        "expected ignored_ranges_of_cart_file to give the documented result",
      )
    }),
    it("report_with_generated_file_excluded holds the expected value", fn() {
      // Arrange
      let value = add_excluded_files.report_with_generated_file_excluded()

      // Act
      let result = report.excluded_files(value)

      // Assert
      result
      |> should
      |> be_equal([
        report.excluded_file(
          source_path: "src/app/generated/db.gleam",
          pattern: "src/app/generated/**",
          reason: Some("generated code"),
        ),
      ])
      |> or_fail_with(
        "expected report_with_generated_file_excluded to hold the expected value",
      )
    }),
    it("excluded_files_of_report gives the documented result", fn() {
      // Act
      let result = excluded_files.excluded_files_of_report()

      // Assert
      result
      |> should
      |> be_equal([
        report.excluded_file(
          source_path: "src/app/generated/db.gleam",
          pattern: "src/app/generated/**",
          reason: None,
        ),
      ])
      |> or_fail_with(
        "expected excluded_files_of_report to give the documented result",
      )
    }),
    it("report_with_inexact_cart_lines holds the expected value", fn() {
      // Arrange
      let value = add_inexact_line_files.report_with_inexact_cart_lines()

      // Act
      let result = report.inexact_line_files(value)

      // Assert
      result
      |> should
      |> be_equal(["src/app/cart.gleam"])
      |> or_fail_with(
        "expected report_with_inexact_cart_lines to hold the expected value",
      )
    }),
    it("inexact_line_files_of_report gives the documented result", fn() {
      // Act
      let result = inexact_line_files.inexact_line_files_of_report()

      // Assert
      result
      |> should
      |> be_equal(["src/app/cart.gleam"])
      |> or_fail_with(
        "expected inexact_line_files_of_report to give the documented result",
      )
    }),
    it("files_of_report gives the documented result", fn() {
      // Act
      let result = files.files_of_report()

      // Assert
      result
      |> should
      |> be_equal([
        report.file("src/app/cart.gleam", [LineCoverage(line: 3, calls: 1)]),
      ])
      |> or_fail_with("expected files_of_report to give the documented result")
    }),
    it("source_path_of_cart_file gives the documented result", fn() {
      // Act
      let result = source_path.source_path_of_cart_file()

      // Assert
      result
      |> should
      |> be_equal("src/app/cart.gleam")
      |> or_fail_with(
        "expected source_path_of_cart_file to give the documented result",
      )
    }),
    it("lines_of_file gives the documented result", fn() {
      // Act
      let result = lines.lines_of_file()

      // Assert
      result
      |> should
      |> be_equal([LineCoverage(line: 3, calls: 1)])
      |> or_fail_with("expected lines_of_file to give the documented result")
    }),
    it("missed_ranges_of_file gives the documented result", fn() {
      // Act
      let result = missed_ranges.missed_ranges_of_file()

      // Assert
      result
      |> should
      |> be_equal([#(1, 2), #(5, 5)])
      |> or_fail_with(
        "expected missed_ranges_of_file to give the documented result",
      )
    }),
    it("one_line_was_hit gives the documented result", fn() {
      // Act
      let result = hit_line_count.one_line_was_hit()

      // Assert
      result
      |> should
      |> be_equal(1)
      |> or_fail_with("expected one_line_was_hit to give the documented result")
    }),
    it("two_lines_are_executable gives the documented result", fn() {
      // Act
      let result = executable_line_count.two_lines_are_executable()

      // Assert
      result
      |> should
      |> be_equal(2)
      |> or_fail_with(
        "expected two_lines_are_executable to give the documented result",
      )
    }),
    it("hit_lines_in_all_files gives the documented result", fn() {
      // Act
      let result = total_hit_line_count.hit_lines_in_all_files()

      // Assert
      result
      |> should
      |> be_equal(2)
      |> or_fail_with(
        "expected hit_lines_in_all_files to give the documented result",
      )
    }),
    it("executable_lines_in_all_files gives the documented result", fn() {
      // Act
      let result = total_executable_line_count.executable_lines_in_all_files()

      // Assert
      result
      |> should
      |> be_equal(3)
      |> or_fail_with(
        "expected executable_lines_in_all_files to give the documented result",
      )
    }),
  ])
}

/// For the child VM: print the summary of a report of two files, where two
/// of the three lines of the first file ran.
pub fn print_summary_of_two_files() -> Nil {
  module.print_summary(
    report.new([
      report.file("src/app/cart.gleam", [
        LineCoverage(line: 1, calls: 1),
        LineCoverage(line: 2, calls: 4),
        LineCoverage(line: 3, calls: 0),
      ]),
      report.file("src/app/order.gleam", [LineCoverage(line: 1, calls: 0)]),
    ]),
  )
}
