import dream_test/gherkin/feature.{background, given}
import dream_test/gherkin/types.{type Step}

pub fn server_background() -> List(Step) {
  background([given("the server is running")])
}
