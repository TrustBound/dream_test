//// Tests of `--only`: the paths on the command line, the tests that they
//// select, the error of a wrong path, and the `Run it alone` line of the
//// reporters.

import dream_test/child_timeout.{with_child_timeout}
import dream_test/file
import dream_test/internal/only.{OnlyPath}
import dream_test/matchers.{be_equal, contain_string, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/gherkin
import dream_test/reporters/json
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/types.{AssertionOk}
import dream_test/unit.{
  after_all, after_each, before_all, before_each, describe, group, it, with_tags,
}
import fixtures/test_results.{report_of}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{None, Some}
import gleam/result

@external(erlang, "dream_test_coverage_test_ffi", "run_measured_main_with_arguments_in_new_vm")
fn run_main_with_arguments(
  module: String,
  function: String,
  arguments: List(String),
) -> #(Int, String)

const bergen = "Forecast/gives the forecast for Bergen"

fn forecast_tests() {
  describe("Forecast", [
    it("gives the forecast for Bergen", fn() { Ok(AssertionOk) }),
    it("gives the forecast for Oslo", fn() { Ok(AssertionOk) }),
    group("alerts", [
      it("warns about wind", fn() { Ok(AssertionOk) })
        |> with_tags(["smoke"]),
      it("warns about rain", fn() { Ok(AssertionOk) }),
    ]),
  ])
}

fn tasks_tests() {
  describe("Tasks", [it("adds a task", fn() { Ok(AssertionOk) })])
}

/// The paths of the tests that ran with these arguments.
fn paths_that_ran(
  builder: runner.RunBuilder,
  arguments: List(String),
) -> List(String) {
  builder
  |> runner.with_arguments(arguments)
  |> runner.silent()
  |> runner.run()
  |> types.report_tests
  |> list.map(path_of_result)
}

fn path_of_result(result: types.TestResult) -> String {
  only.path(types.full_name(result.groups, result.name))
}

fn full_config() -> reporter_types.BddReporterConfig {
  reporter_types.BddReporterConfig(color: False, mode: reporter_types.BddFull)
}

fn smoke_only(info: runner.TestInfo) -> Bool {
  list.contains(info.tags, "smoke")
}

fn failed_result(
  groups: List(String),
  name: String,
  failure: types.AssertionFailure,
  kind: types.TestKind,
) -> types.TestResult {
  types.TestResult(
    name: name,
    groups: groups,
    status: types.Failed,
    duration_ms: 0,
    tags: [],
    failures: [failure],
    kind: kind,
  )
}

fn bergen_failure() -> types.TestResult {
  failed_result(
    ["Forecast"],
    "gives the forecast for Bergen",
    types.AssertionFailure(
      operator: "be_ok",
      message: "Bergen should have a forecast",
      payload: None,
    ),
    types.Unit,
  )
}

fn cart_scenario_failure() -> types.TestResult {
  failed_result(
    ["Shopping cart"],
    "adds an item",
    types.AssertionFailure(
      operator: "step",
      message: "expected 2 items",
      payload: Some(types.StepFailure(
        keyword: "Then",
        text: "the cart has 2 items",
        file: None,
        line: Some(7),
        cause: None,
      )),
    ),
    types.GherkinScenario(
      scenario_id: "cart#1",
      feature: Some("Shopping cart"),
      rule: None,
    ),
  )
}

const bergen_failure_text =
  "Forecast
  ✗ gives the forecast for Bergen
    be_ok
      Message: Bergen should have a forecast
    Run it alone: gleam test -- --only \"Forecast/gives the forecast for Bergen\"
"

const cart_failure_text =
  "Feature: Shopping cart
  ✗ Scenario: adds an item
    step
      Step: Then the cart has 2 items (line 7)
      Message: expected 2 items
    Run it alone: gleam test -- --only \"Shopping cart/adds an item\"
"

pub fn tests() {
  describe("--only", [
    group("the command line", [
      it("has no path when it has no --only", fn() {
        only.parse_arguments([])
        |> should
        |> be_equal(Ok([]))
        |> or_fail_with("no argument should select every test")
      }),
      it("reads one path", fn() {
        only.parse_arguments(["--only", bergen])
        |> should
        |> be_equal(
          Ok([
            OnlyPath(text: bergen, names: [
              "Forecast",
              "gives the forecast for Bergen",
            ]),
          ]),
        )
        |> or_fail_with("one --only should give one path")
      }),
      it("reads each --only, and ignores other arguments", fn() {
        only.parse_arguments([
          "--verbose",
          "--only",
          "Forecast",
          "--only",
          "Tasks/adds a task",
        ])
        |> should
        |> be_equal(
          Ok([
            OnlyPath(text: "Forecast", names: ["Forecast"]),
            OnlyPath(text: "Tasks/adds a task", names: ["Tasks", "adds a task"]),
          ]),
        )
        |> or_fail_with("each --only should give a path, in order")
      }),
      it("reads \\/ as a / and \\\\ as a \\ in a name", fn() {
        only.parse_arguments(["--only", "Math/1 \\/ 2 is a half/a\\\\b"])
        |> should
        |> be_equal(
          Ok([
            OnlyPath(text: "Math/1 \\/ 2 is a half/a\\\\b", names: [
              "Math",
              "1 / 2 is a half",
              "a\\b",
            ]),
          ]),
        )
        |> or_fail_with("the escapes should be part of the names")
      }),
      it("gives an error for an empty path", fn() {
        only.parse_arguments(["--only", ""])
        |> should
        |> be_equal(Error(
          "\n--only needs a path\n"
          <> "  The path after --only is empty.\n"
          <> "  Fix: put the path of a test, a group or a suite after --only, for example: gleam test -- --only \"Suite/group/test\"\n\n",
        ))
        |> or_fail_with("an empty path should be an error")
      }),
      it("gives an error for --only at the end", fn() {
        only.parse_arguments(["--only"])
        |> should
        |> be_equal(Error(
          "\n--only needs a path\n"
          <> "  The command line ends after --only.\n"
          <> "  Fix: put the path of a test, a group or a suite after --only, for example: gleam test -- --only \"Suite/group/test\"\n\n",
        ))
        |> or_fail_with("--only with no path should be an error")
      }),
      it("gives an error for a \\ before another character", fn() {
        only.parse_arguments(["--only", "Math/a\\b"])
        |> should
        |> be_equal(Error(
          "\n--only path is not correct: 'Math/a\\b'\n"
          <> "  Reason: a \\ in a path must come before a / or a \\.\n"
          <> "  Fix: write a / in a name as \\/, and a \\ in a name as \\\\.\n\n",
        ))
        |> or_fail_with("an unknown escape should be an error")
      }),
    ]),
    group("the printed command", [
      it("escapes \\ and / in each name", fn() {
        only.path(["Math", "1 / 2", "a\\b"])
        |> should
        |> be_equal("Math/1 \\/ 2/a\\\\b")
        |> or_fail_with("the path should escape the names")
      }),
      it("puts a plain path in double quotes", fn() {
        only.command(["Forecast", "gives the forecast for Bergen"])
        |> should
        |> be_equal(
          "gleam test -- --only \"Forecast/gives the forecast for Bergen\"",
        )
        |> or_fail_with("a plain path should be in double quotes")
      }),
      it("keeps a ' in double quotes", fn() {
        only.shell_quote("Cart/it's empty")
        |> should
        |> be_equal("\"Cart/it's empty\"")
        |> or_fail_with("a ' is safe in double quotes")
      }),
      it("puts a path with \" $ ` \\ or ! in single quotes", fn() {
        [
          "say \"hi\"",
          "costs $5",
          "runs `ls`",
          "1 \\/ 2",
          "wow!",
        ]
        |> list.map(only.shell_quote)
        |> should
        |> be_equal([
          "'say \"hi\"'",
          "'costs $5'",
          "'runs `ls`'",
          "'1 \\/ 2'",
          "'wow!'",
        ])
        |> or_fail_with("these characters need single quotes")
      }),
      it("writes a ' in single quotes as '\\''", fn() {
        only.command(["Cart", "it's $5"])
        |> should
        |> be_equal("gleam test -- --only 'Cart/it'\\''s $5'")
        |> or_fail_with("a ' should end and start the single quotes")
      }),
    ]),
    group("the selection", [
      it("runs only the test of a test path", fn() {
        runner.new([forecast_tests(), tasks_tests()])
        |> paths_that_ran(["--only", bergen])
        |> should
        |> be_equal([bergen])
        |> or_fail_with("only the Bergen test should run")
      }),
      it("runs each test of a group path", fn() {
        runner.new([forecast_tests(), tasks_tests()])
        |> paths_that_ran(["--only", "Forecast/alerts"])
        |> should
        |> be_equal([
          "Forecast/alerts/warns about wind",
          "Forecast/alerts/warns about rain",
        ])
        |> or_fail_with("the tests of the group should run")
      }),
      it("runs each test of a suite path", fn() {
        runner.new([tasks_tests(), forecast_tests()])
        |> paths_that_ran(["--only", "Tasks"])
        |> should
        |> be_equal(["Tasks/adds a task"])
        |> or_fail_with("the tests of the suite should run")
      }),
      it("runs the tests of each path", fn() {
        runner.new([forecast_tests(), tasks_tests()])
        |> paths_that_ran(["--only", "Tasks", "--only", bergen])
        |> should
        |> be_equal([bergen, "Tasks/adds a task"])
        |> or_fail_with("the tests of both paths should run")
      }),
      it("runs only the tests that filter_tests keeps too", fn() {
        runner.new([forecast_tests(), tasks_tests()])
        |> runner.filter_tests(smoke_only)
        |> paths_that_ran(["--only", "Forecast/alerts"])
        |> should
        |> be_equal(["Forecast/alerts/warns about wind"])
        |> or_fail_with("the path and the filter should both select")
      }),
      it("runs the hooks of the suite and the group of the test", fn() {
        let events = process.new_subject()
        let suite =
          describe("Forecast", [
            before_all(fn() { record(events, "suite before_all") }),
            after_all(fn() { record(events, "suite after_all") }),
            group("alerts", [
              before_all(fn() { record(events, "group before_all") }),
              before_each(fn() { record(events, "before_each") }),
              after_each(fn() { record(events, "after_each") }),
              after_all(fn() { record(events, "group after_all") }),
              it("warns about wind", fn() { Ok(AssertionOk) }),
              it("warns about rain", fn() { Ok(AssertionOk) }),
            ]),
          ])

        let ran =
          runner.new([suite])
          |> paths_that_ran(["--only", "Forecast/alerts/warns about wind"])

        #(ran, received(events))
        |> should
        |> be_equal(
          #(["Forecast/alerts/warns about wind"], [
            "suite before_all",
            "group before_all",
            "before_each",
            "after_each",
            "group after_all",
            "suite after_all",
          ]),
        )
        |> or_fail_with("each hook around the test should run one time")
      }),
    ]),
    group("a path that selects no test", [
      it("gives the error that the runner guide shows", fn() {
        let error =
          only.check_paths(
            [
              OnlyPath(text: "Forecast/gives the forecast for Olso", names: [
                "Forecast",
                "gives the forecast for Olso",
              ]),
            ],
            [
              ["Forecast", "gives the forecast for Oslo"],
              ["Forecast", "gives the forecast for Lisbon"],
              ["Forecast", "reports a city that the API does not know"],
              ["Alert feed", "reads the message of each alert"],
              ["Tasks", "lists a new task as open"],
              ["Tasks", "completes tasks in one transaction"],
              ["Tasks", "rolls back when one task does not exist"],
              ["Tasks", "gives the share token of a task"],
            ],
          )
        let shown =
          file.read("test/fixtures/only_unknown_path.txt")
          |> result.map_error(file.error_to_string)

        #(error, shown)
        |> should
        |> be_equal(#(Error("\n" <> result.unwrap(shown, "") <> "\n"), shown))
        |> or_fail_with("the error should be the text in the runner guide")
      }),
      it("gives the error of the command line before any check", fn() {
        only.checked_paths(["--only"], [
          ["Forecast", "gives the forecast for Bergen"],
        ])
        |> should
        |> be_equal(Error(
          "\n--only needs a path\n"
          <> "  The command line ends after --only.\n"
          <> "  Fix: put the path of a test, a group or a suite after --only, for example: gleam test -- --only \"Suite/group/test\"\n\n",
        ))
        |> or_fail_with("a wrong command line should be an error")
      }),
      it("is an error that shows the closest paths", fn() {
        only.check_paths(
          [
            OnlyPath(text: "Forecast/gives the forcast for Bergen", names: [
              "Forecast",
              "gives the forcast for Bergen",
            ]),
          ],
          [
            ["Forecast", "gives the forecast for Bergen"],
            ["Forecast", "gives the forecast for Oslo"],
            ["Tasks", "adds a task"],
          ],
        )
        |> should
        |> be_equal(Error(
          "\nNo test has the --only path \"Forecast/gives the forcast for Bergen\"\n"
          <> "  Closest paths:\n"
          <> "    gleam test -- --only \"Forecast/gives the forecast for Bergen\"\n"
          <> "    gleam test -- --only \"Forecast/gives the forecast for Oslo\"\n"
          <> "    gleam test -- --only \"Forecast\"\n"
          <> "  Fix: use the full path: the suite name, the group names and the test name, joined with /. Write a / in a name as \\/.\n\n",
        ))
        |> or_fail_with("the error should list the three closest paths")
      }),
      it("is an error that says the run has no tests", fn() {
        only.check_paths([OnlyPath(text: "Forecast", names: ["Forecast"])], [])
        |> should
        |> be_equal(Error(
          "\nNo test has the --only path \"Forecast\"\n"
          <> "  The run has no tests.\n"
          <> "  Fix: use the full path: the suite name, the group names and the test name, joined with /. Write a / in a name as \\/.\n\n",
        ))
        |> or_fail_with("the error should say that there is no test")
      }),
    ]),
    group("the reporters", [
      it(
        "bdd prints the command under a failed unit test and in Failures",
        fn() {
          bdd.render(full_config(), report_of([bergen_failure()]))
          |> should
          |> be_equal(
            bergen_failure_text
            <> "\nFailures:\n"
            <> bergen_failure_text
            <> "\nSummary: 1 run, 1 failed, 0 passed in 0ms\n",
          )
          |> or_fail_with("the command should be under the failure, two times")
        },
      ),
      it("bdd prints the command under a failed scenario", fn() {
        bdd.render(full_config(), report_of([cart_scenario_failure()]))
        |> should
        |> be_equal(
          cart_failure_text
          <> "\nFailures:\n"
          <> cart_failure_text
          <> "\nSummary: 1 run, 1 failed, 0 passed in 0ms\n",
        )
        |> or_fail_with("the scenario path is the feature and scenario names")
      }),
      it(
        "the Gherkin reporter prints the command under a failed scenario",
        fn() {
          gherkin.format(report_of([cart_scenario_failure()]))
          |> should
          |> be_equal(
            "Feature: Shopping cart\n"
            <> "  Scenario: adds an item ✗\n"
            <> "      ✗ step\n"
            <> "        Step: Then the cart has 2 items (line 7)\n"
            <> "        Message: expected 2 items\n"
            <> "      Run it alone: gleam test -- --only \"Shopping cart/adds an item\"\n"
            <> "\nSummary: 1 run, 1 failed, 0 passed in 0ms\n",
          )
          |> or_fail_with("the Gherkin report should show the command")
        },
      ),
      it("JSON has the path and the command of each test", fn() {
        json.format(report_of([bergen_failure()]))
        |> should
        |> contain_string(
          "\"full_name\":[\"Forecast\",\"gives the forecast for Bergen\"],"
          <> "\"only_path\":\"Forecast/gives the forecast for Bergen\","
          <> "\"run_alone\":\"gleam test -- --only \\\"Forecast/gives the forecast for Bergen\\\"\",",
        )
        |> or_fail_with("JSON should have only_path and run_alone")
      }),
    ]),
    group("the real command line", [
      it("runs only the test of the path", fn() {
        run_main_with_arguments("dream_test@only_mains", "forecast_run", [
          "--only",
          bergen,
        ])
        |> should
        |> be_equal(#(0, "ran: Forecast/gives the forecast for Bergen\n"))
        |> or_fail_with("only the passing Bergen test should run")
      })
        |> with_child_timeout,
      it("ends the program with status 1 for an unknown path", fn() {
        run_main_with_arguments("dream_test@only_mains", "forecast_run", [
          "--only",
          "Forecast/Bergen",
        ])
        |> should
        |> be_equal(#(
          1,
          "\nNo test has the --only path \"Forecast/Bergen\"\n"
            <> "  Closest paths:\n"
            <> "    gleam test -- --only \"Forecast\"\n"
            <> "    gleam test -- --only \"Forecast/gives the forecast for Bergen\"\n"
            <> "    gleam test -- --only \"Forecast/gives the forecast for Oslo\"\n"
            <> "  Fix: use the full path: the suite name, the group names and the test name, joined with /. Write a / in a name as \\/.\n\n",
        ))
        |> or_fail_with("no test should run, and the error should show")
      })
        |> with_child_timeout,
    ]),
  ])
}

fn record(events: Subject(String), event: String) -> Result(Nil, String) {
  process.send(events, event)
  Ok(Nil)
}

/// Every message in the queue of `subject`, oldest first.
fn received(subject: Subject(String)) -> List(String) {
  received_loop(subject, [])
}

fn received_loop(subject: Subject(String), acc: List(String)) -> List(String) {
  case process.receive(subject, 0) {
    Ok(text) -> received_loop(subject, [text, ..acc])
    Error(Nil) -> list.reverse(acc)
  }
}
