import dream_test/gherkin/step_trie
import dream_test/gherkin/types.{GivenPhase, ThenPhase, WhenPhase}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}
import gleam/result

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
      step_trie.new()
      |> step_trie.insert(GivenPhase, "I have {int} items", "handler")
      |> result.map(step_trie.lookup(_, GivenPhase, "I have 42 items"))
      |> should
      |> be_equal(
        Ok(Some(step_trie.StepMatch("handler", [step_trie.CapturedInt(42)]))),
      )
      |> or_fail_with("expected int step match with CapturedInt(42)")
    }),

    it("lookup captures a float value for ${float}", fn() {
      step_trie.new()
      |> step_trie.insert(ThenPhase, "the total is ${float}", "money")
      |> result.map(step_trie.lookup(_, ThenPhase, "the total is $19.99"))
      |> should
      |> be_equal(
        Ok(Some(step_trie.StepMatch("money", [step_trie.CapturedFloat(19.99)]))),
      )
      |> or_fail_with("expected float step match with CapturedFloat(19.99)")
    }),

    it("lookup returns None for unmatched steps", fn() {
      let trie = step_trie.new()
      step_trie.lookup(trie, GivenPhase, "I have 1 item")
      |> should
      |> be_equal(None)
      |> or_fail_with("empty trie should not match")
    }),

    it("lookup captures any word for a {} placeholder", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "I see {} here", "h")
      |> result.map(step_trie.lookup(_, GivenPhase, "I see thing here"))
      |> should
      |> be_equal(
        Ok(Some(step_trie.StepMatch("h", [step_trie.CapturedWord("thing")]))),
      )
      |> or_fail_with("{} should capture the word")
    }),

    it("lookup finds the second of two patterns with a shared prefix", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "a b", "h1")
      |> result.try(step_trie.insert(_, GivenPhase, "a c", "h2"))
      |> result.map(step_trie.lookup(_, GivenPhase, "a c"))
      |> should
      |> be_equal(Ok(Some(step_trie.StepMatch("h2", []))))
      |> or_fail_with("the second pattern should match")
    }),

    it("lookup returns None for text that is only a pattern prefix", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "a b", "h")
      |> result.map(step_trie.lookup(_, GivenPhase, "a"))
      |> should
      |> be_equal(Ok(None))
      |> or_fail_with("a prefix has no handler")
    }),

    it("lookup does not match a handler of another phase", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "a b", "h")
      |> result.map(step_trie.lookup(_, WhenPhase, "a b"))
      |> should
      |> be_equal(Ok(None))
      |> or_fail_with("a Given handler should not match a When step")
    }),

    it("lookup finds the handler of the phase it is given", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "a b", "given")
      |> result.try(step_trie.insert(_, ThenPhase, "a b", "then"))
      |> result.map(step_trie.lookup(_, ThenPhase, "a b"))
      |> should
      |> be_equal(Ok(Some(step_trie.StepMatch("then", []))))
      |> or_fail_with("the Then handler should match a Then step")
    }),

    it("insert rejects a pattern defined twice in one phase", fn() {
      step_trie.new()
      |> step_trie.insert(WhenPhase, "I add {int} items", "first")
      |> result.try(step_trie.insert(
        _,
        WhenPhase,
        "I add {int} items",
        "second",
      ))
      |> should
      |> be_equal(Error(
        "Duplicate step definition: When \"I add {int} items\" is already defined. Each pattern can have one definition for each of Given, When and Then.",
      ))
      |> or_fail_with("a second definition in one phase should be an error")
    }),

    it("insert rejects a {float} placeholder defined twice in one phase", fn() {
      step_trie.new()
      |> step_trie.insert(ThenPhase, "{float}", "first")
      |> result.try(step_trie.insert(_, ThenPhase, "{float}", "second"))
      |> should
      |> be_equal(Error(
        "Duplicate step definition: Then \"{float}\" is already defined. Each pattern can have one definition for each of Given, When and Then.",
      ))
      |> or_fail_with("a second definition in one phase should be an error")
    }),

    it("insert rejects a {string} placeholder defined twice in one phase", fn() {
      step_trie.new()
      |> step_trie.insert(ThenPhase, "{string}", "first")
      |> result.try(step_trie.insert(_, ThenPhase, "{string}", "second"))
      |> should
      |> be_equal(Error(
        "Duplicate step definition: Then \"{string}\" is already defined. Each pattern can have one definition for each of Given, When and Then.",
      ))
      |> or_fail_with("a second definition in one phase should be an error")
    }),

    it("insert rejects a {word} placeholder defined twice in one phase", fn() {
      step_trie.new()
      |> step_trie.insert(ThenPhase, "{word}", "first")
      |> result.try(step_trie.insert(_, ThenPhase, "{word}", "second"))
      |> should
      |> be_equal(Error(
        "Duplicate step definition: Then \"{word}\" is already defined. Each pattern can have one definition for each of Given, When and Then.",
      ))
      |> or_fail_with("a second definition in one phase should be an error")
    }),

    it("insert rejects a {} placeholder defined twice in one phase", fn() {
      step_trie.new()
      |> step_trie.insert(ThenPhase, "{}", "first")
      |> result.try(step_trie.insert(_, ThenPhase, "{}", "second"))
      |> should
      |> be_equal(Error(
        "Duplicate step definition: Then \"{}\" is already defined. Each pattern can have one definition for each of Given, When and Then.",
      ))
      |> or_fail_with("a second definition in one phase should be an error")
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
