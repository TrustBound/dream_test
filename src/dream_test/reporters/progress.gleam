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
  let _ = reporter
  let cols = terminal_columns()
  let line = render(cols, event)

  case event {
    reporter_types.HookStarted(..) -> None
    reporter_types.HookFinished(..) -> None
    reporter_types.RunFinished(..) -> Some("\r" <> line <> "\n")
    _ -> Some("\r" <> line)
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
  // Prefer the leaf name, but include some path if available.
  case list.reverse(result.full_name) {
    [] -> result.name
    [leaf] -> leaf
    [leaf, parent, ..] -> parent <> " › " <> leaf
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
