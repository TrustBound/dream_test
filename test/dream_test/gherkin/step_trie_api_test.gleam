import dream_test/gherkin/step_trie
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}

pub fn tests() {
  describe("dream_test/gherkin/step_trie", [
    it(
      "parse_step_pattern splits prefix/suffix placeholders (${float}USD)",
      fn() {
        step_trie.parse_step_pattern("${float}USD")
        |> should
        |> be_equal([
          step_trie.LiteralWord("$"),
          step_trie.FloatParam,
          step_trie.LiteralWord("USD"),
        ])
        |> or_fail_with("pattern ${float}USD should split into $, float, USD")
      },
    ),

    it("parse_step_pattern splits suffix placeholders ({int}%)", fn() {
      step_trie.parse_step_pattern("{int}%")
      |> should
      |> be_equal([step_trie.IntParam, step_trie.LiteralWord("%")])
      |> or_fail_with("pattern {int}% should split into int, %")
    }),

    it("tokenize_step_text preserves quoted strings as a single token", fn() {
      step_trie.tokenize_step_text("I add \"Red Widget\" to cart")
      |> should
      |> be_equal(["I", "add", "\"Red Widget\"", "to", "cart"])
      |> or_fail_with("quoted strings should be one token")
    }),

    it(
      "tokenize_step_text splits numeric boundaries for prefix/suffix matching",
      fn() {
        step_trie.tokenize_step_text("price is $99.99USD")
        |> should
        |> be_equal(["price", "is", "$", "99.99", "USD"])
        |> or_fail_with("numeric boundary splitting should work")
      },
    ),

    it("lookup captures an int value for {int}", fn() {
      let trie =
        step_trie.new()
        |> step_trie.insert("Given", "I have {int} items", "handler")

      let int_match = step_trie.lookup(trie, "Given", "I have 42 items")

      int_match
      |> should
      |> be_equal(
        Some(step_trie.StepMatch("handler", [step_trie.CapturedInt(42)])),
      )
      |> or_fail_with("expected int step match with CapturedInt(42)")
    }),

    it("lookup captures a float value for ${float}", fn() {
      let trie =
        step_trie.new()
        |> step_trie.insert("Then", "the total is ${float}", "money")

      let float_match = step_trie.lookup(trie, "Then", "the total is $19.99")

      float_match
      |> should
      |> be_equal(
        Some(step_trie.StepMatch("money", [step_trie.CapturedFloat(19.99)])),
      )
      |> or_fail_with("expected float step match with CapturedFloat(19.99)")
    }),

    it("lookup returns None for unmatched steps", fn() {
      let trie = step_trie.new()
      step_trie.lookup(trie, "Given", "I have 1 item")
      |> should
      |> be_equal(None)
      |> or_fail_with("empty trie should not match")
    }),
  ])
}
