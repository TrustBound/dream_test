import dream_test/file
import dream_test/gherkin/discover
import dream_test/gherkin/parser
import dream_test/gherkin/steps
import dream_test/matchers.{
  be_empty, be_equal, be_ok, contain, have_length, or_fail_with, should,
}
import dream_test/runner
import dream_test/suite
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
      |> be_ok()
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
      |> be_ok()
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

      let discovered =
        discover.features("./test/tmp/features/discover_name.feature")
        |> discover.with_registry(steps.new(initial: Nil))
        |> discover.to_suite("Features")

      test_names(suite.tests(discovered))
      |> should
      |> be_equal([
        "Parse Error: test/tmp/features/discover_name.feature: line 1: Found \"NOT\", but expected a tag line or a Feature line.",
      ])
      |> or_fail_with("the test name should hold the path and the message")
    }),

    it("to_suite gives the full path with ': ' as the parse error source", fn() {
      let _ = file.write("./test/tmp/features/discover: colon.feature", "NOT\n")

      let discovered =
        discover.features("./test/tmp/features/discover: colon.feature")
        |> discover.with_registry(steps.new(initial: Nil))
        |> discover.to_suite("Features")

      test_sources(suite.tests(discovered))
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

      #(
        list.map(results, result_name),
        list.map(results, result_status),
        list.map(results, result_tags),
        list.map(results, result_messages),
      )
      |> should
      |> be_equal(
        #(
          [
            "No feature files match the pattern \"./test/tmp/features/no_such_*.feature\"",
          ],
          [test_types.Failed],
          [["no-feature-files"]],
          [
            [
              "No feature files found for the pattern (see test name for the cause)",
            ],
          ],
        ),
      )
      |> or_fail_with("a pattern without files should fail the run")
    }),

    it("list_files gives an empty list for a pattern without files", fn() {
      discover.features("./test/tmp/features/no_such_*.feature")
      |> discover.list_files()
      |> should
      |> be_equal(Ok([]))
      |> or_fail_with("a pattern without files should list no files")
    }),

    it("list_files gives an error for a pattern that cannot be searched", fn() {
      discover.features("./test/tmp/features/{a.feature")
      |> discover.list_files()
      |> should
      |> be_equal(
        Error(parser.InvalidFeatureFilePattern(
          pattern: "./test/tmp/features/{a.feature",
          reason: "error:{badpattern,missing_delimiter}",
        )),
      )
      |> or_fail_with("a malformed pattern should be an error")
    }),

    it("load gives an error for a pattern that cannot be searched", fn() {
      let result =
        discover.features("./test/tmp/features/{a.feature")
        |> discover.load()

      #(
        result.features,
        list.map(result.errors, parser.feature_file_error_to_string),
      )
      |> should
      |> be_equal(
        #([], [
          "Cannot search for feature files with the pattern \"./test/tmp/features/{a.feature\": error:{badpattern,missing_delimiter}",
        ]),
      )
      |> or_fail_with("a malformed pattern should be an error")
    }),

    it("to_suite fails a run for a pattern that cannot be searched", fn() {
      let results =
        discover.features("./test/tmp/features/{a.feature")
        |> discover.with_registry(steps.new(initial: Nil))
        |> discover.to_suite("Features")
        |> list.wrap
        |> runner.new
        |> runner.silent
        |> runner.run()
        |> test_types.report_tests

      #(
        list.map(results, result_name),
        list.map(results, result_status),
        list.map(results, result_tags),
        list.map(results, result_messages),
      )
      |> should
      |> be_equal(
        #(
          [
            "Cannot search for feature files with the pattern \"./test/tmp/features/{a.feature\": error:{badpattern,missing_delimiter}",
          ],
          [test_types.Failed],
          [["invalid-feature-pattern"]],
          [
            [
              "The feature file pattern cannot be searched (see test name for the cause)",
            ],
          ],
        ),
      )
      |> or_fail_with("a malformed pattern should fail the run")
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

fn test_names(tests: List(test_types.TestInfo)) -> List(String) {
  list.map(tests, test_name)
}

fn test_name(info: test_types.TestInfo) -> String {
  info.name
}

fn test_sources(tests: List(test_types.TestInfo)) -> List(Option(String)) {
  list.map(tests, test_source)
}

fn test_source(info: test_types.TestInfo) -> Option(String) {
  info.source
}

fn result_status(result: test_types.TestResult) -> test_types.Status {
  result.status
}

fn step_ok(_state: Nil, _context: steps.StepContext) -> Result(Nil, String) {
  Ok(Nil)
}

fn result_tags(result: test_types.TestResult) -> List(String) {
  result.tags
}

fn result_messages(result: test_types.TestResult) -> List(String) {
  list.map(result.failures, failure_message)
}

fn failure_message(failure: test_types.AssertionFailure) -> String {
  failure.message
}

fn result_name(result: test_types.TestResult) -> String {
  result.name
}
