import dream_test/file
import dream_test/matchers.{match_regex, or_fail_with, should}
import dream_test/reporters/progress
import dream_test/unit.{describe, it}
import gleam/result

fn write_progress_line_to_file(text: String) {
  file.write("test/tmp/progress_line.txt", text)
  |> result.unwrap(Nil)
}

pub fn tests() {
  describe("Progress reporter: line", [
    it("writes an in-place line (including carriage return)", fn() {
      let reporter = progress.new()
      progress.line(reporter, progress.RunStartedProgress(total: 10))
      |> write_progress_line_to_file

      use text <- result.try(
        file.read("test/tmp/progress_line.txt")
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
