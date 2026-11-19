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
          [
            step_trie.LiteralText("$"),
            step_trie.FloatParam,
            step_trie.LiteralText("USD"),
          ],
        ])
        |> or_fail_with("pattern ${float}USD should split into $, float, USD")
      },
    ),

    it("parse_step_pattern splits suffix placeholders ({int}%)", fn() {
      step_trie.parse_step_pattern("{int}%")
      |> should
      |> be_equal([[step_trie.IntParam, step_trie.LiteralText("%")]])
      |> or_fail_with("pattern {int}% should split into int, %")
    }),

    it("parse_step_pattern gives one list of segments for each word", fn() {
      step_trie.parse_step_pattern("I add {string} {word} {}")
      |> should
      |> be_equal([
        [step_trie.LiteralText("I")],
        [step_trie.LiteralText("add")],
        [step_trie.StringParam],
        [step_trie.WordParam],
        [step_trie.AnyParam],
      ])
      |> or_fail_with("each word should have its own segments")
    }),

    it("parse_step_pattern keeps other text in braces as literal text", fn() {
      step_trie.parse_step_pattern("a{name}{int}")
      |> should
      |> be_equal([[step_trie.LiteralText("a{name}"), step_trie.IntParam]])
      |> or_fail_with("{name} is not a placeholder")
    }),

    it("tokenize_step_text preserves quoted strings as a single token", fn() {
      step_trie.tokenize_step_text("I add \"Red Widget\" to cart")
      |> should
      |> be_equal(["I", "add", "\"Red Widget\"", "to", "cart"])
      |> or_fail_with("quoted strings should be one token")
    }),

    it("tokenize_step_text does not split a word at digits", fn() {
      step_trie.tokenize_step_text("price is $99.99USD for user42")
      |> should
      |> be_equal(["price", "is", "$99.99USD", "for", "user42"])
      |> or_fail_with("only spaces should split words")
    }),

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

    it("lookup matches {word} against a word that holds digits", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "the user is {word}", "user")
      |> result.map(step_trie.lookup(_, GivenPhase, "the user is user42"))
      |> should
      |> be_equal(
        Ok(
          Some(step_trie.StepMatch("user", [step_trie.CapturedWord("user42")])),
        ),
      )
      |> or_fail_with("{word} should capture user42")
    }),

    it("lookup matches a literal pattern that mixes digits and letters", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "I enable 2FA", "two_factor")
      |> result.map(step_trie.lookup(_, GivenPhase, "I enable 2FA"))
      |> should
      |> be_equal(Ok(Some(step_trie.StepMatch("two_factor", []))))
      |> or_fail_with("a literal pattern should match its own text")
    }),

    it("lookup matches a literal pattern that holds a quoted run", fn() {
      step_trie.new()
      |> step_trie.insert(WhenPhase, "I click \"Save changes\"", "save")
      |> result.map(step_trie.lookup(_, WhenPhase, "I click \"Save changes\""))
      |> should
      |> be_equal(Ok(Some(step_trie.StepMatch("save", []))))
      |> or_fail_with("a literal pattern should match its own text")
    }),

    it("lookup tries a placeholder when a literal branch does not match", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "I have {int} items", "count")
      |> result.try(step_trie.insert(_, GivenPhase, "I have 5 apples", "apples"))
      |> result.map(step_trie.lookup(_, GivenPhase, "I have 5 items"))
      |> should
      |> be_equal(
        Ok(Some(step_trie.StepMatch("count", [step_trie.CapturedInt(5)]))),
      )
      |> or_fail_with("the {int} pattern should match after the literal fails")
    }),

    it("lookup tries {} when a {word} branch does not match", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "I see {word} here", "word")
      |> result.try(step_trie.insert(_, GivenPhase, "I see {} there", "any"))
      |> result.map(step_trie.lookup(_, GivenPhase, "I see thing there"))
      |> should
      |> be_equal(
        Ok(Some(step_trie.StepMatch("any", [step_trie.CapturedWord("thing")]))),
      )
      |> or_fail_with("the {} pattern should match after {word} fails")
    }),

    it(
      "lookup tries a placeholder when the literal branch has no handler for the phase",
      fn() {
        step_trie.new()
        |> step_trie.insert(GivenPhase, "a b", "literal")
        |> result.try(step_trie.insert(_, ThenPhase, "a {word}", "word"))
        |> result.map(step_trie.lookup(_, ThenPhase, "a b"))
        |> should
        |> be_equal(
          Ok(Some(step_trie.StepMatch("word", [step_trie.CapturedWord("b")]))),
        )
        |> or_fail_with("the Then pattern should match")
      },
    ),

    it("lookup prefers a literal word to a placeholder when both match", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "I have {int} items", "count")
      |> result.try(step_trie.insert(_, GivenPhase, "I have 5 items", "five"))
      |> result.map(step_trie.lookup(_, GivenPhase, "I have 5 items"))
      |> should
      |> be_equal(Ok(Some(step_trie.StepMatch("five", []))))
      |> or_fail_with("the literal pattern should win")
    }),

    it("lookup prefers {int} to {word} when both match", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "I have {word} items", "word")
      |> result.try(step_trie.insert(
        _,
        GivenPhase,
        "I have {int} items",
        "count",
      ))
      |> result.map(step_trie.lookup(_, GivenPhase, "I have 5 items"))
      |> should
      |> be_equal(
        Ok(Some(step_trie.StepMatch("count", [step_trie.CapturedInt(5)]))),
      )
      |> or_fail_with("the {int} pattern should win")
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

    it("lookup captures a negative int between literal text", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "the range is a{int}b", "h")
      |> result.map(step_trie.lookup(_, GivenPhase, "the range is a-5b"))
      |> should
      |> be_equal(
        Ok(Some(step_trie.StepMatch("h", [step_trie.CapturedInt(-5)]))),
      )
      |> or_fail_with("{int} should capture -5")
    }),

    it("lookup captures an int before a suffix", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "the rate is {int}%", "h")
      |> result.map(step_trie.lookup(_, GivenPhase, "the rate is 10%"))
      |> should
      |> be_equal(
        Ok(Some(step_trie.StepMatch("h", [step_trie.CapturedInt(10)]))),
      )
      |> or_fail_with("{int}% should capture 10")
    }),

    it("lookup needs a space in the text where the pattern has one", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "the price is $ {float}", "h")
      |> result.map(step_trie.lookup(_, GivenPhase, "the price is $19.99"))
      |> should
      |> be_equal(Ok(None))
      |> or_fail_with("$ {float} should not match $19.99")
    }),

    it("lookup does not match {float} against a number with two points", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "version {float}", "h")
      |> result.map(step_trie.lookup(_, GivenPhase, "version 1.2.3"))
      |> should
      |> be_equal(Ok(None))
      |> or_fail_with("1.2.3 is not a float")
    }),

    it("lookup does not match {float} against a number with a comma", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "total {float}", "h")
      |> result.map(lookup_comma_numbers)
      |> should
      |> be_equal(Ok([None, None]))
      |> or_fail_with("1,000 and 1,5 are not floats")
    }),

    it("lookup does not match {int} against a number with a comma", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "total {int}", "h")
      |> result.map(step_trie.lookup(_, GivenPhase, "total 1,000"))
      |> should
      |> be_equal(Ok(None))
      |> or_fail_with("1,000 is not an int")
    }),

    it("lookup captures a quoted string without its quotes", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "the message is {string}", "h")
      |> result.map(step_trie.lookup(
        _,
        GivenPhase,
        "the message is \"hello world\"",
      ))
      |> should
      |> be_equal(
        Ok(
          Some(
            step_trie.StepMatch("h", [step_trie.CapturedString("hello world")]),
          ),
        ),
      )
      |> or_fail_with("{string} should capture hello world")
    }),

    it("lookup captures an empty quoted string", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "the message is {string}", "h")
      |> result.map(step_trie.lookup(_, GivenPhase, "the message is \"\""))
      |> should
      |> be_equal(
        Ok(Some(step_trie.StepMatch("h", [step_trie.CapturedString("")]))),
      )
      |> or_fail_with("{string} should capture an empty string")
    }),

    it("lookup does not match {string} against text with a quote inside", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "the message is {string}", "h")
      |> result.map(step_trie.lookup(_, GivenPhase, "the message is \"a\"b\""))
      |> should
      |> be_equal(Ok(None))
      |> or_fail_with("a string has no quote inside")
    }),

    it("lookup does not match {string} against one quote", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "the message is {string}", "h")
      |> result.map(step_trie.lookup(_, GivenPhase, "the message is \""))
      |> should
      |> be_equal(Ok(None))
      |> or_fail_with("one quote is not a string")
    }),

    it("lookup does not match {string} against unquoted text", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "the message is {string}", "h")
      |> result.map(step_trie.lookup(_, GivenPhase, "the message is hello"))
      |> should
      |> be_equal(Ok(None))
      |> or_fail_with("hello is not a string")
    }),

    it("lookup does not match {word} against a quoted run with a space", fn() {
      step_trie.new()
      |> step_trie.insert(WhenPhase, "I click {word}", "h")
      |> result.map(step_trie.lookup(_, WhenPhase, "I click \"Save changes\""))
      |> should
      |> be_equal(Ok(None))
      |> or_fail_with("{word} has no space")
    }),

    it("lookup matches {} against a quoted run with a space", fn() {
      step_trie.new()
      |> step_trie.insert(WhenPhase, "I click {}", "h")
      |> result.map(step_trie.lookup(_, WhenPhase, "I click \"Save changes\""))
      |> should
      |> be_equal(
        Ok(
          Some(
            step_trie.StepMatch("h", [
              step_trie.CapturedWord("\"Save changes\""),
            ]),
          ),
        ),
      )
      |> or_fail_with("{} should capture the whole word")
    }),

    it("lookup gives a placeholder the longest text that still matches", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "the path is {word}-{word}", "h")
      |> result.map(step_trie.lookup(_, GivenPhase, "the path is a-b-c"))
      |> should
      |> be_equal(
        Ok(
          Some(
            step_trie.StepMatch("h", [
              step_trie.CapturedWord("a-b"),
              step_trie.CapturedWord("c"),
            ]),
          ),
        ),
      )
      |> or_fail_with("the first {word} should take a-b")
    }),

    it("lookup prefers a word with more segments", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "the rate is {word}", "word")
      |> result.try(step_trie.insert(
        _,
        GivenPhase,
        "the rate is {int}%",
        "percent",
      ))
      |> result.map(step_trie.lookup(_, GivenPhase, "the rate is 10%"))
      |> should
      |> be_equal(
        Ok(Some(step_trie.StepMatch("percent", [step_trie.CapturedInt(10)]))),
      )
      |> or_fail_with("{int}% should win over {word}")
    }),

    it("lookup prefers literal text to a placeholder in the same place", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "the code is {word}x", "word")
      |> result.try(step_trie.insert(_, GivenPhase, "the code is a{word}", "a"))
      |> result.map(step_trie.lookup(_, GivenPhase, "the code is abx"))
      |> should
      |> be_equal(
        Ok(Some(step_trie.StepMatch("a", [step_trie.CapturedWord("bx")]))),
      )
      |> or_fail_with("a{word} should win over {word}x")
    }),

    it("lookup prefers longer literal text in the same place", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "the code is a{word}", "a")
      |> result.try(step_trie.insert(
        _,
        GivenPhase,
        "the code is ab{word}",
        "ab",
      ))
      |> result.try(step_trie.insert(
        _,
        GivenPhase,
        "the code is ac{word}",
        "ac",
      ))
      |> result.map(step_trie.lookup(_, GivenPhase, "the code is abc"))
      |> should
      |> be_equal(
        Ok(Some(step_trie.StepMatch("ab", [step_trie.CapturedWord("c")]))),
      )
      |> or_fail_with("ab{word} should win over a{word}")
    }),

    it("lookup prefers {string} to {}", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "I see {}", "any")
      |> result.try(step_trie.insert(_, GivenPhase, "I see {float}", "float"))
      |> result.try(step_trie.insert(_, GivenPhase, "I see {string}", "string"))
      |> result.map(step_trie.lookup(_, GivenPhase, "I see \"x\""))
      |> should
      |> be_equal(
        Ok(Some(step_trie.StepMatch("string", [step_trie.CapturedString("x")]))),
      )
      |> or_fail_with("{string} should win over {}")
    }),

    it("lookup prefers {float} to {}", fn() {
      step_trie.new()
      |> step_trie.insert(GivenPhase, "I see {}", "any")
      |> result.try(step_trie.insert(_, GivenPhase, "I see {float}", "float"))
      |> result.map(step_trie.lookup(_, GivenPhase, "I see 1.5"))
      |> should
      |> be_equal(
        Ok(Some(step_trie.StepMatch("float", [step_trie.CapturedFloat(1.5)]))),
      )
      |> or_fail_with("{float} should win over {}")
    }),
  ])
}

fn lookup_comma_numbers(
  trie: step_trie.StepTrie(String),
) -> List(option.Option(step_trie.StepMatch(String))) {
  [
    step_trie.lookup(trie, GivenPhase, "total 1,000"),
    step_trie.lookup(trie, GivenPhase, "total 1,5"),
  ]
}
