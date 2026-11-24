import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import snippets/doc/matchers/snapshot/clear_snapshot
import snippets/doc/matchers/snapshot/clear_snapshots_in_directory
import snippets/doc/matchers/snapshot/match_snapshot
import snippets/doc/matchers/snapshot/match_snapshot_inspect

pub fn tests() {
  describe("Doc examples: matchers/snapshot", [
    it("hello_matches_snapshot passes", fn() {
      // Act
      let result = match_snapshot.hello_matches_snapshot()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected hello_matches_snapshot to pass")
    }),
    it("some_one_matches_snapshot passes", fn() {
      // Act
      let result = match_snapshot_inspect.some_one_matches_snapshot()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected some_one_matches_snapshot to pass")
    }),
    it("clear_snapshot_deletes_file passes", fn() {
      // Act
      let result = clear_snapshot.clear_snapshot_deletes_file()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected clear_snapshot_deletes_file to pass")
    }),
    it("clear_two_snapshots passes", fn() {
      // Act
      let result = clear_snapshots_in_directory.clear_two_snapshots()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected clear_two_snapshots to pass")
    }),
  ])
}
