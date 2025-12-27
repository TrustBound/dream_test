import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/types as reporter_types
import dream_test/unit.{describe, it}
import gleam/list
import gleam/option.{Some}
import gleam/result

fn run_started_total(event: reporter_types.ReporterEvent) -> Result(Int, String) {
  case event {
    reporter_types.RunStarted(total: total) -> Ok(total)
    _ -> Error("expected RunStarted")
  }
}

fn hook_error_message(
  event: reporter_types.ReporterEvent,
) -> Result(String, String) {
  case event {
    reporter_types.HookFinished(
      outcome: reporter_types.HookError(message: message),
      ..,
    ) -> Ok(message)
    _ -> Error("expected HookFinished with HookError")
  }
}

fn run_finished_results_count(
  event: reporter_types.ReporterEvent,
) -> Result(Int, String) {
  case event {
    reporter_types.RunFinished(results: results, ..) -> Ok(list.length(results))
    _ -> Error("expected RunFinished")
  }
}

pub fn tests() {
  describe("ReporterEvent", [
    it("RunStarted includes the total number of tests", fn() {
      use total <- result.try(
        run_started_total(reporter_types.RunStarted(total: 3)),
      )

      total
      |> should
      |> be_equal(3)
      |> or_fail_with("expected total to be 3")
    }),
    it("HookFinished can include a HookError message", fn() {
      let event =
        reporter_types.HookFinished(
          kind: reporter_types.AfterEach,
          scope: ["file"],
          test_name: Some("delete"),
          outcome: reporter_types.HookError(message: "boom"),
        )

      use message <- result.try(hook_error_message(event))

      message
      |> should
      |> be_equal("boom")
      |> or_fail_with("expected hook error message 'boom'")
    }),
    it("RunFinished includes the traversal-ordered results list", fn() {
      use count <- result.try(
        run_finished_results_count(
          reporter_types.RunFinished(completed: 1, total: 1, results: []),
        ),
      )

      count
      |> should
      |> be_equal(0)
      |> or_fail_with("expected results count to be 0")
    }),
  ])
}
