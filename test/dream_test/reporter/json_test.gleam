import dream_test/reporters/json
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/option.{None}
import gleam/string

fn sample_results() -> List(types.TestResult) {
  [
    types.TestResult(
      name: "t1",
      full_name: ["suite", "t1"],
      status: types.Passed,
      duration_ms: 1,
      tags: ["tag"],
      failures: [],
      kind: types.Unit,
    ),
  ]
}

pub fn tests() {
  describe("dream_test/reporters/json", [
    it("format emits JSON containing the test name", fn() {
      let out = json.format(sample_results())
      case string.contains(out, "\"t1\"") {
        True -> Ok(types.AssertionOk)
        False ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "json.format",
              message: "expected JSON output to include the test name",
              payload: None,
            )),
          )
      }
    }),

    it("format_pretty emits JSON containing the test name", fn() {
      let out = json.format_pretty(sample_results())
      case string.contains(out, "\"t1\"") {
        True -> Ok(types.AssertionOk)
        False ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "json.format_pretty",
              message: "expected JSON output to include the test name",
              payload: None,
            )),
          )
      }
    }),

    it("report and report_pretty do not crash", fn() {
      let write = fn(_s: String) { Nil }
      json.report(sample_results(), write)
      json.report_pretty(sample_results(), write)
      Ok(types.AssertionOk)
    }),
  ])
}
