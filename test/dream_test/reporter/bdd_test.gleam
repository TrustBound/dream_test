import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/types as reporter_types
import dream_test/types
import dream_test/unit.{describe, group, it}
import gleam/list
import gleam/option.{None, Some}
import gleam/string

fn sample_results() -> List(types.TestResult) {
  [
    types.TestResult(
      name: "t1",
      full_name: ["suite", "t1"],
      status: types.Passed,
      duration_ms: 1,
      tags: [],
      failures: [],
      kind: types.Unit,
    ),
    types.TestResult(
      name: "t2",
      full_name: ["suite", "t2"],
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

pub fn tests() {
  describe("dream_test/reporters/bdd", [
    group("format", [
      it("includes test names", fn() {
        let out = bdd.format(sample_results())
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
            full_name: ["Math", "adds numbers"],
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
            full_name: ["Math", "adds numbers incorrectly"],
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
          <> "\n"
          <> "Summary: 2 run, 1 failed, 1 passed in 0ms\n"

        bdd.format(results)
        |> should
        |> be_equal(expected)
        |> or_fail_with("bdd.format should render a basic BDD-style report")
      }),
    ]),

    it("format_summary_only returns a non-empty summary", fn() {
      let out = bdd.format_summary_only(sample_results())
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
      bdd.report(sample_results(), write)
      Ok(types.AssertionOk)
    }),

    it("bdd.color renders ANSI escapes", fn() {
      let reporter = bdd.new() |> bdd.color()
      let report = case reporter {
        reporter_types.Bdd(config) -> bdd.render(config, sample_results())
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
  ])
}
