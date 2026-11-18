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
//// It is designed to be driven by `dream_test/reporters/types.ReporterEvent`,
//// but most users should not call it directly. Prefer attaching it via
//// `runner.progress_reporter(progress.new())` and letting the runner drive events.
////
//// ## Example
////
//// ```gleam
//// pub fn main() {
////   runner.new([tests()])
////   |> runner.progress_reporter(progress.new())
////   |> runner.exit_on_failure()
////   |> runner.run()
//// }
//// ```

import dream_test/reporters/types as reporter_types
import dream_test/types.{type TestResult}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// A progress-bar reporter that renders a single-line UI during a run.
///
/// Construct one with `progress.new()` and attach it to the runner via
/// `runner.progress_reporter(...)`.
pub opaque type ProgressReporter {
  ProgressReporter
}

/// Create a new progress reporter.
pub fn new() -> ProgressReporter {
  ProgressReporter
}

/// The three points of a run that change the progress bar.
///
/// The runner gives one to `progress.line` for each point. Unlike
/// `ReporterEvent`, it has no hook events, so each one gives a line.
///
/// - `RunStartedProgress`: the run starts. `total` is the number of tests.
/// - `TestFinishedProgress`: one more test finished. `completed` counts the
///   finished tests, this one included.
/// - `RunFinishedProgress`: the run finished.
///
/// ## Example
///
/// ```gleam
/// progress.line(
///   progress.new(),
///   progress.RunFinishedProgress(completed: 4, total: 4),
/// )
/// |> string.ends_with("\n")
/// |> should
/// |> be_equal(True)
/// |> or_fail_with("expected the last line to end the bar")
/// ```
pub type ProgressEvent {
  RunStartedProgress(total: Int)
  TestFinishedProgress(completed: Int, total: Int, result: TestResult)
  RunFinishedProgress(completed: Int, total: Int, teardown_failures: Int)
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
/// ```gleam
/// progress.line(progress.new(), progress.RunStartedProgress(total: 4))
/// |> string.starts_with("\r0/4 [")
/// |> should
/// |> be_equal(True)
/// |> or_fail_with("expected an empty bar for 4 tests")
/// ```
pub fn line(
  reporter reporter: ProgressReporter,
  event event: ProgressEvent,
) -> String {
  let _ = reporter
  let columns = clamp_min(terminal_columns(), 20)
  case event {
    RunStartedProgress(total: total) ->
      "\r" <> render_line(columns, 0, total, "")
    TestFinishedProgress(completed: completed, total: total, result: result) ->
      "\r" <> render_line(columns, completed, total, format_result_name(result))
    RunFinishedProgress(
      completed: completed,
      total: total,
      teardown_failures: teardown_failures,
    ) ->
      "\r"
      <> render_line(columns, completed, total, done_label(teardown_failures))
      <> "\n"
  }
}

/// Handle a single reporter event by writing an in-place progress bar line.
///
/// - For `RunStarted`, prints an initial 0% bar.
/// - For `TestFinished`, prints an updated bar using the included counts.
/// - For `RunFinished`, prints a final 100% bar and a newline.
///
/// This function ignores hook events (`HookStarted` / `HookFinished`) so hook
/// chatter doesn’t scramble the single-line UI.
///
/// ## Parameters
///
/// - `event`: a `ReporterEvent` emitted by the runner
/// - `write`: an output sink (typically `io.print`). For best results this
///   should write **without adding extra newlines**.
///
/// ## When should I use this?
///
/// Usually you shouldn’t call it directly—prefer attaching it via
/// `runner.progress_reporter(progress.new())` and letting the runner drive events.
///
/// You may call it directly only if you are building your own reporter/driver
/// and you are already receiving `ReporterEvent`s.
///
/// ## Example
///
/// ```gleam
/// progress.handle_event(
///   reporter_types.RunStarted(total: 10),
///   write_progress_line_to_file,
/// )
///
/// use text <- result.try(
///   file.read("test/tmp/progress_handle_event.txt")
///   |> result.map_error(file.error_to_string),
/// )
///
/// text
/// |> should
/// |> match_snapshot("./test/snapshots/progress_handle_event_run_started.snap")
/// |> or_fail_with("expected handle_event output snapshot match")
/// ```
pub fn handle_event(
  reporter reporter: ProgressReporter,
  event event: reporter_types.ReporterEvent,
) -> Option(String) {
  case event {
    reporter_types.HookStarted(..) | reporter_types.HookFinished(..) -> None
    reporter_types.RunStarted(total: total) ->
      Some(line(reporter, RunStartedProgress(total: total)))
    reporter_types.TestFinished(
      completed: completed,
      total: total,
      result: result,
    ) ->
      Some(line(
        reporter,
        TestFinishedProgress(completed: completed, total: total, result: result),
      ))
    reporter_types.RunFinished(completed: completed, total: total, results: _) ->
      Some(line(
        reporter,
        RunFinishedProgress(
          completed: completed,
          total: total,
          teardown_failures: 0,
        ),
      ))
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
/// - `event`: event to render
///
/// ## Returns
///
/// A single line of text **exactly** `columns` graphemes wide (after clamping).
///
/// ## Example
///
/// ```gleam
/// progress.render(30, reporter_types.RunStarted(total: 10))
/// |> should
/// |> match_snapshot("./test/snapshots/progress_render_run_started.snap")
/// |> or_fail_with("expected render output snapshot match")
/// ```
pub fn render(
  columns columns: Int,
  event event: reporter_types.ReporterEvent,
) -> String {
  let cols = clamp_min(columns, 20)
  case event {
    reporter_types.RunStarted(total: total) -> render_line(cols, 0, total, "")

    reporter_types.TestFinished(
      completed: completed,
      total: total,
      result: result,
    ) -> render_line(cols, completed, total, format_result_name(result))

    reporter_types.RunFinished(
      completed: completed,
      total: total,
      results: _results,
    ) -> render_line(cols, completed, total, "done")

    // Hook events do not affect the progress bar.
    _ -> render_line(cols, 0, 1, "")
  }
}

/// `done` at the end of a run, with the number of tear-down failures when
/// a tear-down hook failed.
fn done_label(teardown_failures: Int) -> String {
  case teardown_failures {
    0 -> "done"
    count -> "done, " <> int.to_string(count) <> " tear-down failed"
  }
}

fn render_line(
  columns: Int,
  completed: Int,
  total: Int,
  label: String,
) -> String {
  let safe_total = case total <= 0 {
    True -> 1
    False -> total
  }
  let safe_completed = clamp_range(completed, 0, safe_total)
  let percent = safe_completed * 100 / safe_total

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
