//// Black-box tests of the rule that a setup runs only for tests that run.
////
//// A setup hook, and its teardown hook, runs only when at least one of
//// the tests that it serves runs. The rule is the same with and without
//// `runner.filter_tests`.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner.{type RunBuilder}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult, type SuiteInfo, AssertionOk}
import dream_test/unit.{after_all, before_all, describe, group, it}
import gleam/erlang/process.{type Subject}
import gleam/list

pub fn tests() {
  describe("a setup runs only for tests that run", [
    it("a suite with no test runs no before_all or after_all", fn() {
      let calls = process.new_subject()
      describe("empty", [
        before_all(fn() { record(calls, "before_all") }),
        after_all(fn() { record(calls, "after_all") }),
      ])
      |> run_silent
      |> fn(_report) { received(calls, []) }
      |> should
      |> be_equal([])
      |> or_fail_with("no hook should run for a suite with no test")
    }),

    it("a group with no test runs no before_all or after_all", fn() {
      let calls = process.new_subject()
      describe("suite", [
        group("empty", [
          before_all(fn() { record(calls, "before_all") }),
          after_all(fn() { record(calls, "after_all") }),
        ]),
        it("passes", passes),
      ])
      |> run_silent
      |> fn(_report) { received(calls, []) }
      |> should
      |> be_equal([])
      |> or_fail_with("no hook should run for a group with no test")
    }),

    it("a suite with no test runs no before_each_suite", fn() {
      let calls = process.new_subject()
      runner.new([
        describe("empty", []),
        describe("full", [it("passes", passes)]),
      ])
      |> runner.before_each_suite(fn(info) { record_suite(calls, info) })
      |> runner.after_each_suite(fn(info) { record_suite(calls, info) })
      |> runner.silent()
      |> runner.run()
      |> fn(_report) { received(calls, []) }
      |> should
      |> be_equal(["full", "full"])
      |> or_fail_with(
        "the suite hooks should run only for the suite with a test",
      )
    }),

    it("a run with no test runs no before_all_suites", fn() {
      let calls = process.new_subject()
      runner.new([describe("empty", [])])
      |> all_suites_hooks(calls)
      |> runner.silent()
      |> runner.run()
      |> fn(_report) { received(calls, []) }
      |> should
      |> be_equal([])
      |> or_fail_with("no run hook should run when no test runs")
    }),

    it("a filter that keeps no test runs no before_all_suites", fn() {
      let calls = process.new_subject()
      runner.new([describe("full", [it("passes", passes)])])
      |> all_suites_hooks(calls)
      |> runner.filter_tests(keep_no_test)
      |> runner.silent()
      |> runner.run()
      |> fn(_report) { received(calls, []) }
      |> should
      |> be_equal([])
      |> or_fail_with("no run hook should run when the filter keeps no test")
    }),
  ])
}

fn run_silent(suite: TestSuite) -> types.RunReport {
  runner.new([suite])
  |> runner.silent()
  |> runner.run()
}

fn all_suites_hooks(builder: RunBuilder, calls: Subject(String)) -> RunBuilder {
  builder
  |> runner.before_all_suites(fn(_suites) { record(calls, "before_all_suites") })
  |> runner.after_all_suites(fn(_suites) { record(calls, "after_all_suites") })
}

fn record(calls: Subject(String), call: String) -> Result(Nil, String) {
  process.send(calls, call)
  Ok(Nil)
}

fn record_suite(
  calls: Subject(String),
  info: SuiteInfo,
) -> Result(Nil, String) {
  record(calls, info.name)
}

/// The calls that the hooks recorded, in order.
fn received(
  calls: Subject(String),
  received_rev: List(String),
) -> List(String) {
  case process.receive(calls, 0) {
    Ok(call) -> received(calls, [call, ..received_rev])
    Error(Nil) -> list.reverse(received_rev)
  }
}

fn passes() -> Result(AssertionResult, String) {
  Ok(AssertionOk)
}

fn keep_no_test(_info: types.TestInfo) -> Bool {
  False
}
