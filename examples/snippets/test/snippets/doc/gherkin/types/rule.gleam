import dream_test/gherkin/types.{Rule}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types as dream_types
import gleam/option.{None}

pub fn rule_holds_its_name() -> Result(dream_types.AssertionResult, String) {
  Rule(
    name: "Stock",
    description: None,
    tags: [],
    background: None,
    scenarios: [],
  )
  |> should
  |> be_equal(
    Rule(
      name: "Stock",
      description: None,
      tags: [],
      background: None,
      scenarios: [],
    ),
  )
  |> or_fail_with("expected Rule to be constructible")
}
