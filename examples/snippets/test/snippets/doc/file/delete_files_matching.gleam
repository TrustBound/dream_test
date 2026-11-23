import dream_test/file.{delete_files_matching, error_to_string, write}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process.{unique_port}
import dream_test/types.{type AssertionResult}
import gleam/int
import gleam/result

pub fn deletes_two_snapshots() -> Result(AssertionResult, String) {
  let directory = "build/tmp/file_example_" <> int.to_string(unique_port())
  let first_snapshot = directory <> "/a.snap"
  let second_snapshot = directory <> "/b.snap"
  let kept_file = directory <> "/keep.txt"

  // Setup: create 2 matching files and 1 non-matching file
  use _ <- result.try(
    write(first_snapshot, "a") |> result.map_error(error_to_string),
  )
  use _ <- result.try(
    write(second_snapshot, "b") |> result.map_error(error_to_string),
  )
  use _ <- result.try(
    write(kept_file, "keep") |> result.map_error(error_to_string),
  )

  delete_files_matching(directory, ".snap")
  |> should
  |> be_equal(Ok(2))
  |> or_fail_with("expected two deleted snapshots")
}
