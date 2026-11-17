import dream_test/gherkin/feature as gfeature
import dream_test/gherkin/parser
import dream_test/gherkin/steps
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should}
import dream_test/runner
import dream_test/types as test_types
import dream_test/unit.{describe, it}
import gleam/list
import gleam/option.{None, Some}
import gleam/string

pub fn tests() {
  describe("dream_test/gherkin/feature", [
    it("inline feature() builds a runnable suite", fn() {
      // Arrange
      let registry =
        steps.new()
        |> steps.given("a thing", gherkin_step_ok)
        |> steps.then_("it works", gherkin_step_ok)

      let suite =
        gfeature.feature("Inline Feature", registry, [
          gfeature.scenario("Scenario 1", [
            gfeature.given("a thing"),
            gfeature.then("it works"),
          ]),
        ])

      // Act
      let results = runner.new([suite]) |> runner.run()

      // Assert
      case results {
        [
          test_types.TestResult(
            name: "Scenario 1",
            full_name: _,
            status: test_types.Passed,
            duration_ms: _,
            tags: _,
            failures: _,
            kind: _,
          ),
        ] -> Ok(test_types.AssertionOk)
        _ -> Ok(fail_with("unexpected results"))
      }
    }),

    it("with_tags adds scenario tags to the resulting test result", fn() {
      // Arrange
      let registry =
        steps.new()
        |> steps.given("a thing", gherkin_step_ok)

      let suite =
        gfeature.feature("Inline Tags", registry, [
          gfeature.scenario("Scenario 1", [gfeature.given("a thing")])
          |> gfeature.with_tags(["smoke"]),
        ])

      // Act
      let results = runner.new([suite]) |> runner.run()

      // Assert
      case results {
        [
          test_types.TestResult(
            name: _,
            full_name: _,
            status: _,
            duration_ms: _,
            tags: tags,
            failures: _,
            kind: _,
          ),
        ] ->
          tags
          |> should
          |> be_equal(["smoke"])
          |> or_fail_with("scenario tags should appear in result")
        _ -> Ok(fail_with("unexpected results"))
      }
    }),

    it("to_test_suite runs one test for each Examples row", fn() {
      let content =
        "Feature: F\n"
        <> "Scenario Outline: O\n"
        <> "  Given the value is <n>\n"
        <> "Examples:\n"
        <> "  | n |\n"
        <> "  | 1 |\n"
        <> "  | 2 |\n"
      let registry =
        steps.new()
        |> steps.given("the value is {int}", gherkin_step_ok)

      run_parsed(content, registry)
      |> list.map(fn(result) { #(result.kind, result.status) })
      |> should
      |> be_equal([
        #(test_types.GherkinScenario("F::O (Example 1)"), test_types.Passed),
        #(test_types.GherkinScenario("F::O (Example 2)"), test_types.Passed),
      ])
      |> or_fail_with("each examples row should run with its value")
    }),

    it("to_test_suite gives the DataTable and DocString to the handlers", fn() {
      let content =
        "Feature: F\n"
        <> "Scenario: S\n"
        <> "  Given a table\n"
        <> "    | a | b |\n"
        <> "  Then a doc string\n"
        <> "\"\"\"\n"
        <> "hello\n"
        <> "\"\"\"\n"
      let registry =
        steps.new()
        |> steps.given("a table", expect_table)
        |> steps.then_("a doc string", expect_doc_string)

      run_parsed(content, registry)
      |> list.map(fn(result) { result.failures })
      |> should
      |> be_equal([[]])
      |> or_fail_with("handlers should get the step arguments")
    }),

    it("a scenario fails with the message of an undefined step", fn() {
      let suite =
        gfeature.feature("F", steps.new(), [
          gfeature.scenario("S", [gfeature.given("missing")]),
        ])

      runner.new([suite])
      |> runner.run()
      |> list.map(fn(result) { result.failures })
      |> should
      |> be_equal([
        [
          test_types.AssertionFailure(
            operator: "step",
            message: "Undefined step: Given missing",
            payload: None,
          ),
        ],
      ])
      |> or_fail_with("an undefined step should fail the scenario")
    }),

    it("a scenario fails with the Error message of a handler", fn() {
      let registry =
        steps.new()
        |> steps.given("it breaks", gherkin_step_error)
        |> steps.then_("never runs", gherkin_step_ok)
      let suite =
        gfeature.feature("F", registry, [
          gfeature.scenario("S", [
            gfeature.given("it breaks"),
            gfeature.then("never runs"),
          ]),
        ])

      runner.new([suite])
      |> runner.run()
      |> list.map(fn(result) { result.failures })
      |> should
      |> be_equal([
        [
          test_types.AssertionFailure(
            operator: "step",
            message: "boom",
            payload: None,
          ),
        ],
      ])
      |> or_fail_with("a handler Error should fail the scenario")
    }),

    it("feature_with_background runs background and When/And/But steps", fn() {
      let registry =
        steps.new()
        |> steps.given("a base", gherkin_step_ok)
        |> steps.when_("I act", gherkin_step_ok)
        |> steps.when_("I act more", gherkin_step_ok)
        |> steps.when_("I do not stop", gherkin_step_ok)
        |> steps.then_("it works", gherkin_step_ok)
      let suite =
        gfeature.feature_with_background(
          "F",
          registry,
          gfeature.background([gfeature.given("a base")]),
          [
            gfeature.scenario("S", [
              gfeature.when("I act"),
              gfeature.and("I act more"),
              gfeature.but("I do not stop"),
              gfeature.then("it works"),
            ]),
          ],
        )

      runner.new([suite])
      |> runner.run()
      |> list.map(fn(result) { result.status })
      |> should
      |> be_equal([test_types.Passed])
      |> or_fail_with("background and scenario steps should all pass")
    }),
  ])
}

fn run_parsed(
  content: String,
  registry: steps.StepRegistry,
) -> List(test_types.TestResult) {
  case parser.parse_string(content) {
    Ok(feature) ->
      runner.new([
        gfeature.to_test_suite(gfeature.FeatureConfig(
          feature: feature,
          step_registry: registry,
        )),
      ])
      |> runner.run()
    Error(_) -> []
  }
}

fn gherkin_step_error(
  _context: steps.StepContext,
) -> Result(test_types.AssertionResult, String) {
  Error("boom")
}

fn expect_table(
  context: steps.StepContext,
) -> Result(test_types.AssertionResult, String) {
  case context.table {
    Some([["a", "b"]]) -> Ok(test_types.AssertionOk)
    other -> Error("unexpected table: " <> string.inspect(other))
  }
}

fn expect_doc_string(
  context: steps.StepContext,
) -> Result(test_types.AssertionResult, String) {
  case context.doc_string {
    Some("hello") -> Ok(test_types.AssertionOk)
    other -> Error("unexpected doc string: " <> string.inspect(other))
  }
}

fn gherkin_step_ok(
  _context: steps.StepContext,
) -> Result(test_types.AssertionResult, String) {
  Ok(test_types.AssertionOk)
}
