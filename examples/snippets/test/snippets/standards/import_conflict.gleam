import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/option.{None}

// Gherkin is the primary subject → unqualified
import dream_test/gherkin/steps.{type SuiteTest, Group, Scenarios}
import dream_test/gherkin/types.{type Feature, type Scenario}

// Core test types are supporting → alias the conflicting `Group`,
// alias the module (both modules are named `types`)
import dream_test/types.{type Node, Group as NodeGroup} as test_types

pub fn checkout_group(feature: Feature) -> SuiteTest(Nil) {
  Group(name: "Checkout", tags: [], tests: [Scenarios(feature)])
}

pub fn plain_group() -> Node(Nil) {
  NodeGroup(name: "plain", tags: [], tests: [])
}

pub fn first_scenarios(feature: Feature) -> List(Scenario) {
  list.take(feature.scenarios, 1)
}

pub fn kind() -> test_types.TestKind {
  test_types.Unit
}

pub fn tests() {
  describe("STANDARDS.md rule 7: two modules named types", [
    it("builds a Gherkin group, a test tree group and a kind", fn() {
      // Arrange
      let feature =
        types.Feature(
          name: "Shop",
          source: None,
          description: None,
          tags: [],
          background: None,
          scenarios: [],
          rules: [],
        )

      // Act
      let values = #(checkout_group(feature), plain_group(), kind())

      // Assert
      values
      |> should
      |> be_equal(#(
        Group(name: "Checkout", tags: [], tests: [Scenarios(feature)]),
        NodeGroup(name: "plain", tags: [], tests: []),
        test_types.Unit,
      ))
      |> or_fail_with("both groups and the kind should be made")
    }),
  ])
}
