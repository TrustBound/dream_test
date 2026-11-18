//// The section of a report that lists the tear-down hooks that failed.
////
//// A tear-down failure is not a test result, so the BDD and Gherkin
//// reporters show it in its own section, after the test results and before
//// the summary line. Use this module in a custom reporter to show the same
//// section.
////
//// ```gleam
//// import dream_test/reporters/teardown
////
//// teardown.format(types.report_teardown_failures(report))
//// // -> "Tear-down failures:\n  after_all in Database\n    could not drop the schema\n"
//// ```

import dream_test/reporters/ansi
import dream_test/types.{type TeardownFailure, ScopeLost, TeardownFailure}
import gleam/string

/// Format the tear-down failures without colour.
///
/// Each failure has a line with the hook name and the scope (the scope is
/// left out for a hook of the whole run), and a line with the message. A
/// lost scope (`ScopeLost`) has the line `lost scope of <set-up hook> in
/// <scope>`, and the line `the owner process exited: <reason>`.
///
/// ## Parameters
///
/// - `failures`: the tear-down failures of a run
///
/// ## Returns
///
/// A header line and two lines for each failure, or `""` when `failures` is
/// empty.
///
/// ## Example
///
/// ```gleam
/// teardown.format([
///   types.TeardownFailure(
///     hook: types.AfterAllHook,
///     scope: ["Database"],
///     message: "could not drop the schema",
///   ),
/// ])
/// // -> "Tear-down failures:\n  after_all in Database\n    could not drop the schema\n"
/// ```
pub fn format(failures failures: List(TeardownFailure)) -> String {
  format_section(failures, False)
}

/// Format the tear-down failures with ANSI colour codes.
///
/// The header is bold red, and the line with the hook name and the scope is
/// red. The text is the same as the text of `format`.
///
/// ## Parameters
///
/// - `failures`: the tear-down failures of a run
///
/// ## Returns
///
/// A header line and two lines for each failure, or `""` when `failures` is
/// empty.
///
/// ## Example
///
/// ```gleam
/// io.print(teardown.format_in_color(types.report_teardown_failures(report)))
/// ```
pub fn format_in_color(failures failures: List(TeardownFailure)) -> String {
  format_section(failures, True)
}

fn format_section(failures: List(TeardownFailure), color: Bool) -> String {
  case failures {
    [] -> ""
    _ ->
      string.concat([
        ansi.apply_if(
          color,
          ansi.bold,
          ansi.apply_if(color, ansi.red, "Tear-down failures:"),
        ),
        "\n",
        format_failures(failures, color, ""),
      ])
  }
}

fn format_failures(
  failures: List(TeardownFailure),
  color: Bool,
  accumulated: String,
) -> String {
  case failures {
    [] -> accumulated
    [failure, ..rest] ->
      format_failures(
        rest,
        color,
        accumulated <> format_failure(color, failure),
      )
  }
}

fn format_failure(color: Bool, failure: TeardownFailure) -> String {
  string.concat([
    "  ",
    ansi.apply_if(color, ansi.red, title(failure)),
    "\n    ",
    detail(failure),
    "\n",
  ])
}

/// The first line of a failure: the hook name and the scope.
fn title(failure: TeardownFailure) -> String {
  case failure {
    TeardownFailure(hook: hook, scope: scope, message: _) ->
      with_scope(types.teardown_hook_name(hook), scope)
    ScopeLost(set_up: set_up, scope: scope, reason: _) ->
      with_scope("lost scope of " <> types.set_up_hook_name(set_up), scope)
  }
}

/// The second line of a failure: what went wrong.
fn detail(failure: TeardownFailure) -> String {
  case failure {
    TeardownFailure(hook: _, scope: _, message: message) -> message
    ScopeLost(set_up: _, scope: _, reason: reason) ->
      "the owner process exited: " <> reason
  }
}

fn with_scope(name: String, scope: List(String)) -> String {
  case scope {
    [] -> name
    _ -> name <> " in " <> string.join(scope, " > ")
  }
}
