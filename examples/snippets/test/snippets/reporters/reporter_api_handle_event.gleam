//// README: Driving a reporter manually with ReporterEvent

import dream_test/assertions/should.{be_ok, contain_string, or_fail_with, should}
import dream_test/file
import dream_test/reporters
import dream_test/reporters/types as reporter_types
import dream_test/unit.{describe, it}
import gleam/result

pub fn tests() {
  describe("Reporter API: handle_event", [
    it("can be driven manually with ReporterEvent values", fn() {
      let path = "test/tmp/reporter_api_handle_event.json"
      let _ = ignore_file_errors(file.delete(path))

      let r0 = reporters.json(write_to_file(path), False)
      let r1 = reporters.handle_event(r0, reporter_types.RunStarted(total: 1))
      let r2 =
        reporters.handle_event(
          r1,
          reporter_types.RunFinished(completed: 1, total: 1),
        )

      let _ = r2
      let output =
        file.read(path)
        |> result.map_error(file.error_to_string)

      output
      |> should()
      |> be_ok()
      |> contain_string("\"tests\"")
      |> or_fail_with("Expected reporter output to include a JSON report")
    }),
  ])
}

fn write_to_file(path: String) -> fn(String) -> Nil {
  fn(text) {
    let _ = ignore_file_errors(file.write(path, text))
    Nil
  }
}

fn ignore_file_errors(value: Result(a, e)) -> Nil {
  case value {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}
