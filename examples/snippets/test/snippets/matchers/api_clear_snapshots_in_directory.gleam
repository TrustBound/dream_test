import dream_test/file
import dream_test/matchers.{
  be_equal, clear_snapshots_in_directory, or_fail_with, should,
}
import dream_test/unit.{describe, it}
import gleam/result

pub fn tests() {
  describe("matchers.clear_snapshots_in_directory", [
    it("deletes all .snap files in a directory", fn() {
      let directory = "./test/tmp/clear_snapshots_in_directory_example"
      let a = directory <> "/a.snap"
      let b = directory <> "/b.snap"

      // Setup: create two snapshot files (no assertions during setup)
      use _ <- result.try(
        file.write(a, "a") |> result.map_error(file.error_to_string),
      )
      use _ <- result.try(
        file.write(b, "b") |> result.map_error(file.error_to_string),
      )

      clear_snapshots_in_directory(directory)
      |> should
      |> be_equal(Ok(2))
      |> or_fail_with("expected two deleted snapshots")
    }),
  ])
}
