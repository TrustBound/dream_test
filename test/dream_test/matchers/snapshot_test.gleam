import dream_test/assertions/should.{
  be_error, be_ok, equal, or_fail_with, should,
}
import dream_test/file
import dream_test/matchers/snapshot
import dream_test/process
import dream_test/types.{MatchOk}
import dream_test/unit.{before_each, describe, group, it}
import fixtures/match_results
import gleam/int
import matchers/be_match_failed.{be_match_failed}
import matchers/extract_failure_operator.{extract_failure_operator}

pub fn tests() {
  describe("Snapshot Matchers", [
    group("match_snapshot", [
      before_each(fn(ctx) {
        let _ = file.delete("test/fixtures/snapshots/temp/new.snap")
        let _ = file.delete("test/fixtures/snapshots/temp/created.snap")
        Ok(ctx)
      }),
      it("returns MatchOk when content matches existing snapshot", fn(_) {
        // Arrange
        let value = MatchOk("hello world")
        let path = "test/fixtures/snapshots/matching/hello.snap"

        // Act
        let result = snapshot.match_snapshot(value, path)

        // Assert
        result
        |> should()
        |> equal(MatchOk("hello world"))
        |> or_fail_with("should return MatchOk when snapshot matches")
      }),
      it("returns MatchFailed when content differs from snapshot", fn(_) {
        // Arrange
        let value = MatchOk("wrong content")
        let path = "test/fixtures/snapshots/matching/hello.snap"

        // Act
        let result = snapshot.match_snapshot(value, path)

        // Assert
        result
        |> should()
        |> be_match_failed()
        |> or_fail_with("should return MatchFailed for mismatched snapshot")
      }),
      it("creates snapshot file when it doesn't exist", fn(_) {
        // Arrange
        let value = MatchOk("new snapshot content")
        let path = "test/fixtures/snapshots/temp/new.snap"

        // Act
        let _ = snapshot.match_snapshot(value, path)
        let file_content = file.read(path)

        // Assert
        file_content
        |> should()
        |> equal(Ok("new snapshot content"))
        |> or_fail_with("should create snapshot file with content")
      }),
      it("returns MatchOk when creating new snapshot", fn(_) {
        // Arrange
        let value = MatchOk("fresh content")
        let path = "test/fixtures/snapshots/temp/created.snap"

        // Act
        let result = snapshot.match_snapshot(value, path)

        // Assert
        result
        |> should()
        |> equal(MatchOk("fresh content"))
        |> or_fail_with("should return MatchOk when creating snapshot")
      }),
      it("propagates prior MatchFailed", fn(_) {
        // Arrange
        let prior_failure = match_results.make_prior_failure("prior")
        let path = "test/fixtures/snapshots/matching/hello.snap"

        // Act
        let result = snapshot.match_snapshot(prior_failure, path)

        // Assert
        result
        |> should()
        |> extract_failure_operator()
        |> equal("prior")
        |> or_fail_with("should propagate prior failure")
      }),
    ]),
    group("match_snapshot_inspect", [
      before_each(fn(ctx) {
        let _ = file.delete("test/fixtures/snapshots/temp/inspected.snap")
        Ok(ctx)
      }),
      it("returns MatchOk when inspected value matches snapshot", fn(_) {
        // Arrange
        let value = MatchOk([1, 2, 3])
        let path = "test/fixtures/snapshots/matching/inspected_list.snap"

        // Act
        let result = snapshot.match_snapshot_inspect(value, path)

        // Assert
        result
        |> should()
        |> equal(MatchOk([1, 2, 3]))
        |> or_fail_with("should return MatchOk when inspected snapshot matches")
      }),
      it("returns MatchFailed when inspected value differs", fn(_) {
        // Arrange
        let value = MatchOk([4, 5, 6])
        let path = "test/fixtures/snapshots/matching/inspected_list.snap"

        // Act
        let result = snapshot.match_snapshot_inspect(value, path)

        // Assert
        result
        |> should()
        |> be_match_failed()
        |> or_fail_with("should return MatchFailed for mismatched value")
      }),
      it("creates snapshot with inspected content", fn(_) {
        // Arrange
        let value = MatchOk(#("tuple", 42))
        let path = "test/fixtures/snapshots/temp/inspected.snap"

        // Act
        let _ = snapshot.match_snapshot_inspect(value, path)
        let file_content = file.read(path)

        // Assert
        file_content
        |> should()
        |> equal(Ok("#(\"tuple\", 42)"))
        |> or_fail_with("should create snapshot with inspected content")
      }),
      it("propagates prior MatchFailed", fn(_) {
        // Arrange
        let prior_failure = match_results.make_prior_failure("prior_inspect")
        let path = "test/fixtures/snapshots/matching/inspected_list.snap"

        // Act
        let result = snapshot.match_snapshot_inspect(prior_failure, path)

        // Assert
        result
        |> should()
        |> extract_failure_operator()
        |> equal("prior_inspect")
        |> or_fail_with("should propagate prior failure")
      }),
    ]),
    group("clear_snapshot", [
      before_each(fn(ctx) {
        let _ =
          file.write(
            "test/fixtures/snapshots/clearable/to_clear.snap",
            "to be cleared",
          )
        Ok(ctx)
      }),
      it("returns Ok after deleting snapshot", fn(_) {
        // Arrange
        let path = "test/fixtures/snapshots/clearable/to_clear.snap"

        // Act
        let result = snapshot.clear_snapshot(path)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("clear_snapshot should return Ok")
      }),
      it("removes the snapshot file", fn(_) {
        // Arrange
        let path = "test/fixtures/snapshots/clearable/to_clear.snap"

        // Act
        let _ = snapshot.clear_snapshot(path)
        let file_exists = file.read(path)

        // Assert
        file_exists
        |> should()
        |> be_error()
        |> or_fail_with("snapshot file should not exist after clear")
      }),
      it("returns Ok for non-existent file", fn(_) {
        // Arrange
        let path = "test/fixtures/snapshots/clearable/does_not_exist.snap"

        // Act
        let result = snapshot.clear_snapshot(path)

        // Assert
        result
        |> should()
        |> be_ok()
        |> or_fail_with("should return Ok for non-existent file")
      }),
    ]),
    group("clear_snapshots_in_directory", [
      it("returns count of deleted files", fn(_) {
        // Arrange
        let dir = unique_clearable_dir()
        let _ = setup_clearable_dir(dir)

        // Act
        let result = snapshot.clear_snapshots_in_directory(dir)
        cleanup_clearable_dir(dir)

        // Assert
        result
        |> should()
        |> equal(Ok(2))
        |> or_fail_with("should return count of deleted .snap files")
      }),
      it("deletes .snap files", fn(_) {
        // Arrange
        let dir = unique_clearable_dir()
        let _ = setup_clearable_dir(dir)

        // Act
        let _ = snapshot.clear_snapshots_in_directory(dir)
        let file_exists = file.read(dir <> "/to_clear.snap")
        cleanup_clearable_dir(dir)

        // Assert
        file_exists
        |> should()
        |> be_error()
        |> or_fail_with(".snap files should be deleted")
      }),
      it("does not delete non-.snap files", fn(_) {
        // Arrange
        let dir = unique_clearable_dir()
        let _ = setup_clearable_dir(dir)

        // Act
        let _ = snapshot.clear_snapshots_in_directory(dir)
        let keep_file = file.read(dir <> "/keep.txt")
        cleanup_clearable_dir(dir)

        // Assert
        keep_file
        |> should()
        |> be_ok()
        |> or_fail_with("non-.snap files should not be deleted")
      }),
      it("returns 0 when no .snap files exist", fn(_) {
        // Arrange
        let dir = unique_clearable_dir()
        let _ = setup_clearable_dir(dir)
        let _ = snapshot.clear_snapshots_in_directory(dir)

        // Act
        let result = snapshot.clear_snapshots_in_directory(dir)
        cleanup_clearable_dir(dir)

        // Assert
        result
        |> should()
        |> equal(Ok(0))
        |> or_fail_with("should return 0 when no .snap files exist")
      }),
    ]),
  ])
}

fn unique_clearable_dir() -> String {
  // Make these tests safe under parallel execution by isolating filesystem state.
  "test/fixtures/snapshots/clearable_tmp_"
  <> int.to_string(process.unique_port())
}

fn setup_clearable_dir(dir: String) -> Nil {
  let _ = file.write(dir <> "/to_clear.snap", "to be cleared")
  let _ = file.write(dir <> "/another.snap", "another snapshot")
  let _ = file.write(dir <> "/keep.txt", "keep me")
  Nil
}

fn cleanup_clearable_dir(dir: String) -> Nil {
  // Best-effort cleanup to avoid leaving temp artifacts in the repo.
  let _ = file.delete(dir <> "/to_clear.snap")
  let _ = file.delete(dir <> "/another.snap")
  let _ = file.delete(dir <> "/keep.txt")
  Nil
}
