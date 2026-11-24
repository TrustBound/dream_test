import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/parallel
import dream_test/runner
import dream_test/suite
import dream_test/types.{type Status, type TestInfo, type TestResult, Passed}
import dream_test/unit.{describe, it}
import dream_test/unit_context
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{None, Some}

pub fn tests() {
  describe("dream_test/suite", [
    it("from_tree makes a suite with the name and tests of the tree", fn() {
      let made = number_suite()
      #(suite.name(made), list.map(suite.tests(made), full_name))
      |> should
      |> be_equal(#("number", [["number", "gets 41"]]))
      |> or_fail_with("the suite should hold the tree")
    }),

    it("from_tree gives each test the initial value of the tree", fn() {
      run_all([number_suite()])
      |> should
      |> be_equal([#(["number", "gets 41"], Passed)])
      |> or_fail_with("the test should get 41")
    }),

    it("group puts each suite in a group with its own context", fn() {
      let grouped =
        suite.group(name: "all", suites: [plain_suite(), number_suite()])
      #(suite.name(grouped), run_all([grouped]))
      |> should
      |> be_equal(
        #("all", [
          #(["all", "plain", "passes"], Passed),
          #(["all", "number", "gets 41"], Passed),
        ]),
      )
      |> or_fail_with("each suite should run inside the group")
    }),

    it("group gives the group name to the runner hooks", fn() {
      let names = process.new_subject()
      runner.new([
        suite.group(name: "all", suites: [plain_suite(), number_suite()]),
      ])
      |> runner.max_concurrency(1)
      |> runner.before_each_test(fn(info) { send_name(names, info) })
      |> runner.silent()
      |> runner.run()
      receive_all(names, [])
      |> should
      |> be_equal([["all", "plain", "passes"], ["all", "number", "gets 41"]])
      |> or_fail_with("the hook should see the group name")
    }),

    it("join keeps the groups of each test in one suite", fn() {
      let suite_names = process.new_subject()
      let joined =
        suite.join(name: "checkout", suites: [plain_suite(), number_suite()])
      let results =
        runner.new([joined])
        |> runner.before_each_suite(fn(info) {
          send_suite_name(suite_names, info)
        })
        |> runner.silent()
        |> runner.run()
        |> types.report_tests
        |> list.map(full_name_and_status)
      #(suite.name(joined), results, receive_all(suite_names, []))
      |> should
      |> be_equal(
        #(
          "checkout",
          [#(["plain", "passes"], Passed), #(["number", "gets 41"], Passed)],
          [["checkout"]],
        ),
      )
      |> or_fail_with("join should make one suite with the same tests")
    }),

    it("with_source gives each test the source", fn() {
      suite.group(name: "all", suites: [plain_suite(), number_suite()])
      |> suite.with_source(source: "module_test")
      |> suite.tests
      |> list.map(source)
      |> should
      |> be_equal([Some("module_test"), Some("module_test")])
      |> or_fail_with("each test should have the source")
    }),

    it("with_source keeps a source that a test already has", fn() {
      let sourced =
        suite.with_source(suite: feature_file_suite(), source: "module_test")
      let ran =
        runner.new([sourced])
        |> runner.filter_tests(has_source(_, "cart.feature"))
        |> runner.silent()
        |> runner.run()
        |> types.report_tests
        |> list.map(full_name_and_status)
      #(list.map(suite.tests(sourced), source), ran)
      |> should
      |> be_equal(
        #([Some("cart.feature"), Some("module_test")], [
          #(["cart", "from the file"], Passed),
        ]),
      )
      |> or_fail_with("only a test with no source should get the new source")
    }),

    it("with_source keeps the source of an earlier with_source", fn() {
      plain_suite()
      |> suite.with_source(source: "custom")
      |> suite.with_source(source: "module_test")
      |> suite.tests
      |> list.map(source)
      |> should
      |> be_equal([Some("custom")])
      |> or_fail_with("the first source should stay")
    }),

    it("a filter that keeps no test of a tree does not run the tree", fn() {
      let events = process.new_subject()
      let results =
        runner.new([
          suite.group(name: "all", suites: [
            hooked_suite("first", events),
            hooked_suite("second", events),
          ]),
        ])
        |> runner.filter_tests(is_named(_, "second test"))
        |> runner.silent()
        |> runner.run()
        |> types.report_tests
        |> list.map(full_name_and_status)
      #(results, receive_all(events, []))
      |> should
      |> be_equal(
        #([#(["all", "second", "second test"], Passed)], [["second"]]),
      )
      |> or_fail_with("only the tree with a kept test should run")
    }),

    it("run runs each tree of the suite", fn() {
      suite.run(
        suite.group(name: "all", suites: [plain_suite(), number_suite()]),
        suite.RunInput(
          config: parallel.default_config(),
          keep: None,
          progress_reporter: None,
          write: ignore,
          total: 2,
          completed: 0,
          before_each_test: [],
          after_each_test: [],
          outer_setups: [],
        ),
      )
      |> run_summary
      |> should
      |> be_equal(#(
        [
          #(["all", "plain", "passes"], Passed),
          #(["all", "number", "gets 41"], Passed),
        ],
        2,
      ))
      |> or_fail_with("run should give the results and the new count")
    }),
  ])
}

fn plain_suite() {
  describe("plain", [it("passes", fn() { Ok(succeed()) })])
}

fn number_suite() {
  suite.from_tree(
    types.tree("number", 41, [unit_context.it("gets 41", check_number)]),
  )
}

fn check_number(number: Int) {
  number
  |> should
  |> be_equal(41)
  |> or_fail_with("the test should get 41")
}

/// A suite whose `before_all` hook sends its name to `events`.
fn hooked_suite(name: String, events: Subject(List(String))) {
  describe(name, [
    unit.before_all(fn() { send_list(events, [name]) }),
    it(name <> " test", fn() { Ok(succeed()) }),
  ])
}

fn send_list(events: Subject(List(String)), names: List(String)) {
  process.send(events, names)
  Ok(Nil)
}

fn is_named(info: TestInfo, name: String) -> Bool {
  info.name == name
}

fn run_all(suites: List(suite.TestSuite)) -> List(#(List(String), Status)) {
  runner.new(suites)
  |> runner.silent()
  |> runner.run()
  |> types.report_tests
  |> list.map(full_name_and_status)
}

fn run_summary(
  ran: parallel.RunTreeParallelWithReporterResult,
) -> #(List(#(List(String), Status)), Int) {
  #(list.map(ran.results, full_name_and_status), ran.completed)
}

fn full_name(info: TestInfo) -> List(String) {
  types.full_name(info.groups, info.name)
}

fn source(info: TestInfo) -> option.Option(String) {
  info.source
}

fn full_name_and_status(result: TestResult) -> #(List(String), Status) {
  #(types.full_name(result.groups, result.name), result.status)
}

fn send_name(names: Subject(List(String)), info: TestInfo) {
  send_list(names, full_name(info))
}

fn send_suite_name(names: Subject(List(String)), info: types.SuiteInfo) {
  send_list(names, [info.name])
}

fn receive_all(
  subject: Subject(List(String)),
  received_rev: List(List(String)),
) -> List(List(String)) {
  case process.receive(subject, 0) {
    Ok(item) -> receive_all(subject, [item, ..received_rev])
    Error(Nil) -> list.reverse(received_rev)
  }
}

fn ignore(_text: String) -> Nil {
  Nil
}

/// A suite with one test that has the source `cart.feature` and one test
/// with no source.
fn feature_file_suite() -> suite.TestSuite {
  suite.from_tree(
    types.tree(name: "cart", initial: Nil, tests: [
      types.Test(
        name: "from the file",
        tags: [],
        kind: types.Unit,
        run: types.NoInput(fn() { Ok(types.AssertionOk) }),
        timeout_ms: None,
        source: Some("cart.feature"),
      ),
      types.Test(
        name: "with no file",
        tags: [],
        kind: types.Unit,
        run: types.NoInput(fn() { Ok(types.AssertionOk) }),
        timeout_ms: None,
        source: None,
      ),
    ]),
  )
}

fn has_source(info: TestInfo, path: String) -> Bool {
  info.source == Some(path)
}
