//// The start of a context suite: `dream_test/context`, and the labels of
//// `describe` and `group`.

import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/runner
import dream_test/suite
import dream_test/types.{type Status, type TestResult, Passed, SetupFailed}
import dream_test/unit.{describe, it}
import dream_test/unit_context
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list

pub fn tests() {
  describe("dream_test/context", [
    it("context.value gives the same value to each test", fn() {
      let events = process.new_subject()
      let report =
        runner.new([
          unit_context.describe("numbers", context.value(41), [
            unit_context.it("first", fn(value) {
              report_value(events, "first", value)
            }),
            unit_context.it("second", fn(value) {
              report_value(events, "second", value)
            }),
          ]),
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
          [#(["numbers", "first"], Passed), #(["numbers", "second"], Passed)],
          [],
          ["first got 41", "second got 41"],
        ),
      )
      |> or_fail_with("each test should get 41")
    }),

    it("context.value is the value that before_each changes", fn() {
      let events = process.new_subject()
      let report =
        runner.new([
          unit_context.describe("numbers", context.value(41), [
            unit_context.before_each(fn(value) { Ok(value + 1) }),
            unit_context.it("first", fn(value) {
              report_value(events, "first", value)
            }),
          ]),
        ])
        |> runner.silent()
        |> runner.run()
      #(statuses(report), receive_all(events, []))
      |> should
      |> be_equal(#([#(["numbers", "first"], Passed)], ["first got 42"]))
      |> or_fail_with("the test should get 42")
    }),

    it("context.setup runs once, and the teardown gets its value last", fn() {
      let events = process.new_subject()
      let report =
        runner.new([
          unit_context.describe(
            "server",
            context.setup(
              fn() {
                process.send(events, "setup")
                Ok(7)
              },
              teardown: fn(value) {
                process.send(events, "teardown got " <> int.to_string(value))
                Ok(Nil)
              },
            ),
            [
              unit_context.it("first", fn(value) {
                report_value(events, "first", value)
              }),
              unit_context.it("second", fn(value) {
                report_value(events, "second", value)
              }),
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
          [#(["server", "first"], Passed), #(["server", "second"], Passed)],
          [],
          ["setup", "first got 7", "second got 7", "teardown got 7"],
        ),
      )
      |> or_fail_with("the setup should run once and the teardown last")
    }),

    it("a context.setup error fails each test with its text", fn() {
      let report =
        runner.new([
          unit_context.describe(
            "server",
            context.setup(
              fn() { Error("port in use") },
              teardown: fn(_value: Int) { Ok(Nil) },
            ),
            [
              unit_context.it("first", fn(_value) { Ok(succeed()) }),
              unit_context.it("second", fn(_value) { Ok(succeed()) }),
            ],
          ),
        ])
        |> runner.silent()
        |> runner.run()
      list.map(types.report_tests(report), name_status_and_messages)
      |> should
      |> be_equal([
        #("first", SetupFailed, ["port in use"]),
        #("second", SetupFailed, ["port in use"]),
      ])
      |> or_fail_with("each test should fail with the setup error")
    }),

    it("describe and group take their tests with the label tests", fn() {
      let suites = [
        unit_context.describe(
          name: "context",
          context: context.setup(start: fn() { Ok(1) }, teardown: fn(_value) {
            Ok(Nil)
          }),
          tests: [
            unit_context.group(name: "group", tests: [
              unit_context.it("passes", fn(_value) { Ok(succeed()) }),
            ]),
          ],
        ),
        unit.describe(name: "unit", tests: [
          unit.group(name: "group", tests: [
            unit.it("passes", fn() { Ok(succeed()) }),
          ]),
        ]),
        suite.new(
          name: "new",
          tags: [],
          tests: [unit_context.it("passes", fn(_value) { Ok(succeed()) })],
          context: types.FixedContext(Nil),
        ),
        suite.from_tree(
          types.tree(name: "tree", initial: Nil, tests: [
            unit_context.it("passes", fn(_value) { Ok(succeed()) }),
          ]),
        ),
      ]
      runner.new(suites)
      |> runner.silent()
      |> runner.run()
      |> statuses
      |> should
      |> be_equal([
        #(["context", "group", "passes"], Passed),
        #(["unit", "group", "passes"], Passed),
        #(["new", "passes"], Passed),
        #(["tree", "passes"], Passed),
      ])
      |> or_fail_with("each suite should run its test")
    }),
  ])
}

fn report_value(events: Subject(String), name: String, value: Int) {
  process.send(events, name <> " got " <> int.to_string(value))
  Ok(succeed())
}

fn statuses(report: types.RunReport) -> List(#(List(String), Status)) {
  list.map(types.report_tests(report), full_name_and_status)
}

fn full_name_and_status(result: TestResult) -> #(List(String), Status) {
  #(types.full_name(result.groups, result.name), result.status)
}

fn name_status_and_messages(
  result: TestResult,
) -> #(String, Status, List(String)) {
  #(
    result.name,
    result.status,
    list.map(result.failures, fn(failure) { failure.message }),
  )
}

fn receive_all(
  events: Subject(String),
  received: List(String),
) -> List(String) {
  case process.receive(events, 0) {
    Ok(event) -> receive_all(events, [event, ..received])
    Error(Nil) -> list.reverse(received)
  }
}
