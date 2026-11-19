//// Pending tests: a name with no body, for a test skeleton.

import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/bdd
import dream_test/reporters/json
import dream_test/reporters/summary
import dream_test/runner
import dream_test/types.{type Status, type TestResult, Passed, Pending}
import dream_test/unit.{describe, it}
import dream_test/unit_context
import gleam/list
import gleam/string

pub fn tests() {
  describe("pending tests", [
    it("unit.pending gives the status Pending and the run passes", fn() {
      let report = run_skeleton()
      #(
        list.map(types.report_tests(report), name_status_and_failures),
        types.failed(report),
        summary.count(report).pending,
      )
      |> should
      |> be_equal(#(
        [
          #("adds an item", Passed, 0),
          #("removes an item", Pending, 0),
          #("empties the cart", Pending, 0),
        ],
        False,
        2,
      ))
      |> or_fail_with("pending tests should not fail the run")
    }),

    it("unit_context.pending gives the status Pending", fn() {
      runner.new([
        unit_context.describe("context", 41, [
          unit_context.pending("gets the context later"),
        ]),
      ])
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> list.map(name_status_and_failures)
      |> should
      |> be_equal([#("gets the context later", Pending, 0)])
      |> or_fail_with("the context test should be pending")
    }),

    it("the bdd report marks a pending test with ~", fn() {
      run_skeleton()
      |> bdd.format
      |> string.contains("~ removes an item")
      |> should
      |> be_equal(True)
      |> or_fail_with("the bdd report should mark the pending test")
    }),

    it("the JSON report gives the status pending", fn() {
      run_skeleton()
      |> json.format
      |> string.contains("\"status\":\"pending\"")
      |> should
      |> be_equal(True)
      |> or_fail_with("the JSON report should say pending")
    }),
  ])
}

fn run_skeleton() -> types.RunReport {
  runner.new([
    describe("Cart", [
      it("adds an item", fn() { Ok(succeed()) }),
      unit.pending("removes an item"),
      unit.pending("empties the cart"),
    ]),
  ])
  |> runner.silent()
  |> runner.run()
}

fn name_status_and_failures(result: TestResult) -> #(String, Status, Int) {
  #(result.name, result.status, list.length(result.failures))
}
