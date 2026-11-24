import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/diff.{Added, NoNewlineAtEnd, Removed, Same}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/doc/reporters/diff/diff_line
import snippets/doc/reporters/diff/format
import snippets/doc/reporters/diff/lines
import snippets/doc/reporters/diff/module
import snippets/doc/reporters/diff/should_diff

pub fn tests() -> TestSuite {
  describe("Doc examples: reporters/diff", [
    it("receipt_diff gives the expected text", fn() {
      // Act
      let text = module.receipt_diff()

      // Assert
      text
      |> should
      |> be_equal(
        "Diff (- expected, + actual):\n    coffee 3.50\n  - croissant 2.75\n  - TOTAL 6.25\n  + croissant 2.95\n  + TOTAL 6.45\n",
      )
      |> or_fail_with("expected receipt_diff to give the expected text")
    }),
    it("final_newline_lines gives the expected lines", fn() {
      // Act
      let result = diff_line.final_newline_lines()

      // Assert
      result
      |> should
      |> be_equal([Same("a"), Removed("b"), Added("b"), NoNewlineAtEnd])
      |> or_fail_with("expected final_newline_lines to give the expected lines")
    }),
    it("one_changed_line gives the expected lines", fn() {
      // Act
      let result = lines.one_changed_line()

      // Assert
      result
      |> should
      |> be_equal([Same("a"), Removed("b"), Added("B"), Same("c")])
      |> or_fail_with("expected one_changed_line to give the expected lines")
    }),
    it("two_lines_show_as_a_diff gives True", fn() {
      // Act
      let result = should_diff.two_lines_show_as_a_diff()

      // Assert
      result
      |> should
      |> be_equal(True)
      |> or_fail_with("expected two_lines_show_as_a_diff to give True")
    }),
    it("one_line_shows_as_two_lines gives False", fn() {
      // Act
      let result = should_diff.one_line_shows_as_two_lines()

      // Assert
      result
      |> should
      |> be_equal(False)
      |> or_fail_with("expected one_line_shows_as_two_lines to give False")
    }),
    it("final_newline_diff gives the expected text", fn() {
      // Act
      let text = format.final_newline_diff()

      // Assert
      text
      |> should
      |> be_equal(
        "Diff (- expected, + actual):\n    a\n  - b\n  + b\n  \\ No newline at end of text\n",
      )
      |> or_fail_with("expected final_newline_diff to give the expected text")
    }),
  ])
}
