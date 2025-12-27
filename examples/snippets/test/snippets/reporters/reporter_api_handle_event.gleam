import dream_test/file
import dream_test/matchers.{match_regex, or_fail_with, should}
import dream_test/reporters/progress
import dream_test/reporters/types as reporter_types
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/option.{type Option, None, Some}
import gleam/result

fn write_to_file(text: String) {
  file.write("test/tmp/reporter_api_handle_event.txt", text)
  |> result.unwrap(Nil)
}

fn or_empty(text: Option(String)) -> String {
  case text {
    Some(s) -> s
    None -> ""
  }
}

pub fn tests() {
  describe("Reporter API: handle_event", [
    it("can be driven manually with ReporterEvent values", fn() {
      let reporter = progress.new()

      let result =
        types.TestResult(
          name: "passes",
          full_name: ["suite", "passes"],
          status: types.Passed,
          duration_ms: 0,
          tags: [],
          failures: [],
          kind: types.Unit,
        )

      let text =
        or_empty(progress.handle_event(
          reporter,
          reporter_types.RunStarted(total: 1),
        ))
        <> or_empty(progress.handle_event(
          reporter,
          reporter_types.TestFinished(completed: 1, total: 1, result: result),
        ))
        <> or_empty(progress.handle_event(
          reporter,
          reporter_types.RunFinished(completed: 1, total: 1, results: [result]),
        ))

      write_to_file(text)

      // Setup: read output (no assertions during setup)
      use output <- result.try(
        file.read("test/tmp/reporter_api_handle_event.txt")
        |> result.map_error(file.error_to_string),
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
