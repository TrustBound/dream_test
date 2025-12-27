import dream_test/reporters/gherkin
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/option.{None}

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
  ])
}
