import dream_test/file
import dream_test/matchers.{match_snapshot, or_fail_with, should}
import dream_test/reporters/progress
import dream_test/reporters/types as reporter_types
import dream_test/unit.{describe, it}
import gleam/result

fn write_progress_line_to_file(text: String) {
  file.write("test/tmp/progress_handle_event.txt", text)
  |> result.unwrap(Nil)
}

pub fn tests() {
  describe("Progress reporter: handle_event", [
    it("writes an in-place line (including carriage return)", fn() {
      progress.handle_event(
        reporter_types.RunStarted(total: 10),
        write_progress_line_to_file,
      )

      use text <- result.try(
        file.read("test/tmp/progress_handle_event.txt")
        |> result.map_error(file.error_to_string),
      )

      text
      |> should
      |> match_snapshot(
        "./test/snapshots/progress_handle_event_run_started.snap",
      )
      |> or_fail_with("expected handle_event output snapshot match")
    }),
  ])
}
