import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/gherkin
import dream_test/types
import dream_test/unit.{describe, group, it}
import fixtures/test_results.{report_of, report_with_cleanup_failure}
import gleam/list
import gleam/option.{type Option, None, Some}

fn scenario(
  groups: List(String),
  name: String,
  status: types.Status,
  failures: List(types.AssertionFailure),
) -> types.TestResult {
  types.TestResult(
    name: name,
    groups: groups,
    status: status,
    duration_ms: 0,
    tags: [],
    failures: failures,
    kind: types.GherkinScenario(
      scenario_id: "id",
      feature: option.from_result(list.last(groups)),
      rule: None,
    ),
  )
}

/// A passed scenario under the groups `groups` that is in no Feature.
fn scenario_without_feature(
  groups: List(String),
  name: String,
) -> types.TestResult {
  types.TestResult(
    ..scenario(groups, name, types.Passed, []),
    kind: types.GherkinScenario(scenario_id: "id", feature: None, rule: None),
  )
}

/// A passed scenario inside the Rule `rule`, under the groups `groups`.
fn scenario_in_rule(
  groups: List(String),
  rule: String,
  name: String,
) -> types.TestResult {
  types.TestResult(
    ..scenario(list.append(groups, [rule]), name, types.Passed, []),
    kind: types.GherkinScenario(
      scenario_id: "id",
      feature: option.from_result(list.last(groups)),
      rule: Some(rule),
    ),
  )
}

fn failure(
  message: String,
  payload: Option(types.FailurePayload),
) -> types.AssertionFailure {
  types.AssertionFailure(operator: "check", message: message, payload: payload)
}

/// Two features, one scenario of each status.
fn every_status() -> List(types.TestResult) {
  [
    scenario(["Cart"], "adds", types.Passed, []),
    scenario(["Cart"], "removes", types.Failed, [
      failure("bad", Some(types.EqualityFailure(actual: "1", expected: "2"))),
      failure("", Some(types.BooleanFailure(actual: True, expected: False))),
      failure("", None),
    ]),
    scenario(["Cart"], "empties", types.Skipped, []),
    scenario(["Checkout"], "pays", types.Pending, []),
    scenario(["Checkout"], "waits", types.TimedOut, [
      failure("too slow", None),
    ]),
    scenario(["Checkout"], "ships", types.SetupFailed, [
      failure("no db", None),
    ]),
  ]
}

pub fn tests() {
  describe("dream_test/reporters/gherkin", [
    it("format_scenarios prints a Rule heading under its Feature", fn() {
      gherkin.format_scenarios([
        scenario(["Suite", "F"], "Outside", types.Passed, []),
        scenario_in_rule(["Suite", "F"], "Rule: A", "One"),
        scenario_in_rule(["Suite", "F"], "Rule: A", "Two"),
        scenario_in_rule(["Suite", "F"], "Rule: B", "Three"),
        scenario_in_rule(["G"], "Rule: C", "Four"),
        scenario_in_rule([], "Rule: D", "Five"),
      ])
      |> should
      |> be_equal(
        "Feature: F
  Scenario: Outside ✓
  Rule: A
    Scenario: One ✓
    Scenario: Two ✓
  Rule: B
    Scenario: Three ✓
Feature: G
  Rule: C
    Scenario: Four ✓
Rule: D
  Scenario: Five ✓
",
      )
      |> or_fail_with("expected Feature and Rule headings")
    }),

    it("format_scenarios prints a Feature named like a Rule as a Feature", fn() {
      gherkin.format_scenarios([
        scenario(["Rule: refunds"], "Paying back", types.Passed, []),
      ])
      |> should
      |> be_equal("Feature: Rule: refunds\n  Scenario: Paying back ✓\n")
      |> or_fail_with("a scenario outside a Rule has no Rule heading")
    }),

    it("is_gherkin_result is false for non-gherkin kinds", fn() {
      let result =
        types.TestResult(
          name: "t",
          groups: ["suite"],
          status: types.Passed,
          duration_ms: 1,
          tags: [],
          failures: [],
          kind: types.Unit,
        )
      case gherkin.is_gherkin_result(result) {
        True ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "gherkin.is_gherkin_result",
              message: "expected false for Unit tests",
              payload: None,
            )),
          )
        False -> Ok(types.AssertionOk)
      }
    }),

    it("format emits some text for a list (even if empty)", fn() {
      let out = gherkin.format(report_of([]))
      case out == "" {
        True ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "gherkin.format",
              message: "expected non-empty output",
              payload: None,
            )),
          )
        False -> Ok(types.AssertionOk)
      }
    }),

    it("report does not crash", fn() {
      let write = fn(_s: String) { Nil }
      gherkin.report(report_of([]), write)
      Ok(types.AssertionOk)
    }),

    it("is_gherkin_result is true for a Gherkin scenario", fn() {
      gherkin.is_gherkin_result(scenario(["F"], "s", types.Passed, []))
      |> should
      |> be_equal(True)
      |> or_fail_with("a GherkinScenario result is a Gherkin result")
    }),

    group("format", [
      it("writes the hook failures before the summary", fn() {
        gherkin.format(
          report_with_cleanup_failure([
            scenario(["Cart"], "adds", types.Passed, []),
          ]),
        )
        |> should
        |> be_equal(
          "Feature: Cart\n"
          <> "  Scenario: adds ✓\n"
          <> "\n"
          <> "Setup and teardown failures:\n"
          <> "  after_all in root\n"
          <> "    no cleanup\n"
          <> "\n"
          <> "Summary: 1 run, 0 failed, 1 passed, 1 teardown failed in 0ms\n",
        )
        |> or_fail_with("the hook failures should have their own section")
      }),

      it("writes every status and the failures", fn() {
        gherkin.format(report_of(every_status()))
        |> should
        |> be_equal(
          "Feature: Cart\n"
          <> "  Scenario: adds ✓\n"
          <> "  Scenario: removes ✗\n"
          <> "      ✗ check\n"
          <> "        Message: bad\n"
          <> "        Expected: 2\n"
          <> "        Actual:   1\n"
          <> "      ✗ check\n"
          <> "      ✗ check\n"
          <> "  Scenario: empties -\n"
          <> "Feature: Checkout\n"
          <> "  Scenario: pays ~\n"
          <> "  Scenario: waits !\n"
          <> "      ✗ check\n"
          <> "        Message: too slow\n"
          <> "  Scenario: ships ⚠\n"
          <> "      ✗ check\n"
          <> "        Message: no db\n"
          <> "\n"
          <> "Summary: 6 run, 1 failed, 1 passed, 1 skipped, 1 pending, 1 timed out, 1 setup failed in 0ms\n",
        )
        |> or_fail_with("each status should have its marker")
      }),

      it("writes no heading for a scenario with no Feature and no group", fn() {
        gherkin.format(report_of([scenario([], "alone", types.Passed, [])]))
        |> should
        |> be_equal(
          "Scenario: alone ✓\n"
          <> "\n"
          <> "Summary: 1 run, 0 failed, 1 passed in 0ms\n",
        )
        |> or_fail_with(
          "a scenario with nothing to name should have no heading",
        )
      }),

      it("writes the groups of a scenario in no Feature as its heading", fn() {
        gherkin.format_scenarios([
          scenario_without_feature(["Shop", "Billing"], "pays"),
        ])
        |> should
        |> be_equal("Shop > Billing\n  Scenario: pays ✓\n")
        |> or_fail_with("the groups should be the heading, with no Feature")
      }),

      it("writes the groups of a unit test as its heading", fn() {
        gherkin.format_scenarios([
          types.TestResult(
            ..scenario(["math", "add"], "sums", types.Passed, []),
            kind: types.Unit,
          ),
        ])
        |> should
        |> be_equal("math > add\n  Scenario: sums ✓\n")
        |> or_fail_with("a unit test has no Feature")
      }),

      it("format_scenarios writes the scenarios without a summary", fn() {
        gherkin.format_scenarios([
          scenario(["Cart"], "adds", types.Passed, []),
          scenario(["Cart"], "removes", types.Failed, [failure("bad", None)]),
        ])
        |> should
        |> be_equal(
          "Feature: Cart\n"
          <> "  Scenario: adds ✓\n"
          <> "  Scenario: removes ✗\n"
          <> "      ✗ check\n"
          <> "        Message: bad\n",
        )
        |> or_fail_with("format_scenarios should give no summary line")
      }),

      it("format_scenarios gives no text for no results", fn() {
        gherkin.format_scenarios([])
        |> should
        |> be_equal("")
        |> or_fail_with("no results should give no text")
      }),

      it("shows the duration of a slow scenario", fn() {
        gherkin.format(
          report_of([
            types.TestResult(
              ..scenario(["F"], "slow", types.Passed, []),
              duration_ms: 1500,
            ),
          ]),
        )
        |> should
        |> be_equal(
          "Feature: F\n"
          <> "  Scenario: slow ✓ (1.5s)\n"
          <> "\n"
          <> "Summary: 1 run, 0 failed, 1 passed in 1.5s\n",
        )
        |> or_fail_with("a slow scenario should show its duration")
      }),
    ]),
    group("step failures", [
      it("names the step, its file and its line before the message", fn() {
        // Arrange
        let failed =
          types.AssertionFailure(
            operator: "be_equal",
            message: "the total should match",
            payload: Some(types.StepFailure(
              keyword: "Then",
              text: "the total is 15.00",
              file: Some("test/cart.feature"),
              line: Some(7),
              cause: Some(types.EqualityFailure(
                actual: "14.0",
                expected: "15.0",
              )),
            )),
          )

        // Act
        let text =
          gherkin.format_scenarios([
            scenario(["Cart"], "totals", types.Failed, [failed]),
          ])

        // Assert
        text
        |> should
        |> be_equal(
          "Feature: Cart\n"
          <> "  Scenario: totals ✗\n"
          <> "      ✗ be_equal\n"
          <> "        Step: Then the total is 15.00 (test/cart.feature:7)\n"
          <> "        Message: the total should match\n"
          <> "        Expected: 15.0\n"
          <> "        Actual:   14.0\n",
        )
        |> or_fail_with("expected the step line first")
      }),
      it("names the step with the place that is known", fn() {
        // Arrange
        let step_failure = fn(file, line) {
          types.AssertionFailure(
            operator: "step",
            message: "Undefined step: When I pay",
            payload: Some(types.StepFailure(
              keyword: "When",
              text: "I pay",
              file: file,
              line: line,
              cause: None,
            )),
          )
        }

        // Act
        let text =
          gherkin.format_scenarios([
            scenario(["Cart"], "pays", types.Failed, [
              step_failure(None, Some(4)),
              step_failure(Some("pay.feature"), None),
              step_failure(None, None),
            ]),
          ])

        // Assert
        text
        |> should
        |> be_equal(
          "Feature: Cart\n"
          <> "  Scenario: pays ✗\n"
          <> "      ✗ step\n"
          <> "        Step: When I pay (line 4)\n"
          <> "        Message: Undefined step: When I pay\n"
          <> "      ✗ step\n"
          <> "        Step: When I pay (pay.feature)\n"
          <> "        Message: Undefined step: When I pay\n"
          <> "      ✗ step\n"
          <> "        Step: When I pay\n"
          <> "        Message: Undefined step: When I pay\n",
        )
        |> or_fail_with("expected the line, the file, then no place")
      }),
      it("shows a snapshot of more than one line as a diff", fn() {
        // Arrange
        let failed =
          failure(
            "the receipt should match",
            Some(types.SnapshotFailure(
              actual: "a\nB",
              expected: "a\nb",
              snapshot_path: "r.snap",
              is_missing: False,
            )),
          )

        // Act
        let text =
          gherkin.format_scenarios([
            scenario(["Cart"], "prints", types.Failed, [failed]),
          ])

        // Assert
        text
        |> should
        |> be_equal(
          "Feature: Cart\n"
          <> "  Scenario: prints ✗\n"
          <> "      ✗ check\n"
          <> "        Message: the receipt should match\n"
          <> "        Snapshot: r.snap\n"
          <> "        Diff (- expected, + actual):\n"
          <> "            a\n"
          <> "          - b\n"
          <> "          + B\n",
        )
        |> or_fail_with("expected the diff under the snapshot path")
      }),
      it("names a missing snapshot", fn() {
        // Arrange
        let failed =
          failure(
            "",
            Some(types.SnapshotFailure(
              actual: "",
              expected: "",
              snapshot_path: "r.snap",
              is_missing: True,
            )),
          )

        // Act
        let text =
          gherkin.format_scenarios([
            scenario(["Cart"], "prints", types.Failed, [failed]),
          ])

        // Assert
        text
        |> should
        |> be_equal(
          "Feature: Cart\n"
          <> "  Scenario: prints ✗\n"
          <> "      ✗ check\n"
          <> "        Snapshot missing: r.snap\n",
        )
        |> or_fail_with("expected the path of the missing snapshot")
      }),
      it("shows an equality failure of more than one line as a diff", fn() {
        // Arrange
        let failed =
          failure(
            "",
            Some(types.EqualityFailure(actual: "x\nz", expected: "x\ny")),
          )

        // Act
        let text =
          gherkin.format_scenarios([
            scenario(["Cart"], "compares", types.Failed, [failed]),
          ])

        // Assert
        text
        |> should
        |> be_equal(
          "Feature: Cart\n"
          <> "  Scenario: compares ✗\n"
          <> "      ✗ check\n"
          <> "        Diff (- expected, + actual):\n"
          <> "            x\n"
          <> "          - y\n"
          <> "          + z\n",
        )
        |> or_fail_with("expected the diff in place of Expected and Actual")
      }),
    ]),
  ])
}
