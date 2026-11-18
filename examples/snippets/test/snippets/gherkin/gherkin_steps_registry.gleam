import dream_test/gherkin/step_trie.{type StepMatch}
import dream_test/gherkin/steps.{
  type StepContext, type StepDefinition, Action, capture_count, find_step,
  get_int, given, then_, validate, when_,
}
import dream_test/gherkin/types.{GivenPhase, ThenPhase, WhenPhase}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/unit.{describe, it}
import gleam/result

fn step_count(_count: Int, context: StepContext) {
  get_int(context.captures, 0)
}

pub fn tests() {
  describe("Gherkin steps registry", [
    it("can find a step and count captures", fn() {
      let registry =
        steps.new(initial: 0) |> given("I have {int} items", Action(step_count))

      use matched <- result.try(find_step(
        registry,
        GivenPhase,
        "I have 3 items",
      ))

      capture_count(matched.captures)
      |> should
      |> be_equal(1)
      |> or_fail_with("expected exactly one capture")
    }),
    it("can extract an int capture", fn() {
      let registry =
        steps.new(initial: 0) |> given("I have {int} items", Action(step_count))

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
    it("registers a When step", fn() {
      let registry =
        steps.new(initial: 0) |> when_("I add {int} items", Action(step_count))

      use _matched <- result.try(find_step(registry, WhenPhase, "I add 2 items"))
      Ok(succeed())
    }),
    it("registers a Then step", fn() {
      let registry =
        steps.new(initial: 0)
        |> then_("I should have {int} items", Action(step_count))

      use _matched <- result.try(find_step(
        registry,
        ThenPhase,
        "I should have 5 items",
      ))
      Ok(succeed())
    }),
    it("a Given step definition does not match a When step", fn() {
      let registry =
        steps.new(initial: 0) |> given("I add {int} items", Action(step_count))

      find_step(registry, WhenPhase, "I add 2 items")
      |> result.map(capture_count_of)
      |> should
      |> be_equal(Error("Undefined step: When I add 2 items"))
      |> or_fail_with("expected the Given definition not to match")
    }),
    it("validate reports a pattern defined twice in one phase", fn() {
      steps.new(initial: 0)
      |> given("I have {int} items", Action(step_count))
      |> given("I have {int} items", Action(step_count))
      |> validate
      |> should
      |> be_equal(Error(
        "Duplicate step definition: Given \"I have {int} items\" is already defined. Each pattern can have one definition for each of Given, When and Then.",
      ))
      |> or_fail_with("expected a duplicate step definition error")
    }),
    it("validate accepts one pattern in two phases", fn() {
      steps.new(initial: 0)
      |> given("everything is fine", Action(step_count))
      |> then_("everything is fine", Action(step_count))
      |> validate
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("expected one pattern in two phases to be valid")
    }),
  ])
}

fn capture_count_of(matched: StepMatch(StepDefinition(Int))) -> Int {
  capture_count(matched.captures)
}
