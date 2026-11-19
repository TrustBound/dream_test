import dream_test/matchers.{match_regex, or_fail_with, should}
import dream_test/reporters/progress
import dream_test/types
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Reporter API: progress.line", [
    it("can be driven manually with ProgressEvent values", fn() {
      let reporter = progress.new()

      let result =
        types.TestResult(
          name: "passes",
          groups: ["suite"],
          status: types.Passed,
          duration_ms: 0,
          tags: [],
          failures: [],
          kind: types.Unit,
        )

      let output =
        progress.line(reporter, progress.RunStartedProgress(total: 1))
        <> progress.line(
          reporter,
          progress.TestFinishedProgress(completed: 1, total: 1, result: result),
        )
        <> progress.line(
          reporter,
          progress.RunFinishedProgress(
            completed: 1,
            total: 1,
            teardown_failures: 0,
            setup_stopped: 0,
          ),
        )

      output
      |> should
      |> match_regex("\\r0/1 \\[[^\\]]+\\] 0%")
      |> match_regex("\\r1/1 \\[[^\\]]+\\] 100%")
      |> match_regex("suite")
      |> match_regex("passes")
      |> match_regex("\\r1/1 \\[[^\\]]+\\] 100% done")
      |> or_fail_with(
        "expected progress reporter output to include expected counters/labels",
      )
    }),
  ])
}
