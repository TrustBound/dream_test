import dream_test/file.{
  NotFound, delete, delete_files_matching, error_to_string, read, write,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process.{unique_port}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/result

fn tmp_path() {
  "./test/tmp/file_helpers_" <> int.to_string(unique_port()) <> ".txt"
}

pub fn tests() {
  describe("File helpers", [
    it("write + read roundtrip", fn() {
      let path = tmp_path()

      // Setup: create the file (no assertions during setup)
      use _ <- result.try(
        write(path, "hello") |> result.map_error(error_to_string),
      )

      read(path)
      |> should
      |> be_equal(Ok("hello"))
      |> or_fail_with("expected to read back written content")
    }),

    it("delete removes a file", fn() {
      let path = tmp_path()

      // Setup: create the file, then delete it (no assertions during setup)
      use _ <- result.try(
        write(path, "hello") |> result.map_error(error_to_string),
      )
      use _ <- result.try(delete(path) |> result.map_error(error_to_string))

      read(path)
      |> should
      |> be_equal(Error(NotFound(path)))
      |> or_fail_with("expected deleted file to be NotFound")
    }),

    it("error_to_string formats NotFound", fn() {
      error_to_string(NotFound("/x"))
      |> should
      |> be_equal("File not found: /x")
      |> or_fail_with("expected NotFound formatting")
    }),

    it("delete_files_matching deletes files with a given extension", fn() {
      let directory = "./test/tmp/file_helpers_" <> int.to_string(unique_port())
      let a = directory <> "/a.snap"
      let b = directory <> "/b.snap"
      let keep = directory <> "/keep.txt"

      // Setup: create 2 matching files and 1 non-matching file
      use _ <- result.try(write(a, "a") |> result.map_error(error_to_string))
      use _ <- result.try(write(b, "b") |> result.map_error(error_to_string))
      use _ <- result.try(
        write(keep, "keep") |> result.map_error(error_to_string),
      )

      delete_files_matching(directory, ".snap")
      |> should
      |> be_equal(Ok(2))
      |> or_fail_with("expected two deleted snapshots")
    }),
  ])
}
