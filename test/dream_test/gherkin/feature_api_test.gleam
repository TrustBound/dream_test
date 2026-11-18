import dream_test/gherkin/feature as gfeature
import dream_test/gherkin/parser
import dream_test/gherkin/steps
import dream_test/gherkin/types as gherkin_types
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
            groups: _,
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
            groups: _,
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

    it("to_test_suite puts each Rule in a group named Rule: <name>", fn() {
      run_parsed(rules_feature(), rules_registry())
      |> list.map(group_and_name)
      |> should
      |> be_equal([
        #(["F"], "Outside"),
        #(["F", "Rule: Stock"], "Sell"),
        #(["F", "Rule:"], "Nameless"),
      ])
      |> or_fail_with("expected one group for each Rule")
    }),

    it("to_test_suite gives a Rule scenario the Feature and Rule tags", fn() {
      run_parsed(rules_feature(), rules_registry())
      |> list.map(result_tags)
      |> should
      |> be_equal([["f", "f", "outside"], ["f", "f", "r", "sell"], ["f", "f"]])
      |> or_fail_with(
        "expected Feature tags, then Rule tags, then scenario tags",
      )
    }),

    it(
      "to_test_suite runs the Feature Background, then the Rule Background",
      fn() {
        run_parsed(rules_feature(), rules_registry())
        |> list.map(result_status)
        |> should
        |> be_equal([test_types.Passed, test_types.Passed, test_types.Passed])
        |> or_fail_with("expected the Background steps to run in order")
      },
    ),

    it("to_test_suite gives the Rule scenario id the Rule group", fn() {
      run_parsed(rules_feature(), rules_registry())
      |> list.map(result_kind)
      |> should
      |> be_equal([
        test_types.GherkinScenario("F::Outside"),
        test_types.GherkinScenario("F::Rule: Stock::Sell"),
        test_types.GherkinScenario("F::Rule:::Nameless"),
      ])
      |> or_fail_with("expected the Rule group in each id")
    }),

    it("to_test_suite names example rows after their Examples section", fn() {
      run_parsed(examples_feature(), examples_registry())
      |> list.map(result_name)
      |> should
      |> be_equal([
        "O (Small, Example 1)",
        "O (Small, Example 2)",
        "O (Example 3)",
      ])
      |> or_fail_with("expected the Examples name and a running count")
    }),

    it("to_test_suite gives example rows the Examples tags", fn() {
      run_parsed(examples_feature(), examples_registry())
      |> list.map(result_tags)
      |> should
      |> be_equal([["o", "small"], ["o", "small"], ["o", "big"]])
      |> or_fail_with("expected the scenario tags, then the Examples tags")
    }),

    it("to_test_suite runs no test for Examples without a table", fn() {
      run_parsed(
        "Feature: F\n  Scenario Outline: O\n    Given the value is <n>\n    Examples:\n",
        examples_registry(),
      )
      |> should
      |> be_equal([])
      |> or_fail_with("expected no test")
    }),

    it("to_test_suite runs a scenario outline without Examples one time", fn() {
      run_parsed(
        "Feature: F\n  Scenario Outline: O\n    Given the value is 1\n",
        examples_registry(),
      )
      |> list.map(result_name)
      |> should
      |> be_equal(["O"])
      |> or_fail_with("expected one test")
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

    it("given builds an InlineStep with the Given keyword", fn() {
      gfeature.given("a thing")
      |> should
      |> be_equal(gfeature.InlineStep(
        keyword: gherkin_types.Given,
        text: "a thing",
      ))
      |> or_fail_with("given should use the Given keyword")
    }),

    it("when builds an InlineStep with the When keyword", fn() {
      gfeature.when("I act")
      |> should
      |> be_equal(gfeature.InlineStep(
        keyword: gherkin_types.When,
        text: "I act",
      ))
      |> or_fail_with("when should use the When keyword")
    }),

    it("then builds an InlineStep with the Then keyword", fn() {
      gfeature.then("it works")
      |> should
      |> be_equal(gfeature.InlineStep(
        keyword: gherkin_types.Then,
        text: "it works",
      ))
      |> or_fail_with("then should use the Then keyword")
    }),

    it("and builds an InlineStep with the And keyword", fn() {
      gfeature.and("more")
      |> should
      |> be_equal(gfeature.InlineStep(keyword: gherkin_types.And, text: "more"))
      |> or_fail_with("and should use the And keyword")
    }),

    it("but builds an InlineStep with the But keyword", fn() {
      gfeature.but("not this")
      |> should
      |> be_equal(gfeature.InlineStep(
        keyword: gherkin_types.But,
        text: "not this",
      ))
      |> or_fail_with("but should use the But keyword")
    }),

    it("a hand-built InlineStep runs the handler of its keyword", fn() {
      let registry =
        steps.new()
        |> steps.then_("it works", gherkin_step_ok)
      let suite =
        gfeature.feature("F", registry, [
          gfeature.scenario("S", [
            gfeature.InlineStep(keyword: gherkin_types.Then, text: "it works"),
          ]),
        ])

      runner.new([suite])
      |> runner.run()
      |> list.map(fn(result) { result.status })
      |> should
      |> be_equal([test_types.Passed])
      |> or_fail_with("a hand-built Then step should match the Then handler")
    }),
    it("asterisk builds an InlineStep with the Asterisk keyword", fn() {
      gfeature.asterisk("I pack a passport")
      |> should
      |> be_equal(gfeature.InlineStep(
        keyword: gherkin_types.Asterisk,
        text: "I pack a passport",
      ))
      |> or_fail_with("asterisk should use the Asterisk keyword")
    }),

    it("a * step runs the handler of the phase before it", fn() {
      let registry =
        steps.new()
        |> steps.given("a trip", gherkin_step_ok)
        |> steps.given("I pack a passport", gherkin_step_ok)
      let suite =
        gfeature.feature("F", registry, [
          gfeature.scenario("S", [
            gfeature.given("a trip"),
            gfeature.asterisk("I pack a passport"),
          ]),
        ])

      runner.new([suite])
      |> runner.run()
      |> list.map(fn(result) { result.status })
      |> should
      |> be_equal([test_types.Passed])
      |> or_fail_with("a * step after Given should match a Given handler")
    }),

    it(
      "a scenario that starts with And continues the last Background step",
      fn() {
        let registry =
          steps.new()
          |> steps.given("a base", gherkin_step_ok)
          |> steps.given("another base", gherkin_step_ok)
        let suite =
          gfeature.feature_with_background(
            "F",
            registry,
            gfeature.background([gfeature.given("a base")]),
            [gfeature.scenario("S", [gfeature.and("another base")])],
          )

        runner.new([suite])
        |> runner.run()
        |> list.map(fn(result) { result.status })
        |> should
        |> be_equal([test_types.Passed])
        |> or_fail_with("a leading And should take the Given phase")
      },
    ),

    it("a parsed scenario that starts with And continues the Background", fn() {
      let registry =
        steps.new()
        |> steps.given("a base", gherkin_step_ok)
        |> steps.given("another base", gherkin_step_ok)

      run_parsed(
        "Feature: F\nBackground:\n  Given a base\nScenario: S\n  And another base\n",
        registry,
      )
      |> list.map(fn(result) { result.status })
      |> should
      |> be_equal([test_types.Passed])
      |> or_fail_with("a leading And should take the Given phase")
    }),

    it("an inline scenario that starts with And fails with no Background", fn() {
      let registry =
        steps.new()
        |> steps.given("a base", gherkin_step_ok)
      let suite =
        gfeature.feature("F", registry, [
          gfeature.scenario("S", [gfeature.and("a base")]),
        ])

      runner.new([suite])
      |> runner.run()
      |> list.map(fn(result) { result.failures })
      |> should
      |> be_equal([
        [
          test_types.AssertionFailure(
            operator: "step",
            message: "\"And a base\" has no step before it. And, But and * take the phase of the step before them, so the first step of a Background, or of a Scenario with no Background steps, must use Given, When or Then.",
            payload: None,
          ),
        ],
      ])
      |> or_fail_with("a leading And should fail the scenario")
    }),

    it("an inline Background that starts with But fails the scenario", fn() {
      let registry =
        steps.new()
        |> steps.given("a base", gherkin_step_ok)
      let suite =
        gfeature.feature_with_background(
          "F",
          registry,
          gfeature.background([gfeature.but("a base")]),
          [gfeature.scenario("S", [gfeature.given("a base")])],
        )

      runner.new([suite])
      |> runner.run()
      |> list.map(fn(result) { result.failures })
      |> should
      |> be_equal([
        [
          test_types.AssertionFailure(
            operator: "step",
            message: "\"But a base\" has no step before it. And, But and * take the phase of the step before them, so the first step of a Background, or of a Scenario with no Background steps, must use Given, When or Then.",
            payload: None,
          ),
        ],
      ])
      |> or_fail_with("a leading But in a Background should fail the scenario")
    }),

    it("a registry with a duplicate step definition fails every scenario", fn() {
      let registry =
        steps.new()
        |> steps.then_("it works", gherkin_step_ok)
        |> steps.then_("it works", gherkin_step_ok)
      let suite = gfeature.feature("F", registry, [gfeature.scenario("S", [])])

      runner.new([suite])
      |> runner.run()
      |> list.map(fn(result) { result.failures })
      |> should
      |> be_equal([
        [
          test_types.AssertionFailure(
            operator: "step",
            message: "Duplicate step definition: Then \"it works\" is already defined. Each pattern can have one definition for each of Given, When and Then.",
            payload: None,
          ),
        ],
      ])
      |> or_fail_with("a duplicate should fail a scenario with no steps too")
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

fn rules_feature() -> String {
  "@f
Feature: F
  Background:
    Given feature setup

  @outside
  Scenario: Outside
    Then done

  @r
  Rule: Stock
    Background:
      And rule setup

    @sell
    Scenario: Sell
      Then done

  Rule:
    Scenario: Nameless
      Then done
"
}

fn rules_registry() -> steps.StepRegistry {
  steps.new()
  |> steps.given("feature setup", gherkin_step_ok)
  |> steps.given("rule setup", gherkin_step_ok)
  |> steps.then_("done", gherkin_step_ok)
}

fn examples_feature() -> String {
  "Feature: F
  @o
  Scenario Outline: O
    Given the value is <n>

    @small
    Examples: Small
      | n |
      | 1 |
      | 2 |

    Examples: Empty

    @big
    Examples:
      | n |
      | 3 |
"
}

fn examples_registry() -> steps.StepRegistry {
  steps.new()
  |> steps.given("the value is {int}", gherkin_step_ok)
}

fn group_and_name(result: test_types.TestResult) -> #(List(String), String) {
  #(result.groups, result.name)
}

fn result_name(result: test_types.TestResult) -> String {
  result.name
}

fn result_tags(result: test_types.TestResult) -> List(String) {
  result.tags
}

fn result_status(result: test_types.TestResult) -> test_types.Status {
  result.status
}

fn result_kind(result: test_types.TestResult) -> test_types.TestKind {
  result.kind
}
