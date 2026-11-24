//// Live progress bar reporter.
////
//// This module renders a single-line progress bar that updates in-place using
//// carriage returns, and adapts to the current terminal width.
////
//// Because it uses `\r` (carriage return) to rewrite the current line, it is
//// best suited for interactive terminals. In CI logs (or when other output is
//// printed concurrently), the output may be less readable.
////
//// ## Terminal width
////
//// Width is detected via Erlang `io:columns/0` with fallbacks:
////
//// - if `io:columns/0` fails, it reads the `COLUMNS` environment variable
//// - if that is missing/invalid, it defaults to 80 columns
////
//// The runner gives it a `ProgressEvent` at the start of the run, after each
//// test, and at the end of the run. Most users should not call it directly.
//// Attach it with `runner.progress_reporter(progress.new())`.
////
//// ## Example
////
//// ### Show a progress bar during the run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/reporters/progress_reporter.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/matchers.{succeed}
//// import dream_test/reporters/progress
//// import dream_test/runner
//// import dream_test/unit.{describe, it}
////
//// pub fn tests() {
////   describe("Progress reporter", [
////     it("passes", fn() { Ok(succeed()) }),
////     it("also passes", fn() { Ok(succeed()) }),
////   ])
//// }
////
//// pub fn main() {
////   runner.new([tests()])
////   |> runner.progress_reporter(progress.new())
////   |> runner.exit_on_failure()
////   |> runner.run()
//// }
//// ```

import dream_test/types.{type TestResult}
import gleam/int
import gleam/list
import gleam/string

/// A progress-bar reporter that renders a single-line UI during a run.
///
/// Construct one with `progress.new()` and attach it to the runner via
/// `runner.progress_reporter(...)`.
pub opaque type ProgressReporter {
  ProgressReporter
}

/// Create a new progress reporter.
///
/// ## Example
///
/// ### Show a progress bar during the run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/progress/new.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{succeed}
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import dream_test/types.{type RunReport}
/// import dream_test/unit.{describe, it}
///
/// pub fn main() -> RunReport {
///   runner.new([
///     describe("Cart", [
///       it("starts empty", fn() { Ok(succeed()) }),
///       it("adds an item", fn() { Ok(succeed()) }),
///       it("removes an item", fn() { Ok(succeed()) }),
///     ]),
///   ])
///   |> runner.progress_reporter(progress.new())
///   |> runner.run()
/// }
/// ```
pub fn new() -> ProgressReporter {
  ProgressReporter
}

/// The three points of a run that change the progress bar.
///
/// The runner gives one to `progress.line` for each point, and each one
/// gives a line.
///
/// - `RunStartedProgress`: the run starts. `total` is the number of tests.
/// - `TestFinishedProgress`: one more test finished. `completed` counts the
///   finished tests, this one included.
/// - `RunFinishedProgress`: the run finished. `teardown_failed` is the
///   number of teardown hooks that failed, and `setup_stopped` the number
///   of setups whose process stopped while their tests ran.
///
/// ## Example
///
/// ### End the bar when the run finishes <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/progress/progress_event.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/progress
/// import dream_test/types.{type AssertionResult}
/// import gleam/string
///
/// pub fn finished_line_ends_the_bar() -> Result(AssertionResult, String) {
///   progress.line(
///     progress.new(),
///     progress.RunFinishedProgress(
///       completed: 4,
///       total: 4,
///       teardown_failed: 0,
///       setup_stopped: 0,
///     ),
///   )
///   |> string.ends_with("\n")
///   |> should
///   |> be_equal(True)
///   |> or_fail_with("expected the last line to end the bar")
/// }
/// ```
pub type ProgressEvent {
  RunStartedProgress(total: Int)
  TestFinishedProgress(completed: Int, total: Int, result: TestResult)
  RunFinishedProgress(
    completed: Int,
    total: Int,
    teardown_failed: Int,
    setup_stopped: Int,
  )
}

/// The text that updates the progress bar for one point of a run.
///
/// The text starts with a carriage return (`\r`), so it writes over the
/// previous bar. The bar is as wide as the terminal (at least 20 columns).
/// The text for `RunFinishedProgress` ends with a newline.
///
/// ## Parameters
///
/// - `reporter`: the reporter from `progress.new()`
/// - `event`: the point of the run
///
/// ## Returns
///
/// The text to write, without any other change.
///
/// ## Example
///
/// ### Start with an empty bar <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/progress/line.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/progress
/// import dream_test/types.{type AssertionResult}
/// import gleam/string
///
/// pub fn started_line_shows_an_empty_bar() -> Result(AssertionResult, String) {
///   progress.line(progress.new(), progress.RunStartedProgress(total: 4))
///   |> string.starts_with("\r0/4 [")
///   |> should
///   |> be_equal(True)
///   |> or_fail_with("expected an empty bar for 4 tests")
/// }
/// ```
pub fn line(
  reporter reporter: ProgressReporter,
  event event: ProgressEvent,
) -> String {
  let _ = reporter
  let text = "\r" <> render(terminal_columns(), event)
  case event {
    RunFinishedProgress(..) -> text <> "\n"
    RunStartedProgress(..) | TestFinishedProgress(..) -> text
  }
}

/// Render a progress bar line for a given terminal width.
///
/// This is pure and is intended for testing and for custom reporter work.
///
/// Width is measured in **graphemes** (user-visible characters), so Unicode
/// stays aligned. The width is clamped to a minimum of 20 so the bar remains
/// readable.
///
/// Note: The `columns` input is typically a *terminal column count* (from
/// `io:columns/0`), but rendering is done by grapheme count so we can safely
/// pad/truncate Unicode.
///
/// ## Parameters
///
/// - `columns`: terminal width (in columns)
/// - `event`: the point of the run to render
///
/// ## Returns
///
/// A single line of text **exactly** `columns` graphemes wide (after clamping),
/// with no carriage return and no newline. `progress.line` adds them.
///
/// ## Example
///
/// ### Render an empty bar <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/progress/render.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/reporters/progress
/// import dream_test/types.{type AssertionResult}
///
/// pub fn started_render_is_an_empty_bar() -> Result(AssertionResult, String) {
///   progress.render(30, progress.RunStartedProgress(total: 10))
///   |> should
///   |> be_equal("0/10 [░░░░░░░░░░░░░░░░░░░] 0% ")
///   |> or_fail_with("expected an empty bar for 10 tests")
/// }
/// ```
pub fn render(columns columns: Int, event event: ProgressEvent) -> String {
  let width = clamp_min(columns, 20)
  case event {
    RunStartedProgress(total: total) -> render_line(width, 0, total, "")
    TestFinishedProgress(completed: completed, total: total, result: result) ->
      render_line(width, completed, total, format_result_name(result))
    RunFinishedProgress(
      completed: completed,
      total: total,
      teardown_failed: teardown_failed,
      setup_stopped: setup_stopped,
    ) ->
      render_line(
        width,
        completed,
        total,
        done_label(teardown_failed, setup_stopped),
      )
  }
}

/// `done` at the end of a run, with the number of teardown hooks that
/// failed and of setups that stopped, when not zero.
fn done_label(teardown_failed: Int, setup_stopped: Int) -> String {
  "done"
  <> count_label(teardown_failed, " teardown failed")
  <> count_label(setup_stopped, " setup stopped")
}

/// `, <count><label>`, or `""` for a count of 0.
fn count_label(count: Int, label: String) -> String {
  case count {
    0 -> ""
    _ -> ", " <> int.to_string(count) <> label
  }
}

fn render_line(
  columns: Int,
  completed: Int,
  total: Int,
  label: String,
) -> String {
  let safe_total = int.max(total, 0)
  let safe_completed = clamp_range(completed, 0, safe_total)
  let percent = percent_done(safe_completed, safe_total)

  let counter =
    int.to_string(safe_completed) <> "/" <> int.to_string(safe_total)
  let percent_text = int.to_string(percent) <> "%"
  let prefix = counter <> " "
  let suffix = case label {
    "" -> " " <> percent_text
    _ -> " " <> percent_text <> " " <> label
  }

  // Layout: "<counter> [<bar>] <percent> <label>"
  // Ensure we always clear previous content by padding to full width.
  let fixed = string.length(prefix) + 3 + string.length(suffix)
  // "[] " + spaces
  let bar_width = clamp_range(columns - fixed, 10, columns)
  let bar = "[" <> render_bar(bar_width, percent) <> "]"

  let raw = prefix <> bar <> suffix
  pad_or_truncate(raw, columns)
}

/// The percent of the tests that completed. With no tests, nothing is
/// left to run, so it is 100.
fn percent_done(completed: Int, total: Int) -> Int {
  case total {
    0 -> 100
    _ -> completed * 100 / total
  }
}

fn render_bar(width: Int, percent: Int) -> String {
  let filled = width * clamp_range(percent, 0, 100) / 100
  let empty = width - filled
  string.repeat("█", filled) <> string.repeat("░", empty)
}

fn format_result_name(result: TestResult) -> String {
  // Show the test name after the name of the group around it, if any.
  case list.reverse(result.groups) {
    [] -> result.name
    [parent, ..] -> parent <> " › " <> result.name
  }
}

fn pad_or_truncate(text: String, width: Int) -> String {
  let graphemes = string.to_graphemes(text)
  let len = list.length(graphemes)
  case len == width {
    True -> text
    False ->
      case len < width {
        True -> text <> string.repeat(" ", width - len)
        False -> string.join(list.take(graphemes, width), "")
      }
  }
}

fn clamp_min(n: Int, min: Int) -> Int {
  case n < min {
    True -> min
    False -> n
  }
}

fn clamp_range(n: Int, min: Int, max: Int) -> Int {
  case n < min {
    True -> min
    False ->
      case n > max {
        True -> max
        False -> n
      }
  }
}

@external(erlang, "dream_test_reporter_progress_ffi", "columns")
fn terminal_columns() -> Int
