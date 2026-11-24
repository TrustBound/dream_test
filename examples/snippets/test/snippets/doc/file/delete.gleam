import dream_test/file.{NotFound, delete, error_to_string, read, write}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process.{unique_port}
import dream_test/types.{type AssertionResult}
import gleam/int
import gleam/result

fn temporary_path() -> String {
  "build/tmp/file_example_" <> int.to_string(unique_port()) <> ".txt"
}

pub fn deleted_file_is_not_found() -> Result(AssertionResult, String) {
  let path = temporary_path()

  // Setup: create the file, then delete it (no assertions during setup)
  use _ <- result.try(write(path, "hello") |> result.map_error(error_to_string))
  use _ <- result.try(delete(path) |> result.map_error(error_to_string))

  read(path)
  |> should
  |> be_equal(Error(NotFound(path)))
  |> or_fail_with("expected deleted file to be NotFound")
}
