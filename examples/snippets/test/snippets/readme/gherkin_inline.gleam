import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, Action, Check, get_int}
import dream_test/matchers.{be_equal, or_fail_with, should}
import gleam/result

pub fn tests() {
  let steps =
    steps.new(initial: 0)
    |> steps.given(
      "I have {int} items",
      Action(fn(_cart: Int, context: StepContext) {
        get_int(context.captures, 0)
      }),
    )
    |> steps.when_(
      "I add {int} more",
      Action(fn(cart: Int, context: StepContext) {
        use added <- result.try(get_int(context.captures, 0))
        Ok(cart + added)
      }),
    )
    |> steps.then_(
      "I should have {int} items",
      Check(fn(cart: Int, context: StepContext) {
        use expected <- result.try(get_int(context.captures, 0))
        cart
        |> should
        |> be_equal(expected)
        |> or_fail_with("Cart count mismatch")
      }),
    )

  feature("Shopping Cart", steps, [
    scenario("Adding items", [
      given("I have 3 items"),
      when("I add 2 more"),
      then("I should have 5 items"),
    ]),
  ])
}
