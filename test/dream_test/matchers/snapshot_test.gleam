import dream_test/file
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/matchers/snapshot
import dream_test/unit.{describe, it}
import matchers/failure_operator.{have_failure_operator}

pub fn tests() {
  describe("dream_test/matchers/snapshot", [
    it("match_snapshot creates a snapshot when missing", fn() {
      let path = "./test/tmp/snapshots/match_snapshot_create.snap"
      let _ = snapshot.clear_snapshot(path)

      "hello"
      |> should
      |> snapshot.match_snapshot(path)
      |> or_fail_with("should create snapshot on first run")
    }),

    it("match_snapshot matches an existing snapshot", fn() {
      let path = "./test/tmp/snapshots/match_snapshot_existing.snap"
      let _ = snapshot.clear_snapshot(path)
      let _ = file.write(path, "hello")

      "hello"
      |> should
      |> snapshot.match_snapshot(path)
      |> or_fail_with("should match existing snapshot")
    }),

    it("match_snapshot fails when content differs", fn() {
      let path = "./test/tmp/snapshots/match_snapshot_mismatch.snap"
      let _ = snapshot.clear_snapshot(path)
      let _ = file.write(path, "expected")

      "actual"
      |> should
      |> snapshot.match_snapshot(path)
      |> have_failure_operator("match_snapshot")
      |> or_fail_with("expected mismatch to fail with operator match_snapshot")
    }),

    it("clear_snapshot is idempotent", fn() {
      let path = "./test/tmp/snapshots/clear_snapshot_idempotent.snap"
      let _ = snapshot.clear_snapshot(path)
      snapshot.clear_snapshot(path)
      |> should
      |> be_equal(Ok(Nil))
      |> or_fail_with("clear_snapshot should succeed even when missing")
    }),

    it(
      "clear_snapshots_in_directory deletes .snap files and keeps other files",
      fn() {
        let dir = "./test/tmp/snapshots/clear_dir"
        let _ = file.write(dir <> "/a.snap", "a")
        let _ = file.write(dir <> "/b.snap", "b")
        let _ = file.write(dir <> "/c.txt", "c")

        let _ = snapshot.clear_snapshots_in_directory(dir)

        file.read(dir <> "/c.txt")
        |> should
        |> be_equal(Ok("c"))
        |> or_fail_with("non-.snap file should remain")
      },
    ),
  ])
}
