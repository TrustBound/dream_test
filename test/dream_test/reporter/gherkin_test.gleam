import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/gherkin
import dream_test/types
import dream_test/unit.{describe, group, it}
import fixtures/test_results.{report_of, report_with_cleanup_failure}
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
    kind: types.GherkinScenario("id"),
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
        scenario(["Suite", "F", "Rule: A"], "One", types.Passed, []),
        scenario(["Suite", "F", "Rule: A"], "Two", types.Passed, []),
        scenario(["Suite", "F", "Rule: B"], "Three", types.Passed, []),
        scenario(["G", "Rule: C"], "Four", types.Passed, []),
        scenario(["Rule: D"], "Five", types.Passed, []),
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
Feature: Unknown Feature
  Rule: D
    Scenario: Five ✓
",
      )
      |> or_fail_with("expected Feature and Rule headings")
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
      it("writes the tear-down failures before the summary", fn() {
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
          <> "Tear-down failures:\n"
          <> "  after_all in root\n"
          <> "    no cleanup\n"
          <> "\n"
          <> "Summary: 1 run, 0 failed, 1 passed, 1 tear-down failed in 0ms\n",
        )
        |> or_fail_with("the tear-down failures should have their own section")
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

      it("writes a placeholder feature for a result with no group", fn() {
        gherkin.format(report_of([scenario([], "alone", types.Passed, [])]))
        |> should
        |> be_equal(
          "Feature: Unknown Feature\n"
          <> "  Scenario: alone ✓\n"
          <> "\n"
          <> "Summary: 1 run, 0 failed, 1 passed in 0ms\n",
        )
        |> or_fail_with("the feature should have a placeholder name")
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
  ])
}
