import dream_test/gherkin/step_trie
import dream_test/gherkin/steps.{type StepContext, find_step, get_int, given}
import dream_test/gherkin/types.{GivenPhase, ThenPhase}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/option.{Some}
import gleam/result

fn step_count(_count: Int, context: StepContext) {
  get_int(context.captures, 0)
}

pub fn tests() {
  describe("Step lookup", [
    it("can extract an int capture", fn() {
      let registry =
        steps.new(initial: 0) |> given("I have {int} items", step_count)

      use matched <- result.try(find_step(
        registry,
        GivenPhase,
        "I have 3 items",
      ))
      use count <- result.try(get_int(matched.captures, 0))

      count
      |> should
      |> be_equal(3)
      |> or_fail_with("expected captured int to be 3")
    }),
    it("lookup finds the most specific pattern and captures typed values", fn() {
      use trie <- result.try(
        step_trie.new()
        |> step_trie.insert(
          phase: GivenPhase,
          pattern: "I have an empty cart",
          handler: "empty",
        ),
      )
      use trie <- result.try(step_trie.insert(
        trie,
        phase: GivenPhase,
        pattern: "I have {int} items",
        handler: "count",
      ))
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
    it("validate reports a pattern defined twice in one phase", fn() {
      steps.new(initial: 0)
      |> given("I have {int} items", step_count)
      |> given("I have {int} items", step_count)
      |> steps.validate
      |> should
      |> be_equal(Error(
        "Duplicate step definition: Given \"I have {int} items\" is already defined. Each pattern can have one definition for each of Given, When and Then.",
      ))
      |> or_fail_with("expected a duplicate step definition error")
    }),
  ])
}
