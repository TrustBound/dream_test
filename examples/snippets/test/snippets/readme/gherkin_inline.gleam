import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, get_int}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import gleam/result

pub fn tests() {
  let steps =
    steps.new()
    |> steps.given("I have {int} items", fn(ctx: StepContext) {
      put(ctx.world, "cart", get_int(ctx.captures, 0) |> result.unwrap(0))
      Ok(succeed())
    })
    |> steps.when_("I add {int} more", fn(ctx: StepContext) {
      let current = get_or(ctx.world, "cart", 0)
      put(
        ctx.world,
        "cart",
        current + { get_int(ctx.captures, 0) |> result.unwrap(0) },
      )
      Ok(succeed())
    })
    |> steps.then_("I should have {int} items", fn(ctx: StepContext) {
      get_or(ctx.world, "cart", 0)
      |> should
      |> be_equal(get_int(ctx.captures, 0) |> result.unwrap(0))
      |> or_fail_with("Cart count mismatch")
    })

  feature("Shopping Cart", steps, [
    scenario("Adding items", [
      given("I have 3 items"),
      when("I add 2 more"),
      then("I should have 5 items"),
    ]),
  ])
}
