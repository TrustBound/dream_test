import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{None}
import snippets/doc/coverage/format/escape_markup
import snippets/doc/coverage/format/excluded_file
import snippets/doc/coverage/format/excluded_summary
import snippets/doc/coverage/format/file_count
import snippets/doc/coverage/format/ignored_range
import snippets/doc/coverage/format/line_counts
import snippets/doc/coverage/format/line_range
import snippets/doc/coverage/format/missed_lines
import snippets/doc/coverage/format/module
import snippets/doc/coverage/format/module_import_style
import snippets/doc/coverage/format/percent

pub fn tests() {
  describe("Doc examples: coverage/format", [
    it("ninety_percent gives the documented result", fn() {
      // Act
      let result = module.ninety_percent()

      // Assert
      result
      |> should
      |> be_equal("90.0%")
      |> or_fail_with("expected ninety_percent to give the documented result")
    }),
    it("all_lines_ran gives the documented result", fn() {
      // Act
      let result = module_import_style.all_lines_ran()

      // Assert
      result
      |> should
      |> be_equal("100.0%")
      |> or_fail_with("expected all_lines_ran to give the documented result")
    }),
    it("percent_rounds_down gives the documented result", fn() {
      // Act
      let result = percent.percent_rounds_down()

      // Assert
      result
      |> should
      |> be_equal("96.6%")
      |> or_fail_with(
        "expected percent_rounds_down to give the documented result",
      )
    }),
    it("eighteen_of_twenty gives the documented result", fn() {
      // Act
      let result = line_counts.eighteen_of_twenty()

      // Assert
      result
      |> should
      |> be_equal("18/20")
      |> or_fail_with(
        "expected eighteen_of_twenty to give the documented result",
      )
    }),
    it("lines_twelve_to_thirteen gives the documented result", fn() {
      // Act
      let result = line_range.lines_twelve_to_thirteen()

      // Assert
      result
      |> should
      |> be_equal("12-13")
      |> or_fail_with(
        "expected lines_twelve_to_thirteen to give the documented result",
      )
    }),
    it("missed_lines_of_file gives the documented result", fn() {
      // Act
      let result = missed_lines.missed_lines_of_file()

      // Assert
      result
      |> should
      |> be_equal(["12-13", "20"])
      |> or_fail_with(
        "expected missed_lines_of_file to give the documented result",
      )
    }),
    it("debug_only_range_text gives the documented result", fn() {
      // Act
      let result = ignored_range.debug_only_range_text()

      // Assert
      result
      |> should
      |> be_equal("40-44 (debug only)")
      |> or_fail_with(
        "expected debug_only_range_text to give the documented result",
      )
    }),
    it("generated_file_text gives the documented result", fn() {
      // Act
      let result = excluded_file.generated_file_text()

      // Assert
      result
      |> should
      |> be_equal("excluded: matches src/app/generated/** (generated code)")
      |> or_fail_with(
        "expected generated_file_text to give the documented result",
      )
    }),
    it("nothing_was_excluded gives the documented result", fn() {
      // Act
      let result = excluded_summary.nothing_was_excluded()

      // Assert
      result
      |> should
      |> be_equal(None)
      |> or_fail_with(
        "expected nothing_was_excluded to give the documented result",
      )
    }),
    it("two_files gives the documented result", fn() {
      // Act
      let result = file_count.two_files()

      // Assert
      result
      |> should
      |> be_equal("2 files")
      |> or_fail_with("expected two_files to give the documented result")
    }),
    it("escaped_comparison gives the documented result", fn() {
      // Act
      let result = escape_markup.escaped_comparison()

      // Assert
      result
      |> should
      |> be_equal("a &lt; b &amp;&amp; c")
      |> or_fail_with(
        "expected escaped_comparison to give the documented result",
      )
    }),
  ])
}
