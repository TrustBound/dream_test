import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/progress
import dream_test/reporters/types as reporter_types
import dream_test/types
import dream_test/unit.{describe, group, it}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

@external(erlang, "dream_test_reporter_test_ffi", "with_terminal_columns")
fn with_terminal_columns(columns: Int, function: fn() -> a) -> a

@external(erlang, "dream_test_reporter_test_ffi", "without_terminal")
fn without_terminal(function: fn() -> a) -> a

@external(erlang, "dream_test_reporter_test_ffi", "with_columns_variable")
fn with_columns_variable(value: Option(String), function: fn() -> a) -> a

fn passed(full_name: List(String)) -> types.TestResult {
  types.TestResult(
    name: "fallback",
    full_name: full_name,
    status: types.Passed,
    duration_ms: 0,
    tags: [],
    failures: [],
    kind: types.Unit,
  )
}

fn run_started_line() -> Option(String) {
  progress.handle_event(progress.new(), reporter_types.RunStarted(total: 4))
}

fn line_width(line: Option(String)) -> Int {
  case line {
    Some(text) -> string.length(text) - 1
    None -> -1
  }
}

pub fn tests() {
  describe("dream_test/reporters/progress", [
    it("render produces a line containing counts", fn() {
      let result =
        types.TestResult(
          name: "t",
          full_name: ["suite", "t"],
          status: types.Passed,
          duration_ms: 1,
          tags: [],
          failures: [],
          kind: types.Unit,
        )

      let line =
        progress.render(
          30,
          reporter_types.TestFinished(completed: 1, total: 2, result: result),
        )

      case string.contains(line, "1/2") {
        True -> Ok(types.AssertionOk)
        False ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "progress.render",
              message: "expected progress line to include 1/2",
              payload: None,
            )),
          )
      }
    }),

    it(
      "handle_event does not crash for RunStarted/TestFinished/RunFinished",
      fn() {
        let reporter = progress.new()
        let _ =
          progress.handle_event(reporter, reporter_types.RunStarted(total: 2))
        let result =
          types.TestResult(
            name: "t",
            full_name: ["suite", "t"],
            status: types.Passed,
            duration_ms: 1,
            tags: [],
            failures: [],
            kind: types.Unit,
          )
        let _ =
          progress.handle_event(
            reporter,
            reporter_types.TestFinished(completed: 1, total: 2, result: result),
          )
        let _ =
          progress.handle_event(
            reporter,
            reporter_types.RunFinished(completed: 2, total: 2, results: []),
          )
        Ok(types.AssertionOk)
      },
    ),

    group("render", [
      it("gives the label parent › leaf for a deep test", fn() {
        progress.render(
          40,
          reporter_types.TestFinished(
            completed: 1,
            total: 2,
            result: passed(["root", "group", "leaf"]),
          ),
        )
        |> should
        |> be_equal("1/2 [████████░░░░░░░░] 50% group › leaf ")
        |> or_fail_with("the label should be the parent and the leaf")
      }),

      it("gives the leaf alone for a test with one name", fn() {
        progress.render(
          40,
          reporter_types.TestFinished(
            completed: 1,
            total: 2,
            result: passed(["leaf"]),
          ),
        )
        |> should
        |> be_equal("1/2 [████████████░░░░░░░░░░░░] 50% leaf ")
        |> or_fail_with("the label should be the leaf")
      }),

      it("gives the test name for a test with no full name", fn() {
        progress.render(
          40,
          reporter_types.TestFinished(
            completed: 1,
            total: 2,
            result: passed([]),
          ),
        )
        |> should
        |> be_equal("1/2 [██████████░░░░░░░░░░] 50% fallback ")
        |> or_fail_with("the label should be the name of the test")
      }),

      it("uses 20 columns when it gets fewer", fn() {
        progress.render(5, reporter_types.RunStarted(total: 2))
        |> should
        |> be_equal("0/2 [░░░░░░░░░░] 0% ")
        |> or_fail_with("the line should be 20 columns wide")
      }),

      it("shows a total of 0 as 0/1", fn() {
        progress.render(30, reporter_types.RunStarted(total: 0))
        |> should
        |> be_equal("0/1 [░░░░░░░░░░░░░░░░░░░░] 0% ")
        |> or_fail_with("a total of 0 should show as 0/1")
      }),

      it("shows no more completed tests than the total", fn() {
        progress.render(
          30,
          reporter_types.RunFinished(completed: 5, total: 2, results: []),
        )
        |> should
        |> be_equal("2/2 [█████████████] 100% done ")
        |> or_fail_with("the completed count should stop at the total")
      }),

      it("cuts a long label at the line width", fn() {
        progress.render(
          20,
          reporter_types.TestFinished(
            completed: 1,
            total: 1,
            result: passed(["a very long group name", "a very long test name"]),
          ),
        )
        |> should
        |> be_equal("1/1 [██████████] 100")
        |> or_fail_with("the line should stop at 20 columns")
      }),

      it("gives an empty bar for a hook event", fn() {
        progress.render(
          30,
          reporter_types.HookStarted(
            kind: reporter_types.BeforeAll,
            scope: ["root"],
            test_name: None,
          ),
        )
        |> should
        |> be_equal("0/1 [░░░░░░░░░░░░░░░░░░░░] 0% ")
        |> or_fail_with("a hook event should give an empty bar")
      }),
    ]),

    group("handle_event", [
      it("gives no line for a hook start", fn() {
        progress.handle_event(
          progress.new(),
          reporter_types.HookStarted(
            kind: reporter_types.BeforeEach,
            scope: ["root"],
            test_name: Some("test"),
          ),
        )
        |> should
        |> be_equal(None)
        |> or_fail_with("a hook start should write nothing")
      }),

      it("gives no line for a hook end", fn() {
        progress.handle_event(
          progress.new(),
          reporter_types.HookFinished(
            kind: reporter_types.AfterEach,
            scope: ["root"],
            test_name: Some("test"),
            outcome: reporter_types.HookOk,
          ),
        )
        |> should
        |> be_equal(None)
        |> or_fail_with("a hook end should write nothing")
      }),

      it("starts a test line with a carriage return", fn() {
        with_terminal_columns(30, fn() {
          progress.handle_event(
            progress.new(),
            reporter_types.TestFinished(
              completed: 1,
              total: 2,
              result: passed(["root", "test"]),
            ),
          )
        })
        |> should
        |> be_equal(Some("\r1/2 [█████░░░░░] 50% root › te"))
        |> or_fail_with("a test line should start with a carriage return")
      }),

      it("ends the last line with a new line", fn() {
        with_terminal_columns(30, fn() {
          progress.handle_event(
            progress.new(),
            reporter_types.RunFinished(completed: 2, total: 2, results: []),
          )
        })
        |> should
        |> be_equal(Some("\r2/2 [█████████████] 100% done \n"))
        |> or_fail_with("the last line should end with a new line")
      }),

      it("gets the line width from the terminal", fn() {
        with_terminal_columns(50, run_started_line)
        |> line_width
        |> should
        |> be_equal(50)
        |> or_fail_with("the line should be as wide as the terminal")
      }),

      it("gets the line width from COLUMNS without a terminal", fn() {
        // All the COLUMNS cases are in one test, because the environment
        // belongs to the whole node and tests run at the same time.
        without_terminal(fn() {
          [Some("60"), Some("60 wide"), Some("0"), Some("wide"), None]
          |> list.map(fn(value) {
            with_columns_variable(value, run_started_line)
            |> line_width
          })
        })
        |> should
        |> be_equal([60, 60, 80, 80, 80])
        |> or_fail_with("COLUMNS should set the width, with 80 as the default")
      }),
    ]),
  ])
}
