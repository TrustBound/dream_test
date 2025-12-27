import dream_test/gherkin/steps.{
  type StepContext, capture_count, find_step, get_int, given, then_, when_,
}
import dream_test/gherkin/types.{Given, Then, When}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/unit.{describe, it}
import gleam/result

fn step_pass(_context: StepContext) {
  Ok(succeed())
}

pub fn tests() {
  describe("Gherkin steps registry", [
    it("can find a step and count captures", fn() {
      let registry = steps.new() |> given("I have {int} items", step_pass)

      use matched <- result.try(find_step(registry, Given, "I have 3 items"))

      capture_count(matched.captures)
      |> should
      |> be_equal(1)
      |> or_fail_with("expected exactly one capture")
    }),
    it("can extract an int capture", fn() {
      let registry = steps.new() |> given("I have {int} items", step_pass)

      use matched <- result.try(find_step(registry, Given, "I have 3 items"))
      use count <- result.try(get_int(matched.captures, 0))

      count
      |> should
      |> be_equal(3)
      |> or_fail_with("expected captured int to be 3")
    }),
    it("registers a When step", fn() {
      let registry = steps.new() |> when_("I add {int} items", step_pass)

      use _matched <- result.try(find_step(registry, When, "I add 2 items"))
      Ok(succeed())
    }),
    it("registers a Then step", fn() {
      let registry =
        steps.new() |> then_("I should have {int} items", step_pass)

      use _matched <- result.try(find_step(
        registry,
        Then,
        "I should have 5 items",
      ))
      Ok(succeed())
    }),
  ])
}
