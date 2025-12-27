import dream_test/file
import dream_test/matchers.{match_regex, or_fail_with, should}
import dream_test/reporters/progress
import dream_test/reporters/types as reporter_types
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}
import gleam/result

fn write_progress_line_to_file(text: String) {
  file.write("test/tmp/progress_handle_event.txt", text)
  |> result.unwrap(Nil)
}

pub fn tests() {
  describe("Progress reporter: handle_event", [
    it("writes an in-place line (including carriage return)", fn() {
      let reporter = progress.new()
      let maybe_progress_text =
        progress.handle_event(reporter, reporter_types.RunStarted(total: 10))
      case maybe_progress_text {
        Some(text) -> write_progress_line_to_file(text)
        None -> Nil
      }

      use text <- result.try(
        file.read("test/tmp/progress_handle_event.txt")
        |> result.map_error(file.error_to_string),
      )

      text
      |> should
      |> match_regex("\\r0/10 \\[[^\\]]+\\] 0%")
      |> or_fail_with(
        "expected progress output to include carriage-returned 0/10 0% line",
      )
    }),
  ])
}
