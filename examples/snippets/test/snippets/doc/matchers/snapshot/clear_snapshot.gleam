import dream_test/file
import dream_test/matchers.{be_equal, clear_snapshot, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import gleam/result

pub fn clear_snapshot_deletes_file() -> Result(AssertionResult, String) {
  let path = "./build/doc_examples/clear_snapshot_example.snap"

  // Setup: create a snapshot file (no assertions during setup)
  use _ <- result.try(
    file.write(path, "hello") |> result.map_error(file.error_to_string),
  )

  clear_snapshot(path)
  |> should
  |> be_equal(Ok(Nil))
  |> or_fail_with("expected clear_snapshot to succeed")
}
