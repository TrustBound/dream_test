import dream_test/file.{error_to_string, read, write}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process.{unique_port}
import dream_test/types.{type AssertionResult}
import gleam/int
import gleam/result

fn temporary_path() -> String {
  "build/tmp/file_example_" <> int.to_string(unique_port()) <> ".txt"
}

pub fn written_content_reads_back() -> Result(AssertionResult, String) {
  let path = temporary_path()

  // Setup: create the file (no assertions during setup)
  use _ <- result.try(write(path, "hello") |> result.map_error(error_to_string))

  read(path)
  |> should
  |> be_equal(Ok("hello"))
  |> or_fail_with("expected to read back written content")
}
