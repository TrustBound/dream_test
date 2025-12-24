import dream_test/file
import dream_test/matchers.{match_snapshot, or_fail_with, should}
import dream_test/reporters
import dream_test/reporters/types as reporter_types
import dream_test/unit.{describe, it}
import gleam/result
import gleam/string

fn write_to_file(text: String) {
  file.write("test/tmp/reporter_api_handle_event.json", text)
  |> result.unwrap(Nil)
}

fn split_timestamp_missing(_nil: Nil) -> String {
  "expected timestamp_ms field"
}

fn split_timestamp_value_missing(_nil: Nil) -> String {
  "expected timestamp_ms value to end with ','"
}

fn split_on_timestamp_ms(json: String) -> Result(#(String, String), String) {
  string.split_once(json, "\"timestamp_ms\":")
  |> result.map_error(split_timestamp_missing)
}

fn split_on_comma(text: String) -> Result(#(String, String), String) {
  string.split_once(text, ",")
  |> result.map_error(split_timestamp_value_missing)
}

fn normalize_timestamp_ms(json: String) -> Result(String, String) {
  use #(before, after) <- result.try(split_on_timestamp_ms(json))

  use #(_timestamp_digits, rest) <- result.try(split_on_comma(after))

  Ok(before <> "\"timestamp_ms\":0," <> rest)
}

pub fn tests() {
  describe("Reporter API: handle_event", [
    it("can be driven manually with ReporterEvent values", fn() {
      reporters.json(write_to_file, False)
      |> reporters.handle_event(reporter_types.RunStarted(total: 1))
      |> reporters.handle_event(reporter_types.RunFinished(
        completed: 1,
        total: 1,
      ))

      // Setup: read output (no assertions during setup)
      use output <- result.try(
        file.read("test/tmp/reporter_api_handle_event.json")
        |> result.map_error(file.error_to_string),
      )

      // Normalize unstable fields (timestamps) before snapshotting
      use normalized <- result.try(normalize_timestamp_ms(output))

      normalized
      |> should
      |> match_snapshot("./test/snapshots/reporter_api_handle_event_json.snap")
      |> or_fail_with("expected reporter output snapshot match")
    }),
  ])
}
