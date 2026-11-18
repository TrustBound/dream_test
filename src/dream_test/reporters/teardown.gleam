//// The section of a report that lists the tear-down hooks that failed and
//// the set-ups that stopped.
////
//// A tear-down failure is not a test result, so the BDD and Gherkin
//// reporters show it in its own section, after the test results and before
//// the summary line. Use this module in a custom reporter to show the same
//// section.
////
//// ```gleam
//// import dream_test/reporters/teardown
////
//// teardown.format(report)
//// // -> "Tear-down failures:\n  after_all in Database\n    could not drop the schema\n"
//// ```

import dream_test/reporters/ansi
import dream_test/types.{
  type RunReport, type SetUpHook, type TestResult, SetupFailed, SetupStopped,
  TeardownFailure,
}
import gleam/int
import gleam/list
import gleam/string

/// Format the tear-down failures of a run without colour.
///
/// A failed tear-down hook has a line with the hook name and the scope (the
/// scope is left out for a hook of the whole run), and a line with the
/// message. A set-up that stopped (`SetupStopped`) has the line
/// `<set-up hook> in "<scope>" stopped: the process that keeps its set-up
/// alive exited with <reason>.`, and the line `<count> tests in "<scope>"
/// that had not started were not run.` The second line is left out when no
/// test was not run. For the whole run, `in "<scope>"` is left out.
///
/// ## Parameters
///
/// - `report`: the run report. Its tests give the number of tests that a
///   stopped set-up did not run.
///
/// ## Returns
///
/// A header line and the lines of each failure, or `""` when the report
/// has no tear-down failure.
///
/// ## Example
///
/// ```gleam
/// teardown.format(types.run_report(tests: [], teardown_failures: [
///   types.TeardownFailure(
///     hook: types.AfterAllHook,
///     scope: ["Database"],
///     message: "could not drop the schema",
///   ),
/// ]))
/// // -> "Tear-down failures:\n  after_all in Database\n    could not drop the schema\n"
/// ```
pub fn format(report report: RunReport) -> String {
  format_section(report, False)
}

/// Format the tear-down failures of a run with ANSI colour codes.
///
/// The header is bold red, and the first line of each failure is red. The
/// text is the same as the text of `format`.
///
/// ## Parameters
///
/// - `report`: the run report
///
/// ## Returns
///
/// A header line and the lines of each failure, or `""` when the report
/// has no tear-down failure.
///
/// ## Example
///
/// ```gleam
/// io.print(teardown.format_in_color(report))
/// ```
pub fn format_in_color(report report: RunReport) -> String {
  format_section(report, True)
}

fn format_section(report: RunReport, color: Bool) -> String {
  case types.report_teardown_failures(report) {
    [] -> ""
    failures ->
      string.concat([
        ansi.apply_if(
          color,
          ansi.bold,
          ansi.apply_if(color, ansi.red, "Tear-down failures:"),
        ),
        "\n",
        format_failures(failures, types.report_tests(report), color, ""),
      ])
  }
}

fn format_failures(
  failures: List(types.TeardownFailure),
  tests: List(TestResult),
  color: Bool,
  accumulated: String,
) -> String {
  case failures {
    [] -> accumulated
    [failure, ..rest] ->
      format_failures(
        rest,
        tests,
        color,
        accumulated <> format_failure(color, tests, failure),
      )
  }
}

fn format_failure(
  color: Bool,
  tests: List(TestResult),
  failure: types.TeardownFailure,
) -> String {
  case failure {
    TeardownFailure(hook: hook, scope: scope, message: message) ->
      failure_lines(color, with_scope(types.teardown_hook_name(hook), scope), [
        message,
      ])
    SetupStopped(set_up: set_up, scope: scope, reason: reason) ->
      failure_lines(
        color,
        types.set_up_hook_name(set_up)
          <> quoted_scope(scope)
          <> " stopped: the process that keeps its set-up alive exited with "
          <> reason
          <> ".",
        not_run_lines(scope, count_not_run(tests, set_up, scope, reason)),
      )
  }
}

/// The first line of a failure in red, then each detail line.
fn failure_lines(color: Bool, title: String, details: List(String)) -> String {
  string.concat([
    "  ",
    ansi.apply_if(color, ansi.red, title),
    "\n",
    ..list.map(details, fn(detail) { "    " <> detail <> "\n" })
  ])
}

/// The tests that a stopped set-up did not run: each one is `SetupFailed`
/// with the failure of `types.setup_stopped_failure`.
fn count_not_run(
  tests: List(TestResult),
  set_up: SetUpHook,
  scope: List(String),
  reason: String,
) -> Int {
  let failures = [
    types.setup_stopped_failure(set_up: set_up, scope: scope, reason: reason),
  ]
  list.count(tests, fn(test_result) {
    test_result.status == SetupFailed && test_result.failures == failures
  })
}

fn not_run_lines(scope: List(String), count: Int) -> List(String) {
  case count {
    0 -> []
    1 -> [
      "1 test" <> quoted_scope(scope) <> " that had not started was not run.",
    ]
    _ -> [
      int.to_string(count)
      <> " tests"
      <> quoted_scope(scope)
      <> " that had not started were not run.",
    ]
  }
}

fn quoted_scope(scope: List(String)) -> String {
  case scope {
    [] -> ""
    _ -> " in \"" <> string.join(scope, " > ") <> "\""
  }
}

fn with_scope(name: String, scope: List(String)) -> String {
  case scope {
    [] -> name
    _ -> name <> " in " <> string.join(scope, " > ")
  }
}
