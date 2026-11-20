//// A test module whose `tests()` returns a Gherkin suite from a
//// `.feature` file, for discovery. Each test of the suite has the path of
//// the `.feature` file as its source.

import dream_test/gherkin/discover
import dream_test/gherkin/steps.{type StepContext}

pub fn tests() {
  discover.features("test/discovery_fixtures/feature_suite.feature")
  |> discover.with_registry(steps.given(steps.new(Nil), "a step", pass))
  |> discover.to_suite("feature_suite")
}

fn pass(state: Nil, _context: StepContext) -> Result(Nil, String) {
  Ok(state)
}
