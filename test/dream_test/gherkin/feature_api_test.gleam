import dream_test/file
import dream_test/gherkin/feature as gfeature
import dream_test/gherkin/parser
import dream_test/gherkin/steps
import dream_test/gherkin/types as gherkin_types
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should}
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types as test_types
import dream_test/unit.{describe, it}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string

pub fn tests() {
  describe("dream_test/gherkin/feature", [
    it("inline feature() builds a runnable suite", fn() {
      // Arrange
      let registry =
        steps.new(initial: Nil)
        |> steps.given("a thing", gherkin_step_ok)
        |> steps.then("it works", gherkin_check_ok)

      let suite =
        gfeature.feature("Inline Feature", registry, [
          gfeature.scenario("Scenario 1", [
            gfeature.given("a thing"),
            gfeature.then("it works"),
          ]),
        ])

      // Act
      let results =
        runner.new([suite])
        |> runner.run()
        |> test_types.report_tests

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
        steps.new(initial: Nil)
        |> steps.given("a thing", gherkin_step_ok)

      let suite =
        gfeature.feature("Inline Tags", registry, [
          gfeature.scenario("Scenario 1", [gfeature.given("a thing")])
          |> gfeature.with_tags(["smoke"]),
        ])

      // Act
      let results =
        runner.new([suite])
        |> runner.run()
        |> test_types.report_tests

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

    it("feature_suite runs one test for each Examples row", fn() {
      let content =
        "Feature: F\n"
        <> "Scenario Outline: O\n"
        <> "  Given the value is <n>\n"
        <> "Examples:\n"
        <> "  | n |\n"
        <> "  | 1 |\n"
        <> "  | 2 |\n"
      let registry =
        steps.new(initial: Nil)
        |> steps.given("the value is {int}", gherkin_step_ok)

      run_parsed(content, registry)
      |> list.map(name_path_and_status)
      |> should
      |> be_equal([
        #("F::O (Example 1)", test_types.Passed),
        #("F::O (Example 2)", test_types.Passed),
      ])
      |> or_fail_with("each examples row should run with its value")
    }),

    it("feature_suite puts each Rule in a group named Rule: <name>", fn() {
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

    it("feature_suite gives a Rule scenario the Feature and Rule tags", fn() {
      run_parsed(rules_feature(), rules_registry())
      |> list.map(result_tags)
      |> should
      |> be_equal([["f", "outside"], ["f", "r", "sell"], ["f"]])
      |> or_fail_with(
        "expected Feature tags, then Rule tags, then scenario tags",
      )
    }),

    it("a tag filter sees the Rule tags on each test of the Rule", fn() {
      run_parsed_filtered(rules_feature(), rules_registry(), has_rule_tag)
      |> list.map(result_name)
      |> should
      |> be_equal(["Sell"])
      |> or_fail_with("only the scenario in the Rule should run")
    }),

    it("a tag filter sees the Feature tags on each test", fn() {
      run_parsed_filtered(rules_feature(), rules_registry(), has_feature_tag)
      |> list.map(result_name)
      |> should
      |> be_equal(["Outside", "Sell", "Nameless"])
      |> or_fail_with("every scenario should run")
    }),

    it(
      "feature_suite runs the Feature Background, then the Rule Background",
      fn() {
        run_parsed(rules_feature(), rules_registry())
        |> list.map(result_status)
        |> should
        |> be_equal([test_types.Passed, test_types.Passed, test_types.Passed])
        |> or_fail_with("expected the Background steps to run in order")
      },
    ),

    it("feature_suite gives the Rule scenario id the Rule group", fn() {
      run_parsed(rules_feature(), rules_registry())
      |> list.map(scenario_name_path)
      |> should
      |> be_equal(["F::Outside", "F::Rule: Stock::Sell", "F::Rule:::Nameless"])
      |> or_fail_with("expected the Rule group in each id")
    }),

    it("feature_suite gives a scenario in a Rule the Rule in its kind", fn() {
      run_parsed(rules_feature(), rules_registry())
      |> list.map(scenario_rule)
      |> should
      |> be_equal([None, Some("Rule: Stock"), Some("Rule:")])
      |> or_fail_with(
        "expected the Rule group in the kind of each Rule scenario",
      )
    }),

    it("the Gherkin report prints a Rule and a scenario outside it", fn() {
      run_parsed(rules_feature(), rules_registry())
      |> list.map(without_duration)
      |> gherkin_reporter.format_scenarios
      |> should
      |> be_equal(
        "Feature: F
  Scenario: Outside ✓
  Rule: Stock
    Scenario: Sell ✓
  Rule:
    Scenario: Nameless ✓
",
      )
      |> or_fail_with("expected the Rule headings from the result kinds")
    }),

    it(
      "the Gherkin report prints a Feature named like a Rule as a Feature",
      fn() {
        let registry =
          steps.new(initial: Nil)
          |> steps.then("done", gherkin_check_ok)
        let suite =
          gfeature.feature("Rule: refunds", registry, [
            gfeature.scenario("Paying back", [gfeature.then("done")]),
          ])

        run_suites([suite])
        |> list.map(without_duration)
        |> gherkin_reporter.format_scenarios
        |> should
        |> be_equal("Feature: Rule: refunds\n  Scenario: Paying back ✓\n")
        |> or_fail_with("a Feature named like a Rule should print as a Feature")
      },
    ),

    it("feature_suite names example rows after their Examples section", fn() {
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

    it("feature_suite gives example rows the Examples tags", fn() {
      run_parsed(examples_feature(), examples_registry())
      |> list.map(result_tags)
      |> should
      |> be_equal([["o", "small"], ["o", "small"], ["o", "big"]])
      |> or_fail_with("expected the scenario tags, then the Examples tags")
    }),

    it("feature_suite runs no test for Examples without a table", fn() {
      run_parsed(
        "Feature: F\n  Scenario Outline: O\n    Given the value is <n>\n    Examples:\n",
        examples_registry(),
      )
      |> should
      |> be_equal([])
      |> or_fail_with("expected no test")
    }),

    it("feature_suite runs a scenario outline without Examples one time", fn() {
      run_parsed(
        "Feature: F\n  Scenario Outline: O\n    Given the value is 1\n",
        examples_registry(),
      )
      |> list.map(result_name)
      |> should
      |> be_equal(["O"])
      |> or_fail_with("expected one test")
    }),

    it("feature_suite gives the DataTable and DocString to the handlers", fn() {
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
        steps.new(initial: Nil)
        |> steps.given("a table", expect_table)
        |> steps.then("a doc string", expect_doc_string)

      run_parsed(content, registry)
      |> list.map(fn(result) { result.failures })
      |> should
      |> be_equal([[]])
      |> or_fail_with("handlers should get the step arguments")
    }),

    it("feature_suite gives a step both its DataTable and its DocString", fn() {
      let registry =
        steps.new(initial: Nil)
        |> steps.given("a step with both arguments", expect_both_arguments)

      run_file(
        conformance_directory <> "step_with_datatable_and_docstring.feature",
        registry,
      )
      |> list.map(result_failures)
      |> should
      |> be_equal([[], []])
      |> or_fail_with("expected the handler to get both arguments")
    }),

    it("feature_suite puts the example values in the scenario name", fn() {
      run_file(
        conformance_directory <> "example_tokens_everywhere.feature",
        steps.new(initial: Nil),
      )
      |> list.map(result_name)
      |> should
      |> be_equal(["the un (Example 1)", "the uno (Example 2)"])
      |> or_fail_with("expected the example values in the names")
    }),

    it("feature_suite puts the example values in the DocString", fn() {
      let registry =
        steps.new(initial: Nil)
        |> steps.given("the {}", fail_with_doc_string)

      run_file(
        conformance_directory <> "example_tokens_everywhere.feature",
        registry,
      )
      |> list.map(result_failure_messages)
      |> should
      |> be_equal([["trois"], ["tres"]])
      |> or_fail_with("expected the example values in the DocString")
    }),

    it(
      "feature_suite puts the example values in a DocString with a media type",
      fn() {
        let registry =
          steps.new(initial: Nil)
          |> steps.given("this file:", fail_with_doc_string)

        run_file(
          conformance_directory <> "scenario_outline_with_docstring.feature",
          registry,
        )
        |> list.map(result_failure_messages)
        |> should
        |> be_equal([["Greeting:Hello"], ["Greeting:Bonjour"]])
        |> or_fail_with("expected the example values in the DocString")
      },
    ),

    it("feature_suite puts the example values in the DataTable cells", fn() {
      let registry =
        steps.new(initial: Nil)
        |> steps.given("the {}", fail_with_table)

      run_file(
        conformance_directory <> "example_tokens_everywhere.feature",
        registry,
      )
      |> list.map(result_failure_messages)
      |> should
      |> be_equal([["cinq"], ["cinco"]])
      |> or_fail_with("expected the example values in the DataTable")
    }),

    it("feature_suite uses the first column of a repeated example header", fn() {
      run_parsed(
        "Feature: F\n  Scenario Outline: O\n    Given <x>\n    Examples:\n      | x | x |\n      | 1 | 2 |\n",
        steps.new(initial: Nil),
      )
      |> list.map(result_failure_messages)
      |> should
      |> be_equal([["Undefined step: Given 1"]])
      |> or_fail_with("expected the headers to replace in column order")
    }),

    it(
      "feature_suite runs no Background steps for a scenario with no steps",
      fn() {
        run_parsed(
          "Feature: F\n  Background:\n    Given missing\n  Scenario: S\n",
          steps.new(initial: Nil),
        )
        |> list.map(result_status)
        |> should
        |> be_equal([test_types.Passed])
        |> or_fail_with("expected the Background to be left out")
      },
    ),

    it(
      "feature_suite runs no Background steps for an example row with no steps",
      fn() {
        run_parsed(
          "Feature: F\n  Background:\n    Given missing\n  Scenario Outline: O\n    Examples:\n      | n |\n      | 1 |\n",
          steps.new(initial: Nil),
        )
        |> list.map(result_status)
        |> should
        |> be_equal([test_types.Passed])
        |> or_fail_with("expected the Background to be left out")
      },
    ),

    it("a scenario fails with the message of an undefined step", fn() {
      let suite =
        gfeature.feature("F", steps.new(initial: Nil), [
          gfeature.scenario("S", [gfeature.given("missing")]),
        ])

      runner.new([suite])
      |> runner.run()
      |> test_types.report_tests
      |> list.map(fn(result) { result.failures })
      |> should
      |> be_equal([
        [
          test_types.AssertionFailure(
            operator: "step",
            message: "Undefined step: Given missing",
            payload: Some(test_types.StepFailure(
              keyword: "Given",
              text: "missing",
              file: None,
              line: None,
              cause: None,
            )),
          ),
        ],
      ])
      |> or_fail_with("an undefined step should fail the scenario")
    }),

    it("a scenario fails with the Error message of a handler", fn() {
      let registry =
        steps.new(initial: Nil)
        |> steps.given("it breaks", gherkin_step_error)
        |> steps.then("never runs", gherkin_check_ok)
      let suite =
        gfeature.feature("F", registry, [
          gfeature.scenario("S", [
            gfeature.given("it breaks"),
            gfeature.then("never runs"),
          ]),
        ])

      runner.new([suite])
      |> runner.run()
      |> test_types.report_tests
      |> list.map(fn(result) { result.failures })
      |> should
      |> be_equal([
        [
          test_types.AssertionFailure(
            operator: "step",
            message: "boom",
            payload: Some(test_types.StepFailure(
              keyword: "Given",
              text: "it breaks",
              file: None,
              line: None,
              cause: None,
            )),
          ),
        ],
      ])
      |> or_fail_with("a handler Error should fail the scenario")
    }),

    it("a failed check names its step and keeps the matcher failure", fn() {
      // Arrange
      let suite =
        gfeature.feature("F", counter_registry(), [
          gfeature.scenario("S", [
            gfeature.given("the count is 3"),
            gfeature.then("the count should be 5"),
          ]),
        ])

      // Act
      let failures = list.flat_map(run_suites([suite]), result_failures)

      // Assert
      failures
      |> should
      |> be_equal([
        test_types.AssertionFailure(
          operator: "be_equal",
          message: "the count should match",
          payload: Some(test_types.StepFailure(
            keyword: "Then",
            text: "the count should be 5",
            file: None,
            line: None,
            cause: Some(test_types.EqualityFailure(actual: "3", expected: "5")),
          )),
        ),
      ])
      |> or_fail_with("the check failure should name its step")
    }),

    it("a check that returns pending stops the scenario as pending", fn() {
      // Arrange
      let registry =
        steps.new(initial: Nil)
        |> steps.then("it is not written yet", gherkin_check_pending)
      let suite =
        gfeature.feature("F", registry, [
          gfeature.scenario("S", [gfeature.then("it is not written yet")]),
        ])

      // Act
      let statuses = list.map(run_suites([suite]), result_status)

      // Assert
      statuses
      |> should
      |> be_equal([test_types.Pending])
      |> or_fail_with("a pending check should make the scenario pending")
    }),

    it("a step that crashes fails with crash and names its step", fn() {
      // Arrange
      let registry =
        steps.new(initial: Nil)
        |> steps.given("it blows up", gherkin_step_crash)
      let suite =
        gfeature.feature("F", registry, [
          gfeature.scenario("S", [gfeature.given("it blows up")]),
        ])

      // Act
      let failures = list.flat_map(run_suites([suite]), result_failures)

      // Assert
      list.map(failures, crash_summary)
      |> should
      |> be_equal([
        #(
          "crash",
          True,
          Some(test_types.StepFailure(
            keyword: "Given",
            text: "it blows up",
            file: None,
            line: None,
            cause: None,
          )),
        ),
      ])
      |> or_fail_with("the crash should name its step")
    }),

    it("a parsed step names its line, also in a Background", fn() {
      // Act
      let failures =
        run_parsed(
          "Feature: F\n  Background:\n    Given missing\n  Scenario: S\n    Then x\n",
          steps.new(initial: Nil),
        )
        |> list.flat_map(result_failures)

      // Assert
      failures
      |> should
      |> be_equal([
        test_types.AssertionFailure(
          operator: "step",
          message: "Undefined step: Given missing",
          payload: Some(test_types.StepFailure(
            keyword: "Given",
            text: "missing",
            file: None,
            line: Some(3),
            cause: None,
          )),
        ),
      ])
      |> or_fail_with("the Background step should name line 3")
    }),

    it("a step of a feature file names the file and the line", fn() {
      // Arrange
      let path = "test/tmp/features/step_place.feature"
      let _ =
        file.write(
          path,
          "Feature: F\n\n  Scenario Outline: S\n    When I add <n>\n    Examples:\n      | n |\n      | 2 |\n",
        )

      // Act
      let failures =
        run_file_at(path, steps.new(initial: Nil))
        |> list.flat_map(result_failures)

      // Assert
      failures
      |> should
      |> be_equal([
        test_types.AssertionFailure(
          operator: "step",
          message: "Undefined step: When I add 2",
          payload: Some(test_types.StepFailure(
            keyword: "When",
            text: "I add 2",
            file: Some(path),
            line: Some(4),
            cause: None,
          )),
        ),
      ])
      |> or_fail_with("the step should name the file and line 4")
    }),

    it("a scenario fails with the message of a capture error", fn() {
      let registry =
        steps.new(initial: Nil)
        |> steps.given("I add {word}", add_an_int_capture)
      let suite =
        gfeature.feature("F", registry, [
          gfeature.scenario("S", [gfeature.given("I add apples")]),
        ])

      runner.new([suite])
      |> runner.run()
      |> test_types.report_tests
      |> list.map(result_failure_messages)
      |> should
      |> be_equal([["Capture 0 is the word \"apples\", not an integer"]])
      |> or_fail_with("a capture error should fail the scenario")
    }),

    it("feature_with_background runs background and When/And/But steps", fn() {
      let registry =
        steps.new(initial: Nil)
        |> steps.given("a base", gherkin_step_ok)
        |> steps.when("I act", gherkin_step_ok)
        |> steps.when("I act more", gherkin_step_ok)
        |> steps.when("I do not stop", gherkin_step_ok)
        |> steps.then("it works", gherkin_check_ok)
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
      |> test_types.report_tests
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
        steps.new(initial: Nil)
        |> steps.then("it works", gherkin_check_ok)
      let suite =
        gfeature.feature("F", registry, [
          gfeature.scenario("S", [
            gfeature.InlineStep(keyword: gherkin_types.Then, text: "it works"),
          ]),
        ])

      runner.new([suite])
      |> runner.run()
      |> test_types.report_tests
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
        steps.new(initial: Nil)
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
      |> test_types.report_tests
      |> list.map(fn(result) { result.status })
      |> should
      |> be_equal([test_types.Passed])
      |> or_fail_with("a * step after Given should match a Given handler")
    }),

    it(
      "a scenario that starts with And continues the last Background step",
      fn() {
        let registry =
          steps.new(initial: Nil)
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
        |> test_types.report_tests
        |> list.map(fn(result) { result.status })
        |> should
        |> be_equal([test_types.Passed])
        |> or_fail_with("a leading And should take the Given phase")
      },
    ),

    it("a parsed scenario that starts with And continues the Background", fn() {
      let registry =
        steps.new(initial: Nil)
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
        steps.new(initial: Nil)
        |> steps.given("a base", gherkin_step_ok)
      let suite =
        gfeature.feature("F", registry, [
          gfeature.scenario("S", [gfeature.and("a base")]),
        ])

      runner.new([suite])
      |> runner.run()
      |> test_types.report_tests
      |> list.map(fn(result) { result.failures })
      |> should
      |> be_equal([
        [
          test_types.AssertionFailure(
            operator: "step",
            message: "\"And a base\" has no step before it. And, But and * take the phase of the step before them, so the first step of a Background, or of a Scenario with no Background steps, must use Given, When or Then.",
            payload: Some(test_types.StepFailure(
              keyword: "And",
              text: "a base",
              file: None,
              line: None,
              cause: None,
            )),
          ),
        ],
      ])
      |> or_fail_with("a leading And should fail the scenario")
    }),

    it("an inline Background that starts with But fails the scenario", fn() {
      let registry =
        steps.new(initial: Nil)
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
      |> test_types.report_tests
      |> list.map(fn(result) { result.failures })
      |> should
      |> be_equal([
        [
          test_types.AssertionFailure(
            operator: "step",
            message: "\"But a base\" has no step before it. And, But and * take the phase of the step before them, so the first step of a Background, or of a Scenario with no Background steps, must use Given, When or Then.",
            payload: Some(test_types.StepFailure(
              keyword: "But",
              text: "a base",
              file: None,
              line: None,
              cause: None,
            )),
          ),
        ],
      ])
      |> or_fail_with("a leading But in a Background should fail the scenario")
    }),

    it("an Action gives its state to the next step", fn() {
      let suite =
        gfeature.feature("F", counter_registry(), [
          gfeature.scenario("S", [
            gfeature.given("the count is 3"),
            gfeature.when("I add 2"),
            gfeature.then("the count should be 5"),
          ]),
        ])

      run_suites([suite])
      |> list.map(result_status)
      |> should
      |> be_equal([test_types.Passed])
      |> or_fail_with("the state should go from Given to When to Then")
    }),

    it("each scenario starts from the initial state", fn() {
      let registry =
        steps.new(initial: 10)
        |> steps.then("the count should be {int}", expect_count)
      let suite =
        gfeature.feature("F", registry, [
          gfeature.scenario("S", [gfeature.then("the count should be 10")]),
        ])

      run_suites([suite])
      |> list.map(result_status)
      |> should
      |> be_equal([test_types.Passed])
      |> or_fail_with("the scenario should start from the initial state")
    }),

    it("two scenarios that run in parallel do not share state", fn() {
      let suite =
        gfeature.feature("F", counter_registry(), [
          gfeature.scenario("First", [
            gfeature.when("I add 2"),
            gfeature.then("the count should be 2"),
          ]),
          gfeature.scenario("Second", [
            gfeature.when("I add 3"),
            gfeature.then("the count should be 3"),
          ]),
        ])

      runner.new([suite])
      |> runner.max_concurrency(2)
      |> runner.silent
      |> runner.run()
      |> test_types.report_tests
      |> list.map(result_status)
      |> should
      |> be_equal([test_types.Passed, test_types.Passed])
      |> or_fail_with("each scenario should have its own state")
    }),

    it("a Check that fails gives its message to the scenario", fn() {
      let suite =
        gfeature.feature("F", counter_registry(), [
          gfeature.scenario("S", [
            gfeature.given("the count is 3"),
            gfeature.then("the count should be 9"),
          ]),
        ])

      run_suites([suite])
      |> list.map(result_failure_messages)
      |> should
      |> be_equal([["the count should match"]])
      |> or_fail_with("the Check message should fail the scenario")
    }),

    it("the Background state goes to the scenario", fn() {
      let suite =
        gfeature.feature_with_background(
          "F",
          counter_registry(),
          gfeature.background([gfeature.given("the count is 4")]),
          [
            gfeature.scenario("S", [
              gfeature.when("I add 1"),
              gfeature.then("the count should be 5"),
            ]),
          ],
        )

      run_suites([suite])
      |> list.map(result_status)
      |> should
      |> be_equal([test_types.Passed])
      |> or_fail_with("the Background state should reach the scenario")
    }),

    it("an Action Error fails the scenario and stops it", fn() {
      let registry =
        counter_registry()
        |> steps.when("the shop is closed", close_shop)
        |> steps.then("never runs", check_never_runs)
      let suite =
        gfeature.feature("F", registry, [
          gfeature.scenario("S", [
            gfeature.when("the shop is closed"),
            gfeature.then("never runs"),
          ]),
        ])

      run_suites([suite])
      |> list.map(result_failure_messages)
      |> should
      |> be_equal([["the shop is closed"]])
      |> or_fail_with("the Action Error should fail the scenario")
    }),

    it("a step gets the id of its scenario", fn() {
      let registry =
        steps.new(initial: 0)
        |> steps.then("the id is right", fail_with_scenario_id)
      let suite =
        gfeature.feature("F", registry, [
          gfeature.scenario("S", [gfeature.then("the id is right")]),
        ])

      run_suites([suite])
      |> scenario_id_check("F::S#")
      |> should
      |> be_equal(#([True], 1))
      |> or_fail_with("the step context should hold the scenario id")
    }),

    it(
      "two scenarios with the same name in one feature get different ids",
      fn() {
        let suite =
          gfeature.feature("F", scenario_id_registry(), [
            gfeature.scenario("S", [gfeature.then("the id is right")]),
            gfeature.scenario("S", [gfeature.then("the id is right")]),
          ])

        run_suites([suite])
        |> scenario_id_check("F::S#")
        |> should
        |> be_equal(#([True, True], 2))
        |> or_fail_with("each scenario should get its own id")
      },
    ),

    it("scenarios with the same name in two features get different ids", fn() {
      let first =
        gfeature.feature("F", scenario_id_registry(), [
          gfeature.scenario("S", [gfeature.then("the id is right")]),
        ])
      let second =
        gfeature.feature("F", scenario_id_registry(), [
          gfeature.scenario("S", [gfeature.then("the id is right")]),
        ])

      run_suites([first, second])
      |> scenario_id_check("F::S#")
      |> should
      |> be_equal(#([True, True], 2))
      |> or_fail_with("each feature should give its scenario its own id")
    }),

    it("one feature built as two suites gives different ids", fn() {
      let content = "Feature: F\n  Scenario: S\n    Then the id is right\n"
      let registry = scenario_id_registry()

      list.append(run_parsed(content, registry), run_parsed(content, registry))
      |> scenario_id_check("F::S#")
      |> should
      |> be_equal(#([True, True], 2))
      |> or_fail_with("each built suite should give its scenario its own id")
    }),

    it("a feature suite runs with a unit suite in one runner", fn() {
      let feature_suite =
        gfeature.feature("F", counter_registry(), [
          gfeature.scenario("S", [gfeature.then("the count should be 0")]),
        ])
      let unit_suite =
        describe("U", [it("passes", fn() { Ok(test_types.AssertionOk) })])

      run_suites([feature_suite, unit_suite])
      |> list.map(result_status)
      |> should
      |> be_equal([test_types.Passed, test_types.Passed])
      |> or_fail_with("both suites should run")
    }),

    it("a registry with a duplicate step definition fails every scenario", fn() {
      let registry =
        steps.new(initial: Nil)
        |> steps.then("it works", gherkin_check_ok)
        |> steps.then("it works", gherkin_check_ok)
      let suite = gfeature.feature("F", registry, [gfeature.scenario("S", [])])

      runner.new([suite])
      |> runner.run()
      |> test_types.report_tests
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

fn run_suites(suites: List(TestSuite)) -> List(test_types.TestResult) {
  runner.new(suites)
  |> runner.silent
  |> runner.run()
  |> test_types.report_tests
}

fn counter_registry() -> steps.StepRegistry(Int) {
  steps.new(initial: 0)
  |> steps.given("the count is {int}", set_count)
  |> steps.when("I add {int}", add_to_count)
  |> steps.then("the count should be {int}", expect_count)
}

fn set_count(_count: Int, context: steps.StepContext) -> Result(Int, String) {
  steps.get_int(context.captures, 0)
}

fn add_to_count(count: Int, context: steps.StepContext) -> Result(Int, String) {
  use amount <- result.try(steps.get_int(context.captures, 0))
  Ok(count + amount)
}

fn expect_count(
  count: Int,
  context: steps.StepContext,
) -> Result(test_types.AssertionResult, String) {
  use expected <- result.try(steps.get_int(context.captures, 0))
  count
  |> should
  |> be_equal(expected)
  |> or_fail_with("the count should match")
}

fn close_shop(_count: Int, _context: steps.StepContext) -> Result(Int, String) {
  Error("the shop is closed")
}

fn check_never_runs(
  _count: Int,
  _context: steps.StepContext,
) -> Result(test_types.AssertionResult, String) {
  Error("this step should not run")
}

fn scenario_id_registry() -> steps.StepRegistry(Nil) {
  steps.new(initial: Nil)
  |> steps.then("the id is right", fail_with_scenario_id)
}

/// For each result: whether the id that the step got is the id in the
/// result kind, starts with `prefix` and ends with a positive number. Also
/// the count of different ids.
fn scenario_id_check(
  results: List(test_types.TestResult),
  prefix: String,
) -> #(List(Bool), Int) {
  let ids = list.map(results, step_scenario_id)
  #(
    list.map(results, has_scenario_id_shape(_, prefix)),
    list.length(list.unique(ids)),
  )
}

fn step_scenario_id(result: test_types.TestResult) -> String {
  string.concat(result_failure_messages(result))
}

fn has_scenario_id_shape(
  result: test_types.TestResult,
  prefix: String,
) -> Bool {
  let id = step_scenario_id(result)
  case result.kind {
    test_types.GherkinScenario(scenario_id: kind_id, rule: None, ..) ->
      kind_id == id && has_number_after(id, prefix)
    _ -> False
  }
}

fn has_number_after(id: String, prefix: String) -> Bool {
  string.starts_with(id, prefix)
  && is_positive_number(string.drop_start(id, string.length(prefix)))
}

fn is_positive_number(text: String) -> Bool {
  int.parse(text)
  |> result.map(is_above_zero)
  |> result.unwrap(False)
}

fn is_above_zero(number: Int) -> Bool {
  number > 0
}

fn fail_with_scenario_id(
  _count: a,
  context: steps.StepContext,
) -> Result(test_types.AssertionResult, String) {
  Error(context.scenario_id)
}

fn run_parsed(
  content: String,
  registry: steps.StepRegistry(Nil),
) -> List(test_types.TestResult) {
  case parser.parse_string(content) {
    Ok(feature) ->
      runner.new([
        steps.feature_suite(registry: registry, feature: feature),
      ])
      |> runner.run()
      |> test_types.report_tests
    Error(_) -> []
  }
}

const conformance_directory = "test/fixtures/gherkin_conformance/good/"

fn run_file(
  path: String,
  registry: steps.StepRegistry(Nil),
) -> List(test_types.TestResult) {
  case parser.parse_file(path) {
    Ok(feature) ->
      runner.new([
        steps.feature_suite(registry: registry, feature: feature),
      ])
      |> runner.run()
      |> test_types.report_tests
    Error(_) -> []
  }
}

fn expect_both_arguments(
  _state: Nil,
  context: steps.StepContext,
) -> Result(Nil, String) {
  case context.table, context.doc_string {
    Some([["id", "name"], ["1", "bob"]]), Some("hello") -> Ok(Nil)
    table, doc_string ->
      Error(
        "unexpected arguments: "
        <> string.inspect(table)
        <> " "
        <> string.inspect(doc_string),
      )
  }
}

fn fail_with_doc_string(
  _state: Nil,
  context: steps.StepContext,
) -> Result(Nil, String) {
  case context.doc_string {
    Some(content) -> Error(content)
    None -> Ok(Nil)
  }
}

fn fail_with_table(
  _state: Nil,
  context: steps.StepContext,
) -> Result(Nil, String) {
  case context.table {
    Some(rows) -> Error(string.join(list.flatten(rows), ","))
    None -> Ok(Nil)
  }
}

fn result_failures(
  result: test_types.TestResult,
) -> List(test_types.AssertionFailure) {
  result.failures
}

fn result_failure_messages(result: test_types.TestResult) -> List(String) {
  list.map(result.failures, failure_message)
}

fn failure_message(failure: test_types.AssertionFailure) -> String {
  failure.message
}

fn add_an_int_capture(
  _state: Nil,
  context: steps.StepContext,
) -> Result(Nil, String) {
  use _count <- result.try(steps.get_int(context.captures, 0))
  Ok(Nil)
}

fn gherkin_step_error(
  _state: Nil,
  _context: steps.StepContext,
) -> Result(Nil, String) {
  Error("boom")
}

fn expect_table(
  _state: Nil,
  context: steps.StepContext,
) -> Result(Nil, String) {
  case context.table {
    Some([["a", "b"]]) -> Ok(Nil)
    other -> Error("unexpected table: " <> string.inspect(other))
  }
}

fn expect_doc_string(
  _state: Nil,
  context: steps.StepContext,
) -> Result(test_types.AssertionResult, String) {
  case context.doc_string {
    Some("hello") -> Ok(test_types.AssertionOk)
    other -> Error("unexpected doc string: " <> string.inspect(other))
  }
}

fn gherkin_check_ok(
  _state: Nil,
  _context: steps.StepContext,
) -> Result(test_types.AssertionResult, String) {
  Ok(test_types.AssertionOk)
}

fn gherkin_step_ok(
  _state: Nil,
  _context: steps.StepContext,
) -> Result(Nil, String) {
  Ok(Nil)
}

fn run_parsed_filtered(
  content: String,
  registry: steps.StepRegistry(Nil),
  predicate: fn(test_types.TestInfo) -> Bool,
) -> List(test_types.TestResult) {
  case parser.parse_string(content) {
    Ok(feature) ->
      runner.new([
        steps.feature_suite(registry: registry, feature: feature),
      ])
      |> runner.filter_tests(predicate)
      |> runner.run()
      |> test_types.report_tests
    Error(_) -> []
  }
}

fn has_rule_tag(info: test_types.TestInfo) -> Bool {
  list.contains(info.tags, "r")
}

fn has_feature_tag(info: test_types.TestInfo) -> Bool {
  list.contains(info.tags, "f")
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

fn rules_registry() -> steps.StepRegistry(Nil) {
  steps.new(initial: Nil)
  |> steps.given("feature setup", gherkin_step_ok)
  |> steps.given("rule setup", gherkin_step_ok)
  |> steps.then("done", gherkin_check_ok)
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

fn examples_registry() -> steps.StepRegistry(Nil) {
  steps.new(initial: Nil)
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

fn name_path_and_status(
  result: test_types.TestResult,
) -> #(String, test_types.Status) {
  #(scenario_name_path(result), result.status)
}

/// The scenario id of a Gherkin result without its `#<number>` end: the
/// Feature, Rule and scenario names joined with `::`. Another kind gives
/// `""`.
fn scenario_name_path(result: test_types.TestResult) -> String {
  case result.kind {
    test_types.GherkinScenario(scenario_id: id, ..) -> without_number(id)
    _ -> ""
  }
}

/// The result with a duration of 0, so the report has no duration text.
fn without_duration(result: test_types.TestResult) -> test_types.TestResult {
  test_types.TestResult(..result, duration_ms: 0)
}

/// The Rule in the kind of a Gherkin result. Another kind gives `None`.
fn scenario_rule(result: test_types.TestResult) -> option.Option(String) {
  case result.kind {
    test_types.GherkinScenario(rule: rule, ..) -> rule
    _ -> None
  }
}

fn without_number(id: String) -> String {
  let parts = string.split(id, "#")
  list.take(parts, list.length(parts) - 1)
  |> string.join("#")
}

/// The operator, whether the message has the panic text, and the payload.
fn crash_summary(
  failure: test_types.AssertionFailure,
) -> #(String, Bool, option.Option(test_types.FailurePayload)) {
  #(
    failure.operator,
    string.contains(failure.message, "the step blew up"),
    failure.payload,
  )
}

fn gherkin_step_crash(
  _state: Nil,
  _context: steps.StepContext,
) -> Result(Nil, String) {
  panic as "the step blew up"
}

fn run_file_at(
  path: String,
  registry: steps.StepRegistry(Nil),
) -> List(test_types.TestResult) {
  case parser.parse_file(path) {
    Ok(feature) ->
      runner.new([steps.feature_suite(registry: registry, feature: feature)])
      |> runner.silent
      |> runner.run()
      |> test_types.report_tests
    Error(_) -> []
  }
}

fn gherkin_check_pending(
  _state: Nil,
  _context: steps.StepContext,
) -> Result(test_types.AssertionResult, String) {
  Ok(test_types.AssertionPending)
}
