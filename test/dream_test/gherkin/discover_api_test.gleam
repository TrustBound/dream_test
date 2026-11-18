import dream_test/file
import dream_test/gherkin/discover
import dream_test/gherkin/parser
import dream_test/gherkin/steps
import dream_test/matchers.{
  be_empty, be_equal, contain, have_length, or_fail_with, should,
}
import dream_test/runner
import dream_test/types as test_types
import dream_test/unit.{describe, it}
import gleam/list
import gleam/option.{type Option, Some}

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
          |> discover.with_registry(steps.new(initial: Nil))
          |> discover.to_suite("Features")

        // Act
        let run_results =
          runner.new([suite])
          |> runner.run()
          |> test_types.report_tests

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

    it("load gives a parse error as the path and the parser message", fn() {
      let _ = file.write("./test/tmp/features/discover_text.feature", "NOT\n")

      let discover.LoadResult(features: _, errors: errors) =
        discover.features("./test/tmp/features/discover_text.feature")
        |> discover.load()

      errors
      |> should
      |> be_equal([
        parser.InvalidFeatureFile(
          path: "test/tmp/features/discover_text.feature",
          error: parser.ParseError(
            line: 1,
            problem: parser.UnexpectedLine("NOT", [
              parser.TagLine,
              parser.FeatureLine,
            ]),
          ),
        ),
      ])
      |> or_fail_with("the error should name the path and the message")
    }),

    it("to_suite names a parse error test after the path and message", fn() {
      let _ = file.write("./test/tmp/features/discover_name.feature", "NOT\n")

      let suite =
        discover.features("./test/tmp/features/discover_name.feature")
        |> discover.with_registry(steps.new(initial: Nil))
        |> discover.to_suite("Features")

      test_names(suite.children)
      |> should
      |> be_equal([
        "Parse Error: test/tmp/features/discover_name.feature: line 1: Found \"NOT\", but expected a tag line or a Feature line.",
      ])
      |> or_fail_with("the test name should hold the path and the message")
    }),

    it("to_suite gives the full path with ': ' as the parse error source", fn() {
      let _ = file.write("./test/tmp/features/discover: colon.feature", "NOT\n")

      let suite =
        discover.features("./test/tmp/features/discover: colon.feature")
        |> discover.with_registry(steps.new(initial: Nil))
        |> discover.to_suite("Features")

      test_sources(suite.children)
      |> should
      |> be_equal([Some("test/tmp/features/discover: colon.feature")])
      |> or_fail_with("the source should be the whole path")
    }),

    it("load gives an error for a pattern that matches no files", fn() {
      let result =
        discover.features("./test/tmp/features/no_such_*.feature")
        |> discover.load()

      #(
        result.features,
        list.map(result.errors, parser.feature_file_error_to_string),
      )
      |> should
      |> be_equal(
        #([], [
          "No feature files match the pattern \"./test/tmp/features/no_such_*.feature\"",
        ]),
      )
      |> or_fail_with("a pattern without files should be an error")
    }),

    it("to_suite fails a run for a pattern that matches no files", fn() {
      let results =
        discover.features("./test/tmp/features/no_such_*.feature")
        |> discover.with_registry(steps.new(initial: Nil))
        |> discover.to_suite("Features")
        |> list.wrap
        |> runner.new
        |> runner.run()
        |> test_types.report_tests

      #(list.map(results, result_name), list.map(results, result_status))
      |> should
      |> be_equal(
        #(
          [
            "No feature files match the pattern \"./test/tmp/features/no_such_*.feature\"",
          ],
          [test_types.Failed],
        ),
      )
      |> or_fail_with("a pattern without files should fail the run")
    }),

    it("to_suite runs the scenarios with the attached registry", fn() {
      let _ =
        file.write(
          "./test/tmp/features/discover_good.feature",
          "Feature: Good\n  Scenario: One\n    Given a thing\n",
        )
      let registry = steps.new(initial: Nil) |> steps.given("a thing", step_ok)

      let suite =
        discover.features("./test/tmp/features/discover_good.feature")
        |> discover.with_registry(registry)
        |> discover.to_suite("Features")

      runner.new([suite])
      |> runner.run()
      |> test_types.report_tests
      |> list.map(result_status)
      |> should
      |> be_equal([test_types.Passed])
      |> or_fail_with("the scenario should pass with the registry handler")
    }),
  ])
}

fn test_names(nodes: List(test_types.Node(Nil))) -> List(String) {
  list.filter_map(nodes, test_name)
}

fn test_name(node: test_types.Node(Nil)) -> Result(String, Nil) {
  case node {
    test_types.Test(name: name, ..) -> Ok(name)
    _ -> Error(Nil)
  }
}

fn test_sources(nodes: List(test_types.Node(Nil))) -> List(Option(String)) {
  list.filter_map(nodes, test_source)
}

fn test_source(node: test_types.Node(Nil)) -> Result(Option(String), Nil) {
  case node {
    test_types.Test(source: source, ..) -> Ok(source)
    _ -> Error(Nil)
  }
}

fn result_status(result: test_types.TestResult) -> test_types.Status {
  result.status
}

fn step_ok(_state: Nil, _context: steps.StepContext) -> Result(Nil, String) {
  Ok(Nil)
}

fn result_name(result: test_types.TestResult) -> String {
  result.name
}
