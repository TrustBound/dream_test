//// The tests of the outputs that the guide on snapshots shows. The
//// snapshot files themselves are checked by the tests of
//// `snapshot_receipt`, which compare them with the real receipt.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/guides/snapshot_changed
import snippets/guides/snapshot_first_run
import snippets/guides/snapshot_receipt
import snippets_outputs

pub fn tests() -> TestSuite {
  describe("Guide: snapshots", [
    it("the receipt snapshot tests pass", fn() {
      // Act
      let report = snippets_outputs.bdd_report([snapshot_receipt.tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_snapshot_first"))
      |> or_fail_with("expected test/outputs/guide_snapshot_first.txt")
    }),
    it("a changed receipt fails with a line diff", fn() {
      // Act
      let report =
        snippets_outputs.bdd_report([snapshot_changed.changed_receipt_tests()])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_snapshot_changed"))
      |> or_fail_with("expected test/outputs/guide_snapshot_changed.txt")
    }),
    it("the snapshot checks pass", fn() {
      // Act
      let report =
        snippets_outputs.bdd_report([
          snapshot_first_run.tests(),
          snapshot_changed.tests(),
        ])

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.expected("guide_snapshot_check"))
      |> or_fail_with("expected test/outputs/guide_snapshot_check.txt")
    }),
  ])
}
