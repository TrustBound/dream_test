//// A Gherkin registry whose scenarios start from the value of a setup:
//// `steps.new_with_setup`.

import dream_test/file
import dream_test/gherkin/discover
import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, type StepRegistry}
import dream_test/gherkin/types as gherkin_types
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{
  type AssertionFailure, type Status, type TestInfo, type TestResult,
  AssertionFailure, Failed, GherkinScenario, Passed, SetupFailed,
}
import dream_test/unit.{describe, it}
import dream_test/unit_context
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/result

pub fn tests() {
  describe("steps.new_with_setup", [
    it("runs the setup once; each scenario starts from its value", fn() {
      let events = process.new_subject()
      let report = run([counter_feature(counter_steps(events, Ok(10)))])
      #(statuses(report), receive_all(events, []))
      |> should
      |> be_equal(
        #(
          [
            #(["Counter", "adds one"], Passed),
            #(["Counter", "adds two"], Passed),
          ],
          ["setup", "teardown got 10"],
        ),
      )
      |> or_fail_with("each scenario should start from 10")
    }),

    it("does not run the setup when no scenario runs", fn() {
      let events = process.new_subject()
      let report =
        runner.new([
          counter_feature(counter_steps(events, Ok(10))),
          describe("plain", [it("passes", fn() { Ok(matchers.succeed()) })]),
        ])
        |> runner.filter_tests(is_unit)
        |> runner.silent()
        |> runner.run()
      #(statuses(report), receive_all(events, []))
      |> should
      |> be_equal(#([#(["plain", "passes"], Passed)], []))
      |> or_fail_with("the setup should not run")
    }),

    it("a setup error gives SetupFailed to each scenario", fn() {
      let events = process.new_subject()
      let report =
        run([counter_feature(counter_steps(events, Error("no counter")))])
      #(failures(report), receive_all(events, []))
      |> should
      |> be_equal(
        #(
          [
            #(["Counter", "adds one"], SetupFailed, [failure("no counter")]),
            #(["Counter", "adds two"], SetupFailed, [failure("no counter")]),
          ],
          ["setup"],
        ),
      )
      |> or_fail_with("no scenario should run and no teardown")
    }),

    it("to_suite gives each test the state of a registry from new", fn() {
      run([
        steps.to_suite(
          registry: steps.new(initial: 7),
          name: "start",
          tags: [],
          children: [steps.Node(unit_context.it("gets 7", is_7))],
        ),
      ])
      |> statuses
      |> should
      |> be_equal([#(["start", "gets 7"], Passed)])
      |> or_fail_with("the test should start from 7")
    }),

    it("to_suite gives each test the value of the setup", fn() {
      let events = process.new_subject()
      let report =
        run([
          steps.to_suite(
            registry: counter_steps(events, Ok(7)),
            name: "start",
            tags: [],
            children: [steps.Node(unit_context.it("gets 7", is_7))],
          ),
        ])
      #(statuses(report), receive_all(events, []))
      |> should
      |> be_equal(
        #([#(["start", "gets 7"], Passed)], ["setup", "teardown got 7"]),
      )
      |> or_fail_with("the test should start from the setup value")
    }),

    it("to_suite runs every kind of child under one setup", fn() {
      // Feature, Scenarios, a Group with a tag that holds a
      // Feature, and Node with a unit_context.it and a
      // before_each. The setup runs one time; before_each runs before each
      // of the four tests. The tests
      // directly in the suite run before the tests of its groups.
      let events = process.new_subject()
      let registry = counter_steps(events, Ok(10))
      let report =
        run([
          steps.to_suite(registry: registry, name: "Shop", tags: [], children: [
            steps.Node(
              unit_context.before_each(fn(value) {
                record_before_each(events, value)
              }),
            ),
            steps.Feature(counter_parsed("Cart")),
            steps.Scenarios(counter_parsed("Stock")),
            steps.Group(name: "Billing", tags: ["billing"], children: [
              steps.Feature(counter_parsed("Invoice")),
            ]),
            steps.Node(unit_context.it("gets 10", is_10)),
          ]),
        ])
      #(
        list.map(types.report_tests(report), full_name_status_and_tags),
        receive_all(events, []),
      )
      |> should
      |> be_equal(
        #(
          [
            #(["Shop", "adds one"], Passed, []),
            #(["Shop", "gets 10"], Passed, []),
            #(["Shop", "Cart", "adds one"], Passed, []),
            #(["Shop", "Billing", "Invoice", "adds one"], Passed, ["billing"]),
          ],
          [
            "setup",
            "before_each",
            "before_each",
            "before_each",
            "before_each",
            "teardown got 10",
          ],
        ),
      )
      |> or_fail_with("one setup should serve every child")
    }),

    it("two registries in two joined suites each set up their own", fn() {
      let cart_events = process.new_subject()
      let stock_events = process.new_subject()
      let report =
        run([
          suite.join(name: "all", suites: [
            steps.to_suite(
              registry: counter_steps(cart_events, Ok(10)),
              name: "Cart suite",
              tags: [],
              children: [steps.Feature(counter_parsed("Cart"))],
            ),
            steps.to_suite(
              registry: counter_steps(stock_events, Ok(10)),
              name: "Stock suite",
              tags: [],
              children: [steps.Feature(counter_parsed("Stock"))],
            ),
          ]),
        ])
      #(
        statuses(report),
        receive_all(cart_events, []),
        receive_all(stock_events, []),
      )
      |> should
      |> be_equal(
        #(
          [
            #(["Cart suite", "Cart", "adds one"], Passed),
            #(["Stock suite", "Stock", "adds one"], Passed),
          ],
          ["setup", "teardown got 10"],
          ["setup", "teardown got 10"],
        ),
      )
      |> or_fail_with("each registry should set up once for its features")
    }),

    it(
      "a Feature whose steps are in another registry has undefined steps",
      fn() {
        // The nearest misuse that compiles: both Features under the registry
        // of the counter. The Feature of the shop uses steps that only another
        // registry has, so its scenario fails; it does not run silently.
        let events = process.new_subject()
        let report =
          run([
            steps.to_suite(
              registry: counter_steps(events, Ok(10)),
              name: "Shop",
              tags: [],
              children: [
                steps.Feature(counter_parsed("Cart")),
                steps.Feature(shop_parsed()),
              ],
            ),
          ])
        list.map(types.report_tests(report), full_name_status_and_messages)
        |> should
        |> be_equal([
          #(["Shop", "Cart", "adds one"], Passed, []),
          #(["Shop", "Shelf", "opens"], Failed, [
            "Undefined step: Given the shop opens",
          ]),
        ])
        |> or_fail_with("a step of another registry should be undefined")
      },
    ),

    it("discover.to_suite runs the setup once for all files", fn() {
      let events = process.new_subject()
      write_counter_file("setup_a")
      write_counter_file("setup_b")
      let report =
        run([
          discover.features("test/tmp/features/setup_[ab].feature")
          |> discover.with_registry(counter_steps(events, Ok(10)))
          |> discover.to_suite("Features"),
        ])
      #(statuses(report), receive_all(events, []))
      |> should
      |> be_equal(
        #(
          [
            #(["Features", "setup_a", "adds one"], Passed),
            #(["Features", "setup_b", "adds one"], Passed),
          ],
          ["setup", "teardown got 10"],
        ),
      )
      |> or_fail_with("one setup should serve both files")
    }),

    it("discover.to_suite runs a parse error test without the setup", fn() {
      let events = process.new_subject()
      write_counter_file("setup_good")
      let _ = file.write("test/tmp/features/setup_bad.feature", "NOT\n")
      let report =
        runner.new([
          discover.features("test/tmp/features/setup_{good,bad}.feature")
          |> discover.with_registry(counter_steps(events, Ok(10)))
          |> discover.to_suite("Features"),
        ])
        |> runner.filter_tests(is_unit)
        |> runner.silent()
        |> runner.run()
      #(list.map(statuses(report), status_of), receive_all(events, []))
      |> should
      |> be_equal(#([Failed], []))
      |> or_fail_with("the parse error should fail without the setup")
    }),
  ])
}

/// A registry whose setup sends `setup` and gives `start`.
fn counter_steps(
  events: Subject(String),
  start: Result(Int, String),
) -> StepRegistry(Int) {
  steps.new_with_setup(
    setup: fn() { send_and_give(events, start) },
    teardown: fn(value: Int) { send_teardown(events, value) },
  )
  |> steps.given("the counter starts", keep)
  |> steps.when("I add {int}", add)
  |> steps.then("the counter is {int}", counter_is)
}

fn counter_feature(registry: StepRegistry(Int)) -> TestSuite {
  feature("Counter", registry, [
    scenario("adds one", [
      given("the counter starts"),
      when("I add 1"),
      then("the counter is 11"),
    ]),
    scenario("adds two", [
      given("the counter starts"),
      when("I add 2"),
      then("the counter is 12"),
    ]),
  ])
}

/// The parsed Feature named `name` with one scenario.
fn counter_parsed(name: String) -> gherkin_types.Feature {
  let assert Ok(parsed) = parser.parse_string(counter_text(name))
  parsed
}

/// A Feature whose step only another registry has.
fn shop_parsed() -> gherkin_types.Feature {
  let assert Ok(parsed) =
    parser.parse_string(
      "Feature: Shelf\nScenario: opens\n  Given the shop opens\n",
    )
  parsed
}

fn record_before_each(
  events: Subject(String),
  value: Int,
) -> Result(Int, String) {
  process.send(events, "before_each")
  Ok(value)
}

fn is_10(value: Int) {
  value
  |> should
  |> be_equal(10)
  |> or_fail_with("the state should be 10")
}

fn full_name_status_and_tags(
  result: TestResult,
) -> #(List(String), Status, List(String)) {
  #(types.full_name(result.groups, result.name), result.status, result.tags)
}

fn full_name_status_and_messages(
  result: TestResult,
) -> #(List(String), Status, List(String)) {
  #(
    types.full_name(result.groups, result.name),
    result.status,
    list.map(result.failures, failure_message),
  )
}

fn failure_message(failure: AssertionFailure) -> String {
  failure.message
}

fn counter_text(name: String) -> String {
  "Feature: "
  <> name
  <> "\nScenario: adds one\n  Given the counter starts\n  When I add 1\n  Then the counter is 11\n"
}

fn write_counter_file(name: String) -> Nil {
  let _ =
    file.write("test/tmp/features/" <> name <> ".feature", counter_text(name))
  Nil
}

fn is_7(value: Int) {
  value
  |> should
  |> be_equal(7)
  |> or_fail_with("the state should be 7")
}

fn keep(value: Int, _context: StepContext) -> Result(Int, String) {
  Ok(value)
}

fn add(value: Int, context: StepContext) -> Result(Int, String) {
  use amount <- result.try(steps.get_int(context.captures, 0))
  Ok(value + amount)
}

fn counter_is(value: Int, context: StepContext) {
  use expected <- result.try(steps.get_int(context.captures, 0))
  value
  |> should
  |> be_equal(expected)
  |> or_fail_with("the counter should match")
}

fn send_and_give(
  events: Subject(String),
  start: Result(Int, String),
) -> Result(Int, String) {
  process.send(events, "setup")
  start
}

fn send_teardown(events: Subject(String), value: Int) -> Result(Nil, String) {
  process.send(events, "teardown got " <> int.to_string(value))
  Ok(Nil)
}

fn is_unit(info: TestInfo) -> Bool {
  case info.kind {
    GherkinScenario(..) -> False
    _ -> True
  }
}

fn run(suites: List(TestSuite)) -> types.RunReport {
  runner.new(suites)
  |> runner.max_concurrency(1)
  |> runner.silent()
  |> runner.run()
}

fn failure(message: String) -> AssertionFailure {
  AssertionFailure(operator: "context setup", message: message, payload: None)
}

fn statuses(report: types.RunReport) -> List(#(List(String), Status)) {
  list.map(types.report_tests(report), full_name_and_status)
}

fn status_of(entry: #(List(String), Status)) -> Status {
  entry.1
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

fn receive_all(
  subject: Subject(String),
  received_rev: List(String),
) -> List(String) {
  case process.receive(subject, 0) {
    Ok(item) -> receive_all(subject, [item, ..received_rev])
    Error(Nil) -> list.reverse(received_rev)
  }
}
