import dream_test/file
import dream_test/gherkin/discover
import dream_test/gherkin/steps
import dream_test/matchers.{be_empty, contain, have_length, or_fail_with, should}
import dream_test/runner
import dream_test/types as test_types
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("dream_test/gherkin/discover", [
    it("list_files includes discover_a.feature", fn() {
      // Arrange
      let a = "test/tmp/features/discover_a.feature"
      let b = "test/tmp/features/discover_b.feature"
      let _ = file.write(a, "Feature: A\nScenario: One\n  Given ok\n")
      let _ = file.write(b, "Feature: B\nScenario: One\n  Given ok\n")

      let discovery = discover.features("test/tmp/features/discover_*.feature")

      // Act
      let files = discover.list_files(discovery)

      // Assert
      files
      |> should
      |> contain(a)
      |> or_fail_with("expected discover_a.feature to be listed")
    }),

    it("list_files includes discover_b.feature", fn() {
      // Arrange
      let a = "test/tmp/features/discover_a.feature"
      let b = "test/tmp/features/discover_b.feature"
      let _ = file.write(a, "Feature: A\nScenario: One\n  Given ok\n")
      let _ = file.write(b, "Feature: B\nScenario: One\n  Given ok\n")

      let discovery = discover.features("test/tmp/features/discover_*.feature")

      // Act
      let files = discover.list_files(discovery)

      // Assert
      files
      |> should
      |> contain(b)
      |> or_fail_with("expected discover_b.feature to be listed")
    }),

    it("load returns errors for invalid feature files (non-happy path)", fn() {
      // Arrange
      let bad = "./test/tmp/features/discover_bad.feature"
      let _ = file.write(bad, "NOT GHERKIN\n")
      let discovery =
        discover.features("./test/tmp/features/discover_bad.feature")

      // Act
      let discover.LoadResult(features: _features, errors: errors) =
        discover.load(discovery)

      // Assert
      errors
      |> should
      |> have_length(1)
      |> or_fail_with("expected one parse error for invalid feature")
    }),

    it(
      "load returns no features for invalid feature files (non-happy path)",
      fn() {
        // Arrange
        let bad = "./test/tmp/features/discover_bad_2.feature"
        let _ = file.write(bad, "NOT GHERKIN\n")
        let discovery =
          discover.features("./test/tmp/features/discover_bad_2.feature")

        // Act
        let discover.LoadResult(features: features, errors: _errors) =
          discover.load(discovery)

        // Assert
        features
        |> should
        |> be_empty()
        |> or_fail_with("expected no parsed features for invalid input")
      },
    ),

    it(
      "to_suite converts parse errors into failing tests tagged parse-error",
      fn() {
        // Arrange
        let bad = "./test/tmp/features/discover_bad_suite.feature"
        let _ = file.write(bad, "NOT GHERKIN\n")

        let suite =
          discover.features("./test/tmp/features/discover_bad_suite.feature")
          |> discover.with_registry(steps.new())
          |> discover.to_suite("Features")

        // Act
        let run_results = runner.new([suite]) |> runner.run()

        // Assert: at least one result is tagged parse-error
        let tags = case run_results {
          [test_types.TestResult(tags: tags, ..)] -> tags
          _ -> []
        }
        tags
        |> should
        |> contain("parse-error")
        |> or_fail_with("expected a parse-error test result")
      },
    ),
  ])
}
