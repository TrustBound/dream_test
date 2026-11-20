//// A suite whose context comes from a setup:
//// `unit_context.describe_with_setup`.

import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/hook_failures
import dream_test/reporters/json
import dream_test/runner
import dream_test/suite
import dream_test/types.{
  type AssertionFailure, type HookFailure, type Status, type TestInfo,
  type TestResult, AssertionFailure, BeforeEachSuiteHook, ContextSetupHook,
  ContextTeardownHook, Passed, SetupFailed, SetupStopped, TeardownFailed,
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
  describe("unit_context.describe_with_setup", [
    it("gives the value of the setup to each test, once", fn() {
      let events = process.new_subject()
      let report =
        runner.new([counted_suite(events)])
        |> runner.max_concurrency(1)
        |> runner.silent()
        |> runner.run()
      #(
        statuses(report),
        types.report_hook_failures(report),
        receive_all(events, []),
      )
      |> should
      |> be_equal(
        #(
          [#(["server", "first"], Passed), #(["server", "second"], Passed)],
          [],
          ["setup", "first got 7", "second got 7", "teardown got 7"],
        ),
      )
      |> or_fail_with("the setup should run once and the teardown last")
    }),

    it("does not run the setup when no test of the tree runs", fn() {
      let events = process.new_subject()
      let report =
        runner.new([plain_suite(), counted_suite(events)])
        |> runner.filter_tests(is_named(_, "passes"))
        |> runner.silent()
        |> runner.run()
      #(statuses(report), receive_all(events, []))
      |> should
      |> be_equal(#([#(["plain", "passes"], Passed)], []))
      |> or_fail_with("the setup should not run")
    }),

    it("does not run the setup of a tree with no test", fn() {
      let events = process.new_subject()
      let report =
        runner.new([
          unit_context.describe_with_setup(
            "empty",
            setup: fn() { send_and_give(events, "setup", 7) },
            teardown: fn(_value: Int) { send_ok(events, "teardown") },
            children: [],
          ),
        ])
        |> runner.silent()
        |> runner.run()
      #(statuses(report), receive_all(events, []))
      |> should
      |> be_equal(#([], []))
      |> or_fail_with("the setup should not run")
    }),

    it("a setup error gives SetupFailed and no teardown", fn() {
      let events = process.new_subject()
      let report =
        runner.new([
          broken_suite(events, fn() { Error("port in use") }),
        ])
        |> runner.silent()
        |> runner.run()
      #(
        failures(report),
        types.report_hook_failures(report),
        receive_all(events, []),
      )
      |> should
      |> be_equal(
        #(
          [
            #(["broken", "first"], SetupFailed, [
              failure("context setup", "port in use"),
            ]),
            #(["broken", "second"], SetupFailed, [
              failure("context setup", "port in use"),
            ]),
          ],
          [],
          [],
        ),
      )
      |> or_fail_with("each test should be SetupFailed")
    }),

    it("a setup that crashes gives SetupFailed and no teardown", fn() {
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
            "the context setup crashed in broken: error:#{",
            "the context setup crashed in broken: error:#{",
          ],
          [],
        ),
      )
      |> or_fail_with("each test should name the crash")
    }),

    it("a setup that times out gives SetupFailed and no teardown", fn() {
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
              failure("context setup", "the context setup timed out in broken"),
            ]),
            #(["broken", "second"], SetupFailed, [
              failure("context setup", "the context setup timed out in broken"),
            ]),
          ],
          [],
        ),
      )
      |> or_fail_with("each test should name the timeout")
    }),

    it("a setup whose process stops records each test as not run", fn() {
      let events = process.new_subject()
      let report =
        runner.new([broken_suite(events, kill_self)])
        |> runner.silent()
        |> runner.run()
      #(
        failures(report),
        types.report_hook_failures(report),
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
              setup: ContextSetupHook,
              groups: ["broken"],
              reason: "killed",
              not_run: [["broken", "first"], ["broken", "second"]],
            ),
          ],
          [],
        ),
      )
      |> or_fail_with("the stopped setup should list the tests")
    }),

    it("a teardown error is a teardown failure", fn() {
      let report =
        runner.new([
          unit_context.describe_with_setup(
            "server",
            setup: fn() { Ok(7) },
            teardown: fn(_value: Int) { Error("port still open") },
            children: [unit_context.it("passes", fn(_value) { Ok(succeed()) })],
          ),
        ])
        |> runner.silent()
        |> runner.run()
      #(statuses(report), types.report_hook_failures(report))
      |> should
      |> be_equal(
        #([#(["server", "passes"], Passed)], [
          TeardownFailed(
            hook: ContextTeardownHook,
            groups: ["server"],
            message: "port still open",
          ),
        ]),
      )
      |> or_fail_with("the teardown failure should name the suite")
    }),

    it("a teardown that crashes is a teardown failure", fn() {
      let report =
        runner.new([
          unit_context.describe_with_setup(
            "server",
            setup: fn() { Ok(7) },
            teardown: crash_with,
            children: [unit_context.it("passes", fn(_value) { Ok(succeed()) })],
          ),
        ])
        |> runner.silent()
        |> runner.run()
      types.report_hook_failures(report)
      |> list.map(teardown_message_start)
      |> should
      |> be_equal(["the context teardown crashed in server: error:#{"])
      |> or_fail_with("the teardown failure should name the crash")
    }),

    it("the reports name a failed context teardown in plain words", fn() {
      let failures =
        runner.new([
          unit_context.describe_with_setup(
            "Server",
            setup: fn() { Ok(7) },
            teardown: fn(_value: Int) { Error("port still open") },
            children: [unit_context.it("passes", fn(_value) { Ok(succeed()) })],
          ),
        ])
        |> runner.silent()
        |> runner.run()
        |> types.report_hook_failures
      #(
        hook_failures.format(failures),
        json.format(
          types.run_report(
            tests: [],
            hook_failures: failures,
            reporter_crashes: [],
          ),
        )
          |> string.contains(
            "{\"kind\":\"teardown_failed\",\"hook\":\"context teardown\",\"groups\":[\"Server\"],\"message\":\"port still open\"}",
          ),
      )
      |> should
      |> be_equal(#(
        "Setup and teardown failures:\n  context teardown in Server\n    port still open\n",
        True,
      ))
      |> or_fail_with("the reports should say context teardown")
    }),

    it("the reports name a stopped context setup in plain words", fn() {
      let failures = [
        SetupStopped(
          setup: ContextSetupHook,
          groups: ["Server"],
          reason: "killed",
          not_run: [["Server", "a"]],
        ),
      ]
      #(
        hook_failures.format(failures),
        json.format(
          types.run_report(
            tests: [],
            hook_failures: failures,
            reporter_crashes: [],
          ),
        )
          |> string.contains(
            "{\"kind\":\"setup_stopped\",\"hook\":\"context setup\",\"groups\":[\"Server\"],\"message\":\"killed\",\"not_run\":[[\"Server\",\"a\"]]}",
          ),
      )
      |> should
      |> be_equal(#(
        "Setup and teardown failures:\n  context setup in \"Server\" stopped: the process that keeps its setup alive exited with killed.\n    These tests had not started and were not run:\n      Server > a\n",
        True,
      ))
      |> or_fail_with("the reports should say context setup")
    }),

    it("a setup process that stops during the tests runs the teardown", fn() {
      let events = process.new_subject()
      let report =
        runner.new([
          unit_context.describe_with_setup(
            "server",
            setup: fn() { Ok(process.self()) },
            teardown: fn(_setup_process: Pid) { send_ok(events, "teardown") },
            children: [
              unit_context.it("stops the setup", kill_and_wait),
              unit_context.it("never runs", fn(_setup_process) { Ok(succeed()) }),
            ],
          ),
        ])
        |> runner.max_concurrency(1)
        |> runner.silent()
        |> runner.run()
      #(
        statuses(report),
        types.report_hook_failures(report),
        receive_all(events, []),
      )
      |> should
      |> be_equal(
        #(
          [
            #(["server", "stops the setup"], Passed),
            #(["server", "never runs"], SetupFailed),
          ],
          [
            SetupStopped(
              setup: ContextSetupHook,
              groups: ["server"],
              reason: "killed",
              not_run: [["server", "never runs"]],
            ),
          ],
          ["teardown"],
        ),
      )
      |> or_fail_with("the teardown should run after the setup stopped")
    }),

    it("an outer setup that stopped skips the setup", fn() {
      let events = process.new_subject()
      let setup_processes = process.new_name("before_each_suite_process")
      let report =
        runner.new([
          suite.join(name: "all", suites: [
            unit_context.describe("first", setup_processes, [
              unit_context.it(
                "stops the before_each_suite setup",
                kill_before_each_suite_process,
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
        types.report_hook_failures(report),
        receive_all(events, []),
      )
      |> should
      |> be_equal(
        #(
          [
            #(["first", "stops the before_each_suite setup"], Passed),
            #(["server", "first"], SetupFailed),
            #(["server", "second"], SetupFailed),
          ],
          [
            SetupStopped(
              setup: BeforeEachSuiteHook,
              groups: ["all"],
              reason: "killed",
              not_run: [["server", "first"], ["server", "second"]],
            ),
          ],
          [],
        ),
      )
      |> or_fail_with("the setup should not run after the outer one stopped")
    }),
  ])
}

/// A suite whose setup gives 7. Each step sends an event.
fn counted_suite(events: Subject(String)) {
  unit_context.describe_with_setup(
    "server",
    setup: fn() { send_and_give(events, "setup", 7) },
    teardown: fn(value: Int) {
      send_ok(events, "teardown got " <> int.to_string(value))
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

/// A suite with the setup `setup`. Its teardown sends an event.
fn broken_suite(events: Subject(String), setup: fn() -> Result(Int, String)) {
  unit_context.describe_with_setup(
    "broken",
    setup: setup,
    teardown: fn(_value: Int) { send_ok(events, "teardown") },
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
  panic as "setup crash"
}

fn crash_with(_value: Int) -> Result(Nil, String) {
  panic as "teardown crash"
}

fn wait_forever() -> Result(Int, String) {
  process.sleep_forever()
  Ok(0)
}

fn kill_self() -> Result(Int, String) {
  process.kill(process.self())
  Ok(0)
}

/// Kill the process of the setup and wait until it is gone.
fn kill_and_wait(setup_process: Pid) {
  kill_and_wait_for(setup_process)
  Ok(succeed())
}

/// Kill the process of the `before_each_suite` hook and wait until it is
/// gone.
fn kill_before_each_suite_process(name: Name(Nil)) {
  case process.named(name) {
    Ok(setup_process) -> {
      kill_and_wait_for(setup_process)
      Ok(succeed())
    }
    Error(Nil) -> Error("the before_each_suite hook has no process")
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
    "context setup",
    "not run: the context setup of \"broken\" stopped (killed)",
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

/// The first 45 characters of the first failure message of a result.
fn first_message_start(
  result: #(List(String), Status, List(AssertionFailure)),
) -> String {
  case result.2 {
    [first, ..] -> string.slice(first.message, 0, 45)
    [] -> ""
  }
}

/// The first 48 characters of the message of a teardown failure.
fn teardown_message_start(failure: HookFailure) -> String {
  case failure {
    TeardownFailed(message: message, ..) -> string.slice(message, 0, 48)
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
