//// A receipt test after a change to the receipt: it compares a new
//// receipt with the snapshot of the old one. The failing suite is
//// `changed_receipt_tests`, so test discovery runs only `tests`, which
//// checks that it fails.

import dream_test/matchers.{be_equal, match_snapshot, or_fail_with, should}
import dream_test/reporters/summary
import dream_test/runner
import dream_test/unit.{describe, it}
import snippets/guides/snapshot_receipt.{render_receipt}

pub fn changed_receipt_tests() {
  describe("Receipt", [
    it("renders the items and the total", fn() {
      render_receipt([#("coffee", 350), #("croissant", 295)])
      |> should
      |> match_snapshot("./test/snapshots/guide_receipt.snap")
      |> or_fail_with("the receipt should match the snapshot")
    }),
  ])
}

pub fn tests() {
  describe("A changed receipt", [
    it("fails its snapshot test", fn() {
      // Act
      let report =
        runner.new([changed_receipt_tests()])
        |> runner.silent()
        |> runner.run()

      // Assert
      summary.count(report).failed
      |> should
      |> be_equal(1)
      |> or_fail_with("the changed receipt should not match")
    }),
  ])
}
