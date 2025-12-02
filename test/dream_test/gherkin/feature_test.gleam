import dream_test/assertions/should.{
  equal, fail_with, have_length, or_fail_with, should,
}
import dream_test/gherkin/feature.{
  FeatureConfig, InlineStep, and, background, but, feature,
  feature_with_background, given, scenario, then, to_test_cases, to_test_suite,
  when,
}
import dream_test/gherkin/steps as step_registry
import dream_test/gherkin/types as gherkin_types
import dream_test/types.{type AssertionResult, AssertionOk}
import dream_test/unit.{describe, it}
import gleam/option.{None}
import matchers/extract_single_test_tags.{extract_single_test_tags}
import matchers/have_single_gherkin_test.{have_single_gherkin_test}

pub fn tests() {
  describe("Gherkin Feature", [
    describe("to_test_suite", [
      it("creates suite with feature name", fn() {
        // Arrange
        let feat =
          gherkin_types.Feature(
            name: "My Feature",
            description: None,
            tags: [],
            background: None,
            scenarios: [],
          )
        let registry = step_registry.new_registry()
        let config = FeatureConfig(feature: feat, step_registry: registry)

        // Act
        let result = to_test_suite("test_module", config)

        // Assert
        result.name
        |> should()
        |> equal("My Feature")
        |> or_fail_with("Suite name should be feature name")
      }),
      it("creates suite with correct full_name", fn() {
        // Arrange
        let feat =
          gherkin_types.Feature(
            name: "Shopping Cart",
            description: None,
            tags: [],
            background: None,
            scenarios: [],
          )
        let registry = step_registry.new_registry()
        let config = FeatureConfig(feature: feat, step_registry: registry)

        // Act
        let result = to_test_suite("cart_test", config)

        // Assert
        result.full_name
        |> should()
        |> equal(["cart_test", "Shopping Cart"])
        |> or_fail_with("Suite full_name should include module and feature")
      }),
      it("creates suite items for scenarios", fn() {
        // Arrange
        let feat =
          gherkin_types.Feature(
            name: "Feature",
            description: None,
            tags: [],
            background: None,
            scenarios: [
              gherkin_types.Scenario(name: "Test 1", tags: [], steps: []),
              gherkin_types.Scenario(name: "Test 2", tags: [], steps: []),
            ],
          )
        let registry = step_registry.new_registry()
        let config = FeatureConfig(feature: feat, step_registry: registry)

        // Act
        let result = to_test_suite("test", config)

        // Assert
        result.items
        |> should()
        |> have_length(2)
        |> or_fail_with("Should have 2 suite items for 2 scenarios")
      }),
      it("sets GherkinScenario kind for test cases", fn() {
        // Arrange
        let feat =
          gherkin_types.Feature(
            name: "Feature",
            description: None,
            tags: [],
            background: None,
            scenarios: [
              gherkin_types.Scenario(name: "Test", tags: [], steps: []),
            ],
          )
        let registry = step_registry.new_registry()
        let config = FeatureConfig(feature: feat, step_registry: registry)

        // Act
        let result = to_test_suite("test", config)

        // Assert
        result.items
        |> should()
        |> have_single_gherkin_test()
        |> or_fail_with("Should have one GherkinScenario test")
      }),
    ]),
    describe("to_test_cases", [
      it("flattens feature to test case list", fn() {
        // Arrange
        let feat =
          gherkin_types.Feature(
            name: "Feature",
            description: None,
            tags: [],
            background: None,
            scenarios: [
              gherkin_types.Scenario(name: "Test 1", tags: [], steps: []),
              gherkin_types.Scenario(name: "Test 2", tags: [], steps: []),
            ],
          )
        let registry = step_registry.new_registry()
        let config = FeatureConfig(feature: feat, step_registry: registry)

        // Act
        let result = to_test_cases("test", config)

        // Assert
        result
        |> should()
        |> have_length(2)
        |> or_fail_with("Should have 2 test cases")
      }),
    ]),
    describe("scenario outline expansion", [
      it("expands scenario outline to multiple test cases", fn() {
        // Arrange
        let feat =
          gherkin_types.Feature(
            name: "Feature",
            description: None,
            tags: [],
            background: None,
            scenarios: [
              gherkin_types.ScenarioOutline(
                name: "Parameterized",
                tags: [],
                steps: [],
                examples: gherkin_types.ExamplesTable(headers: ["x"], rows: [
                  ["1"],
                  ["2"],
                  ["3"],
                ]),
              ),
            ],
          )
        let registry = step_registry.new_registry()
        let config = FeatureConfig(feature: feat, step_registry: registry)

        // Act
        let result = to_test_cases("test", config)

        // Assert
        result
        |> should()
        |> have_length(3)
        |> or_fail_with("Should expand to 3 test cases")
      }),
    ]),
    describe("inline DSL - scenario", [
      it("creates InlineScenario with name", fn() {
        // Arrange
        let name = "My Scenario"

        // Act
        let result = scenario(name, [])

        // Assert
        result.name
        |> should()
        |> equal(name)
        |> or_fail_with("Scenario name should match")
      }),
      it("creates InlineScenario with steps", fn() {
        // Arrange
        let steps = [given("something"), when("action")]

        // Act
        let result = scenario("Test", steps)

        // Assert
        result.steps
        |> should()
        |> have_length(2)
        |> or_fail_with("Scenario should have 2 steps")
      }),
    ]),
    describe("inline DSL - step helpers", [
      it("given creates Given step", fn() {
        // Arrange
        let text = "I have something"

        // Act
        let result = given(text)

        // Assert
        case result {
          InlineStep(keyword, step_text) -> {
            case keyword == "Given" && step_text == text {
              True -> pass()
              False ->
                fail_with("Given step should have correct keyword and text")
            }
          }
        }
      }),
      it("when creates When step", fn() {
        // Arrange
        let text = "I do something"

        // Act
        let result = when(text)

        // Assert
        case result {
          InlineStep(keyword, step_text) -> {
            case keyword == "When" && step_text == text {
              True -> pass()
              False ->
                fail_with("When step should have correct keyword and text")
            }
          }
        }
      }),
      it("then creates Then step", fn() {
        // Arrange
        let text = "I see something"

        // Act
        let result = then(text)

        // Assert
        case result {
          InlineStep(keyword, step_text) -> {
            case keyword == "Then" && step_text == text {
              True -> pass()
              False ->
                fail_with("Then step should have correct keyword and text")
            }
          }
        }
      }),
      it("and creates And step", fn() {
        // Arrange
        let text = "also this"

        // Act
        let result = and(text)

        // Assert
        case result {
          InlineStep(keyword, step_text) -> {
            case keyword == "And" && step_text == text {
              True -> pass()
              False ->
                fail_with("And step should have correct keyword and text")
            }
          }
        }
      }),
      it("but creates But step", fn() {
        // Arrange
        let text = "not this"

        // Act
        let result = but(text)

        // Assert
        case result {
          InlineStep(keyword, step_text) -> {
            case keyword == "But" && step_text == text {
              True -> pass()
              False ->
                fail_with("But step should have correct keyword and text")
            }
          }
        }
      }),
    ]),
    describe("inline DSL - feature", [
      it("creates TestSuite from inline feature", fn() {
        // Arrange
        let registry = step_registry.new_registry()
        let scenarios = [scenario("Test", [given("something")])]

        // Act
        let result = feature("My Feature", registry, scenarios)

        // Assert
        result.name
        |> should()
        |> equal("My Feature")
        |> or_fail_with("Feature name should match")
      }),
      it("includes scenarios in suite items", fn() {
        // Arrange
        let registry = step_registry.new_registry()
        let scenarios = [
          scenario("Test 1", []),
          scenario("Test 2", []),
        ]

        // Act
        let result = feature("Feature", registry, scenarios)

        // Assert
        result.items
        |> should()
        |> have_length(2)
        |> or_fail_with("Should have 2 suite items")
      }),
    ]),
    describe("inline DSL - background", [
      it("creates list of parsed steps", fn() {
        // Arrange
        let inline_steps = [given("I am logged in"), given("I have a cart")]

        // Act
        let result = background(inline_steps)

        // Assert
        result
        |> should()
        |> have_length(2)
        |> or_fail_with("Background should have 2 steps")
      }),
    ]),
    describe("feature_with_background", [
      it("creates feature with background steps", fn() {
        // Arrange
        let registry = step_registry.new_registry()
        let bg = background([given("I am logged in")])
        let scenarios = [scenario("Test", [when("I do something")])]

        // Act
        let result = feature_with_background("Feature", registry, bg, scenarios)

        // Assert
        // The feature with background should still create the suite
        result.name
        |> should()
        |> equal("Feature")
        |> or_fail_with("Feature name should match")
      }),
    ]),
    describe("tags inheritance", [
      it("combines feature and scenario tags", fn() {
        // Arrange
        let feat =
          gherkin_types.Feature(
            name: "Feature",
            description: None,
            tags: ["feature-tag"],
            background: None,
            scenarios: [
              gherkin_types.Scenario(
                name: "Test",
                tags: ["scenario-tag"],
                steps: [],
              ),
            ],
          )
        let registry = step_registry.new_registry()
        let config = FeatureConfig(feature: feat, step_registry: registry)

        // Act
        let result = to_test_suite("test", config)

        // Assert
        result.items
        |> should()
        |> extract_single_test_tags()
        |> equal(["feature-tag", "scenario-tag"])
        |> or_fail_with("Should combine feature and scenario tags")
      }),
    ]),
  ])
}

// =============================================================================
// Test Helpers
// =============================================================================

fn pass() -> AssertionResult {
  AssertionOk
}
