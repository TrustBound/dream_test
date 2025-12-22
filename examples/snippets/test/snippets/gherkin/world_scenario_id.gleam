import dream_test/gherkin/world

pub fn main() {
  let w = world.new_world("example_scenario")
  let id = world.scenario_id(w)
  world.cleanup(w)
  id
}
