import dream_test/matchers.{be_equal, be_false, be_true, or_fail_with, should}
import dream_test/reporters/diff.{Added, NoNewlineAtEnd, Removed, Same}
import dream_test/unit.{describe, group, it}
import gleam/int
import gleam/list
import gleam/string

/// The lines `<prefix>1` to `<prefix><count>`.
fn numbered(prefix: String, count: Int) -> List(String) {
  numbered_from(prefix, count, [])
}

fn numbered_from(
  prefix: String,
  number: Int,
  later_lines: List(String),
) -> List(String) {
  case number {
    0 -> later_lines
    _ ->
      numbered_from(prefix, number - 1, [
        prefix <> int.to_string(number),
        ..later_lines
      ])
  }
}

/// The numbers 1 to `count`, one on each line, with no final newline.
fn number_lines(count: Int) -> String {
  string.join(numbered("", count), "\n")
}

pub fn tests() {
  describe("dream_test/reporters/diff", [
    group("lines", [
      it("gives only Same lines for equal texts", fn() {
        // Act
        let result = diff.lines(expected: "a\nb", actual: "a\nb")

        // Assert
        result
        |> should
        |> be_equal([Same("a"), Same("b")])
        |> or_fail_with("equal texts should have no change")
      }),
      it("gives a removed and an added line for one changed line", fn() {
        // Act
        let result = diff.lines(expected: "a\nb\nc", actual: "a\nB\nc")

        // Assert
        result
        |> should
        |> be_equal([Same("a"), Removed("b"), Added("B"), Same("c")])
        |> or_fail_with("the changed line should be removed, then added")
      }),
      it("gives a removed line and an added line at their places", fn() {
        // Act
        let result = diff.lines(expected: "a\nb\nc", actual: "a\nc\nd")

        // Assert
        result
        |> should
        |> be_equal([Same("a"), Removed("b"), Same("c"), Added("d")])
        |> or_fail_with("b should be removed and d added")
      }),
      it("keeps the longest run of common lines", fn() {
        // Act
        let result =
          diff.lines(expected: "a\nb\nc\nd\ne", actual: "a\nc\nb\nd\ne")

        // Assert
        result
        |> should
        |> be_equal([
          Same("a"),
          Removed("b"),
          Same("c"),
          Added("b"),
          Same("d"),
          Same("e"),
        ])
        |> or_fail_with("four of the five lines should be the same")
      }),
      it("gives a change at the start", fn() {
        // Act
        let result = diff.lines(expected: "x\nb\nc", actual: "y\nb\nc")

        // Assert
        result
        |> should
        |> be_equal([Removed("x"), Added("y"), Same("b"), Same("c")])
        |> or_fail_with("the first line should change")
      }),
      it("gives a change at the end", fn() {
        // Act
        let result = diff.lines(expected: "a\nb\nx", actual: "a\nb\ny")

        // Assert
        result
        |> should
        |> be_equal([Same("a"), Same("b"), Removed("x"), Added("y")])
        |> or_fail_with("the last line should change")
      }),
      it("gives every line as added for an empty expected text", fn() {
        // Act
        let result = diff.lines(expected: "", actual: "a\nb")

        // Assert
        result
        |> should
        |> be_equal([Added("a"), Added("b")])
        |> or_fail_with("every actual line should be added")
      }),
      it("gives every line as removed for an empty actual text", fn() {
        // Act
        let result = diff.lines(expected: "a\nb", actual: "")

        // Assert
        result
        |> should
        |> be_equal([Removed("a"), Removed("b")])
        |> or_fail_with("every expected line should be removed")
      }),
      it("marks the actual line that has no final newline", fn() {
        // Act
        let result = diff.lines(expected: "a\nb\n", actual: "a\nb")

        // Assert
        result
        |> should
        |> be_equal([Same("a"), Removed("b"), Added("b"), NoNewlineAtEnd])
        |> or_fail_with("the last line should differ in its newline")
      }),
      it("marks the expected line that has no final newline", fn() {
        // Act
        let result = diff.lines(expected: "a\nb", actual: "a\nb\n")

        // Assert
        result
        |> should
        |> be_equal([Same("a"), Removed("b"), NoNewlineAtEnd, Added("b")])
        |> or_fail_with("the last line should differ in its newline")
      }),
      it("gives a line with trailing whitespace as changed", fn() {
        // Act
        let result = diff.lines(expected: "a \nb", actual: "a\nb")

        // Assert
        result
        |> should
        |> be_equal([Removed("a "), Added("a"), Same("b")])
        |> or_fail_with("the trailing space should change the line")
      }),
      it(
        "gives the changed part as removed, then added, above the size limit",
        fn() {
          // Arrange
          let expected_lines = numbered("e", 1001)
          let actual_lines = numbered("a", 1000)
          let expected = string.join(["top", ..expected_lines], "\n")
          let actual = string.join(["top", ..actual_lines], "\n")

          // Act
          let result = diff.lines(expected: expected, actual: actual)

          // Assert
          result
          |> should
          |> be_equal(
            list.flatten([
              [Same("top")],
              list.map(expected_lines, Removed),
              list.map(actual_lines, Added),
            ]),
          )
          |> or_fail_with("1001 x 1000 line pairs should not be compared")
        },
      ),
    ]),
    group("should_diff", [
      it("is True when the expected text has more than one line", fn() {
        // Act
        let result = diff.should_diff(expected: "a\nb", actual: "a")

        // Assert
        result
        |> should
        |> be_true()
        |> or_fail_with("a text of two lines should show as a diff")
      }),
      it("is True when the actual text has more than one line", fn() {
        // Act
        let result = diff.should_diff(expected: "a", actual: "a\n")

        // Assert
        result
        |> should
        |> be_true()
        |> or_fail_with("a text with a newline should show as a diff")
      }),
      it("is True when the texts differ only in trailing whitespace", fn() {
        // Act
        let result = diff.should_diff(expected: "a ", actual: "a")

        // Assert
        result
        |> should
        |> be_true()
        |> or_fail_with("trailing whitespace should show as a diff")
      }),
      it("is False for two different texts of one line", fn() {
        // Act
        let result = diff.should_diff(expected: "1", actual: "2")

        // Assert
        result
        |> should
        |> be_false()
        |> or_fail_with("one-line values should keep Expected and Actual")
      }),
    ]),
    group("format", [
      it("shows the changed lines between the same lines", fn() {
        // Act
        let text =
          diff.format(
            expected: "coffee...... 3.50\ncroissant... 2.75\nTOTAL 6.25",
            actual: "coffee...... 3.50\ncroissant... 2.95\nTOTAL 6.45",
            indent: "  ",
            color: False,
          )

        // Assert
        text
        |> should
        |> be_equal(
          "  Diff (- expected, + actual):\n"
          <> "      coffee...... 3.50\n"
          <> "    - croissant... 2.75\n"
          <> "    - TOTAL 6.25\n"
          <> "    + croissant... 2.95\n"
          <> "    + TOTAL 6.45\n",
        )
        |> or_fail_with("expected the receipt diff")
      }),
      it("hides the same lines more than 3 lines from a change", fn() {
        // Act
        let text =
          diff.format(
            expected: number_lines(20),
            actual: string.replace(number_lines(20), "\n10\n", "\nten\n"),
            indent: "  ",
            color: False,
          )

        // Assert
        text
        |> should
        |> be_equal(
          "  Diff (- expected, + actual):\n"
          <> "    ... 6 unchanged lines\n"
          <> "      7\n"
          <> "      8\n"
          <> "      9\n"
          <> "    - 10\n"
          <> "    + ten\n"
          <> "      11\n"
          <> "      12\n"
          <> "      13\n"
          <> "    ... 7 unchanged lines\n",
        )
        |> or_fail_with("expected 3 lines of context around the change")
      }),
      it("hides the middle of a long run between two changes", fn() {
        // Act
        let text =
          diff.format(
            expected: number_lines(12),
            actual: number_lines(12)
              |> string.replace("\n2\n", "\ntwo\n")
              |> string.replace("\n11\n", "\neleven\n"),
            indent: "",
            color: False,
          )

        // Assert
        text
        |> should
        |> be_equal(
          "Diff (- expected, + actual):\n"
          <> "    1\n"
          <> "  - 2\n"
          <> "  + two\n"
          <> "    3\n"
          <> "    4\n"
          <> "    5\n"
          <> "  ... 2 unchanged lines\n"
          <> "    8\n"
          <> "    9\n"
          <> "    10\n"
          <> "  - 11\n"
          <> "  + eleven\n"
          <> "    12\n",
        )
        |> or_fail_with("expected lines 6 and 7 hidden")
      }),
      it("names one hidden line in the singular", fn() {
        // Act
        let text =
          diff.format(
            expected: "1\n2\n3\n4\n5",
            actual: "1\n2\n3\n4\nfive",
            indent: "",
            color: False,
          )

        // Assert
        text
        |> should
        |> be_equal(
          "Diff (- expected, + actual):\n"
          <> "  ... 1 unchanged line\n"
          <> "    2\n"
          <> "    3\n"
          <> "    4\n"
          <> "  - 5\n"
          <> "  + five\n",
        )
        |> or_fail_with("expected line 1 hidden")
      }),
      it("shows trailing spaces, tabs and carriage returns", fn() {
        // Act
        let text =
          diff.format(
            expected: "total 6.25 \t\r\nend",
            actual: "total 6.25\nend",
            indent: "",
            color: False,
          )

        // Assert
        text
        |> should
        |> be_equal(
          "Diff (- expected, + actual):\n"
          <> "  - total 6.25·→␍\n"
          <> "  + total 6.25\n"
          <> "    end\n",
        )
        |> or_fail_with("expected the trailing whitespace made visible")
      }),
      it("shows a missing final newline", fn() {
        // Act
        let text =
          diff.format(
            expected: "a\nb\n",
            actual: "a\nb",
            indent: "",
            color: False,
          )

        // Assert
        text
        |> should
        |> be_equal(
          "Diff (- expected, + actual):\n"
          <> "    a\n"
          <> "  - b\n"
          <> "  + b\n"
          <> "  \\ No newline at end of text\n",
        )
        |> or_fail_with("expected the newline marker after the actual line")
      }),
      it("shows every line of a text against an empty text", fn() {
        // Act
        let text =
          diff.format(expected: "", actual: "a\nb", indent: "", color: False)

        // Assert
        text
        |> should
        |> be_equal("Diff (- expected, + actual):\n" <> "  + a\n" <> "  + b\n")
        |> or_fail_with("expected two added lines")
      }),
      it("shows a removed empty line as a lone marker", fn() {
        // Act
        let text =
          diff.format(
            expected: "a\n\nb",
            actual: "a\nb",
            indent: "",
            color: False,
          )

        // Assert
        text
        |> should
        |> be_equal(
          "Diff (- expected, + actual):\n" <> "    a\n" <> "  -\n" <> "    b\n",
        )
        |> or_fail_with("expected the empty line as a lone -")
      }),
      it("shows an empty same line as an empty line", fn() {
        // Act
        let text =
          diff.format(
            expected: "a\n\nb\nc",
            actual: "a\n\nb\nd",
            indent: "",
            color: False,
          )

        // Assert
        text
        |> should
        |> be_equal(
          "Diff (- expected, + actual):\n"
          <> "    a\n"
          <> "\n"
          <> "    b\n"
          <> "  - c\n"
          <> "  + d\n",
        )
        |> or_fail_with("expected no trailing spaces on the empty line")
      }),
      it("shows at most 100 lines of a long diff", fn() {
        // Arrange
        let expected_lines = numbered("e", 150)
        let actual_lines = numbered("a", 150)

        // Act
        let text =
          diff.format(
            expected: string.join(expected_lines, "\n"),
            actual: string.join(actual_lines, "\n"),
            indent: "",
            color: False,
          )

        // Assert
        text
        |> should
        |> be_equal(
          "Diff (- expected, + actual):\n"
          <> string.concat(
            list.map(list.take(expected_lines, 100), fn(line) {
              "  - " <> line <> "\n"
            }),
          )
          <> "  ... 200 more lines of the diff\n",
        )
        |> or_fail_with("expected the first 100 lines")
      }),
      it("says so when the changed part is too large to compare", fn() {
        // Arrange
        let expected_lines = numbered("e", 1001)
        let actual_lines = numbered("a", 1000)

        // Act
        let text =
          diff.format(
            expected: string.join(expected_lines, "\n"),
            actual: string.join(actual_lines, "\n"),
            indent: "",
            color: False,
          )

        // Assert
        text
        |> should
        |> be_equal(
          "Diff (- expected, + actual):\n"
          <> "  (too large to match line by line: the changed lines show as removed, then added)\n"
          <> string.concat(
            list.map(list.take(expected_lines, 100), fn(line) {
              "  - " <> line <> "\n"
            }),
          )
          <> "  ... 1901 more lines of the diff\n",
        )
        |> or_fail_with("expected the note and the first 100 lines")
      }),
      it("colours each kind of line", fn() {
        // Act
        let text =
          diff.format(
            expected: "1\n2\n3\n4\nx\n",
            actual: "1\n2\n3\n4\ny",
            indent: "",
            color: True,
          )

        // Assert
        text
        |> should
        |> be_equal(
          "\u{1b}[2mDiff (- expected, + actual):\u{1b}[0m\n"
          <> "  \u{1b}[2m... 1 unchanged line\u{1b}[0m\n"
          <> "    2\n"
          <> "    3\n"
          <> "    4\n"
          <> "  \u{1b}[32m- x\u{1b}[0m\n"
          <> "  \u{1b}[31m+ y\u{1b}[0m\n"
          <> "  \u{1b}[2m\\ No newline at end of text\u{1b}[0m\n",
        )
        |> or_fail_with("expected - in green, + in red, and the rest dim")
      }),
    ]),
  ])
}
