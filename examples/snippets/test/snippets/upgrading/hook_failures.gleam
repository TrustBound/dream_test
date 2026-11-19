import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/runner
import dream_test/types.{
  type RunReport, AfterAllHook, Failed, Passed, Pending, SetupFailed, Skipped,
  TeardownFailure, TimedOut,
}
import dream_test/unit.{after_all, before_all, describe, it}
import gleam/list

fn stop_database() -> Result(Nil, String) {
  Error("the database did not stop")
}

fn database_suite() {
  describe("Database", [
    after_all(stop_database),
    it("reads a row", fn() { Ok(succeed()) }),
  ])
}

fn after_all_failed(report: RunReport) -> Bool {
  types.report_teardown_failures(report)
  |> list.any(fn(failure) {
    case failure {
      TeardownFailure(hook: AfterAllHook, ..) -> True
      _ -> False
    }
  })
}

fn start_database() -> Result(Nil, String) {
  Error("the database did not start")
}

fn broken_database_suite() {
  describe("Broken database", [
    before_all(start_database),
    it("reads a row", fn() { Ok(succeed()) }),
    it("writes a row", fn() { Ok(succeed()) }),
  ])
}

fn count_broken(report: RunReport) -> Int {
  list.count(types.report_tests(report), fn(result) {
    case result.status {
      Failed | SetupFailed | TimedOut -> True
      Passed | Skipped | Pending -> False
    }
  })
}

pub fn tests() {
  describe("Hook failures", [
    it("a failed after_all hook is in the tear-down list", fn() {
      let report =
        runner.new([database_suite()])
        |> runner.silent()
        |> runner.run()

      #(after_all_failed(report), list.length(types.report_tests(report)))
      |> should
      |> be_equal(#(True, 1))
      |> or_fail_with("expected one test and one after_all failure")
    }),
    it("a failed before_all hook gives SetupFailed", fn() {
      let report =
        runner.new([broken_database_suite()])
        |> runner.silent()
        |> runner.run()

      count_broken(report)
      |> should
      |> be_equal(2)
      |> or_fail_with("expected two broken tests")
    }),
  ])
}
