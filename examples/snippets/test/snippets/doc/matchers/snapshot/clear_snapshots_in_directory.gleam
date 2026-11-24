import dream_test/file
import dream_test/matchers.{
  be_equal, clear_snapshots_in_directory, or_fail_with, should,
}
import dream_test/types.{type AssertionResult}
import gleam/result

pub fn clear_two_snapshots() -> Result(AssertionResult, String) {
  let directory = "./build/doc_examples/clear_snapshots_in_directory_example"
  let first_snapshot = directory <> "/a.snap"
  let second_snapshot = directory <> "/b.snap"

  // Setup: create two snapshot files (no assertions during setup)
  use _ <- result.try(
    file.write(first_snapshot, "a") |> result.map_error(file.error_to_string),
  )
  use _ <- result.try(
    file.write(second_snapshot, "b") |> result.map_error(file.error_to_string),
  )

  clear_snapshots_in_directory(directory)
  |> should
  |> be_equal(Ok(2))
  |> or_fail_with("expected two deleted snapshots")
}
