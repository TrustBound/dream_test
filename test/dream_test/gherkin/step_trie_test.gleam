import dream_test/assertions/should.{equal, have_length, or_fail_with, should}
import dream_test/gherkin/step_trie.{
  AnyParam, FloatParam, IntParam, LiteralWord, StringParam, WordParam,
  parse_step_pattern, tokenize_step_text,
}
import dream_test/unit.{describe, group, it}

pub fn tests() {
  describe("Step Trie", [
    group("parse_step_pattern", [
      it("parses literal words", fn(_) {
        parse_step_pattern("I have items")
        |> should()
        |> equal([LiteralWord("I"), LiteralWord("have"), LiteralWord("items")])
        |> or_fail_with("Should parse literal words")
      }),

      it("parses placeholders", fn(_) {
        parse_step_pattern(
          "the {word} costs {float} and {int} items for {string} {}",
        )
        |> should()
        |> equal([
          LiteralWord("the"),
          WordParam,
          LiteralWord("costs"),
          FloatParam,
          LiteralWord("and"),
          IntParam,
          LiteralWord("items"),
          LiteralWord("for"),
          StringParam,
          AnyParam,
        ])
        |> or_fail_with("Should parse all placeholders")
      }),

      it("handles empty pattern", fn(_) {
        parse_step_pattern("")
        |> should()
        |> equal([])
        |> or_fail_with("Empty pattern should produce empty segments")
      }),
    ]),

    group("tokenize_step_text", [
      it("tokenizes simple words", fn(_) {
        tokenize_step_text("I have items")
        |> should()
        |> equal(["I", "have", "items"])
        |> or_fail_with("Should tokenize simple words")
      }),

      it("keeps quoted strings together", fn(_) {
        tokenize_step_text("the user \"John Doe\" is logged in")
        |> should()
        |> equal(["the", "user", "\"John Doe\"", "is", "logged", "in"])
        |> or_fail_with("Should keep quoted strings as single token")
      }),

      it("handles multiple quoted strings", fn(_) {
        tokenize_step_text("\"A\" and \"B\" are values")
        |> should()
        |> have_length(5)
        |> or_fail_with("Should handle multiple quoted strings")
      }),
    ]),
  ])
}
