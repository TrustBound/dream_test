//// A suite whose context comes from a set-up:
//// `unit_context.describe_with_set_up`.

import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/json
import dream_test/reporters/teardown
import dream_test/runner
import dream_test/suite
import dream_test/types.{
  type AssertionFailure, type Status, type TeardownFailure, type TestInfo,
  type TestResult, AssertionFailure, BeforeEachSuiteHook, Passed, SetupFailed,
  SetupStopped, SuiteSetUpHook, SuiteTearDownHook, TeardownFailure,
}
import dream_test/unit.{describe, it}
import dream_test/unit_context
import gleam/erlang/process.{type Name, type Pid, type Subject}
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string

pub fn tests() {
  describe("unit_context.describe_with_set_up", [
    it("gives the value of the set-up to each test, once", fn() {
      let events = process.new_subject()
      let report =
        runner.new([counted_suite(events)])
        |> runner.max_concurrency(1)
        |> runner.silent()
        |> runner.run()
      #(
        statuses(report),
        types.report_teardown_failures(report),
        receive_all(events, []),
      )
      |> should
      |> be_equal(
        #(
          [#(["server", "first"], Passed), #(["server", "second"], Passed)],
          [],
          ["set_up", "first got 7", "second got 7", "tear_down got 7"],
        ),
      )
      |> or_fail_with("the set-up should run once and the tear-down last")
    }),

    it("does not run the set-up when no test of the suite runs", fn() {
      let events = process.new_subject()
      let report =
        runner.new([plain_suite(), counted_suite(events)])
        |> runner.filter_tests(is_named(_, "passes"))
        |> runner.silent()
        |> runner.run()
      #(statuses(report), receive_all(events, []))
      |> should
      |> be_equal(#([#(["plain", "passes"], Passed)], []))
      |> or_fail_with("the set-up should not run")
    }),

    it("does not run the set-up of a suite with no test", fn() {
      let events = process.new_subject()
      let report =
        runner.new([
          unit_context.describe_with_set_up(
            "empty",
            set_up: fn() { send_and_give(events, "set_up", 7) },
            tear_down: fn(_value: Int) { send_ok(events, "tear_down") },
            children: [],
          ),
        ])
        |> runner.silent()
        |> runner.run()
      #(statuses(report), receive_all(events, []))
      |> should
      |> be_equal(#([], []))
      |> or_fail_with("the set-up should not run")
    }),

    it("a set-up error gives SetupFailed and no tear-down", fn() {
      let events = process.new_subject()
      let report =
        runner.new([
          broken_suite(events, fn() { Error("port in use") }),
        ])
        |> runner.silent()
        |> runner.run()
      #(
        failures(report),
        types.report_teardown_failures(report),
        receive_all(events, []),
      )
      |> should
      |> be_equal(
        #(
          [
            #(["broken", "first"], SetupFailed, [
              failure("suite set-up", "port in use"),
            ]),
            #(["broken", "second"], SetupFailed, [
              failure("suite set-up", "port in use"),
            ]),
          ],
          [],
          [],
        ),
      )
      |> or_fail_with("each test should be SetupFailed")
    }),

    it("a set-up that crashes gives SetupFailed and no tear-down", fn() {
      let events = process.new_subject()
      let report =
        runner.new([broken_suite(events, crash)])
        |> runner.silent()
        |> runner.run()
      #(
        list.map(failures(report), first_message_start),
        receive_all(events, []),
      )
      |> should
      |> be_equal(
        #(
          [
            "the suite set-up crashed in broken: error:#{",
            "the suite set-up crashed in broken: error:#{",
          ],
          [],
        ),
      )
      |> or_fail_with("each test should name the crash")
    }),

    it("a set-up that times out gives SetupFailed and no tear-down", fn() {
      let events = process.new_subject()
      let report =
        runner.new([broken_suite(events, wait_forever)])
        |> runner.default_timeout_ms(20)
        |> runner.silent()
        |> runner.run()
      #(failures(report), receive_all(events, []))
      |> should
      |> be_equal(
        #(
          [
            #(["broken", "first"], SetupFailed, [
              failure("suite set-up", "the suite set-up timed out in broken"),
            ]),
            #(["broken", "second"], SetupFailed, [
              failure("suite set-up", "the suite set-up timed out in broken"),
            ]),
          ],
          [],
        ),
      )
      |> or_fail_with("each test should name the timeout")
    }),

    it("a set-up whose process stops records each test as not run", fn() {
      let events = process.new_subject()
      let report =
        runner.new([broken_suite(events, kill_self)])
        |> runner.silent()
        |> runner.run()
      #(
        failures(report),
        types.report_teardown_failures(report),
        receive_all(events, []),
      )
      |> should
      |> be_equal(
        #(
          [
            #(["broken", "first"], SetupFailed, [stopped_failure()]),
            #(["broken", "second"], SetupFailed, [stopped_failure()]),
          ],
          [
            SetupStopped(
              set_up: SuiteSetUpHook,
              groups: ["broken"],
              reason: "killed",
              not_run: [["broken", "first"], ["broken", "second"]],
            ),
          ],
          [],
        ),
      )
      |> or_fail_with("the stopped set-up should list the tests")
    }),

    it("a tear-down error is a tear-down failure", fn() {
      let report =
        runner.new([
          unit_context.describe_with_set_up(
            "server",
            set_up: fn() { Ok(7) },
            tear_down: fn(_value: Int) { Error("port still open") },
            children: [unit_context.it("passes", fn(_value) { Ok(succeed()) })],
          ),
        ])
        |> runner.silent()
        |> runner.run()
      #(statuses(report), types.report_teardown_failures(report))
      |> should
      |> be_equal(
        #([#(["server", "passes"], Passed)], [
          TeardownFailure(
            hook: SuiteTearDownHook,
            groups: ["server"],
            message: "port still open",
          ),
        ]),
      )
      |> or_fail_with("the tear-down failure should name the suite")
    }),

    it("a tear-down that crashes is a tear-down failure", fn() {
      let report =
        runner.new([
          unit_context.describe_with_set_up(
            "server",
            set_up: fn() { Ok(7) },
            tear_down: crash_with,
            children: [unit_context.it("passes", fn(_value) { Ok(succeed()) })],
          ),
        ])
        |> runner.silent()
        |> runner.run()
      types.report_teardown_failures(report)
      |> list.map(teardown_message_start)
      |> should
      |> be_equal(["the suite tear-down crashed in server: error:#{"])
      |> or_fail_with("the tear-down failure should name the crash")
    }),

    it("the reports name a failed suite tear-down in plain words", fn() {
      let failures =
        runner.new([
          unit_context.describe_with_set_up(
            "Server",
            set_up: fn() { Ok(7) },
            tear_down: fn(_value: Int) { Error("port still open") },
            children: [unit_context.it("passes", fn(_value) { Ok(succeed()) })],
          ),
        ])
        |> runner.silent()
        |> runner.run()
        |> types.report_teardown_failures
      #(
        teardown.format(failures),
        json.format(types.run_report(tests: [], teardown_failures: failures))
          |> string.contains(
            "{\"kind\":\"hook_failed\",\"hook\":\"suite tear-down\",\"groups\":[\"Server\"],\"message\":\"port still open\"}",
          ),
      )
      |> should
      |> be_equal(#(
        "Set-up and tear-down failures:\n  suite tear-down in Server\n    port still open\n",
        True,
      ))
      |> or_fail_with("the reports should say suite tear-down")
    }),

    it("the reports name a stopped suite set-up in plain words", fn() {
      let failures = [
        SetupStopped(
          set_up: SuiteSetUpHook,
          groups: ["Server"],
          reason: "killed",
          not_run: [["Server", "a"]],
        ),
      ]
      #(
        teardown.format(failures),
        json.format(types.run_report(tests: [], teardown_failures: failures))
          |> string.contains(
            "{\"kind\":\"setup_stopped\",\"hook\":\"suite set-up\",\"groups\":[\"Server\"],\"message\":\"killed\",\"not_run\":[[\"Server\",\"a\"]]}",
          ),
      )
      |> should
      |> be_equal(#(
        "Set-up and tear-down failures:\n  suite set-up in \"Server\" stopped: the process that keeps its set-up alive exited with killed.\n    These tests had not started and were not run:\n      Server > a\n",
        True,
      ))
      |> or_fail_with("the reports should say suite set-up")
    }),

    it("a set-up process that stops during the tests runs the tear-down", fn() {
      let events = process.new_subject()
      let report =
        runner.new([
          unit_context.describe_with_set_up(
            "server",
            set_up: fn() { Ok(process.self()) },
            tear_down: fn(_setup_process: Pid) { send_ok(events, "tear_down") },
            children: [
              unit_context.it("stops the set-up", kill_and_wait),
              unit_context.it("never runs", fn(_setup_process) { Ok(succeed()) }),
            ],
          ),
        ])
        |> runner.max_concurrency(1)
        |> runner.silent()
        |> runner.run()
      #(
        statuses(report),
        types.report_teardown_failures(report),
        receive_all(events, []),
      )
      |> should
      |> be_equal(
        #(
          [
            #(["server", "stops the set-up"], Passed),
            #(["server", "never runs"], SetupFailed),
          ],
          [
            SetupStopped(
              set_up: SuiteSetUpHook,
              groups: ["server"],
              reason: "killed",
              not_run: [["server", "never runs"]],
            ),
          ],
          ["tear_down"],
        ),
      )
      |> or_fail_with("the tear-down should run after the set-up stopped")
    }),

    it("an outer set-up that stopped skips the set-up", fn() {
      let events = process.new_subject()
      let setup_processes = process.new_name("suite_setup_process")
      let report =
        runner.new([
          suite.join(name: "all", suites: [
            unit_context.describe("first", setup_processes, [
              unit_context.it(
                "stops the suite set-up",
                kill_suite_setup_process,
              ),
            ]),
            counted_suite(events),
          ]),
        ])
        |> runner.before_each_suite(fn(_info) { register_self(setup_processes) })
        |> runner.silent()
        |> runner.run()
      #(
        statuses(report),
        types.report_teardown_failures(report),
        receive_all(events, []),
      )
      |> should
      |> be_equal(
        #(
          [
            #(["first", "stops the suite set-up"], Passed),
            #(["server", "first"], SetupFailed),
            #(["server", "second"], SetupFailed),
          ],
          [
            SetupStopped(
              set_up: BeforeEachSuiteHook,
              groups: ["all"],
              reason: "killed",
              not_run: [["server", "first"], ["server", "second"]],
            ),
          ],
          [],
        ),
      )
      |> or_fail_with("the set-up should not run after the outer one stopped")
    }),
  ])
}

/// A suite whose set-up gives 7. Each step sends an event.
fn counted_suite(events: Subject(String)) {
  unit_context.describe_with_set_up(
    "server",
    set_up: fn() { send_and_give(events, "set_up", 7) },
    tear_down: fn(value: Int) {
      send_ok(events, "tear_down got " <> int.to_string(value))
    },
    children: [
      unit_context.it("first", fn(value) {
        report_value(events, "first", value)
      }),
      unit_context.it("second", fn(value) {
        report_value(events, "second", value)
      }),
    ],
  )
}

/// A suite with the set-up `set_up`. Its tear-down sends an event.
fn broken_suite(events: Subject(String), set_up: fn() -> Result(Int, String)) {
  unit_context.describe_with_set_up(
    "broken",
    set_up: set_up,
    tear_down: fn(_value: Int) { send_ok(events, "tear_down") },
    children: [
      unit_context.it("first", fn(_value) { Ok(succeed()) }),
      unit_context.it("second", fn(_value) { Ok(succeed()) }),
    ],
  )
}

fn plain_suite() {
  describe("plain", [it("passes", fn() { Ok(succeed()) })])
}

fn report_value(events: Subject(String), name: String, value: Int) {
  process.send(events, name <> " got " <> int.to_string(value))
  Ok(succeed())
}

fn send_and_give(
  events: Subject(String),
  event: String,
  value: Int,
) -> Result(Int, String) {
  process.send(events, event)
  Ok(value)
}

fn send_ok(events: Subject(String), event: String) -> Result(Nil, String) {
  process.send(events, event)
  Ok(Nil)
}

/// Register the process of the hook under `name`.
fn register_self(name: Name(Nil)) -> Result(Nil, String) {
  process.register(process.self(), name)
  |> result.replace_error("the name is taken")
}

fn crash() -> Result(Int, String) {
  panic as "set-up crash"
}

fn crash_with(_value: Int) -> Result(Nil, String) {
  panic as "tear-down crash"
}

fn wait_forever() -> Result(Int, String) {
  process.sleep_forever()
  Ok(0)
}

fn kill_self() -> Result(Int, String) {
  process.kill(process.self())
  Ok(0)
}

/// Kill the process of the set-up and wait until it is gone.
fn kill_and_wait(setup_process: Pid) {
  kill_and_wait_for(setup_process)
  Ok(succeed())
}

/// Kill the process of the `before_each_suite` hook and wait until it is
/// gone.
fn kill_suite_setup_process(name: Name(Nil)) {
  case process.named(name) {
    Ok(setup_process) -> {
      kill_and_wait_for(setup_process)
      Ok(succeed())
    }
    Error(Nil) -> Error("the suite set-up has no process")
  }
}

fn kill_and_wait_for(pid: Pid) -> Nil {
  let monitor = process.monitor(pid)
  process.kill(pid)
  let _down =
    process.new_selector()
    |> process.select_specific_monitor(monitor, fn(down) { down })
    |> process.selector_receive_forever
  Nil
}

fn is_named(info: TestInfo, name: String) -> Bool {
  info.name == name
}

fn stopped_failure() -> AssertionFailure {
  failure(
    "suite set-up",
    "not run: the suite set-up of \"broken\" stopped (killed)",
  )
}

fn failure(operator: String, message: String) -> AssertionFailure {
  AssertionFailure(operator: operator, message: message, payload: None)
}

fn statuses(report: types.RunReport) -> List(#(List(String), Status)) {
  list.map(types.report_tests(report), full_name_and_status)
}

fn full_name_and_status(result: TestResult) -> #(List(String), Status) {
  #(types.full_name(result.groups, result.name), result.status)
}

fn failures(
  report: types.RunReport,
) -> List(#(List(String), Status, List(AssertionFailure))) {
  list.map(types.report_tests(report), full_name_status_and_failures)
}

fn full_name_status_and_failures(
  result: TestResult,
) -> #(List(String), Status, List(AssertionFailure)) {
  #(types.full_name(result.groups, result.name), result.status, result.failures)
}

/// The first 44 characters of the first failure message of a result.
fn first_message_start(
  result: #(List(String), Status, List(AssertionFailure)),
) -> String {
  case result.2 {
    [first, ..] -> string.slice(first.message, 0, 44)
    [] -> ""
  }
}

fn teardown_message_start(failure: TeardownFailure) -> String {
  case failure {
    TeardownFailure(message: message, ..) -> string.slice(message, 0, 47)
    SetupStopped(..) -> ""
  }
}

fn receive_all(
  subject: Subject(String),
  received_rev: List(String),
) -> List(String) {
  case process.receive(subject, 0) {
    Ok(item) -> receive_all(subject, [item, ..received_rev])
    Error(Nil) -> list.reverse(received_rev)
  }
}
