//// The summary line of a test run, and the counts behind it.
////
//// The BDD and Gherkin reporters end their report with this line, and the
//// JSON reporter writes the same counts. Use this module in a custom
//// reporter to give the same summary as dream_test.
////
//// ### Format the summary line <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/summary/module.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/reporters/summary
//// import dream_test/types.{type RunReport}
////
//// pub fn summary_line(report: RunReport) -> String {
////   summary.format(report)
////   // -> "Summary: 3 run, 1 failed, 2 passed in 12ms\n"
//// }
//// ```
////
//// The line always has the run, failed and passed counts. The failed count
//// is the tests with the status `Failed` only. It adds the
//// skipped, pending, timed out, setup failed, teardown failed and setup
//// stopped counts, in that order, only when they are not zero.
////
//// A run that ran no test fails (see `types.failed_with_no_tests`). For
//// that run, a second line follows the summary line: `No tests ran. The
//// filter or the suites selected no test. To allow an empty run, use
//// runner.allow_no_tests().`

import dream_test/reporters/ansi
import dream_test/timing
import dream_test/types.{
  type HookFailure, type RunReport, type TestResult, Failed, Passed, Pending,
  SetupFailed, Skipped, TimedOut,
}
import gleam/int
import gleam/list
import gleam/string

/// The number of tests with each status, the number of teardown hooks that
/// failed, the number of setups that stopped, and the sum of the test
/// durations.
///
/// `run` is the number of results. The six status counts add up to `run`.
///
/// ## Example
///
/// ### Count the results of a report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/summary/counts.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/summary.{type Counts}
/// import dream_test/types.{type TestResult}
///
/// pub fn count_two_results(
///   passed_result: TestResult,
///   failed_result: TestResult,
/// ) -> Counts {
///   summary.count(
///     types.run_report(
///       tests: [passed_result, failed_result],
///       hook_failures: [],
///       reporter_crashes: [],
///     ),
///   )
///   // -> Counts(run: 2, passed: 1, failed: 1, skipped: 0, pending: 0,
///   //    timed_out: 0, setup_failed: 0, teardown_failed: 0, setup_stopped: 0,
///   //    duration_ms: 0)
/// }
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
    /// Teardown hooks that failed: the `TeardownFailed` entries of
    /// `types.report_hook_failures`. They are not test results, so they
    /// are not part of `run`.
    teardown_failed: Int,
    /// Setups whose process stopped while their tests ran: the
    /// `SetupStopped` entries of `types.report_hook_failures`. They are
    /// not part of `run`.
    setup_stopped: Int,
    /// Sum of the `duration_ms` of all results
    duration_ms: Int,
  )
}

/// Count the test results by status, count the teardown hooks that failed
/// and the setups that stopped, and add up the test durations.
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
/// ### Read the failed count <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/summary/count.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/summary
/// import dream_test/types.{type RunReport}
///
/// pub fn failed_count(report: RunReport) -> Int {
///   let counts = summary.count(report)
///   counts.failed
///   // -> 1
/// }
/// ```
pub fn count(report report: RunReport) -> Counts {
  let counts = list.fold(types.report_tests(report), empty_counts(), add_result)
  list.fold(types.report_hook_failures(report), counts, add_hook_failure)
}

/// Format the summary line without colour.
///
/// ## Parameters
///
/// - `report`: the report of a run
///
/// ## Returns
///
/// One line, with a trailing newline. When `types.failed_with_no_tests`
/// is `True` for the report, a second line follows: the `No tests ran`
/// line, with a trailing newline.
///
/// ## Example
///
/// ### Format a summary line with a skipped test <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/summary/format.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/summary
/// import dream_test/types.{type RunReport}
///
/// pub fn summary_line_with_skipped(report: RunReport) -> String {
///   summary.format(report)
///   // -> "Summary: 4 run, 1 failed, 2 passed, 1 skipped in 12ms\n"
/// }
/// ```
pub fn format(report report: RunReport) -> String {
  format_counts(count(report), False) <> format_no_tests(report, False)
}

/// Format the summary line with ANSI colour codes.
///
/// The word `Summary:` is bold cyan. The run count and the duration are
/// cyan, the failed count is red and the passed count is green. The skipped
/// and pending counts are yellow, the timed out, setup failed, teardown
/// failed and setup stopped counts are red, and their labels are dim. The
/// `No tests ran` line is red.
///
/// ## Parameters
///
/// - `report`: the report of a run
///
/// ## Returns
///
/// One line, with a trailing newline. When `types.failed_with_no_tests`
/// is `True` for the report, a second line follows: the `No tests ran`
/// line, with a trailing newline.
///
/// ## Example
///
/// ### Print the summary line in color <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/summary/format_in_color.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/summary
/// import dream_test/types.{type RunReport}
/// import gleam/io
///
/// pub fn print_summary_in_color(report: RunReport) -> Nil {
///   io.print(summary.format_in_color(report))
/// }
/// ```
pub fn format_in_color(report report: RunReport) -> String {
  format_counts(count(report), True) <> format_no_tests(report, True)
}

/// The text of the line for a run that failed because it ran no test.
const no_tests_text =
  "No tests ran. The filter or the suites selected no test. To allow an empty run, use runner.allow_no_tests()."

/// The `No tests ran` line, or `""` when the run did not fail that way.
fn format_no_tests(report: RunReport, color: Bool) -> String {
  case types.failed_with_no_tests(report) {
    True -> ansi.apply_if(color, ansi.red, no_tests_text) <> "\n"
    False -> ""
  }
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
    setup_stopped: 0,
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

fn add_hook_failure(counts: Counts, failure: HookFailure) -> Counts {
  case failure {
    types.TeardownFailed(..) ->
      Counts(..counts, teardown_failed: counts.teardown_failed + 1)
    types.SetupStopped(..) ->
      Counts(..counts, setup_stopped: counts.setup_stopped + 1)
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
    ExtraCount(counts.teardown_failed, " teardown failed", ansi.red, color),
    ExtraCount(counts.setup_stopped, " setup stopped", ansi.red, color),
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
