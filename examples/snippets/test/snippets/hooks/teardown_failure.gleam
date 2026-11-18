import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/runner
import dream_test/types.{AfterAllHook, Passed, TeardownFailure}
import dream_test/unit.{after_all, describe, it}
import gleam/list

pub fn cleanup_failure_tests() {
  describe("Database", [
    after_all(fn() { Error("could not drop the test schema") }),
    it("saves a user", fn() { Ok(succeed()) }),
  ])
}

pub fn tests() {
  describe("Tear-down failure example", [
    it("keeps the status of the test", fn() {
      runner.new([cleanup_failure_tests()])
      |> runner.run()
      |> types.report_tests
      |> list.map(fn(result) { result.status })
      |> should
      |> be_equal([Passed])
      |> or_fail_with("expected the test to stay Passed")
    }),
    it("puts the failure in the tear-down list of the report", fn() {
      runner.new([cleanup_failure_tests()])
      |> runner.run()
      |> types.report_teardown_failures
      |> should
      |> be_equal([
        TeardownFailure(
          hook: AfterAllHook,
          groups: ["Database"],
          message: "could not drop the test schema",
        ),
      ])
      |> or_fail_with("expected one tear-down failure")
    }),
  ])
}
