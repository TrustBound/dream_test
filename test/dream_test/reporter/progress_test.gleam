import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/progress
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

fn passed(groups: List(String), name: String) -> types.TestResult {
  types.TestResult(
    name: name,
    groups: groups,
    status: types.Passed,
    duration_ms: 0,
    tags: [],
    failures: [],
    kind: types.Unit,
  )
}

fn run_started_line() -> String {
  progress.line(progress.new(), progress.RunStartedProgress(total: 4))
}

/// The width of a line without its carriage return.
fn line_width(line: String) -> Int {
  string.length(line) - 1
}

pub fn tests() {
  describe("dream_test/reporters/progress", [
    group("render", [
      it("gives the label parent › leaf for a deep test", fn() {
        progress.render(
          40,
          progress.TestFinishedProgress(
            completed: 1,
            total: 2,
            result: passed(["root", "group"], "leaf"),
          ),
        )
        |> should
        |> be_equal("1/2 [████████░░░░░░░░] 50% group › leaf ")
        |> or_fail_with("the label should be the parent and the leaf")
      }),

      it("gives the leaf alone for a test with one name", fn() {
        progress.render(
          40,
          progress.TestFinishedProgress(
            completed: 1,
            total: 2,
            result: passed([], "leaf"),
          ),
        )
        |> should
        |> be_equal("1/2 [████████████░░░░░░░░░░░░] 50% leaf ")
        |> or_fail_with("the label should be the leaf")
      }),

      it("uses 20 columns when it gets fewer", fn() {
        progress.render(5, progress.RunStartedProgress(total: 2))
        |> should
        |> be_equal("0/2 [░░░░░░░░░░] 0% ")
        |> or_fail_with("the line should be 20 columns wide")
      }),

      it("shows a total of 0 as 0/1", fn() {
        progress.render(30, progress.RunStartedProgress(total: 0))
        |> should
        |> be_equal("0/1 [░░░░░░░░░░░░░░░░░░░░] 0% ")
        |> or_fail_with("a total of 0 should show as 0/1")
      }),

      it("shows no more completed tests than the total", fn() {
        progress.render(
          30,
          progress.RunFinishedProgress(
            completed: 5,
            total: 2,
            teardown_failures: 0,
          ),
        )
        |> should
        |> be_equal("2/2 [█████████████] 100% done ")
        |> or_fail_with("the completed count should stop at the total")
      }),

      it("cuts a long label at the line width", fn() {
        progress.render(
          20,
          progress.TestFinishedProgress(
            completed: 1,
            total: 1,
            result: passed(["a very long group name"], "a very long test name"),
          ),
        )
        |> should
        |> be_equal("1/1 [██████████] 100")
        |> or_fail_with("the line should stop at 20 columns")
      }),

      it("counts the tear-down failures on the last line", fn() {
        progress.render(
          50,
          progress.RunFinishedProgress(
            completed: 2,
            total: 2,
            teardown_failures: 1,
          ),
        )
        |> should
        |> be_equal("2/2 [█████████████] 100% done, 1 tear-down failed ")
        |> or_fail_with("the last line should count the tear-down failures")
      }),
    ]),

    group("line", [
      it("gives an empty bar when the run starts", fn() {
        with_terminal_columns(30, fn() {
          progress.line(progress.new(), progress.RunStartedProgress(total: 4))
        })
        |> should
        |> be_equal("\r0/4 [░░░░░░░░░░░░░░░░░░░░] 0% ")
        |> or_fail_with("the first line should show 0 of 4")
      }),

      it("names the test that finished", fn() {
        with_terminal_columns(30, fn() {
          progress.line(
            progress.new(),
            progress.TestFinishedProgress(
              completed: 1,
              total: 2,
              result: passed(["root"], "test"),
            ),
          )
        })
        |> should
        |> be_equal("\r1/2 [█████░░░░░] 50% root › te")
        |> or_fail_with("a test line should name the test")
      }),

      it("ends the last line with a new line", fn() {
        with_terminal_columns(30, fn() {
          progress.line(
            progress.new(),
            progress.RunFinishedProgress(
              completed: 2,
              total: 2,
              teardown_failures: 0,
            ),
          )
        })
        |> should
        |> be_equal("\r2/2 [█████████████] 100% done \n")
        |> or_fail_with("the last line should end with a new line")
      }),

      it("names the tear-down failures on the last line", fn() {
        with_terminal_columns(60, fn() {
          progress.line(
            progress.new(),
            progress.RunFinishedProgress(
              completed: 2,
              total: 2,
              teardown_failures: 1,
            ),
          )
        })
        |> should
        |> be_equal(
          "\r2/2 [███████████████████████] 100% done, 1 tear-down failed \n",
        )
        |> or_fail_with("the last line should count the tear-down failures")
      }),
    ]),

    group("terminal width", [
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
