//// Direct black-box tests of public items that other modules use for you:
//// `suite.new`, `types.FixedContext` and `types.ContextFromSetup` built by
//// hand, `types.AssertionPending` from a body, `suite.run` with a
//// `suite.RunInput`, and `parallel.run_tree` with a
//// `parallel.RunTreeConfig`.

import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/parallel
import dream_test/runner
import dream_test/suite
import dream_test/types.{
  type AssertionResult, type Status, type TestInfo, type TestResult,
  AssertionPending, ContextFromSetup, FixedContext, Passed, Pending,
}
import dream_test/unit
import dream_test/unit_context
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{None}

pub fn tests() {
  unit.describe("public plumbing", [
    unit.it("suite.new with FixedContext gives each test the value", fn() {
      suite.new(
        name: "fixed",
        tags: ["tagged"],
        tests: [unit_context.it("gets 7", is_seven)],
        context: FixedContext(7),
      )
      |> run_all
      |> should
      |> be_equal([#(["fixed", "gets 7"], Passed)])
      |> or_fail_with("the test should get the fixed value")
    }),

    unit.it("suite.new keeps the name and the tags of the suite", fn() {
      let made =
        suite.new(
          name: "fixed",
          tags: ["tagged"],
          tests: [unit_context.it("gets 7", is_seven)],
          context: FixedContext(7),
        )
      #(suite.name(made), list.map(suite.tests(made), test_tags))
      |> should
      |> be_equal(#("fixed", [["tagged"]]))
      |> or_fail_with("the suite should keep its name and tags")
    }),

    unit.it(
      "suite.new with ContextFromSetup runs the setup once and the teardown",
      fn() {
        let calls = process.new_subject()
        suite.new(
          name: "setup",
          tags: [],
          tests: [
            unit_context.it("first gets 7", is_seven),
            unit_context.it("second gets 7", is_seven),
          ],
          context: ContextFromSetup(
            setup: fn() { setup_seven(calls) },
            teardown: fn(value) { teardown(calls, value) },
          ),
        )
        |> run_all
        |> fn(results) { #(results, received(calls, [])) }
        |> should
        |> be_equal(
          #(
            [
              #(["setup", "first gets 7"], Passed),
              #(["setup", "second gets 7"], Passed),
            ],
            ["setup", "teardown 7"],
          ),
        )
        |> or_fail_with("the setup should run once, then the teardown")
      },
    ),

    unit.it("a body that returns AssertionPending is Pending", fn() {
      unit.describe("skeleton", [unit.it("later", pending_body)])
      |> run_all
      |> should
      |> be_equal([#(["skeleton", "later"], Pending)])
      |> or_fail_with("AssertionPending should give the status Pending")
    }),

    unit.it("suite.run runs a suite with a RunInput", fn() {
      let ran =
        suite.run(
          suite.new(
            name: "fixed",
            tags: [],
            tests: [unit_context.it("gets 7", is_seven)],
            context: FixedContext(7),
          ),
          suite.RunInput(
            config: parallel.default_config(),
            keep: None,
            progress_reporter: None,
            write: ignore,
            total: 1,
            completed: 0,
            before_each_test: [],
            after_each_test: [],
            outer_setups: [],
          ),
        )
      #(list.map(ran.results, full_name_and_status), ran.completed)
      |> should
      |> be_equal(#([#(["fixed", "gets 7"], Passed)], 1))
      |> or_fail_with("suite.run should give the result and the new count")
    }),

    unit.it("parallel.run_tree runs a tree inside its groups", fn() {
      let names = process.new_subject()
      let ran =
        parallel.run_tree(
          parallel.RunTreeConfig(
            config: parallel.default_config(),
            groups: ["all"],
            name: "suite",
            tags: [],
            tests: [unit.it("passes", passes)],
            context: FixedContext(Nil),
            progress_reporter: None,
            write: ignore,
            total: 1,
            completed: 0,
            runner_before_each_test: [fn(info) { send_name(names, info) }],
            runner_after_each_test: [],
            outer_setups: [],
          ),
        )
      #(
        list.map(ran.results, full_name_and_status),
        ran.completed,
        process.receive(names, 0),
      )
      |> should
      |> be_equal(#(
        [#(["all", "suite", "passes"], Passed)],
        1,
        Ok(["all", "suite", "passes"]),
      ))
      |> or_fail_with("run_tree should put the tree inside its groups")
    }),
  ])
}

fn is_seven(value: Int) -> Result(AssertionResult, String) {
  value
  |> should
  |> be_equal(7)
  |> or_fail_with("the context should be 7")
}

fn setup_seven(calls: Subject(String)) -> Result(Int, String) {
  process.send(calls, "setup")
  Ok(7)
}

fn teardown(calls: Subject(String), value: Int) -> Result(Nil, String) {
  process.send(calls, "teardown " <> int.to_string(value))
  Ok(Nil)
}

fn pending_body() -> Result(AssertionResult, String) {
  Ok(AssertionPending)
}

fn passes() -> Result(AssertionResult, String) {
  Ok(succeed())
}

fn send_name(
  names: Subject(List(String)),
  info: TestInfo,
) -> Result(Nil, String) {
  process.send(names, types.full_name(info.groups, info.name))
  Ok(Nil)
}

fn received(
  calls: Subject(String),
  received_rev: List(String),
) -> List(String) {
  case process.receive(calls, 0) {
    Ok(call) -> received(calls, [call, ..received_rev])
    Error(Nil) -> list.reverse(received_rev)
  }
}

fn run_all(made: suite.TestSuite) -> List(#(List(String), Status)) {
  runner.new([made])
  |> runner.silent()
  |> runner.run()
  |> types.report_tests
  |> list.map(full_name_and_status)
}

fn full_name_and_status(result: TestResult) -> #(List(String), Status) {
  #(types.full_name(result.groups, result.name), result.status)
}

fn test_tags(info: TestInfo) -> List(String) {
  info.tags
}

fn ignore(_text: String) -> Nil {
  Nil
}
