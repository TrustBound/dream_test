import dream_test/gherkin/feature.{
  and, asterisk, background, feature_with_background, given, scenario, then,
  when,
}
import dream_test/gherkin/steps.{type StepContext}
import dream_test/matchers.{be_equal, or_fail_with, should}

fn step_trip(_bag: Int, _context: StepContext) {
  Ok(0)
}

fn step_pack(bag: Int, _context: StepContext) {
  Ok(bag + 1)
}

fn step_close_bag(bag: Int, _context: StepContext) {
  Ok(bag)
}

fn step_bag_has_two(bag: Int, _context: StepContext) {
  bag
  |> should
  |> be_equal(2)
  |> or_fail_with("expected two things in the bag")
}

pub fn tests() {
  let steps =
    steps.new(initial: 0)
    |> steps.given("I plan a trip", step_trip)
    |> steps.given("I pack a passport", step_pack)
    |> steps.given("I pack a toothbrush", step_pack)
    |> steps.when("I close the bag", step_close_bag)
    |> steps.then("the bag has 2 things", step_bag_has_two)

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
