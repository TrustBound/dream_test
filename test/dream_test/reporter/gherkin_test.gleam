import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/gherkin
import dream_test/types
import dream_test/unit.{describe, group, it}
import gleam/option.{type Option, None, Some}

fn scenario(
  full_name: List(String),
  status: types.Status,
  failures: List(types.AssertionFailure),
) -> types.TestResult {
  types.TestResult(
    name: "fallback",
    full_name: full_name,
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
    scenario(["Cart", "adds"], types.Passed, []),
    scenario(["Cart", "removes"], types.Failed, [
      failure("bad", Some(types.EqualityFailure(actual: "1", expected: "2"))),
      failure("", Some(types.BooleanFailure(actual: True, expected: False))),
      failure("", None),
    ]),
    scenario(["Cart", "empties"], types.Skipped, []),
    scenario(["Checkout", "pays"], types.Pending, []),
    scenario(["Checkout", "waits"], types.TimedOut, [
      failure("too slow", None),
    ]),
    scenario(["Checkout", "ships"], types.SetupFailed, [
      failure("no db", None),
    ]),
  ]
}

pub fn tests() {
  describe("dream_test/reporters/gherkin", [
    it("is_gherkin_result is false for non-gherkin kinds", fn() {
      let result =
        types.TestResult(
          name: "t",
          full_name: ["suite", "t"],
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
      let out = gherkin.format([])
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
      gherkin.report([], write)
      Ok(types.AssertionOk)
    }),

    it("is_gherkin_result is true for a Gherkin scenario", fn() {
      gherkin.is_gherkin_result(scenario(["F", "s"], types.Passed, []))
      |> should
      |> be_equal(True)
      |> or_fail_with("a GherkinScenario result is a Gherkin result")
    }),

    group("format", [
      it("writes every status and the failures", fn() {
        gherkin.format(every_status())
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
          <> "  Scenario: ships ⚠\n"
          <> "      ✗ check\n"
          <> "        Message: no db\n"
          <> "\n"
          <> "Summary: 6 run, 1 failed, 1 passed, 1 setup failed, 1 timed out, 1 pending, 1 skipped in 0ms\n",
        )
        |> or_fail_with("each status should have its marker")
      }),

      it("writes a placeholder for a result with no full name", fn() {
        gherkin.format([scenario([], types.Passed, [])])
        |> should
        |> be_equal(
          "Feature: Unknown Feature\n"
          <> "  Scenario: Unknown Scenario ✓\n"
          <> "\n"
          <> "Summary: 1 run, 0 failed, 1 passed in 0ms\n",
        )
        |> or_fail_with(
          "the feature and scenario should have placeholder names",
        )
      }),

      it("shows the duration of a slow scenario", fn() {
        gherkin.format([
          types.TestResult(
            ..scenario(["F", "slow"], types.Passed, []),
            duration_ms: 1500,
          ),
        ])
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
