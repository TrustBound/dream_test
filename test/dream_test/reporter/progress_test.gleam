import dream_test/reporters/progress
import dream_test/reporters/types as reporter_types
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/option.{None}
import gleam/string

pub fn tests() {
  describe("dream_test/reporters/progress", [
    it("render produces a line containing counts", fn() {
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

      let line =
        progress.render(
          30,
          reporter_types.TestFinished(completed: 1, total: 2, result: result),
        )

      case string.contains(line, "1/2") {
        True -> Ok(types.AssertionOk)
        False ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "progress.render",
              message: "expected progress line to include 1/2",
              payload: None,
            )),
          )
      }
    }),

    it(
      "handle_event does not crash for RunStarted/TestFinished/RunFinished",
      fn() {
        let reporter = progress.new()
        let _ =
          progress.handle_event(reporter, reporter_types.RunStarted(total: 2))
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
        let _ =
          progress.handle_event(
            reporter,
            reporter_types.TestFinished(completed: 1, total: 2, result: result),
          )
        let _ =
          progress.handle_event(
            reporter,
            reporter_types.RunFinished(completed: 2, total: 2, results: []),
          )
        Ok(types.AssertionOk)
      },
    ),
  ])
}
