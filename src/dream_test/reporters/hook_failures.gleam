//// The section of a report that lists the teardown hooks that failed and
//// the setups that stopped.
////
//// A teardown failure is not a test result, so the BDD and Gherkin
//// reporters show it in its own section, after the test results and before
//// the summary line. Use this module in a custom reporter to show the same
//// section.
////
//// ```gleam
//// import dream_test/reporters/hook_failures
////
//// hook_failures.format(types.report_hook_failures(report))
//// // -> "Setup and teardown failures:\n  after_all in Database\n    could not drop the schema\n"
//// ```

import dream_test/reporters/ansi
import dream_test/types.{type HookFailure, SetupStopped, TeardownFailed}
import gleam/list
import gleam/string

/// Format the setup and teardown failures of a run without colour.
///
/// A failed teardown hook has a line with the hook name and its groups
/// (left out for a hook of the whole run), and a line with the message. A
/// setup that stopped (`SetupStopped`) has the line
/// `<setup hook> in "<groups>" stopped: the process that keeps its setup
/// alive exited with <reason>.` For the whole run, `in "<groups>"` is left
/// out. When the setup did not run some tests, the line
/// `These tests had not started and were not run:` follows, then the full
/// name of each test, with its names joined by ` > `.
///
/// ## Parameters
///
/// - `failures`: the teardown failures of the run, for example from
///   `types.report_hook_failures`
///
/// ## Returns
///
/// A header line and the lines of each failure, or `""` when `failures` is
/// empty.
///
/// ## Example
///
/// ```gleam
/// hook_failures.format([
///   types.SetupStopped(
///     setup: types.BeforeAllHook,
///     groups: ["root"],
///     reason: "Boom",
///     not_run: [["root", "b"], ["root", "c"]],
///   ),
/// ])
/// // -> "Setup and teardown failures:\n  before_all in \"root\" stopped: the process that keeps its setup alive exited with Boom.\n    These tests had not started and were not run:\n      root > b\n      root > c\n"
/// ```
pub fn format(failures failures: List(HookFailure)) -> String {
  format_section(failures, False)
}

/// Format the setup and teardown failures of a run with ANSI colour codes.
///
/// The header is bold red, and the first line of each failure is red. The
/// text is the same as the text of `format`.
///
/// ## Parameters
///
/// - `failures`: the teardown failures of the run
///
/// ## Returns
///
/// A header line and the lines of each failure, or `""` when `failures` is
/// empty.
///
/// ## Example
///
/// ```gleam
/// io.print(hook_failures.format_in_color(types.report_hook_failures(report)))
/// ```
pub fn format_in_color(failures failures: List(HookFailure)) -> String {
  format_section(failures, True)
}

fn format_section(failures: List(HookFailure), color: Bool) -> String {
  case failures {
    [] -> ""
    _ ->
      string.concat([
        ansi.apply_if(
          color,
          ansi.bold,
          ansi.apply_if(color, ansi.red, "Setup and teardown failures:"),
        ),
        "\n",
        ..format_failures(color, failures)
      ])
  }
}

/// The text of each failure, in order.
fn format_failures(color: Bool, failures: List(HookFailure)) -> List(String) {
  case failures {
    [] -> []
    [failure, ..rest] -> [
      format_failure(color, failure),
      ..format_failures(color, rest)
    ]
  }
}

fn format_failure(color: Bool, failure: HookFailure) -> String {
  case failure {
    TeardownFailed(hook: hook, groups: groups, message: message) ->
      failure_lines(color, with_groups(types.teardown_hook_name(hook), groups), [
        message,
      ])
    SetupStopped(setup: setup, groups: groups, reason: reason, not_run: not_run) ->
      failure_lines(
        color,
        types.setup_hook_name(setup)
          <> quoted_groups(groups)
          <> " stopped: the process that keeps its setup alive exited with "
          <> reason
          <> ".",
        not_run_lines(not_run),
      )
  }
}

/// The first line of a failure in red, then each detail line.
fn failure_lines(color: Bool, title: String, details: List(String)) -> String {
  string.concat([
    "  ",
    ansi.apply_if(color, ansi.red, title),
    "\n",
    ..list.map(details, detail_line)
  ])
}

/// One detail line of a failure, indented under its first line.
fn detail_line(detail: String) -> String {
  "    " <> detail <> "\n"
}

/// The lines that name the tests that a stopped setup did not run, or no
/// line when it did not skip a test.
fn not_run_lines(not_run: List(List(String))) -> List(String) {
  case not_run {
    [] -> []
    _ -> [
      "These tests had not started and were not run:",
      ..list.map(not_run, not_run_name)
    ]
  }
}

/// The full name of a test that did not run, indented under its heading.
fn not_run_name(full_name: List(String)) -> String {
  "  " <> string.join(full_name, " > ")
}

fn quoted_groups(groups: List(String)) -> String {
  case groups {
    [] -> ""
    _ -> " in \"" <> string.join(groups, " > ") <> "\""
  }
}

fn with_groups(name: String, groups: List(String)) -> String {
  case groups {
    [] -> name
    _ -> name <> " in " <> string.join(groups, " > ")
  }
}
