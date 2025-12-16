import dream_test/assertions/should.{
  be_true, equal, have_length, or_fail_with, should,
}
import dream_test/gherkin/feature.{
  FeatureConfig, InlineStep, and, background, but, feature,
  feature_with_background, given, scenario, then, to_test_suite, when,
}
import dream_test/gherkin/steps as step_registry
import dream_test/gherkin/types as gherkin_types
import dream_test/unit.{describe, group, it}
import gleam/option.{None}
import matchers/have_single_gherkin_test.{have_single_gherkin_test}

pub fn tests() {
  describe("Gherkin Feature", [
    group("to_test_suite", [
      it("creates suite with feature name", fn(_) {
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

        let result = to_test_suite("test_module", config)

        result.name
        |> should()
        |> equal("My Feature")
        |> or_fail_with("Suite name should be feature name")
      }),

      it("creates suite items for scenarios", fn(_) {
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

        let result = to_test_suite("test", config)

        result.items
        |> should()
        |> have_length(2)
        |> or_fail_with("Should have 2 suite items for 2 scenarios")
      }),

      it("sets GherkinScenario kind for test cases", fn(_) {
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

        let result = to_test_suite("test", config)

        result.items
        |> should()
        |> have_single_gherkin_test()
        |> or_fail_with("Should have one GherkinScenario test")
      }),

      it("expands scenario outlines via to_test_suite", fn(_) {
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

        let result = to_test_suite("test", config)

        result.items
        |> should()
        |> have_length(3)
        |> or_fail_with("Should expand outline to 3 suite items")
      }),
    ]),

    group("inline DSL - scenario", [
      it("creates InlineScenario with name", fn(_) {
        let name = "My Scenario"
        let result = scenario(name, [])

        result.name
        |> should()
        |> equal(name)
        |> or_fail_with("Scenario name should match")
      }),

      it("creates InlineScenario with steps", fn(_) {
        let steps = [given("something"), when("action")]
        let result = scenario("Test", steps)

        result.steps
        |> should()
        |> have_length(2)
        |> or_fail_with("Scenario should have 2 steps")
      }),
    ]),

    group("inline DSL - step helpers", [
      it("given creates Given step", fn(_) {
        let text = "I have something"
        let result = given(text)

        case result {
          InlineStep(keyword, step_text) -> {
            let ok = keyword == "Given" && step_text == text
            ok
            |> should()
            |> be_true()
            |> or_fail_with("Given step should have correct keyword and text")
          }
        }
      }),

      it("and creates And step", fn(_) {
        let text = "and also"
        let result = and(text)

        case result {
          InlineStep(keyword, step_text) -> {
            let ok = keyword == "And" && step_text == text
            ok
            |> should()
            |> be_true()
            |> or_fail_with("And step should have correct keyword and text")
          }
        }
      }),

      it("but creates But step", fn(_) {
        let text = "but not"
        let result = but(text)

        case result {
          InlineStep(keyword, step_text) -> {
            let ok = keyword == "But" && step_text == text
            ok
            |> should()
            |> be_true()
            |> or_fail_with("But step should have correct keyword and text")
          }
        }
      }),
    ]),

    group("inline DSL - feature", [
      it("feature returns a suite with scenario items", fn(_) {
        let registry = step_registry.new_registry()
        let s =
          scenario("Adding items", [
            given("I have an empty cart"),
            when("I add 2 apples"),
            then("the cart should contain 2 items"),
          ])

        let suite = feature("Shopping Cart", registry, [s])

        suite.items
        |> should()
        |> have_length(1)
        |> or_fail_with("Feature should have 1 scenario item")
      }),

      it("feature_with_background includes background for each scenario", fn(_) {
        let registry = step_registry.new_registry()
        let bg = background([given("I am logged in")])
        let s = scenario("Scenario", [then("something")])

        // Act
        let suite = feature_with_background("Feat", registry, bg, [s])

        // Assert (still one scenario item; background is executed during run)
        suite.items
        |> should()
        |> have_length(1)
        |> or_fail_with("Feature with background should have 1 scenario item")
      }),
    ]),
  ])
}
