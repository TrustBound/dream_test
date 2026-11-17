//// Black-box tests of parallel runner paths: hook failures, timeouts and
//// crashes, in the parallel and the sequential executor.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/parallel
import dream_test/reporters/progress
import dream_test/runner
import dream_test/types.{
  type AssertionFailure, type AssertionResult, type Node, type Status,
  type TestResult, AssertionFailure, AssertionOk, Failed, Passed, SetupFailed,
  Skipped, Test, TimedOut, Unit,
}
import dream_test/unit.{
  after_all, after_each, before_all, before_each, describe, group, it, skip,
}
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process
import gleam/list
import gleam/option.{None, Some}

pub fn tests() {
  describe("dream_test/parallel paths", [
    it("run_root_parallel runs a suite", fn() {
      parallel.run_root_parallel(
        parallel.default_config(),
        describe("root", [it("passes", fn() { Ok(AssertionOk) })]),
      )
      |> summaries
      |> should
      |> be_equal([#(["root", "passes"], Passed, [])])
      |> or_fail_with("run_root_parallel should run the suite")
    }),

    it("a before_all failure fails the tests of nested groups", fn() {
      describe("root", [
        before_all(fn() { Error("nope") }),
        group("inner", [it("a", fn() { Ok(AssertionOk) })]),
        group("other", [it("b", fn() { Ok(AssertionOk) })]),
      ])
      |> run_default
      |> summaries
      |> should
      |> be_equal([
        #(["root", "inner", "a"], Failed, [failure("before_all", "nope")]),
        #(["root", "other", "b"], Failed, [failure("before_all", "nope")]),
      ])
      |> or_fail_with("tests in nested groups should fail with the hook error")
    }),

    it("a test that returns an error fails in parallel", fn() {
      describe("root", [it("errors", fn() { Error("bad") })])
      |> run_default
      |> summaries
      |> should
      |> be_equal([#(["root", "errors"], Failed, [failure("error", "bad")])])
      |> or_fail_with("an Error result should fail the test")
    }),

    it("a test that returns an error fails in sequence", fn() {
      describe("root", [it("errors", fn() { Error("bad") })])
      |> run_sequential
      |> summaries
      |> should
      |> be_equal([#(["root", "errors"], Failed, [failure("error", "bad")])])
      |> or_fail_with("an Error result should fail the test")
    }),

    it("a skipped test is skipped in sequence", fn() {
      describe("root", [skip("skipped", fn() { Ok(AssertionOk) })])
      |> run_sequential
      |> summaries
      |> should
      |> be_equal([#(["root", "skipped"], Skipped, [])])
      |> or_fail_with("skip should give Skipped in sequence")
    }),

    it("a test that crashes fails in sequence", fn() {
      describe("root", [
        it("crashes", fn() { erlang_error(atom.create("boom")) }),
      ])
      |> run_sequential
      |> summaries
      |> should
      |> be_equal([
        #(["root", "crashes"], Failed, [failure("crash", "error:boom")]),
      ])
      |> or_fail_with("a crash should fail the test")
    }),

    it("a test that runs too long times out in sequence", fn() {
      describe("root", [
        it("sleeps", fn() {
          process.sleep(1000)
          Ok(AssertionOk)
        }),
      ])
      |> run_sequential_with_timeout(50)
      |> summaries
      |> should
      |> be_equal([
        #(["root", "sleeps"], Failed, [failure("timeout", "test timed out")]),
      ])
      |> or_fail_with("a slow test should time out")
    }),

    it("a before_each failure gives SetupFailed in sequence", fn() {
      describe("root", [
        before_each(fn() { Error("no setup") }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> run_sequential
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], SetupFailed, [failure("before_each", "no setup")]),
      ])
      |> or_fail_with("a failing before_each should give SetupFailed")
    }),

    it("a runner before_each_test failure gives SetupFailed in sequence", fn() {
      runner.new([describe("root", [it("a", fn() { Ok(AssertionOk) })])])
      |> runner.max_concurrency(1)
      |> runner.before_each_test(fn(_info, _context) {
        Error("no runner setup")
      })
      |> runner.silent()
      |> runner.run()
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], SetupFailed, [
          failure("before_each_test", "no runner setup"),
        ]),
      ])
      |> or_fail_with("a failing before_each_test should give SetupFailed")
    }),

    it("an after_each failure fails the test", fn() {
      describe("root", [
        after_each(fn() { Error("no teardown") }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> run_default
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], Failed, [failure("after_each", "no teardown")]),
      ])
      |> or_fail_with("a failing after_each should fail the test")
    }),

    it("an after_all failure adds an <after_all> result", fn() {
      describe("root", [
        after_all(fn() { Error("no cleanup") }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> run_default
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], Passed, []),
        #(["root", "<after_all>"], Failed, [failure("after_all", "no cleanup")]),
      ])
      |> or_fail_with("a failing after_all should add an <after_all> result")
    }),

    it("a before_all that runs too long fails the tests", fn() {
      describe("root", [
        before_all(fn() {
          process.sleep(1000)
          Ok(Nil)
        }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> run_sequential_with_timeout(50)
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], Failed, [
          failure("before_all", "hook timed out in root"),
        ]),
      ])
      |> or_fail_with("a slow before_all should fail the tests")
    }),

    it("a before_all that crashes fails the tests", fn() {
      describe("root", [
        before_all(fn() { erlang_error(atom.create("boom")) }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> run_default
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], Failed, [
          failure("before_all", "hook crashed in root: error:boom"),
        ]),
      ])
      |> or_fail_with("a crashing before_all should fail the tests")
    }),

    it("an after_each that runs too long fails the test", fn() {
      describe("root", [
        after_each(fn() {
          process.sleep(1000)
          Ok(Nil)
        }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> run_sequential_with_timeout(50)
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], Failed, [
          failure("after_each", "hook timed out in root"),
        ]),
      ])
      |> or_fail_with("a slow after_each should fail the test")
    }),

    it("an after_each that crashes fails the test", fn() {
      describe("root", [
        after_each(fn() { erlang_error(atom.create("boom")) }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> run_default
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], Failed, [
          failure("after_each", "hook crashed in root: error:boom"),
        ]),
      ])
      |> or_fail_with("a crashing after_each should fail the test")
    }),

    it("a runner before_each_test that runs too long gives SetupFailed", fn() {
      runner.new([describe("root", [it("a", fn() { Ok(AssertionOk) })])])
      |> runner.max_concurrency(1)
      |> runner.default_timeout_ms(50)
      |> runner.before_each_test(fn(_info, context) {
        process.sleep(1000)
        Ok(context)
      })
      |> runner.silent()
      |> runner.run()
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], SetupFailed, [
          failure("before_each_test", "hook timed out in root"),
        ]),
      ])
      |> or_fail_with("a slow before_each_test should give SetupFailed")
    }),

    it("a runner before_each_test that crashes gives SetupFailed", fn() {
      runner.new([describe("root", [it("a", fn() { Ok(AssertionOk) })])])
      |> runner.before_each_test(fn(_info, _context) {
        erlang_error(atom.create("boom"))
      })
      |> runner.silent()
      |> runner.run()
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], SetupFailed, [
          failure("before_each_test", "hook crashed in root: error:boom"),
        ]),
      ])
      |> or_fail_with("a crashing before_each_test should give SetupFailed")
    }),

    it("a runner after_each_test that runs too long fails the test", fn() {
      runner.new([describe("root", [it("a", fn() { Ok(AssertionOk) })])])
      |> runner.max_concurrency(1)
      |> runner.default_timeout_ms(50)
      |> runner.after_each_test(fn(_info, _context) {
        process.sleep(1000)
        Ok(Nil)
      })
      |> runner.silent()
      |> runner.run()
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], Failed, [
          failure("after_each_test", "hook timed out in root"),
        ]),
      ])
      |> or_fail_with("a slow after_each_test should fail the test")
    }),

    it("a runner after_each_test that crashes fails the test", fn() {
      runner.new([describe("root", [it("a", fn() { Ok(AssertionOk) })])])
      |> runner.after_each_test(fn(_info, _context) {
        erlang_error(atom.create("boom"))
      })
      |> runner.silent()
      |> runner.run()
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], Failed, [
          failure("after_each_test", "hook crashed in root: error:boom"),
        ]),
      ])
      |> or_fail_with("a crashing after_each_test should fail the test")
    }),

    it("a test with its own timeout times out while another runs on", fn() {
      // The runner hook holds each worker for 30ms, so the 20ms deadline of
      // "short" passes before its body starts, while "long" still runs.
      runner.new([
        describe("root", [
          timed_test("short", Some(20), 1000),
          timed_test("long", None, 200),
        ]),
      ])
      |> runner.before_each_test(fn(_info, context) {
        process.sleep(30)
        Ok(context)
      })
      |> runner.silent()
      |> runner.run()
      |> summaries
      |> should
      |> be_equal([
        #(["root", "short"], TimedOut, [failure("timeout", "test timed out")]),
        #(["root", "long"], Passed, []),
      ])
      |> or_fail_with("the short test should time out and the long one pass")
    }),

    it("a test past its deadline during a slow progress write fails", fn() {
      // Each progress write takes 100ms. While the runner writes the line of
      // "fast", the 50ms sandbox timeout of "slow" ends its body, so "slow"
      // fails with the sandbox timeout and not with the runner deadline.
      runner.new([
        describe("root", [
          timed_test("slow", None, 1000),
          timed_test("fast", None, 0),
        ]),
      ])
      |> runner.default_timeout_ms(50)
      |> runner.progress_reporter(progress.new())
      |> runner.output(
        runner.Output(out: fn(_text) { process.sleep(100) }, error: fn(_text) {
          Nil
        }),
      )
      |> runner.run()
      |> summaries
      |> should
      |> be_equal([
        #(["root", "slow"], Failed, [failure("timeout", "test timed out")]),
        #(["root", "fast"], Passed, []),
      ])
      |> or_fail_with("the slow test should time out after the slow write")
    }),

    it("a test with its own timeout runs in sequence", fn() {
      describe("root", [timed_test("own", Some(1000), 0)])
      |> run_sequential
      |> summaries
      |> should
      |> be_equal([#(["root", "own"], Passed, [])])
      |> or_fail_with("a test with its own timeout should pass")
    }),
  ])
}

/// A test that sleeps `sleep_ms` and passes, with its own timeout.
fn timed_test(
  name: String,
  timeout_ms: option.Option(Int),
  sleep_ms: Int,
) -> Node(Nil) {
  Test(
    name: name,
    tags: [],
    kind: Unit,
    run: fn(_nil) { sleep_then_pass(sleep_ms) },
    timeout_ms: timeout_ms,
    source: None,
  )
}

fn sleep_then_pass(sleep_ms: Int) -> Result(AssertionResult, String) {
  process.sleep(sleep_ms)
  Ok(AssertionOk)
}

fn run_default(suite: types.TestSuite(Nil)) -> List(TestResult) {
  runner.new([suite]) |> runner.silent() |> runner.run()
}

fn run_sequential(suite: types.TestSuite(Nil)) -> List(TestResult) {
  runner.new([suite])
  |> runner.max_concurrency(1)
  |> runner.silent()
  |> runner.run()
}

fn run_sequential_with_timeout(
  suite: types.TestSuite(Nil),
  timeout_ms: Int,
) -> List(TestResult) {
  runner.new([suite])
  |> runner.max_concurrency(1)
  |> runner.default_timeout_ms(timeout_ms)
  |> runner.silent()
  |> runner.run()
}

fn failure(operator: String, message: String) -> AssertionFailure {
  AssertionFailure(operator: operator, message: message, payload: None)
}

fn summaries(
  results: List(TestResult),
) -> List(#(List(String), Status, List(AssertionFailure))) {
  list.map(results, fn(result) {
    #(result.full_name, result.status, result.failures)
  })
}

@external(erlang, "erlang", "error")
fn erlang_error(reason: Atom) -> a
