import dream_test/gherkin/step_trie
import dream_test/gherkin/types.{GivenPhase, ThenPhase}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{Some}
import gleam/result

pub fn tests() {
  describe("Step trie", [
    it(
      "parse_step_pattern splits prefix/suffix placeholders into segments",
      fn() {
        step_trie.parse_step_pattern("the total is ${float}USD")
        |> should
        |> be_equal([
          [step_trie.LiteralText("the")],
          [step_trie.LiteralText("total")],
          [step_trie.LiteralText("is")],
          [
            step_trie.LiteralText("$"),
            step_trie.FloatParam,
            step_trie.LiteralText("USD"),
          ],
        ])
        |> or_fail_with(
          "expected ${float}USD to split into literal + FloatParam segments",
        )
      },
    ),
    it("tokenize_step_text keeps a quoted run in one word", fn() {
      step_trie.tokenize_step_text("I add \"Red Widget\" and pay $19.99USD")
      |> should
      |> be_equal(["I", "add", "\"Red Widget\"", "and", "pay", "$19.99USD"])
      |> or_fail_with("expected tokenization to keep the quoted run")
    }),
    it("lookup finds the most specific pattern and captures typed values", fn() {
      use trie <- result.try(
        step_trie.new()
        |> step_trie.insert(
          phase: GivenPhase,
          pattern: "I have {int} items",
          handler: "count",
        ),
      )
      use trie <- result.try(step_trie.insert(
        trie,
        phase: ThenPhase,
        pattern: "the total is ${float}USD",
        handler: "total_usd",
      ))

      step_trie.lookup(trie, ThenPhase, "the total is $19.99USD")
      |> should
      |> be_equal(
        Some(
          step_trie.StepMatch(handler: "total_usd", captures: [
            step_trie.CapturedFloat(19.99),
          ]),
        ),
      )
      |> or_fail_with("expected float capture for $19.99USD")
    }),
    it("insert rejects a second definition of a pattern in one phase", fn() {
      use trie <- result.try(
        step_trie.new()
        |> step_trie.insert(
          phase: GivenPhase,
          pattern: "I have {int} items",
          handler: "first",
        ),
      )

      step_trie.insert(
        trie,
        phase: GivenPhase,
        pattern: "I have {int} items",
        handler: "second",
      )
      |> should
      |> be_equal(Error(
        "Duplicate step definition: Given \"I have {int} items\" is already defined. Each pattern can have one definition for each of Given, When and Then.",
      ))
      |> or_fail_with("expected a duplicate step definition error")
    }),
  ])
}
