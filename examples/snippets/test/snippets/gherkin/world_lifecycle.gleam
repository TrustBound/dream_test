import dream_test/gherkin/world

pub fn main() {
  // In normal gherkin runs, the runner creates and cleans up the World for you.
  let w = world.new_world("example_scenario")
  world.cleanup(w)
}
