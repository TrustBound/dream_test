//// Black-box tests of where suite-level and group-level hooks run.
////
//// A hook that starts a resource the way a user does, for example a pool
//// that links to the caller or an ETS table that the caller owns, must find
//// that resource alive in the tests that it serves. Suite-level hooks and
//// group `before_all`/`after_all` hooks run in the process that runs the
//// suite, so a resource lives until the hook that stops it.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{
  type AssertionResult, type Status, type TestResult, AfterAllSuitesHook,
  AfterEachSuiteHook, AssertionFailure, AssertionOk, Passed, SetupFailed,
  TeardownFailure,
}
import dream_test/unit.{describe, it}
import dream_test/unit_context
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Name, type Pid}
import gleam/list
import gleam/otp/actor
import gleam/otp/static_supervisor
import gleam/result

pub fn tests() {
  describe("hook resources", [
    it("a pool that before_all starts lives for the tests of its group", fn() {
      unit_context.describe("pool group", NoPool, [
        unit_context.before_all(start_pool_in_context),
        unit_context.it("uses the pool", pool_in_context_is_alive),
        unit_context.after_all(stop_pool_in_context),
      ])
      |> run_suite
      |> statuses
      |> should
      |> be_equal([#("uses the pool", Passed)])
      |> or_fail_with("the pool from before_all should live for the test")
    }),

    it(
      "an ETS table that before_all makes lives for the tests of its group",
      fn() {
        unit_context.describe(
          "table group",
          atom.create("dream_test_before_all_table"),
          [
            unit_context.before_all(make_table),
            unit_context.it("uses the table", table_in_context_exists),
            unit_context.after_all(remove_table),
          ],
        )
        |> run_suite
        |> statuses
        |> should
        |> be_equal([#("uses the table", Passed)])
        |> or_fail_with(
          "the ETS table from before_all should live for the test",
        )
      },
    ),

    it("a pool that before_all_suites starts lives for the tests", fn() {
      let pool_name = process.new_name("dream_test_suite_pool")
      runner.new([
        unit_context.describe("pool suite", pool_name, [
          unit_context.it("uses the pool", named_pool_is_alive),
        ]),
      ])
      |> runner.before_all_suites(fn(_suites) { start_named_pool(pool_name) })
      |> runner.after_all_suites(fn(_suites) { stop_named_pool(pool_name) })
      |> runner.run()
      |> types.report_tests
      |> statuses
      |> should
      |> be_equal([#("uses the pool", Passed)])
      |> or_fail_with(
        "the pool from before_all_suites should live for the test",
      )
    }),

    it("a before_all_suites hook that crashes gives SetupFailed", fn() {
      runner.new([describe("suite", [it("a", passing_test)])])
      |> runner.before_all_suites(fn(_suites) { erlang_error(boom()) })
      |> runner.run()
      |> types.report_tests
      |> failures
      |> should
      |> be_equal([
        #("a", SetupFailed, [
          #("before_all_suites", "hook crashed: error:boom"),
        ]),
      ])
      |> or_fail_with("a crash in before_all_suites should fail the tests")
    }),

    it("a before_each_suite hook that crashes gives SetupFailed", fn() {
      runner.new([describe("suite", [it("a", passing_test)])])
      |> runner.before_each_suite(fn(_suite) { erlang_error(boom()) })
      |> runner.run()
      |> types.report_tests
      |> failures
      |> should
      |> be_equal([
        #("a", SetupFailed, [
          #("before_each_suite", "hook crashed in suite: error:boom"),
        ]),
      ])
      |> or_fail_with("a crash in before_each_suite should fail the tests")
    }),

    it("an after_each_suite hook that crashes is a tear-down failure", fn() {
      runner.new([describe("suite", [it("a", passing_test)])])
      |> runner.after_each_suite(fn(_suite) { erlang_error(boom()) })
      |> runner.run()
      |> types.report_teardown_failures
      |> should
      |> be_equal([
        TeardownFailure(
          hook: AfterEachSuiteHook,
          scope: ["suite"],
          message: "hook crashed in suite: error:boom",
        ),
      ])
      |> or_fail_with(
        "a crash in after_each_suite should be a tear-down failure",
      )
    }),

    it("an after_all_suites hook that crashes is a tear-down failure", fn() {
      runner.new([describe("suite", [it("a", passing_test)])])
      |> runner.after_all_suites(fn(_suites) { erlang_error(boom()) })
      |> runner.run()
      |> types.report_teardown_failures
      |> should
      |> be_equal([
        TeardownFailure(
          hook: AfterAllSuitesHook,
          scope: [],
          message: "hook crashed: error:boom",
        ),
      ])
      |> or_fail_with(
        "a crash in after_all_suites should be a tear-down failure",
      )
    }),
  ])
}

/// The context of the pool group: no pool before `before_all` runs.
type PoolContext {
  NoPool
  Pool(pid: Pid)
}

@external(erlang, "dream_test_hook_resource_test_ffi", "new_named_table")
fn new_named_table(name: Atom) -> Nil

@external(erlang, "dream_test_hook_resource_test_ffi", "table_exists")
fn table_exists(name: Atom) -> Bool

@external(erlang, "dream_test_hook_resource_test_ffi", "delete_table")
fn delete_table(name: Atom) -> Nil

@external(erlang, "erlang", "error")
fn erlang_error(reason: Atom) -> a

fn boom() -> Atom {
  atom.create("boom")
}

/// Start a pool the way a user does: a supervisor that links to the caller
/// and traps exits, so it stops when the caller stops.
fn start_pool() -> Result(Pid, String) {
  case
    static_supervisor.new(static_supervisor.OneForOne)
    |> static_supervisor.start
  {
    Ok(actor.Started(pid: pid, data: _supervisor)) -> Ok(pid)
    Error(_error) -> Error("the pool did not start")
  }
}

fn start_pool_in_context(_context: PoolContext) -> Result(PoolContext, String) {
  case start_pool() {
    Ok(pid) -> Ok(Pool(pid))
    Error(message) -> Error(message)
  }
}

fn stop_pool_in_context(context: PoolContext) -> Result(Nil, String) {
  case context {
    NoPool -> Error("no pool to stop")
    Pool(pid) -> {
      process.unlink(pid)
      process.kill(pid)
      Ok(Nil)
    }
  }
}

/// Wait a short time first, so that a pool that dies with the process that
/// started it is gone before the check.
fn pool_in_context_is_alive(
  context: PoolContext,
) -> Result(AssertionResult, String) {
  process.sleep(100)
  case context {
    NoPool -> Error("before_all gave no pool")
    Pool(pid) ->
      process.is_alive(pid)
      |> should
      |> be_equal(True)
      |> or_fail_with("the pool should be alive")
  }
}

fn start_named_pool(name: Name(Nil)) -> Result(Nil, String) {
  case start_pool() {
    Ok(pid) -> register(pid, name)
    Error(message) -> Error(message)
  }
}

fn register(pid: Pid, name: Name(Nil)) -> Result(Nil, String) {
  case process.register(pid, name) {
    Ok(Nil) -> Ok(Nil)
    Error(Nil) -> Error("the pool name is taken")
  }
}

fn stop_named_pool(name: Name(Nil)) -> Result(Nil, String) {
  case process.named(name) {
    Ok(pid) -> {
      process.unlink(pid)
      process.kill(pid)
      Ok(Nil)
    }
    Error(Nil) -> Error("no pool to stop")
  }
}

fn named_pool_is_alive(name: Name(Nil)) -> Result(AssertionResult, String) {
  process.sleep(100)
  process.named(name)
  |> result.map(process.is_alive)
  |> should
  |> be_equal(Ok(True))
  |> or_fail_with("the pool should be alive")
}

fn make_table(name: Atom) -> Result(Atom, String) {
  new_named_table(name)
  Ok(name)
}

fn remove_table(name: Atom) -> Result(Nil, String) {
  delete_table(name)
  Ok(Nil)
}

fn table_in_context_exists(name: Atom) -> Result(AssertionResult, String) {
  process.sleep(100)
  table_exists(name)
  |> should
  |> be_equal(True)
  |> or_fail_with("the ETS table should exist")
}

fn passing_test() -> Result(AssertionResult, String) {
  Ok(AssertionOk)
}

fn run_suite(suite: types.TestSuite(context)) -> List(TestResult) {
  runner.new([suite])
  |> runner.run()
  |> types.report_tests
}

fn statuses(results: List(TestResult)) -> List(#(String, Status)) {
  list.map(results, fn(result) { #(result.name, result.status) })
}

fn failures(
  results: List(TestResult),
) -> List(#(String, Status, List(#(String, String)))) {
  list.map(results, fn(result) {
    #(
      result.name,
      result.status,
      list.map(result.failures, fn(failure) {
        let AssertionFailure(operator: operator, message: message, payload: _) =
          failure
        #(operator, message)
      }),
    )
  })
}
