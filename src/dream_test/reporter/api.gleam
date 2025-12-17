//// Event-driven reporters for dream_test.
////
//// Reporters are state machines that consume `reporter_types.ReporterEvent`.
//// This allows the runner to drive progress (and other live output) without
//// requiring the caller to wire event handlers manually.
////
//// A reporter is responsible for printing any live output and for printing the
//// final report when it receives `RunFinished`.
////
//// ## Choosing a reporter
////
//// - `bdd(write, show_progress)`: human-readable BDD output.
////   - `show_progress: True` streams output as tests complete (useful in long runs).
////   - `show_progress: False` prints only once at the end.
//// - `json(write, show_progress)`: machine-readable JSON output.
////   - `show_progress: True` also shows the live progress bar while the run executes.
////   - `show_progress: False` prints only JSON once at the end.
//// - `progress(write)`: progress bar only (no final summary).
////
//// ## How this fits with the runner
////
//// You attach a reporter to a run via `runner.reporter(...)`. During execution
//// the runner emits events like `RunStarted`, `TestFinished`, and `RunFinished`,
//// and the reporter decides what (if anything) to print for each event.
////
//// ## Usage
////
//// Most users will construct one of these reporters and attach it to the runner:
////
//// ```gleam
//// import dream_test/reporter/api as reporter
//// import dream_test/runner
//// import dream_test/unit.{describe, it}
//// import dream_test/types.{AssertionOk}
//// import gleam/io
////
//// let suite =
////   describe("Example", [
////     it("passes", fn(_) { Ok(AssertionOk) }),
////   ])
////
//// runner.new([suite])
//// |> runner.reporter(reporter.bdd(io.print, True))
//// |> runner.exit_on_failure()
//// |> runner.run()
//// ```

import dream_test/reporter/bdd as bdd_reporter
import dream_test/reporter/json as json_reporter
import dream_test/reporter/progress as progress_reporter
import dream_test/reporter/types as reporter_types
import dream_test/types.{type TestResult}
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// A reporter state machine driven by `ReporterEvent`s.
///
/// Construct a reporter with `bdd`, `json`, or `progress`, then attach it to a
/// run via `runner.reporter(...)`.
///
/// Treat `Reporter` as opaque: construct it using the functions in this module.
/// The internal variants/fields are not intended for pattern matching by users.
pub type Reporter {
  Bdd(
    write: fn(String) -> Nil,
    show_progress: Bool,
    results_rev: List(TestResult),
    pending_hooks: Dict(String, #(Option(String), Option(String))),
  )

  Json(
    write: fn(String) -> Nil,
    show_progress: Bool,
    results_rev: List(TestResult),
  )

  Progress(write: fn(String) -> Nil)
}

/// Construct a BDD-style reporter.
///
/// Set `show_progress` to `True` to include live output as tests complete.
///
/// When `True`, BDD output is streamed during the run and the final summary is
/// printed on `RunFinished`.
///
/// ## Parameters
///
/// - `write`: output sink (e.g. `io.print`)
/// - `show_progress`: when `True`, stream output during the run
///
/// ## Example
///
/// ```gleam
/// import dream_test/reporter/api as reporter
/// import dream_test/runner
/// import gleam/io
///
/// runner.new([suite])
/// |> runner.reporter(reporter.bdd(io.print, True))
/// |> runner.exit_on_failure()
/// |> runner.run()
/// ```
pub fn bdd(write: fn(String) -> Nil, show_progress: Bool) -> Reporter {
  Bdd(
    write: write,
    show_progress: show_progress,
    results_rev: [],
    pending_hooks: dict.new(),
  )
}

/// Construct a JSON reporter.
///
/// Set `show_progress` to `True` to include the live progress bar.
///
/// When `False`, JSON is printed only once on `RunFinished`.
///
/// ## Parameters
///
/// - `write`: output sink (e.g. `io.print`)
/// - `show_progress`: when `True`, show a live progress bar during the run
///
/// ## Example
///
/// ```gleam
/// import dream_test/reporter/api as reporter
/// import dream_test/runner
/// import gleam/io
///
/// runner.new([suite])
/// |> runner.reporter(reporter.json(io.print, False))
/// |> runner.exit_on_failure()
/// |> runner.run()
/// ```
pub fn json(write: fn(String) -> Nil, show_progress: Bool) -> Reporter {
  Json(write: write, show_progress: show_progress, results_rev: [])
}

/// Construct a progress-only reporter.
///
/// This prints only the progress bar (no final summary).
///
/// ## Example
///
/// ```gleam
/// import dream_test/reporter/api as reporter
/// import dream_test/runner
/// import gleam/io
///
/// runner.new([suite])
/// |> runner.reporter(reporter.progress(io.print))
/// |> runner.exit_on_failure()
/// |> runner.run()
/// ```
pub fn progress(write: fn(String) -> Nil) -> Reporter {
  Progress(write: write)
}

/// Feed a single `ReporterEvent` into a reporter state machine.
///
/// The runner uses this internally. It’s public so you can build custom
/// reporter drivers if you need them.
///
/// Reporters are state machines: this function returns the updated reporter.
///
/// ## Example
///
/// ```gleam
/// import dream_test/reporter/api as reporter
/// import dream_test/reporter/types as reporter_types
/// import gleam/io
///
/// let r0 = reporter.progress(io.print)
/// let r1 = reporter.handle_event(r0, reporter_types.RunStarted(total: 10))
/// let _r2 = reporter.handle_event(r1, reporter_types.RunFinished(completed: 10, total: 10))
/// ```
pub fn handle_event(
  reporter: Reporter,
  event: reporter_types.ReporterEvent,
) -> Reporter {
  case reporter {
    Bdd(
      write: write,
      show_progress: show_progress,
      results_rev: results_rev,
      pending_hooks: pending_hooks,
    ) -> {
      let next_results_rev = accumulate_results(results_rev, event)
      let next_pending_hooks = accumulate_pending_hooks(pending_hooks, event)

      case show_progress {
        True -> handle_bdd_live_event(event, results_rev, pending_hooks, write)
        False -> Nil
      }

      case event {
        reporter_types.RunFinished(..) -> {
          case show_progress {
            True -> {
              let results = list.reverse(next_results_rev)
              write("\n" <> bdd_reporter.format_summary_only(results))
            }

            False -> {
              let results = list.reverse(next_results_rev)
              write(bdd_reporter.format(results))
            }
          }

          Bdd(
            write: write,
            show_progress: show_progress,
            results_rev: next_results_rev,
            pending_hooks: dict.new(),
          )
        }

        _ ->
          Bdd(
            write: write,
            show_progress: show_progress,
            results_rev: next_results_rev,
            pending_hooks: next_pending_hooks,
          )
      }
    }

    Json(write: write, show_progress: show_progress, results_rev: results_rev) -> {
      let next_results_rev = accumulate_results(results_rev, event)

      case show_progress {
        True -> progress_reporter.handle_event(event, write)
        False -> Nil
      }

      case event {
        reporter_types.RunFinished(..) -> {
          let results = list.reverse(next_results_rev)
          write(json_reporter.format(results))
          Json(
            write: write,
            show_progress: show_progress,
            results_rev: next_results_rev,
          )
        }

        _ ->
          Json(
            write: write,
            show_progress: show_progress,
            results_rev: next_results_rev,
          )
      }
    }

    Progress(write: write) -> {
      progress_reporter.handle_event(event, write)
      reporter
    }
  }
}

fn handle_bdd_live_event(
  event: reporter_types.ReporterEvent,
  results_rev: List(TestResult),
  pending_hooks: Dict(String, #(Option(String), Option(String))),
  write: fn(String) -> Nil,
) -> Nil {
  case event {
    reporter_types.TestFinished(completed: _c, total: _t, result: result) -> {
      let previous_path = previous_describe_path(results_rev)
      let key = full_name_key(result.full_name)
      let pending = dict.get(pending_hooks, key)

      let before_each_line = case pending {
        Ok(#(line, _)) -> line
        Error(Nil) -> None
      }

      let after_each_line = case pending {
        Ok(#(_, line)) -> line
        Error(Nil) -> None
      }

      let extra_indent = case before_each_line {
        Some(_) -> 1
        None -> 0
      }

      let #(headers, test_line, _new_path) =
        bdd_reporter.format_incremental_parts_with_test_indent(
          result,
          previous_path,
          extra_indent,
        )

      // Ensure describe/group headers print before lifecycle hook lines so the
      // hook appears under the correct suite/group.
      write(headers)

      case before_each_line {
        Some(line) -> write(line)
        None -> Nil
      }

      write(test_line)

      case after_each_line {
        Some(line) -> write(line)
        None -> Nil
      }
    }

    reporter_types.HookStarted(kind: kind, scope: scope, test_name: test_name) ->
      case kind, test_name {
        reporter_types.BeforeAll, _ ->
          write(format_hook_line(kind, scope, test_name, None))
        reporter_types.AfterAll, _ ->
          write(format_hook_line(kind, scope, test_name, None))
        _, _ -> Nil
      }

    reporter_types.HookFinished(
      kind: kind,
      scope: scope,
      test_name: test_name,
      outcome: outcome,
    ) -> {
      case outcome {
        reporter_types.HookOk -> Nil
        reporter_types.HookError(message: message) ->
          case kind, test_name {
            reporter_types.BeforeAll, _ ->
              write(format_hook_line(kind, scope, test_name, Some(message)))
            reporter_types.AfterAll, _ ->
              write(format_hook_line(kind, scope, test_name, Some(message)))
            _, _ -> Nil
          }
      }
    }

    // For RunStarted we currently print nothing. The first TestFinished will
    // emit the initial suite headers.
    _ -> Nil
  }
}

fn accumulate_pending_hooks(
  pending: Dict(String, #(Option(String), Option(String))),
  event: reporter_types.ReporterEvent,
) -> Dict(String, #(Option(String), Option(String))) {
  case event {
    reporter_types.HookFinished(
      kind: reporter_types.BeforeEach,
      scope: scope,
      test_name: Some(name),
      outcome: outcome,
    ) -> {
      let key = full_name_key(list.append(scope, [name]))
      let message = hook_outcome_message(outcome)
      let line =
        format_hook_line(reporter_types.BeforeEach, scope, Some(name), message)
      upsert_pending_before_each(pending, key, line)
    }

    reporter_types.HookFinished(
      kind: reporter_types.AfterEach,
      scope: scope,
      test_name: Some(name),
      outcome: outcome,
    ) -> {
      let key = full_name_key(list.append(scope, [name]))
      let message = hook_outcome_message(outcome)
      let line =
        format_hook_line(reporter_types.AfterEach, scope, Some(name), message)
      upsert_pending_after_each(pending, key, line)
    }

    reporter_types.TestFinished(completed: _c, total: _t, result: result) -> {
      // Clear any buffered hooks for this test once it's printed.
      dict.delete(pending, full_name_key(result.full_name))
    }

    _ -> pending
  }
}

fn hook_outcome_message(outcome: reporter_types.HookOutcome) -> Option(String) {
  case outcome {
    reporter_types.HookOk -> None
    reporter_types.HookError(message: message) -> Some(message)
  }
}

fn upsert_pending_before_each(
  pending: Dict(String, #(Option(String), Option(String))),
  key: String,
  line: String,
) -> Dict(String, #(Option(String), Option(String))) {
  case dict.get(pending, key) {
    Error(Nil) -> dict.insert(pending, key, #(Some(line), None))
    Ok(#(_before_each, after_each)) ->
      dict.insert(pending, key, #(Some(line), after_each))
  }
}

fn upsert_pending_after_each(
  pending: Dict(String, #(Option(String), Option(String))),
  key: String,
  line: String,
) -> Dict(String, #(Option(String), Option(String))) {
  case dict.get(pending, key) {
    Error(Nil) -> dict.insert(pending, key, #(None, Some(line)))
    Ok(#(before_each, _after_each)) ->
      dict.insert(pending, key, #(before_each, Some(line)))
  }
}

fn full_name_key(full_name: List(String)) -> String {
  string.join(full_name, "\u{1F}")
}

fn format_hook_line(
  kind: reporter_types.HookKind,
  scope: List(String),
  test_name: Option(String),
  error_message: Option(String),
) -> String {
  let indent = string.repeat("  ", list.length(scope))
  let kind_text = hook_kind_to_string(kind)
  let test_suffix = case test_name {
    None -> ""
    Some(name) -> " (" <> name <> ")"
  }
  let error_suffix = case error_message {
    None -> ""
    Some(message) -> " ✗ " <> message
  }
  indent <> "↳ " <> kind_text <> test_suffix <> error_suffix <> "\n"
}

fn hook_kind_to_string(kind: reporter_types.HookKind) -> String {
  case kind {
    reporter_types.BeforeAll -> "before_all"
    reporter_types.BeforeEach -> "before_each"
    reporter_types.AfterEach -> "after_each"
    reporter_types.AfterAll -> "after_all"
  }
}

fn previous_describe_path(results_rev: List(TestResult)) -> List(String) {
  case results_rev {
    [] -> []
    [previous, ..] -> drop_last_segment(previous.full_name, [])
  }
}

fn drop_last_segment(
  full_name: List(String),
  rev_acc: List(String),
) -> List(String) {
  case full_name {
    [] -> []
    [_] -> list.reverse(rev_acc)
    [head, ..rest] -> drop_last_segment(rest, [head, ..rev_acc])
  }
}

fn accumulate_results(
  results_rev: List(TestResult),
  event: reporter_types.ReporterEvent,
) -> List(TestResult) {
  case event {
    reporter_types.TestFinished(completed: _c, total: _t, result: result) -> [
      result,
      ..results_rev
    ]
    _ -> results_rev
  }
}
