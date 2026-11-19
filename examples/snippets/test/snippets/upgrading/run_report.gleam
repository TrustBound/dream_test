import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("types.failed", [
    it("is True after a failed test", fn() {
      let report = runner.new([failing_suite()]) |> runner.run()

      report
      |> types.failed()
      |> should
      |> be_equal(True)
      |> or_fail_with("expected failures to be present")
    }),
  ])
}

fn failing_suite() {
  describe("failing suite", [
    it("fails", fn() {
      1
      |> should
      |> be_equal(2)
      |> or_fail_with("intentional failure for the types.failed example")
    }),
  ])
}
