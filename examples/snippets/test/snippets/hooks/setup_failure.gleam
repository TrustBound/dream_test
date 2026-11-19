import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/runner
import dream_test/types.{SetupFailed}
import dream_test/unit.{before_each, describe, it}
import gleam/io
import gleam/list

pub fn setup_failure_tests() {
  describe("Setup failures", [
    before_each(fn() { Error("could not connect to database") }),
    it("will not run", fn() {
      // This won't execute.
      io.println("nope")
      Ok(succeed())
    }),
  ])
}

pub fn tests() {
  describe("Setup failure example", [
    it("reports the test as SetupFailed without running its body", fn() {
      runner.new([setup_failure_tests()])
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> list.map(fn(result) { result.status })
      |> should
      |> be_equal([SetupFailed])
      |> or_fail_with("expected one SetupFailed result")
    }),
  ])
}
