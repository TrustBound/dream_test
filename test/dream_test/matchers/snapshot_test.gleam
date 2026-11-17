import dream_test/file
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/matchers/snapshot
import dream_test/types.{AssertionFailure, MatchFailed, MatchOk, SnapshotFailure}
import dream_test/unit.{describe, it}
import gleam/dynamic.{type Dynamic}
import gleam/option.{Some}
import matchers/failure_operator.{have_failure_operator}
import matchers/prior_failure.{prior_failure}

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

    it("match_snapshot ignores a CRLF line end at the end of the file", fn() {
      let path = "./test/tmp/snapshots/match_snapshot_crlf.snap"
      let _ = file.write(path, "hello\r\n")

      "hello"
      |> should
      |> snapshot.match_snapshot(path)
      |> or_fail_with("a trailing CRLF should not cause a mismatch")
    }),

    it("match_snapshot ignores a LF line end at the end of the file", fn() {
      let path = "./test/tmp/snapshots/match_snapshot_lf.snap"
      let _ = file.write(path, "hello\n")

      "hello"
      |> should
      |> snapshot.match_snapshot(path)
      |> or_fail_with("a trailing LF should not cause a mismatch")
    }),

    it("match_snapshot ignores a CR at the end of the file", fn() {
      let path = "./test/tmp/snapshots/match_snapshot_cr.snap"
      let _ = file.write(path, "hello\r")

      "hello"
      |> should
      |> snapshot.match_snapshot(path)
      |> or_fail_with("a trailing CR should not cause a mismatch")
    }),

    it("match_snapshot reports both texts on a mismatch", fn() {
      let path = "./test/tmp/snapshots/match_snapshot_mismatch_payload.snap"
      let _ = file.write(path, "expected")

      "actual"
      |> should
      |> snapshot.match_snapshot(path)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "match_snapshot",
          message: "",
          payload: Some(SnapshotFailure(
            actual: "actual",
            expected: "expected",
            snapshot_path: path,
            is_missing: False,
          )),
        )),
      )
      |> or_fail_with("match_snapshot should report the mismatch")
    }),

    it("match_snapshot reports a snapshot path it cannot read", fn() {
      let path = "./test/tmp/snapshots/match_snapshot_directory.snap"
      let _ = file.write(path <> "/inner.txt", "")

      "hello"
      |> should
      |> snapshot.match_snapshot(path)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "match_snapshot",
          message: "Failed to read snapshot: Is a directory: " <> path,
          payload: Some(SnapshotFailure(
            actual: "",
            expected: "",
            snapshot_path: path,
            is_missing: True,
          )),
        )),
      )
      |> or_fail_with("match_snapshot should report the read error")
    }),

    it("match_snapshot reports a new snapshot it cannot write", fn() {
      let path = "./test/tmp/snapshots/match_snapshot_dangling.snap"
      let result =
        with_dangling_link(path, fn() {
          "hello"
          |> should
          |> snapshot.match_snapshot(path)
        })

      result
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "match_snapshot",
          message: "Failed to write snapshot: File not found: " <> path,
          payload: Some(SnapshotFailure(
            actual: "",
            expected: "",
            snapshot_path: path,
            is_missing: True,
          )),
        )),
      )
      |> or_fail_with("match_snapshot should report the write error")
    }),

    it("match_snapshot passes an earlier failure through", fn() {
      prior_failure()
      |> snapshot.match_snapshot("./test/tmp/snapshots/never_written.snap")
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("match_snapshot should keep the earlier failure")
    }),

    it("match_snapshot_inspect writes the inspected value when missing", fn() {
      let path = "./test/tmp/snapshots/match_snapshot_inspect_create.snap"
      let _ = snapshot.clear_snapshot(path)
      let _ = [1, 2] |> should |> snapshot.match_snapshot_inspect(path)

      file.read(path)
      |> should
      |> be_equal(Ok("[1, 2]"))
      |> or_fail_with("match_snapshot_inspect should write the inspected value")
    }),

    it("match_snapshot_inspect matches an existing snapshot", fn() {
      let path = "./test/tmp/snapshots/match_snapshot_inspect_existing.snap"
      let _ = file.write(path, "[1, 2]\n")

      [1, 2]
      |> should
      |> snapshot.match_snapshot_inspect(path)
      |> should
      |> be_equal(MatchOk([1, 2]))
      |> or_fail_with("match_snapshot_inspect should match and keep the value")
    }),

    it("match_snapshot_inspect reports both texts on a mismatch", fn() {
      let path = "./test/tmp/snapshots/match_snapshot_inspect_mismatch.snap"
      let _ = file.write(path, "[1, 2]")

      [3]
      |> should
      |> snapshot.match_snapshot_inspect(path)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "match_snapshot_inspect",
          message: "",
          payload: Some(SnapshotFailure(
            actual: "[3]",
            expected: "[1, 2]",
            snapshot_path: path,
            is_missing: False,
          )),
        )),
      )
      |> or_fail_with("match_snapshot_inspect should report the mismatch")
    }),

    it("match_snapshot_inspect reports a snapshot path it cannot read", fn() {
      let path = "./test/tmp/snapshots/match_snapshot_inspect_directory.snap"
      let _ = file.write(path <> "/inner.txt", "")

      [1]
      |> should
      |> snapshot.match_snapshot_inspect(path)
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "match_snapshot_inspect",
          message: "Failed to read snapshot: Is a directory: " <> path,
          payload: Some(SnapshotFailure(
            actual: "",
            expected: "",
            snapshot_path: path,
            is_missing: True,
          )),
        )),
      )
      |> or_fail_with("match_snapshot_inspect should report the read error")
    }),

    it("match_snapshot_inspect reports a new snapshot it cannot write", fn() {
      let path = "./test/tmp/snapshots/match_snapshot_inspect_dangling.snap"
      let result =
        with_dangling_link(path, fn() {
          [1]
          |> should
          |> snapshot.match_snapshot_inspect(path)
        })

      result
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "match_snapshot_inspect",
          message: "Failed to write snapshot: File not found: " <> path,
          payload: Some(SnapshotFailure(
            actual: "",
            expected: "",
            snapshot_path: path,
            is_missing: True,
          )),
        )),
      )
      |> or_fail_with("match_snapshot_inspect should report the write error")
    }),

    it("match_snapshot_inspect passes an earlier failure through", fn() {
      prior_failure()
      |> snapshot.match_snapshot_inspect(
        "./test/tmp/snapshots/never_written.snap",
      )
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("match_snapshot_inspect should keep the earlier failure")
    }),

    it("clear_snapshot reports a path it cannot delete", fn() {
      let parent = "./test/tmp/snapshots/clear_snapshot_parent_file"
      let _ = file.write(parent, "a file, not a directory")
      let path = parent <> "/x.snap"

      snapshot.clear_snapshot(path)
      |> should
      |> be_equal(Error("File error (enotdir): " <> path))
      |> or_fail_with("clear_snapshot should report the delete error")
    }),

    it("clear_snapshots_in_directory reports a directory it cannot list", fn() {
      let path = "./test/tmp/snapshots/clear_directory_is_a_file"
      let _ = file.write(path, "a file, not a directory")

      snapshot.clear_snapshots_in_directory(path)
      |> should
      |> be_equal(Error("File error (enotdir): " <> path))
      |> or_fail_with("clear_snapshots_in_directory should report the error")
    }),
  ])
}

/// Run `body` while `path` is a symbolic link to a file in a directory that
/// does not exist, then delete the link.
///
/// Reading the link gives "not found", and writing through it fails too.
/// The link must not stay: a dangling link stops Gleam from copying this
/// project as a path dependency (examples/snippets).
fn with_dangling_link(path: String, body: fn() -> a) -> a {
  let _ = file.delete(path)
  let _ = file.write(path <> ".keep", "")
  let _ = make_symlink("missing_directory/target.snap", path)
  let result = body()
  let _ = file.delete(path)
  result
}

@external(erlang, "file", "make_symlink")
fn make_symlink(target: String, link: String) -> Dynamic
