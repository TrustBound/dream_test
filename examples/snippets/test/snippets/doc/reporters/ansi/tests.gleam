import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/doc/reporters/ansi/apply_if
import snippets/doc/reporters/ansi/bold
import snippets/doc/reporters/ansi/cyan
import snippets/doc/reporters/ansi/dim
import snippets/doc/reporters/ansi/green
import snippets/doc/reporters/ansi/magenta
import snippets/doc/reporters/ansi/module
import snippets/doc/reporters/ansi/red
import snippets/doc/reporters/ansi/yellow

pub fn tests() -> TestSuite {
  describe("Doc examples: reporters/ansi", [
    it("red_line_numbers gives the expected text", fn() {
      // Act
      let text = module.red_line_numbers()

      // Assert
      text
      |> should
      |> be_equal("\u{1b}[31m12-13\u{1b}[0m")
      |> or_fail_with("expected red_line_numbers to give the expected text")
    }),
    it("red_failed gives the expected text", fn() {
      // Act
      let text = red.red_failed()

      // Assert
      text
      |> should
      |> be_equal("\u{1b}[31mFailed\u{1b}[0m")
      |> or_fail_with("expected red_failed to give the expected text")
    }),
    it("green_percent gives the expected text", fn() {
      // Act
      let text = green.green_percent()

      // Assert
      text
      |> should
      |> be_equal("\u{1b}[32m100.0%\u{1b}[0m")
      |> or_fail_with("expected green_percent to give the expected text")
    }),
    it("yellow_percent gives the expected text", fn() {
      // Act
      let text = yellow.yellow_percent()

      // Assert
      text
      |> should
      |> be_equal("\u{1b}[33m90.0%\u{1b}[0m")
      |> or_fail_with("expected yellow_percent to give the expected text")
    }),
    it("magenta_skipped gives the expected text", fn() {
      // Act
      let text = magenta.magenta_skipped()

      // Assert
      text
      |> should
      |> be_equal("\u{1b}[35mSkipped\u{1b}[0m")
      |> or_fail_with("expected magenta_skipped to give the expected text")
    }),
    it("cyan_feature gives the expected text", fn() {
      // Act
      let text = cyan.cyan_feature()

      // Assert
      text
      |> should
      |> be_equal("\u{1b}[36mFeature\u{1b}[0m")
      |> or_fail_with("expected cyan_feature to give the expected text")
    }),
    it("dim_duration gives the expected text", fn() {
      // Act
      let text = dim.dim_duration()

      // Assert
      text
      |> should
      |> be_equal("\u{1b}[2m12ms\u{1b}[0m")
      |> or_fail_with("expected dim_duration to give the expected text")
    }),
    it("bold_failures gives the expected text", fn() {
      // Act
      let text = bold.bold_failures()

      // Assert
      text
      |> should
      |> be_equal("\u{1b}[1mFailures:\u{1b}[0m")
      |> or_fail_with("expected bold_failures to give the expected text")
    }),
    it("red_when_enabled gives the expected text", fn() {
      // Act
      let text = apply_if.red_when_enabled()

      // Assert
      text
      |> should
      |> be_equal("\u{1b}[31mFailed\u{1b}[0m")
      |> or_fail_with("expected red_when_enabled to give the expected text")
    }),
    it("plain_when_disabled gives the expected text", fn() {
      // Act
      let text = apply_if.plain_when_disabled()

      // Assert
      text
      |> should
      |> be_equal("Failed")
      |> or_fail_with("expected plain_when_disabled to give the expected text")
    }),
  ])
}
