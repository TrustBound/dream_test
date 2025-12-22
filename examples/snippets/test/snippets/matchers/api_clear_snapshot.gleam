import dream_test/file
import dream_test/matchers.{be_equal, clear_snapshot, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/result

pub fn tests() {
  describe("matchers.clear_snapshot", [
    it("deletes a snapshot file (so next run recreates it)", fn() {
      let path = "./test/tmp/clear_snapshot_example.snap"

      // Setup: create a snapshot file (no assertions during setup)
      use _ <- result.try(
        file.write(path, "hello") |> result.map_error(file.error_to_string),
      )

      clear_snapshot(path)
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("expected clear_snapshot to succeed")
    }),
  ])
}
