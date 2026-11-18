//// The summary line of a test run, and the counts behind it.
////
//// The BDD and Gherkin reporters end their report with this line, and the
//// JSON reporter writes the same counts. Use this module in a custom
//// reporter to give the same summary as dream_test.
////
//// ```gleam
//// import dream_test/reporters/summary
////
//// summary.format(report)
//// // -> "Summary: 3 run, 1 failed, 2 passed in 12ms\n"
//// ```
////
//// The line always has the run, failed and passed counts. It adds the
//// skipped, pending, timed out, setup failed and tear-down failed counts, in
//// that order, only when they are not zero.

import dream_test/reporters/ansi
import dream_test/timing
import dream_test/types.{
  type RunReport, type TestResult, Failed, Passed, Pending, SetupFailed, Skipped,
  TimedOut,
}
import gleam/int
import gleam/list
import gleam/string

/// The number of tests with each status, the number of tear-down failures,
/// and the sum of the test durations.
///
/// `run` is the number of results. The six status counts add up to `run`.
///
/// ## Example
///
/// ```gleam
/// summary.count(types.run_report(
///   tests: [passed_result, failed_result],
///   teardown_failures: [],
/// ))
/// // -> Counts(run: 2, passed: 1, failed: 1, skipped: 0, pending: 0,
/// //    timed_out: 0, setup_failed: 0, teardown_failed: 0, duration_ms: 0)
/// ```
pub type Counts {
  Counts(
    /// Number of results
    run: Int,
    /// Results with status `Passed`
    passed: Int,
    /// Results with status `Failed`
    failed: Int,
    /// Results with status `Skipped`
    skipped: Int,
    /// Results with status `Pending`
    pending: Int,
    /// Results with status `TimedOut`
    timed_out: Int,
    /// Results with status `SetupFailed`
    setup_failed: Int,
    /// Tear-down hooks that failed. They are not test results, so they are
    /// not part of `run`.
    teardown_failed: Int,
    /// Sum of the `duration_ms` of all results
    duration_ms: Int,
  )
}

/// Count the test results by status, count the tear-down failures, and add
/// up the test durations.
///
/// ## Parameters
///
/// - `report`: the report of a run
///
/// ## Returns
///
/// The `Counts` of the report.
///
/// ## Example
///
/// ```gleam
/// let counts = summary.count(report)
/// counts.failed
/// // -> 1
/// ```
pub fn count(report report: RunReport) -> Counts {
  let counts = list.fold(types.report_tests(report), empty_counts(), add_result)
  Counts(
    ..counts,
    teardown_failed: list.length(types.report_teardown_failures(report)),
  )
}

/// Format the summary line without colour.
///
/// ## Parameters
///
/// - `report`: the report of a run
///
/// ## Returns
///
/// One line, with a trailing newline.
///
/// ## Example
///
/// ```gleam
/// summary.format(report)
/// // -> "Summary: 4 run, 1 failed, 2 passed, 1 skipped in 12ms\n"
/// ```
pub fn format(report report: RunReport) -> String {
  format_counts(count(report), False)
}

/// Format the summary line with ANSI colour codes.
///
/// The word `Summary:` is bold cyan. The run count and the duration are
/// cyan, the failed count is red and the passed count is green. The skipped
/// and pending counts are yellow, the timed out, setup failed and tear-down
/// failed counts are red, and their labels are dim.
///
/// ## Parameters
///
/// - `report`: the report of a run
///
/// ## Returns
///
/// One line, with a trailing newline.
///
/// ## Example
///
/// ```gleam
/// io.print(summary.format_in_color(report))
/// ```
pub fn format_in_color(report report: RunReport) -> String {
  format_counts(count(report), True)
}

fn empty_counts() -> Counts {
  Counts(
    run: 0,
    passed: 0,
    failed: 0,
    skipped: 0,
    pending: 0,
    timed_out: 0,
    setup_failed: 0,
    teardown_failed: 0,
    duration_ms: 0,
  )
}

fn add_result(counts: Counts, result: TestResult) -> Counts {
  let counts =
    Counts(
      ..counts,
      run: counts.run + 1,
      duration_ms: counts.duration_ms + result.duration_ms,
    )
  case result.status {
    Passed -> Counts(..counts, passed: counts.passed + 1)
    Failed -> Counts(..counts, failed: counts.failed + 1)
    Skipped -> Counts(..counts, skipped: counts.skipped + 1)
    Pending -> Counts(..counts, pending: counts.pending + 1)
    TimedOut -> Counts(..counts, timed_out: counts.timed_out + 1)
    SetupFailed -> Counts(..counts, setup_failed: counts.setup_failed + 1)
  }
}

fn format_counts(counts: Counts, color: Bool) -> String {
  string.concat([
    ansi.apply_if(
      color,
      ansi.bold,
      ansi.apply_if(color, ansi.cyan, "Summary: "),
    ),
    ansi.apply_if(color, ansi.cyan, int.to_string(counts.run)),
    " run, ",
    ansi.apply_if(color, ansi.red, int.to_string(counts.failed)),
    " failed, ",
    ansi.apply_if(color, ansi.green, int.to_string(counts.passed)),
    " passed",
    format_extra_counts(counts, color),
    " in ",
    ansi.apply_if(
      color,
      ansi.cyan,
      timing.format_duration_ms(counts.duration_ms),
    ),
    "\n",
  ])
}

/// The counts that show only when they are not zero, in status order.
fn format_extra_counts(counts: Counts, color: Bool) -> String {
  [
    ExtraCount(counts.skipped, " skipped", ansi.yellow, color),
    ExtraCount(counts.pending, " pending", ansi.yellow, color),
    ExtraCount(counts.timed_out, " timed out", ansi.red, color),
    ExtraCount(counts.setup_failed, " setup failed", ansi.red, color),
    ExtraCount(counts.teardown_failed, " tear-down failed", ansi.red, color),
  ]
  |> list.filter(is_not_zero)
  |> list.map(format_extra_count)
  |> join_extra_counts
}

/// One count that shows only when it is not zero.
type ExtraCount {
  ExtraCount(
    count: Int,
    label: String,
    style: fn(String) -> String,
    color: Bool,
  )
}

fn is_not_zero(extra: ExtraCount) -> Bool {
  extra.count != 0
}

fn format_extra_count(extra: ExtraCount) -> String {
  string.concat([
    ansi.apply_if(extra.color, extra.style, int.to_string(extra.count)),
    ansi.apply_if(extra.color, ansi.dim, extra.label),
  ])
}

fn join_extra_counts(parts: List(String)) -> String {
  case parts {
    [] -> ""
    _ -> ", " <> string.join(parts, ", ")
  }
}
