//// Live progress bar reporter.
////
//// This module renders a single-line progress bar that updates in-place using
//// carriage returns, and adapts to the current terminal width.
////
//// It is designed to be driven by `dream_test/reporter/types.ReporterEvent`,
//// which you can obtain by using `runner.run_*_with_events` (or the underlying
//// parallel functions).
////
//// ## Usage
////
//// ```gleam
//// import dream_test/reporter/progress
//// import dream_test/reporter/types.{type ReporterEvent}
//// import dream_test/runner
//// import gleam/io
////
//// pub fn main() {
////   let on_event = fn(event: ReporterEvent) {
////     progress.handle_event(event, io.print)
////   }
////
////   tests()
////   |> to_test_cases("my_test")
////   |> runner.run_all_with_progress(on_event)
////   |> bdd.report(io.print)
////   |> runner.exit_on_failure()
//// }
//// ```
////
//// This module intentionally does not return callbacks (to avoid forcing
//// closures in library code). Call `handle_event` from your own callback.

import dream_test/reporter/types as reporter_types
import dream_test/types.{type TestResult}
import gleam/int
import gleam/list
import gleam/string

/// Handle a single reporter event by writing an in-place progress bar line.
///
/// - For `RunStarted`, prints an initial 0% bar.
/// - For `TestFinished`, prints an updated bar using the included counts.
/// - For `RunFinished`, prints a final 100% bar and a newline.
pub fn handle_event(
  event: reporter_types.ReporterEvent,
  write: fn(String) -> Nil,
) -> Nil {
  let cols = terminal_columns()
  let line = render(cols, event)
  case event {
    reporter_types.RunFinished(..) -> write("\r" <> line <> "\n")
    _ -> write("\r" <> line)
  }
}

/// Render a progress bar line for a given terminal width.
///
/// This is pure and is intended for testing.
pub fn render(columns: Int, event: reporter_types.ReporterEvent) -> String {
  let cols = clamp_min(columns, 20)
  case event {
    reporter_types.RunStarted(total: total) -> render_line(cols, 0, total, "")

    reporter_types.TestFinished(
      completed: completed,
      total: total,
      result: result,
    ) -> render_line(cols, completed, total, format_result_name(result))

    reporter_types.RunFinished(completed: completed, total: total) ->
      render_line(cols, completed, total, "done")
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
