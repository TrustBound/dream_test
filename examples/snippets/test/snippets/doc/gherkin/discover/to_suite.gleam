import dream_test/gherkin/discover
import dream_test/gherkin/steps.{type StepRegistry}
import dream_test/suite.{type TestSuite}

pub fn cart_features(steps: StepRegistry(state)) -> TestSuite {
  // Discover and load all .feature files
  discover.features("test/*.feature")
  |> discover.with_registry(steps)
  |> discover.to_suite("cart_features")
}
