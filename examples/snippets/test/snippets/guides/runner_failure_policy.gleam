import dream_test/matchers.{be_true, or_fail_with, should, succeed}
import dream_test/runner
import dream_test/types
import dream_test/unit.{after_all, describe, it}

/// Every test passes, but the cleanup fails.
fn suite_with_a_failed_cleanup() {
  describe("Uploads", [
    after_all(fn() { Error("could not delete the upload folder") }),
    it("stores a file", fn() { Ok(succeed()) }),
  ])
}

pub fn tests() {
  describe("The run report", [
    it("fails a run whose cleanup failed", fn() {
      // Act
      let report =
        runner.new([suite_with_a_failed_cleanup()])
        |> runner.silent()
        |> runner.run()

      // Assert
      types.failed(report)
      |> should
      |> be_true()
      |> or_fail_with("a failed teardown should fail the run")
    }),
    it("fails a run that ran no test", fn() {
      // Act
      let report =
        runner.new([suite_with_a_failed_cleanup()])
        |> runner.filter_tests(fn(_info) { False })
        |> runner.silent()
        |> runner.run()

      // Assert
      types.failed(report)
      |> should
      |> be_true()
      |> or_fail_with("a run with no test should fail")
    }),
  ])
}
