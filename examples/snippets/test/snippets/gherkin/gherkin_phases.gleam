import dream_test/gherkin/feature.{
  and, asterisk, background, feature_with_background, given, scenario, then,
  when,
}
import dream_test/gherkin/steps.{type StepContext}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}

fn step_trip(context: StepContext) {
  put(context.world, "bag", 0)
  Ok(succeed())
}

fn step_pack(context: StepContext) {
  put(context.world, "bag", get_or(context.world, "bag", 0) + 1)
  Ok(succeed())
}

fn step_close_bag(_context: StepContext) {
  Ok(succeed())
}

fn step_bag_has_two(context: StepContext) {
  get_or(context.world, "bag", 0)
  |> should
  |> be_equal(2)
  |> or_fail_with("expected two things in the bag")
}

pub fn tests() {
  let steps =
    steps.new()
    |> steps.given("I plan a trip", step_trip)
    |> steps.given("I pack a passport", step_pack)
    |> steps.given("I pack a toothbrush", step_pack)
    |> steps.when_("I close the bag", step_close_bag)
    |> steps.then_("the bag has 2 things", step_bag_has_two)

  feature_with_background(
    "Packing",
    steps,
    background([given("I plan a trip")]),
    [
      scenario("Packing for a trip", [
        and("I pack a passport"),
        asterisk("I pack a toothbrush"),
        when("I close the bag"),
        then("the bag has 2 things"),
      ]),
    ],
  )
}
