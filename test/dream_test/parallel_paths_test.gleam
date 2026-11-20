//// Black-box tests of parallel runner paths: hook failures, timeouts and
//// crashes, in the parallel and the sequential executor.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/parallel
import dream_test/reporters/progress
import dream_test/runner
import dream_test/sandbox
import dream_test/suite.{type TestSuite}
import dream_test/types.{
  type AssertionFailure, type AssertionResult, type Node, type Status,
  type TeardownFailure, type TestResult, AfterAllHook, AfterEachHook,
  AfterEachTestHook, AssertionFailure, AssertionOk, Failed, Passed, SetupFailed,
  Skipped, TeardownFailure, Test, TimedOut, Unit,
}
import dream_test/unit.{
  after_all, after_each, before_all, before_each, describe, group, it, skip,
}
import dream_test/unit_context
import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Name, type Pid, type Subject}
import gleam/list
import gleam/option.{None, Some}

pub fn tests() {
  describe("dream_test/parallel paths", [
    it("run_tree_parallel runs a tree", fn() {
      parallel.run_tree_parallel(
        parallel.default_config(),
        types.tree("root", Nil, [it("passes", fn() { Ok(AssertionOk) })]),
      )
      |> types.report_tests
      |> summaries
      |> should
      |> be_equal([#(["root", "passes"], Passed, [])])
      |> or_fail_with("run_tree_parallel should run the tree")
    }),

    it("a before_all failure gives SetupFailed in nested groups", fn() {
      describe("root", [
        before_all(fn() { Error("nope") }),
        group("inner", [it("a", fn() { Ok(AssertionOk) })]),
        group("other", [it("b", fn() { Ok(AssertionOk) })]),
      ])
      |> run_default
      |> summaries
      |> should
      |> be_equal([
        #(["root", "inner", "a"], SetupFailed, [failure("before_all", "nope")]),
        #(["root", "other", "b"], SetupFailed, [failure("before_all", "nope")]),
      ])
      |> or_fail_with("tests in nested groups should give SetupFailed")
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
        it("sleeps", block_forever),
      ])
      |> run_sequential_with_timeout(50)
      |> summaries
      |> should
      |> be_equal([
        #(["root", "sleeps"], TimedOut, [failure("timeout", "test timed out")]),
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
      |> runner.before_each_test(fn(_info) { Error("no runner setup") })
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], SetupFailed, [
          failure("before_each_test", "no runner setup"),
        ]),
      ])
      |> or_fail_with("a failing before_each_test should give SetupFailed")
    }),

    it("an after_each failure keeps the status of the test", fn() {
      describe("root", [
        after_each(fn() { Error("no teardown") }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> run_default
      |> summaries
      |> should
      |> be_equal([#(["root", "a"], Passed, [])])
      |> or_fail_with("a failing after_each should not change the status")
    }),

    it("an after_each failure is a tear-down failure of the test", fn() {
      describe("root", [
        after_each(fn() { Error("no teardown") }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> teardown_failures_default
      |> should
      |> be_equal([
        TeardownFailure(
          hook: AfterEachHook,
          groups: ["root", "a"],
          message: "no teardown",
        ),
      ])
      |> or_fail_with("a failing after_each should be a tear-down failure")
    }),

    it("an after_each failure keeps the TimedOut status of a test", fn() {
      describe("root", [
        after_each(fn() { Error("no teardown") }),
        timed_test("slow", Some(50), block_forever),
      ])
      |> run_default
      |> statuses
      |> should
      |> be_equal([#(["root", "slow"], TimedOut)])
      |> or_fail_with("a failing after_each should not hide a timeout")
    }),

    it("an after_all failure adds no test result", fn() {
      describe("root", [
        after_all(fn() { Error("no cleanup") }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> run_default
      |> summaries
      |> should
      |> be_equal([#(["root", "a"], Passed, [])])
      |> or_fail_with("a failing after_all should add no test result")
    }),

    it("an after_all failure is a tear-down failure of the group", fn() {
      describe("root", [
        after_all(fn() { Error("no cleanup") }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> teardown_failures_default
      |> should
      |> be_equal([
        TeardownFailure(
          hook: AfterAllHook,
          groups: ["root"],
          message: "no cleanup",
        ),
      ])
      |> or_fail_with("a failing after_all should be a tear-down failure")
    }),

    it("an after_all failure does not stop the next after_all", fn() {
      describe("root", [
        after_all(fn() { Error("first") }),
        after_all(fn() { Error("second") }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> teardown_failures_default
      |> should
      |> be_equal([
        TeardownFailure(hook: AfterAllHook, groups: ["root"], message: "first"),
        TeardownFailure(hook: AfterAllHook, groups: ["root"], message: "second"),
      ])
      |> or_fail_with("every after_all should run")
    }),

    it("run_tree_parallel gives the tear-down failures", fn() {
      parallel.run_tree_parallel(
        parallel.default_config(),
        types.tree("root", Nil, [
          after_all(fn() { Error("no cleanup") }),
          it("a", fn() { Ok(AssertionOk) }),
        ]),
      )
      |> types.report_teardown_failures
      |> should
      |> be_equal([
        TeardownFailure(
          hook: AfterAllHook,
          groups: ["root"],
          message: "no cleanup",
        ),
      ])
      |> or_fail_with("run_tree_parallel should give the tear-down failures")
    }),

    it("a before_all that crashes gives SetupFailed", fn() {
      describe("root", [
        before_all(fn() { erlang_error(atom.create("boom")) }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> run_default
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], SetupFailed, [
          failure("before_all", "hook crashed in root: error:boom"),
        ]),
      ])
      |> or_fail_with("a crashing before_all should give SetupFailed")
    }),

    it("an after_each that runs too long is a tear-down failure", fn() {
      describe("root", [
        after_each(fn() {
          process.sleep_forever()
          Ok(Nil)
        }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> teardown_failures_sequential_with_timeout(50)
      |> should
      |> be_equal([
        TeardownFailure(
          hook: AfterEachHook,
          groups: ["root", "a"],
          message: "hook timed out in root",
        ),
      ])
      |> or_fail_with("a slow after_each should be a tear-down failure")
    }),

    it("an after_each that crashes is a tear-down failure", fn() {
      describe("root", [
        after_each(fn() { erlang_error(atom.create("boom")) }),
        it("a", fn() { Ok(AssertionOk) }),
      ])
      |> teardown_failures_default
      |> should
      |> be_equal([
        TeardownFailure(
          hook: AfterEachHook,
          groups: ["root", "a"],
          message: "hook crashed in root: error:boom",
        ),
      ])
      |> or_fail_with("a crashing after_each should be a tear-down failure")
    }),

    it("a runner before_each_test that runs too long gives SetupFailed", fn() {
      runner.new([describe("root", [it("a", fn() { Ok(AssertionOk) })])])
      |> runner.max_concurrency(1)
      |> runner.default_timeout_ms(50)
      |> runner.before_each_test(fn(_info) {
        process.sleep_forever()
        Ok(Nil)
      })
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
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
      |> runner.before_each_test(fn(_info) { erlang_error(atom.create("boom")) })
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], SetupFailed, [
          failure("before_each_test", "hook crashed in root: error:boom"),
        ]),
      ])
      |> or_fail_with("a crashing before_each_test should give SetupFailed")
    }),

    it("a before_each hook that crashes gives SetupFailed", fn() {
      runner.new([
        describe("root", [
          before_each(fn() { erlang_error(atom.create("boom")) }),
          it("a", fn() { Ok(AssertionOk) }),
        ]),
      ])
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> summaries
      |> should
      |> be_equal([
        #(["root", "a"], SetupFailed, [
          failure("before_each", "hook crashed in root: error:boom"),
        ]),
      ])
      |> or_fail_with("a crashing before_each should give SetupFailed")
    }),

    it(
      "a runner after_each_test that runs too long is a tear-down failure",
      fn() {
        runner.new([describe("root", [it("a", fn() { Ok(AssertionOk) })])])
        |> runner.max_concurrency(1)
        |> runner.default_timeout_ms(50)
        |> runner.after_each_test(fn(_info) {
          process.sleep_forever()
          Ok(Nil)
        })
        |> runner.silent()
        |> runner.run()
        |> types.report_teardown_failures
        |> should
        |> be_equal([
          TeardownFailure(
            hook: AfterEachTestHook,
            groups: ["root", "a"],
            message: "hook timed out in root",
          ),
        ])
        |> or_fail_with("a slow after_each_test should be a tear-down failure")
      },
    ),

    it("a runner after_each_test that crashes is a tear-down failure", fn() {
      runner.new([describe("root", [it("a", fn() { Ok(AssertionOk) })])])
      |> runner.after_each_test(fn(_info) { erlang_error(atom.create("boom")) })
      |> runner.silent()
      |> runner.run()
      |> types.report_teardown_failures
      |> should
      |> be_equal([
        TeardownFailure(
          hook: AfterEachTestHook,
          groups: ["root", "a"],
          message: "hook crashed in root: error:boom",
        ),
      ])
      |> or_fail_with(
        "a crashing after_each_test should be a tear-down failure",
      )
    }),

    it("a timed-out test process has exited before its after_each runs", fn() {
      // before_each gives the pid of the test process to the after_each
      // hook. The body never returns, so it times out after its own 20ms;
      // the hooks get 60s, so they always finish. The test times out, and the
      // after_each hook runs in a new process. It must not see the old
      // process alive: that process could still own a table or a name.
      unit_context.describe("root", process.self(), [
        unit_context.before_each(test_process),
        timed_context_test("hangs", 20, hang_with_context),
        unit_context.after_each(fail_if_alive),
      ])
      |> list.wrap
      |> runner.new
      |> runner.default_timeout_ms(60_000)
      |> runner.silent()
      |> runner.run()
      |> types.report_teardown_failures
      |> should
      |> be_equal([])
      |> or_fail_with("the timed-out test process should be gone")
    }),

    it("a body that times out runs its after_each once", fn() {
      // The body never returns and times out after 20ms. The hooks get the
      // default timeout of 60s, so after_each always finishes. The test is
      // TimedOut, and after_each runs exactly once: the loop reads every
      // message of the killed process before it starts the tear-down.
      let calls = process.new_subject()
      runner.new([
        describe("root", [
          after_each(fn() { record_call(calls) }),
          timed_test("hangs", Some(20), block_forever),
        ]),
      ])
      |> runner.default_timeout_ms(60_000)
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> list.map(test_status)
      |> fn(statuses) { #(statuses, count_calls(calls, 0)) }
      |> should
      |> be_equal(#([TimedOut], 1))
      |> or_fail_with("after_each should run once after a timeout")
    }),

    it("an after_each that times out runs once, and the next one runs", fn() {
      // The first after_each never returns and times out. The loop keeps it
      // as the step that timed out, so it does not run again, and runs the
      // second after_each in a new process. The second after_each only
      // sends a message, so it ends long before the 1s hook timeout.
      let first_calls = process.new_subject()
      let second_calls = process.new_subject()
      let report =
        runner.new([
          describe("root", [
            after_each(fn() { record_call_then_block(first_calls) }),
            after_each(fn() { record_call(second_calls) }),
            timed_test("passes", Some(60_000), pass),
          ]),
        ])
        |> runner.default_timeout_ms(1000)
        |> runner.silent()
        |> runner.run()
      #(
        list.length(types.report_teardown_failures(report)),
        count_calls(first_calls, 0),
        count_calls(second_calls, 0),
      )
      |> should
      |> be_equal(#(1, 1, 1))
      |> or_fail_with("each after_each should run once after a hook timeout")
    }),

    it("a test with its own timeout times out while another runs on", fn() {
      // The runner hook holds each worker for 30ms before the bodies start.
      // The 20ms deadline of "short" counts from the start of its body.
      // "short" never ends, and "long" waits until the process of "short"
      // has exited, so "short" times out while "long" still runs.
      let watch = start_watch()
      runner.new([
        describe("root", [
          timed_test("short", Some(20), fn() { start_then_block(watch) }),
          timed_test("long", None, fn() { pass_when_gone(watch) }),
        ]),
      ])
      |> runner.before_each_test(fn(_info) {
        process.sleep(30)
        Ok(Nil)
      })
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> summaries
      |> should
      |> be_equal([
        #(["root", "short"], TimedOut, [failure("timeout", "test timed out")]),
        #(["root", "long"], Passed, []),
      ])
      |> or_fail_with("the short test should time out and the long one pass")
    }),

    it("a test past its deadline during a slow progress write times out", fn() {
      // Each progress write takes 100ms. While the runner writes the line of
      // "fast", the 50ms deadline of the body of "slow" passes. The runner
      // checks the deadline after the write, so "slow" times out.
      runner.new([
        describe("root", [
          timed_test("slow", None, block_forever),
          // "fast" has its own long timeout, so a slow machine cannot
          // make it time out.
          timed_test("fast", Some(60_000), pass),
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
      |> types.report_tests
      |> summaries
      |> should
      |> be_equal([
        #(["root", "slow"], TimedOut, [failure("timeout", "test timed out")]),
        #(["root", "fast"], Passed, []),
      ])
      |> or_fail_with("the slow test should time out after the slow write")
    }),

    it("a worker killed from outside fails its test", fn() {
      // The first test kills its own test process. The parallel run must
      // give a failed result for it and go on, so the sandbox deadline is
      // never met.
      sandbox.run_isolated(
        sandbox.SandboxConfig(timeout_ms: 2000, show_crash_reports: False),
        run_suite_that_kills_a_worker,
        Nil,
      )
      |> should
      |> be_equal(
        sandbox.SandboxCompleted([
          #(["root", "kills its worker"], Failed, [
            failure("crash", "worker crashed in root: killed"),
          ]),
          #(["root", "passes"], Passed, []),
        ]),
      )
      |> or_fail_with("a killed worker should fail its test, not hang")
    }),

    it("a test with its own timeout runs in sequence", fn() {
      describe("root", [timed_test("own", Some(1000), pass)])
      |> run_sequential
      |> summaries
      |> should
      |> be_equal([#(["root", "own"], Passed, [])])
      |> or_fail_with("a test with its own timeout should pass")
    }),
  ])
}

/// A test with its own timeout.
fn timed_test(
  name: String,
  timeout_ms: option.Option(Int),
  body: fn() -> Result(AssertionResult, String),
) -> Node(Nil) {
  Test(
    name: name,
    tags: [],
    kind: Unit,
    run: types.WithInput(fn(_nil) { body() }),
    timeout_ms: timeout_ms,
    source: None,
  )
}

/// A test with a context and its own timeout.
fn timed_context_test(
  name: String,
  timeout_ms: Int,
  body: fn(Pid) -> Result(AssertionResult, String),
) -> Node(Pid) {
  Test(
    name: name,
    tags: [],
    kind: Unit,
    run: types.WithInput(body),
    timeout_ms: Some(timeout_ms),
    source: None,
  )
}

fn pass() -> Result(AssertionResult, String) {
  Ok(AssertionOk)
}

fn test_process(_pid: Pid) -> Result(Pid, String) {
  Ok(process.self())
}

fn hang_with_context(_pid: Pid) -> Result(AssertionResult, String) {
  block_forever()
}

fn fail_if_alive(pid: Pid) -> Result(Nil, String) {
  case process.is_alive(pid) {
    True -> Error("the test process is still alive")
    False -> Ok(Nil)
  }
}

/// A body that never returns, so its test can only time out.
fn block_forever() -> Result(AssertionResult, String) {
  process.sleep_forever()
  Ok(AssertionOk)
}

/// The messages of a watch process: one test process says that it started,
/// and another test waits until that process has exited.
type Watch {
  Started(pid: Pid)
  WaitUntilGone(reply: Subject(Nil))
}

/// What a watch process gets: a message from a test, or the exit of the
/// process that started it or of the process that it watches.
type WatchEvent {
  FromTest(Watch)
  SetupProcessGone
  WatchedGone
}

/// Start a watch process under a new name. The name is registered before
/// this function returns, so the tests can always send to it. The watch
/// process stops when the process that started it exits, so it never
/// outlives its test.
fn start_watch() -> Name(Watch) {
  let setup_process = process.self()
  let name = process.new_name("dream_test_watch")
  let pid =
    process.spawn_unlinked(fn() {
      let monitor = process.monitor(setup_process)
      process.new_selector()
      |> process.select_map(process.named_subject(name), FromTest)
      |> process.select_specific_monitor(monitor, fn(_down) { SetupProcessGone })
      |> watch(None, None)
    })
  let assert Ok(Nil) = process.register(pid, name)
  name
}

fn watch(
  selector: process.Selector(WatchEvent),
  started: option.Option(Pid),
  waiting: option.Option(Subject(Nil)),
) -> Nil {
  case started, waiting {
    Some(pid), Some(reply) -> {
      let monitor = process.monitor(pid)
      let selector =
        process.select_specific_monitor(selector, monitor, fn(_down) {
          WatchedGone
        })
      wait_until_gone(selector, reply)
    }
    _, _ ->
      case process.selector_receive_forever(selector) {
        FromTest(Started(pid)) -> watch(selector, Some(pid), waiting)
        FromTest(WaitUntilGone(reply)) -> watch(selector, started, Some(reply))
        SetupProcessGone | WatchedGone -> Nil
      }
  }
}

/// Answer `reply` when the watched process exits. Stop without an answer
/// when the setup process exits first.
fn wait_until_gone(
  selector: process.Selector(WatchEvent),
  reply: Subject(Nil),
) -> Nil {
  case process.selector_receive_forever(selector) {
    WatchedGone -> process.send(reply, Nil)
    SetupProcessGone -> Nil
    FromTest(_) -> wait_until_gone(selector, reply)
  }
}

/// Tell `watch` which process this test is, then never return.
fn start_then_block(watch: Name(Watch)) -> Result(AssertionResult, String) {
  process.send(process.named_subject(watch), Started(process.self()))
  block_forever()
}

/// Pass when the test process that started at `watch` has exited.
fn pass_when_gone(watch: Name(Watch)) -> Result(AssertionResult, String) {
  let reply = process.new_subject()
  process.send(process.named_subject(watch), WaitUntilGone(reply))
  process.receive_forever(reply)
  Ok(AssertionOk)
}

fn run_suite_that_kills_a_worker(
  _input: Nil,
) -> List(#(List(String), Status, List(AssertionFailure))) {
  let watch = start_watch()
  describe("root", [
    it("kills its worker", fn() { kill_worker_then_pass(watch) }),
    timed_test("passes", None, fn() { pass_when_gone(watch) }),
  ])
  |> run_default
  |> summaries
}

/// The body runs in the test process, so the body kills that process. It
/// first tells `watch` which process it is, so "passes" still runs when the
/// worker is killed.
fn kill_worker_then_pass(
  watch: Name(Watch),
) -> Result(AssertionResult, String) {
  process.send(process.named_subject(watch), Started(process.self()))
  process.kill(process.self())
  Ok(AssertionOk)
}

fn run_default(suite: TestSuite) -> List(TestResult) {
  runner.new([suite])
  |> runner.silent()
  |> runner.run()
  |> types.report_tests
}

fn run_sequential(suite: TestSuite) -> List(TestResult) {
  runner.new([suite])
  |> runner.max_concurrency(1)
  |> runner.silent()
  |> runner.run()
  |> types.report_tests
}

fn run_sequential_with_timeout(
  suite: TestSuite,
  timeout_ms: Int,
) -> List(TestResult) {
  runner.new([suite])
  |> runner.max_concurrency(1)
  |> runner.default_timeout_ms(timeout_ms)
  |> runner.silent()
  |> runner.run()
  |> types.report_tests
}

fn failure(operator: String, message: String) -> AssertionFailure {
  AssertionFailure(operator: operator, message: message, payload: None)
}

fn summaries(
  results: List(TestResult),
) -> List(#(List(String), Status, List(AssertionFailure))) {
  list.map(results, fn(result) {
    #(
      types.full_name(result.groups, result.name),
      result.status,
      result.failures,
    )
  })
}

@external(erlang, "erlang", "error")
fn erlang_error(reason: Atom) -> a

fn teardown_failures_default(suite: TestSuite) -> List(TeardownFailure) {
  runner.new([suite])
  |> runner.silent()
  |> runner.run()
  |> types.report_teardown_failures
}

fn teardown_failures_sequential_with_timeout(
  suite: TestSuite,
  timeout_ms: Int,
) -> List(TeardownFailure) {
  runner.new([suite])
  |> runner.max_concurrency(1)
  |> runner.default_timeout_ms(timeout_ms)
  |> runner.silent()
  |> runner.run()
  |> types.report_teardown_failures
}

fn statuses(results: List(TestResult)) -> List(#(List(String), Status)) {
  list.map(results, fn(result) {
    #(types.full_name(result.groups, result.name), result.status)
  })
}

fn record_call(calls: Subject(Nil)) -> Result(Nil, String) {
  process.send(calls, Nil)
  Ok(Nil)
}

fn record_call_then_block(calls: Subject(Nil)) -> Result(Nil, String) {
  process.send(calls, Nil)
  process.sleep_forever()
  Ok(Nil)
}

fn count_calls(calls: Subject(Nil), count: Int) -> Int {
  case process.receive(calls, 0) {
    Ok(Nil) -> count_calls(calls, count + 1)
    Error(Nil) -> count
  }
}

fn test_status(result: TestResult) -> Status {
  result.status
}
