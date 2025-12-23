import dream_test/file
import dream_test/matchers.{
  be_equal, clear_snapshot, clear_snapshots_in_directory, match_snapshot,
  match_snapshot_inspect, or_fail_with, should,
}
import dream_test/unit.{describe, it}
import gleam/option.{Some}
import gleam/result

pub fn tests() {
  describe("Matchers: snapshots", [
    it("match_snapshot compares a string against a snapshot file", fn() {
      let path = "./test/tmp/match_snapshot_example.snap"
      "hello"
      |> should
      |> match_snapshot(path)
      |> or_fail_with("expected snapshot match")
    }),
    it(
      "match_snapshot_inspect snapshots any value by using string.inspect",
      fn() {
        let path = "./test/tmp/match_snapshot_inspect_example.snap"
        Some(1)
        |> should
        |> match_snapshot_inspect(path)
        |> or_fail_with("expected inspect snapshot match")
      },
    ),
    it(
      "clear_snapshot deletes a snapshot file (so next run recreates it)",
      fn() {
        let path = "./test/tmp/clear_snapshot_example.snap"

        // Setup: create a snapshot file (no assertions during setup)
        use _ <- result.try(
          file.write(path, "hello") |> result.map_error(file.error_to_string),
        )

        clear_snapshot(path)
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("expected clear_snapshot to succeed")
      },
    ),
    it(
      "clear_snapshots_in_directory deletes all .snap files in a directory",
      fn() {
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
      },
    ),
  ])
}
