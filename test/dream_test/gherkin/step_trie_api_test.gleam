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

    it("lookup captures any word for a {} placeholder", fn() {
      step_trie.new()
      |> step_trie.insert("Given", "I see {} here", "h")
      |> step_trie.lookup("Given", "I see thing here")
      |> should
      |> be_equal(
        Some(step_trie.StepMatch("h", [step_trie.CapturedWord("thing")])),
      )
      |> or_fail_with("{} should capture the word")
    }),

    it("lookup finds the second of two patterns with a shared prefix", fn() {
      step_trie.new()
      |> step_trie.insert("Given", "a b", "h1")
      |> step_trie.insert("Given", "a c", "h2")
      |> step_trie.lookup("Given", "a c")
      |> should
      |> be_equal(Some(step_trie.StepMatch("h2", [])))
      |> or_fail_with("the second pattern should match")
    }),

    it("lookup returns None for text that is only a pattern prefix", fn() {
      step_trie.new()
      |> step_trie.insert("Given", "a b", "h")
      |> step_trie.lookup("Given", "a")
      |> should
      |> be_equal(None)
      |> or_fail_with("a prefix has no handler")
    }),

    it("tokenize_step_text ignores repeated spaces", fn() {
      step_trie.tokenize_step_text("a  b")
      |> should
      |> be_equal(["a", "b"])
      |> or_fail_with("two spaces should not make an empty token")
    }),

    it(
      "tokenize_step_text keeps a minus sign in front of digits with the number",
      fn() {
        step_trie.tokenize_step_text("-5")
        |> should
        |> be_equal(["-5"])
        |> or_fail_with("unexpected tokens")
      },
    ),

    it(
      "tokenize_step_text splits a negative number from the letters around it",
      fn() {
        step_trie.tokenize_step_text("a-5b")
        |> should
        |> be_equal(["a", "-5", "b"])
        |> or_fail_with("unexpected tokens")
      },
    ),

    it("tokenize_step_text ends a number at its second decimal point", fn() {
      step_trie.tokenize_step_text("1.2.3")
      |> should
      |> be_equal(["1.2", ".", "3"])
      |> or_fail_with("unexpected tokens")
    }),

    it(
      "tokenize_step_text keeps a decimal point that has no digits after it",
      fn() {
        step_trie.tokenize_step_text("3.")
        |> should
        |> be_equal(["3."])
        |> or_fail_with("unexpected tokens")
      },
    ),

    it(
      "tokenize_step_text keeps only the last minus sign of two with the number",
      fn() {
        step_trie.tokenize_step_text("--5")
        |> should
        |> be_equal(["-", "-5"])
        |> or_fail_with("unexpected tokens")
      },
    ),

    it(
      "tokenize_step_text keeps a minus sign with no digits after it as text",
      fn() {
        step_trie.tokenize_step_text("x-")
        |> should
        |> be_equal(["x-"])
        |> or_fail_with("unexpected tokens")
      },
    ),

    it("tokenize_step_text splits a suffix from a number", fn() {
      step_trie.tokenize_step_text("10%")
      |> should
      |> be_equal(["10", "%"])
      |> or_fail_with("unexpected tokens")
    }),

    it("tokenize_step_text does not split a quoted number", fn() {
      step_trie.tokenize_step_text("\"$5\"")
      |> should
      |> be_equal(["\"$5\""])
      |> or_fail_with("unexpected tokens")
    }),

    it("tokenize_step_text keeps a token without digits as one token", fn() {
      step_trie.tokenize_step_text("hello")
      |> should
      |> be_equal(["hello"])
      |> or_fail_with("unexpected tokens")
    }),
  ])
}
