import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/json
import dream_test/reporters/types as reporter_types
import dream_test/types
import dream_test/unit.{describe, group, it}
import fixtures/test_results.{report_of, report_with_cleanup_failure}
import gleam/list
import gleam/option.{None, Some}
import gleam/string

fn sample_results() -> List(types.TestResult) {
  [
    types.TestResult(
      name: "t1",
      groups: ["suite"],
      status: types.Passed,
      duration_ms: 1,
      tags: [],
      failures: [],
      kind: types.Unit,
    ),
    types.TestResult(
      name: "t2",
      groups: ["suite"],
      status: types.Failed,
      duration_ms: 1,
      tags: [],
      failures: [
        types.AssertionFailure(operator: "fail", message: "nope", payload: None),
      ],
      kind: types.Unit,
    ),
  ]
}

fn result_of(
  groups: List(String),
  name: String,
  status: types.Status,
  failures: List(types.AssertionFailure),
  kind: types.TestKind,
) -> types.TestResult {
  types.TestResult(
    name: name,
    groups: groups,
    status: status,
    duration_ms: 0,
    tags: [],
    failures: failures,
    kind: kind,
  )
}

fn failure(
  message: String,
  payload: types.FailurePayload,
) -> types.AssertionFailure {
  types.AssertionFailure(
    operator: "check",
    message: message,
    payload: Some(payload),
  )
}

fn timeout_failure() -> types.AssertionFailure {
  types.AssertionFailure(
    operator: "timeout",
    message: "too slow",
    payload: None,
  )
}

/// One test of each status, in one group.
fn every_status() -> List(types.TestResult) {
  [
    result_of(["s"], "passes", types.Passed, [], types.Unit),
    result_of(
      ["s"],
      "fails",
      types.Failed,
      [failure("bad", types.EqualityFailure(actual: "1", expected: "2"))],
      types.Unit,
    ),
    result_of(["s"], "skips", types.Skipped, [], types.Unit),
    result_of(["s"], "waits", types.Pending, [], types.Unit),
    result_of(
      ["s"],
      "times out",
      types.TimedOut,
      [timeout_failure()],
      types.Unit,
    ),
    result_of(
      ["s"],
      "has no setup",
      types.SetupFailed,
      [
        types.AssertionFailure(
          operator: "before_each",
          message: "no db",
          payload: None,
        ),
      ],
      types.Unit,
    ),
  ]
}

/// One failure of each payload, with both values of every Bool.
fn every_payload() -> List(types.AssertionFailure) {
  [
    failure("", types.BooleanFailure(actual: True, expected: False)),
    failure("", types.BooleanFailure(actual: False, expected: True)),
    failure("", types.OptionFailure(actual: "None", expected_some: True)),
    failure("", types.OptionFailure(actual: "Some(1)", expected_some: False)),
    failure("", types.ResultFailure(actual: "Error(1)", expected_ok: True)),
    failure("", types.ResultFailure(actual: "Ok(1)", expected_ok: False)),
    failure(
      "",
      types.CollectionFailure(
        actual: "[1]",
        expected: "2",
        operation: "contain",
      ),
    ),
    failure(
      "",
      types.ComparisonFailure(actual: "1", expected: "2", operator: "greater"),
    ),
    failure(
      "",
      types.StringMatchFailure(
        actual: "abc",
        pattern: "x",
        operation: "start_with",
      ),
    ),
    failure(
      "",
      types.SnapshotFailure(
        actual: "new",
        expected: "",
        snapshot_path: "a.snap",
        is_missing: True,
      ),
    ),
    failure(
      "",
      types.SnapshotFailure(
        actual: "new",
        expected: "old",
        snapshot_path: "b.snap",
        is_missing: False,
      ),
    ),
    failure("", types.CustomMatcherFailure(actual: "7", description: "is even")),
  ]
}

fn config(color: Bool, mode: reporter_types.BddOutputMode) {
  reporter_types.BddReporterConfig(color: color, mode: mode)
}

fn gherkin_results() -> List(types.TestResult) {
  [
    result_of(
      ["Cart"],
      "adds",
      types.Passed,
      [],
      types.GherkinScenario(
        scenario_id: "c1",
        feature: Some("Cart"),
        rule: None,
      ),
    ),
    result_of(
      ["Cart"],
      "removes",
      types.Failed,
      [failure("gone", types.EqualityFailure(actual: "1", expected: "0"))],
      types.GherkinScenario(
        scenario_id: "c2",
        feature: Some("Cart"),
        rule: None,
      ),
    ),
  ]
}

pub fn tests() {
  describe("dream_test/reporters/bdd", [
    group("format", [
      it("includes test names", fn() {
        let out = bdd.format(report_of(sample_results()))
        case string.contains(out, "t1") && string.contains(out, "t2") {
          True -> Ok(types.AssertionOk)
          False ->
            Ok(
              types.AssertionFailed(types.AssertionFailure(
                operator: "bdd.format",
                message: "expected formatted output to contain test names",
                payload: None,
              )),
            )
        }
      }),

      it("renders a basic BDD-style report (exact)", fn() {
        let passing =
          types.TestResult(
            name: "adds numbers",
            groups: ["Math"],
            status: types.Passed,
            duration_ms: 0,
            tags: [],
            failures: [],
            kind: types.Unit,
          )

        let failure =
          types.AssertionFailure(
            operator: "equal",
            message: "1 + 2 should equal 3",
            payload: Some(types.EqualityFailure(actual: "4", expected: "3")),
          )

        let failing =
          types.TestResult(
            name: "adds numbers incorrectly",
            groups: ["Math"],
            status: types.Failed,
            duration_ms: 0,
            tags: [],
            failures: [failure],
            kind: types.Unit,
          )

        let results = [passing, failing]

        let expected =
          "Math\n"
          <> "  ✓ adds numbers\n"
          <> "  ✗ adds numbers incorrectly\n"
          <> "    equal\n"
          <> "      Message: 1 + 2 should equal 3\n"
          <> "      Expected: 3\n"
          <> "      Actual:   4\n"
          <> "    Run it alone: gleam test -- --only \"Math/adds numbers incorrectly\"\n"
          <> "\n"
          <> "Summary: 2 run, 1 failed, 1 passed in 0ms\n"

        bdd.format(report_of(results))
        |> should
        |> be_equal(expected)
        |> or_fail_with("bdd.format should render a basic BDD-style report")
      }),
    ]),

    group("builders", [
      it("color leaves a JSON reporter as it is", fn() {
        bdd.color(json.new())
        |> should
        |> be_equal(json.new())
        |> or_fail_with("color should change only a BDD reporter")
      }),

      it("summary_only leaves a JSON reporter as it is", fn() {
        bdd.summary_only(json.new())
        |> should
        |> be_equal(json.new())
        |> or_fail_with("summary_only should change only a BDD reporter")
      }),

      it("failures_only leaves a JSON reporter as it is", fn() {
        bdd.failures_only(json.new())
        |> should
        |> be_equal(json.new())
        |> or_fail_with("failures_only should change only a BDD reporter")
      }),

      it("failures_only keeps the colour setting", fn() {
        bdd.new()
        |> bdd.color()
        |> bdd.failures_only()
        |> should
        |> be_equal(
          reporter_types.Bdd(config(True, reporter_types.BddFailuresOnly)),
        )
        |> or_fail_with("failures_only should keep colour on")
      }),
    ]),

    group("render", [
      it("writes the hook failures before the summary", fn() {
        bdd.render(
          config(False, reporter_types.BddFull),
          report_with_cleanup_failure([
            result_of(["root"], "adds", types.Passed, [], types.Unit),
          ]),
        )
        |> should
        |> be_equal(
          "root\n"
          <> "  ✓ adds\n"
          <> "\n"
          <> "Setup and teardown failures:\n"
          <> "  after_all in root\n"
          <> "    no cleanup\n"
          <> "\n"
          <> "Summary: 1 run, 0 failed, 1 passed, 1 teardown failed in 0ms\n",
        )
        |> or_fail_with("the hook failures should have their own section")
      }),

      it("writes the hook failures in colour", fn() {
        bdd.render(
          config(True, reporter_types.BddFailuresOnly),
          report_with_cleanup_failure([]) |> types.allow_no_tests,
        )
        |> should
        |> be_equal(
          "\n"
          <> "\u{1b}[1m\u{1b}[31mSetup and teardown failures:\u{1b}[0m\u{1b}[0m\n"
          <> "  \u{1b}[31mafter_all in root\u{1b}[0m\n"
          <> "    no cleanup\n"
          <> "\n"
          <> "\u{1b}[1m\u{1b}[36mSummary: \u{1b}[0m\u{1b}[0m\u{1b}[36m0\u{1b}[0m run, \u{1b}[31m0\u{1b}[0m failed, \u{1b}[32m0\u{1b}[0m passed, \u{1b}[31m1\u{1b}[0m\u{1b}[2m teardown failed\u{1b}[0m in \u{1b}[36m0ms\u{1b}[0m\n",
        )
        |> or_fail_with("the teardown section should have colour")
      }),

      it("writes the hook failures in failures-only mode", fn() {
        bdd.render(
          config(False, reporter_types.BddFailuresOnly),
          report_with_cleanup_failure([
            result_of(["root"], "adds", types.Passed, [], types.Unit),
          ]),
        )
        |> should
        |> be_equal(
          "\n"
          <> "Setup and teardown failures:\n"
          <> "  after_all in root\n"
          <> "    no cleanup\n"
          <> "\n"
          <> "Summary: 1 run, 0 failed, 1 passed, 1 teardown failed in 0ms\n",
        )
        |> or_fail_with("failures-only mode should show hook failures")
      }),

      it("writes every status without colour", fn() {
        bdd.render(
          config(False, reporter_types.BddFull),
          report_of(every_status()),
        )
        |> should
        |> be_equal(
          "s\n"
          <> "  ✓ passes\n"
          <> "  ✗ fails\n"
          <> "    check\n"
          <> "      Message: bad\n"
          <> "      Expected: 2\n"
          <> "      Actual:   1\n"
          <> "    Run it alone: gleam test -- --only \"s/fails\"\n"
          <> "  - skips\n"
          <> "  ~ waits\n"
          <> "  ! times out\n"
          <> "    timeout\n"
          <> "      Message: too slow\n"
          <> "    Run it alone: gleam test -- --only \"s/times out\"\n"
          <> "  ⚠ has no setup\n"
          <> "    before_each\n"
          <> "      Message: no db\n"
          <> "    Run it alone: gleam test -- --only \"s/has no setup\"\n"
          <> "\n"
          <> "Failures:\n"
          <> "s\n"
          <> "  ✗ fails\n"
          <> "    check\n"
          <> "      Message: bad\n"
          <> "      Expected: 2\n"
          <> "      Actual:   1\n"
          <> "    Run it alone: gleam test -- --only \"s/fails\"\n"
          <> "  ! times out\n"
          <> "    timeout\n"
          <> "      Message: too slow\n"
          <> "    Run it alone: gleam test -- --only \"s/times out\"\n"
          <> "  ⚠ has no setup\n"
          <> "    before_each\n"
          <> "      Message: no db\n"
          <> "    Run it alone: gleam test -- --only \"s/has no setup\"\n"
          <> "\n"
          <> "Summary: 6 run, 1 failed, 1 passed, 1 skipped, 1 pending, 1 timed out, 1 setup failed in 0ms\n",
        )
        |> or_fail_with("every status should have its marker and failures")
      }),

      it("writes every status with colour", fn() {
        bdd.render(
          config(True, reporter_types.BddFull),
          report_of(every_status()),
        )
        |> should
        |> be_equal(
          "\u{001B}[1m\u{001B}[36ms\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[32m✓\u{001B}[0m passes\n"
          <> "  \u{001B}[31m✗\u{001B}[0m \u{001B}[31mfails\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Message: \u{001B}[0m\u{001B}[31mbad\u{001B}[0m\n"
          <> "  \u{001B}[2m    Expected: \u{001B}[0m\u{001B}[32m2\u{001B}[0m\n"
          <> "  \u{001B}[2m    Actual:   \u{001B}[0m\u{001B}[31m1\u{001B}[0m\n"
          <> "    \u{001B}[2mRun it alone: \u{001B}[0mgleam test -- --only \"s/fails\"\n"
          <> "  \u{001B}[33m-\u{001B}[0m \u{001B}[33mskips\u{001B}[0m\n"
          <> "  \u{001B}[33m~\u{001B}[0m \u{001B}[33mwaits\u{001B}[0m\n"
          <> "  \u{001B}[31m!\u{001B}[0m \u{001B}[31mtimes out\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mtimeout\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Message: \u{001B}[0m\u{001B}[31mtoo slow\u{001B}[0m\n"
          <> "    \u{001B}[2mRun it alone: \u{001B}[0mgleam test -- --only \"s/times out\"\n"
          <> "  \u{001B}[31m⚠\u{001B}[0m \u{001B}[31mhas no setup\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mbefore_each\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Message: \u{001B}[0m\u{001B}[31mno db\u{001B}[0m\n"
          <> "    \u{001B}[2mRun it alone: \u{001B}[0mgleam test -- --only \"s/has no setup\"\n"
          <> "\n"
          <> "\u{001B}[1m\u{001B}[31mFailures:\u{001B}[0m\u{001B}[0m\n"
          <> "\u{001B}[1m\u{001B}[36ms\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[31m✗\u{001B}[0m \u{001B}[31mfails\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Message: \u{001B}[0m\u{001B}[31mbad\u{001B}[0m\n"
          <> "  \u{001B}[2m    Expected: \u{001B}[0m\u{001B}[32m2\u{001B}[0m\n"
          <> "  \u{001B}[2m    Actual:   \u{001B}[0m\u{001B}[31m1\u{001B}[0m\n"
          <> "    \u{001B}[2mRun it alone: \u{001B}[0mgleam test -- --only \"s/fails\"\n"
          <> "  \u{001B}[31m!\u{001B}[0m \u{001B}[31mtimes out\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mtimeout\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Message: \u{001B}[0m\u{001B}[31mtoo slow\u{001B}[0m\n"
          <> "    \u{001B}[2mRun it alone: \u{001B}[0mgleam test -- --only \"s/times out\"\n"
          <> "  \u{001B}[31m⚠\u{001B}[0m \u{001B}[31mhas no setup\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mbefore_each\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Message: \u{001B}[0m\u{001B}[31mno db\u{001B}[0m\n"
          <> "    \u{001B}[2mRun it alone: \u{001B}[0mgleam test -- --only \"s/has no setup\"\n"
          <> "\n"
          <> "\u{001B}[1m\u{001B}[36mSummary: \u{001B}[0m\u{001B}[0m\u{001B}[36m6\u{001B}[0m run, \u{001B}[31m1\u{001B}[0m failed, \u{001B}[32m1\u{001B}[0m passed, \u{001B}[33m1\u{001B}[0m\u{001B}[2m skipped\u{001B}[0m, \u{001B}[33m1\u{001B}[0m\u{001B}[2m pending\u{001B}[0m, \u{001B}[31m1\u{001B}[0m\u{001B}[2m timed out\u{001B}[0m, \u{001B}[31m1\u{001B}[0m\u{001B}[2m setup failed\u{001B}[0m in \u{001B}[36m0ms\u{001B}[0m\n",
        )
        |> or_fail_with("every status should have its colour")
      }),

      it("writes only the failures in failures_only mode", fn() {
        bdd.render(
          config(False, reporter_types.BddFailuresOnly),
          report_of(every_status()),
        )
        |> should
        |> be_equal(
          "s\n"
          <> "  ✗ fails\n"
          <> "    check\n"
          <> "      Message: bad\n"
          <> "      Expected: 2\n"
          <> "      Actual:   1\n"
          <> "    Run it alone: gleam test -- --only \"s/fails\"\n"
          <> "  ! times out\n"
          <> "    timeout\n"
          <> "      Message: too slow\n"
          <> "    Run it alone: gleam test -- --only \"s/times out\"\n"
          <> "  ⚠ has no setup\n"
          <> "    before_each\n"
          <> "      Message: no db\n"
          <> "    Run it alone: gleam test -- --only \"s/has no setup\"\n"
          <> "\n"
          <> "Summary: 6 run, 1 failed, 1 passed, 1 skipped, 1 pending, 1 timed out, 1 setup failed in 0ms\n",
        )
        |> or_fail_with("only failed, timed out and setup failed tests")
      }),

      it("writes only the summary in summary_only mode", fn() {
        bdd.render(
          config(False, reporter_types.BddSummaryOnly),
          report_of(every_status()),
        )
        |> should
        |> be_equal(
          "Summary: 6 run, 1 failed, 1 passed, 1 skipped, 1 pending, 1 timed out, 1 setup failed in 0ms\n",
        )
        |> or_fail_with("only the summary line")
      }),

      it("writes the hook failures in summary_only mode", fn() {
        bdd.render(
          config(False, reporter_types.BddSummaryOnly),
          report_with_cleanup_failure([
            result_of(["root"], "adds", types.Passed, [], types.Unit),
          ]),
        )
        |> should
        |> be_equal(
          "\n"
          <> "Setup and teardown failures:\n"
          <> "  after_all in root\n"
          <> "    no cleanup\n"
          <> "\n"
          <> "Summary: 1 run, 0 failed, 1 passed, 1 teardown failed in 0ms\n",
        )
        |> or_fail_with("summary_only mode should show what failed")
      }),

      it("writes Feature and Scenario for Gherkin results", fn() {
        bdd.render(
          config(False, reporter_types.BddFull),
          report_of(gherkin_results()),
        )
        |> should
        |> be_equal(
          "Feature: Cart\n"
          <> "  ✓ Scenario: adds\n"
          <> "  ✗ Scenario: removes\n"
          <> "    check\n"
          <> "      Message: gone\n"
          <> "      Expected: 0\n"
          <> "      Actual:   1\n"
          <> "    Run it alone: gleam test -- --only \"Cart/removes\"\n"
          <> "\n"
          <> "Failures:\n"
          <> "Feature: Cart\n"
          <> "  ✗ Scenario: removes\n"
          <> "    check\n"
          <> "      Message: gone\n"
          <> "      Expected: 0\n"
          <> "      Actual:   1\n"
          <> "    Run it alone: gleam test -- --only \"Cart/removes\"\n"
          <> "\n"
          <> "Summary: 2 run, 1 failed, 1 passed in 0ms\n",
        )
        |> or_fail_with(
          "Gherkin results should have Feature and Scenario labels",
        )
      }),
    ]),

    group("format with hook failures", [
      it("format writes the hook failures before the summary", fn() {
        bdd.format(
          report_with_cleanup_failure([
            result_of(["root"], "adds", types.Passed, [], types.Unit),
          ]),
        )
        |> should
        |> be_equal(
          "root\n"
          <> "  ✓ adds\n"
          <> "\n"
          <> "Setup and teardown failures:\n"
          <> "  after_all in root\n"
          <> "    no cleanup\n"
          <> "\n"
          <> "Summary: 1 run, 0 failed, 1 passed, 1 teardown failed in 0ms\n",
        )
        |> or_fail_with("format should show the hook failures")
      }),
    ]),

    group("format", [
      it("writes every failure payload", fn() {
        bdd.format(
          report_of([
            result_of(
              ["p"],
              "payloads",
              types.Failed,
              every_payload(),
              types.Unit,
            ),
          ]),
        )
        |> should
        |> be_equal(
          "p\n"
          <> "  ✗ payloads\n"
          <> "    check\n"
          <> "      Expected: False\n"
          <> "      Actual:   True\n"
          <> "    check\n"
          <> "      Expected: True\n"
          <> "      Actual:   False\n"
          <> "    check\n"
          <> "      Expected: Some(_)\n"
          <> "      Actual:   None\n"
          <> "    check\n"
          <> "      Expected: None\n"
          <> "      Actual:   Some(1)\n"
          <> "    check\n"
          <> "      Expected: Ok(_)\n"
          <> "      Actual:   Error(1)\n"
          <> "    check\n"
          <> "      Expected: Error(_)\n"
          <> "      Actual:   Ok(1)\n"
          <> "    check\n"
          <> "      Operation: contain\n"
          <> "      Expected: 2\n"
          <> "      Actual:   [1]\n"
          <> "    check\n"
          <> "      Operator: greater\n"
          <> "      Expected: 2\n"
          <> "      Actual:   1\n"
          <> "    check\n"
          <> "      Operation: start_with\n"
          <> "      Pattern:   x\n"
          <> "      Actual:    abc\n"
          <> "    check\n"
          <> "      Snapshot missing: a.snap\n"
          <> "    check\n"
          <> "      Snapshot: b.snap\n"
          <> "      Expected: old\n"
          <> "      Actual:   new\n"
          <> "    check\n"
          <> "      Description: is even\n"
          <> "      Actual:      7\n"
          <> "    Run it alone: gleam test -- --only \"p/payloads\"\n"
          <> "\n"
          <> "Summary: 1 run, 1 failed, 0 passed in 0ms\n",
        )
        |> or_fail_with("each payload should have its own lines")
      }),

      it("writes every failure payload with colour", fn() {
        bdd.render(
          config(True, reporter_types.BddFailuresOnly),
          report_of([
            result_of(
              ["p"],
              "payloads",
              types.Failed,
              every_payload(),
              types.Unit,
            ),
          ]),
        )
        |> should
        |> be_equal(
          "\u{001B}[1m\u{001B}[36mp\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[31m✗\u{001B}[0m \u{001B}[31mpayloads\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Expected: \u{001B}[0m\u{001B}[32mFalse\u{001B}[0m\n"
          <> "  \u{001B}[2m    Actual:   \u{001B}[0m\u{001B}[31mTrue\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Expected: \u{001B}[0m\u{001B}[32mTrue\u{001B}[0m\n"
          <> "  \u{001B}[2m    Actual:   \u{001B}[0m\u{001B}[31mFalse\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Expected: \u{001B}[0m\u{001B}[32mSome(_)\u{001B}[0m\n"
          <> "  \u{001B}[2m    Actual:   \u{001B}[0m\u{001B}[31mNone\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Expected: \u{001B}[0m\u{001B}[32mNone\u{001B}[0m\n"
          <> "  \u{001B}[2m    Actual:   \u{001B}[0m\u{001B}[31mSome(1)\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Expected: \u{001B}[0m\u{001B}[32mOk(_)\u{001B}[0m\n"
          <> "  \u{001B}[2m    Actual:   \u{001B}[0m\u{001B}[31mError(1)\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Expected: \u{001B}[0m\u{001B}[32mError(_)\u{001B}[0m\n"
          <> "  \u{001B}[2m    Actual:   \u{001B}[0m\u{001B}[31mOk(1)\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Operation: \u{001B}[0m\u{001B}[36mcontain\u{001B}[0m\n"
          <> "  \u{001B}[2m    Expected: \u{001B}[0m\u{001B}[32m2\u{001B}[0m\n"
          <> "  \u{001B}[2m    Actual:   \u{001B}[0m\u{001B}[31m[1]\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Operator: \u{001B}[0m\u{001B}[36mgreater\u{001B}[0m\n"
          <> "  \u{001B}[2m    Expected: \u{001B}[0m\u{001B}[32m2\u{001B}[0m\n"
          <> "  \u{001B}[2m    Actual:   \u{001B}[0m\u{001B}[31m1\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Operation: \u{001B}[0m\u{001B}[36mstart_with\u{001B}[0m\n"
          <> "  \u{001B}[2m    Pattern:   \u{001B}[0m\u{001B}[32mx\u{001B}[0m\n"
          <> "  \u{001B}[2m    Actual:    \u{001B}[0m\u{001B}[31mabc\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Snapshot missing: \u{001B}[0m\u{001B}[33ma.snap\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Snapshot: \u{001B}[0m\u{001B}[36mb.snap\u{001B}[0m\n"
          <> "  \u{001B}[2m    Expected: \u{001B}[0m\u{001B}[32mold\u{001B}[0m\n"
          <> "  \u{001B}[2m    Actual:   \u{001B}[0m\u{001B}[31mnew\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Description: \u{001B}[0m\u{001B}[36mis even\u{001B}[0m\n"
          <> "  \u{001B}[2m    Actual:      \u{001B}[0m\u{001B}[31m7\u{001B}[0m\n"
          <> "    \u{001B}[2mRun it alone: \u{001B}[0mgleam test -- --only \"p/payloads\"\n"
          <> "\n"
          <> "\u{001B}[1m\u{001B}[36mSummary: \u{001B}[0m\u{001B}[0m\u{001B}[36m1\u{001B}[0m run, \u{001B}[31m1\u{001B}[0m failed, \u{001B}[32m0\u{001B}[0m passed in \u{001B}[36m0ms\u{001B}[0m\n",
        )
        |> or_fail_with("each payload should have its own colours")
      }),

      it("writes a test with no group at the top level", fn() {
        bdd.format(
          report_of([result_of([], "alone", types.Passed, [], types.Unit)]),
        )
        |> should
        |> be_equal("✓ alone\n\nSummary: 1 run, 0 failed, 1 passed in 0ms\n")
        |> or_fail_with("a test with no group should have no indent")
      }),

      it("sorts a group before the tests of a longer path", fn() {
        bdd.format(
          report_of([
            result_of(["a", "b"], "c", types.Passed, [], types.Unit),
            result_of(["a"], "b", types.Passed, [], types.Unit),
            result_of(["a"], "b", types.Skipped, [], types.Unit),
          ]),
        )
        |> should
        |> be_equal(
          "a\n"
          <> "  ✓ b\n"
          <> "  - b\n"
          <> "  b\n"
          <> "    ✓ c\n"
          <> "\n"
          <> "Summary: 3 run, 0 failed, 2 passed, 1 skipped in 0ms\n",
        )
        |> or_fail_with("the shorter path should come first")
      }),

      it("writes Gherkin results with one summary", fn() {
        bdd.format(report_of(gherkin_results()))
        |> should
        |> be_equal(
          "Feature: Cart\n"
          <> "  Scenario: adds ✓\n"
          <> "  Scenario: removes ✗\n"
          <> "      ✗ check\n"
          <> "        Message: gone\n"
          <> "        Expected: 0\n"
          <> "        Actual:   1\n"
          <> "      Run it alone: gleam test -- --only \"Cart/removes\"\n"
          <> "\n"
          <> "Summary: 2 run, 1 failed, 1 passed in 0ms\n",
        )
        |> or_fail_with("the Gherkin summary should be replaced by one summary")
      }),

      it("writes unit and Gherkin results together", fn() {
        bdd.format(
          report_of([
            result_of(["Math"], "adds", types.Passed, [], types.Unit),
            ..gherkin_results()
          ]),
        )
        |> should
        |> be_equal(
          "Math\n"
          <> "  ✓ adds\n"
          <> "Feature: Cart\n"
          <> "  Scenario: adds ✓\n"
          <> "  Scenario: removes ✗\n"
          <> "      ✗ check\n"
          <> "        Message: gone\n"
          <> "        Expected: 0\n"
          <> "        Actual:   1\n"
          <> "      Run it alone: gleam test -- --only \"Cart/removes\"\n"
          <> "\n"
          <> "Summary: 3 run, 1 failed, 2 passed in 0ms\n",
        )
        |> or_fail_with("unit results should come before Gherkin results")
      }),

      it("shows the duration of a slow test", fn() {
        bdd.format(
          report_of([
            types.TestResult(
              ..result_of(["s"], "slow", types.Passed, [], types.Unit),
              duration_ms: 1500,
            ),
          ]),
        )
        |> should
        |> be_equal(
          "s\n  ✓ slow (1.5s)\n\nSummary: 1 run, 0 failed, 1 passed in 1.5s\n",
        )
        |> or_fail_with("a slow test should show its duration")
      }),
    ]),

    it("format_summary_only writes the skipped count without colour", fn() {
      bdd.format_summary_only(
        report_of([
          types.TestResult(
            name: "later",
            groups: ["suite"],
            status: types.Skipped,
            duration_ms: 0,
            tags: [],
            failures: [],
            kind: types.Unit,
          ),
        ]),
      )
      |> should
      |> be_equal("Summary: 1 run, 0 failed, 0 passed, 1 skipped in 0ms\n")
      |> or_fail_with("an uncoloured summary should have no ANSI codes")
    }),

    it("format_summary_only returns a non-empty summary", fn() {
      let out = bdd.format_summary_only(report_of(sample_results()))
      case out == "" {
        True ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "bdd.format_summary_only",
              message: "expected non-empty summary",
              payload: None,
            )),
          )
        False -> Ok(types.AssertionOk)
      }
    }),

    it("format_incremental and friends do not crash", fn() {
      case list.first(sample_results()) {
        Ok(_r) -> {
          // Any crash here should fail the test run.
          let previous = []
          let assert Ok(r) = list.first(sample_results())
          let _ = bdd.format_incremental(r, previous)
          let _ = bdd.format_incremental_with_test_indent(r, previous, 2)
          let _ = bdd.format_incremental_parts_with_test_indent(r, previous, 2)
          Ok(types.AssertionOk)
        }
        Error(_) ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "bdd",
              message: "expected sample_results to have at least one element",
              payload: None,
            )),
          )
      }
    }),

    it("report does not crash", fn() {
      let write = fn(_s: String) { Nil }
      bdd.report(report_of(sample_results()), write)
      Ok(types.AssertionOk)
    }),

    it("bdd.color renders ANSI escapes", fn() {
      let reporter = bdd.new() |> bdd.color()
      let report = case reporter {
        reporter_types.Bdd(config) ->
          bdd.render(config, report_of(sample_results()))
        _ -> ""
      }

      case string.contains(report, "\u{1b}[") {
        True -> Ok(types.AssertionOk)
        False ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "bdd.color",
              message: "expected colored report to include ANSI escape sequences",
              payload: None,
            )),
          )
      }
    }),
    group("diffs and steps", [
      it("shows a line diff for a snapshot of more than one line", fn() {
        // Arrange
        let report =
          report_of([
            result_of(
              ["s"],
              "renders",
              types.Failed,
              [
                failure(
                  "the receipt should match",
                  types.SnapshotFailure(
                    actual: "a\nB\nc",
                    expected: "a\nb\nc",
                    snapshot_path: "r.snap",
                    is_missing: False,
                  ),
                ),
              ],
              types.Unit,
            ),
          ])

        // Act
        let text = bdd.format(report)

        // Assert
        text
        |> should
        |> be_equal(
          "s\n"
          <> "  ✗ renders\n"
          <> "    check\n"
          <> "      Message: the receipt should match\n"
          <> "      Snapshot: r.snap\n"
          <> "      Diff (- expected, + actual):\n"
          <> "          a\n"
          <> "        - b\n"
          <> "        + B\n"
          <> "          c\n"
          <> "    Run it alone: gleam test -- --only \"s/renders\"\n"
          <> "\n"
          <> "Summary: 1 run, 1 failed, 0 passed in 0ms\n",
        )
        |> or_fail_with("expected the diff under the snapshot path")
      }),
      it(
        "shows a line diff for an equality failure of more than one line",
        fn() {
          // Arrange
          let report =
            report_of([
              result_of(
                ["s"],
                "compares",
                types.Failed,
                [
                  failure(
                    "",
                    types.EqualityFailure(actual: "x\nz", expected: "x\ny"),
                  ),
                ],
                types.Unit,
              ),
            ])

          // Act
          let text = bdd.format(report)

          // Assert
          text
          |> should
          |> be_equal(
            "s\n"
            <> "  ✗ compares\n"
            <> "    check\n"
            <> "      Diff (- expected, + actual):\n"
            <> "          x\n"
            <> "        - y\n"
            <> "        + z\n"
            <> "    Run it alone: gleam test -- --only \"s/compares\"\n"
            <> "\n"
            <> "Summary: 1 run, 1 failed, 0 passed in 0ms\n",
          )
          |> or_fail_with("expected the diff in place of Expected and Actual")
        },
      ),
      it("names the step, its file and its line before the message", fn() {
        // Arrange
        let report =
          report_of([
            result_of(
              ["s"],
              "checks",
              types.Failed,
              [
                failure(
                  "the total should match",
                  types.StepFailure(
                    keyword: "Then",
                    text: "the total is 15.00",
                    file: Some("test/cart.feature"),
                    line: Some(7),
                    cause: Some(types.EqualityFailure(
                      actual: "14.0",
                      expected: "15.0",
                    )),
                  ),
                ),
              ],
              types.Unit,
            ),
          ])

        // Act
        let text = bdd.format(report)

        // Assert
        text
        |> should
        |> be_equal(
          "s\n"
          <> "  ✗ checks\n"
          <> "    check\n"
          <> "      Step: Then the total is 15.00 (test/cart.feature:7)\n"
          <> "      Message: the total should match\n"
          <> "      Expected: 15.0\n"
          <> "      Actual:   14.0\n"
          <> "    Run it alone: gleam test -- --only \"s/checks\"\n"
          <> "\n"
          <> "Summary: 1 run, 1 failed, 0 passed in 0ms\n",
        )
        |> or_fail_with("expected the step line first")
      }),
      it("names the step with the place that is known", fn() {
        // Arrange
        let step_failure = fn(file, line) {
          failure(
            "Undefined step: When I pay",
            types.StepFailure(
              keyword: "When",
              text: "I pay",
              file: file,
              line: line,
              cause: None,
            ),
          )
        }
        let report =
          report_of([
            result_of(
              ["s"],
              "pays",
              types.Failed,
              [
                step_failure(None, Some(4)),
                step_failure(Some("pay.feature"), None),
                step_failure(None, None),
              ],
              types.Unit,
            ),
          ])

        // Act
        let text = bdd.format(report)

        // Assert
        text
        |> should
        |> be_equal(
          "s\n"
          <> "  ✗ pays\n"
          <> "    check\n"
          <> "      Step: When I pay (line 4)\n"
          <> "      Message: Undefined step: When I pay\n"
          <> "    check\n"
          <> "      Step: When I pay (pay.feature)\n"
          <> "      Message: Undefined step: When I pay\n"
          <> "    check\n"
          <> "      Step: When I pay\n"
          <> "      Message: Undefined step: When I pay\n"
          <> "    Run it alone: gleam test -- --only \"s/pays\"\n"
          <> "\n"
          <> "Summary: 1 run, 1 failed, 0 passed in 0ms\n",
        )
        |> or_fail_with("expected the line, the file, then no place")
      }),
      it("colours the step line and the diff", fn() {
        // Arrange
        let report =
          report_of([
            result_of(
              ["s"],
              "checks",
              types.Failed,
              [
                failure(
                  "",
                  types.StepFailure(
                    keyword: "Then",
                    text: "the receipt matches",
                    file: None,
                    line: Some(9),
                    cause: Some(types.SnapshotFailure(
                      actual: "a\nc",
                      expected: "a\nb",
                      snapshot_path: "r.snap",
                      is_missing: False,
                    )),
                  ),
                ),
              ],
              types.Unit,
            ),
          ])

        // Act
        let text =
          bdd.render(config(True, reporter_types.BddFailuresOnly), report)

        // Assert
        text
        |> should
        |> be_equal(
          "\u{001B}[1m\u{001B}[36ms\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[31m✗\u{001B}[0m \u{001B}[31mchecks\u{001B}[0m\n"
          <> "    \u{001B}[1m\u{001B}[35mcheck\u{001B}[0m\u{001B}[0m\n"
          <> "  \u{001B}[2m    Step: \u{001B}[0m\u{001B}[36mThen the receipt matches (line 9)\u{001B}[0m\n"
          <> "  \u{001B}[2m    Snapshot: \u{001B}[0m\u{001B}[36mr.snap\u{001B}[0m\n"
          <> "      \u{001B}[2mDiff (- expected, + actual):\u{001B}[0m\n"
          <> "          a\n"
          <> "        \u{001B}[32m- b\u{001B}[0m\n"
          <> "        \u{001B}[31m+ c\u{001B}[0m\n"
          <> "    \u{001B}[2mRun it alone: \u{001B}[0mgleam test -- --only \"s/checks\"\n"
          <> "\n"
          <> "\u{001B}[1m\u{001B}[36mSummary: \u{001B}[0m\u{001B}[0m\u{001B}[36m1\u{001B}[0m run, \u{001B}[31m1\u{001B}[0m failed, \u{001B}[32m0\u{001B}[0m passed in \u{001B}[36m0ms\u{001B}[0m\n",
        )
        |> or_fail_with("expected the step line in cyan and the diff in colour")
      }),
    ]),
  ])
}
