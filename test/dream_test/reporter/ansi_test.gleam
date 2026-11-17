import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/ansi
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("dream_test/reporters/ansi", [
    it("red wraps the text in code 31", fn() {
      ansi.red("text")
      |> should
      |> be_equal("\u{1b}[31mtext\u{1b}[0m")
      |> or_fail_with("expected the red code")
    }),
    it("green wraps the text in code 32", fn() {
      ansi.green("text")
      |> should
      |> be_equal("\u{1b}[32mtext\u{1b}[0m")
      |> or_fail_with("expected the green code")
    }),
    it("yellow wraps the text in code 33", fn() {
      ansi.yellow("text")
      |> should
      |> be_equal("\u{1b}[33mtext\u{1b}[0m")
      |> or_fail_with("expected the yellow code")
    }),
    it("magenta wraps the text in code 35", fn() {
      ansi.magenta("text")
      |> should
      |> be_equal("\u{1b}[35mtext\u{1b}[0m")
      |> or_fail_with("expected the magenta code")
    }),
    it("cyan wraps the text in code 36", fn() {
      ansi.cyan("text")
      |> should
      |> be_equal("\u{1b}[36mtext\u{1b}[0m")
      |> or_fail_with("expected the cyan code")
    }),
    it("dim wraps the text in code 2", fn() {
      ansi.dim("text")
      |> should
      |> be_equal("\u{1b}[2mtext\u{1b}[0m")
      |> or_fail_with("expected the dim code")
    }),
    it("bold wraps the text in code 1", fn() {
      ansi.bold("text")
      |> should
      |> be_equal("\u{1b}[1mtext\u{1b}[0m")
      |> or_fail_with("expected the bold code")
    }),
  ])
}
