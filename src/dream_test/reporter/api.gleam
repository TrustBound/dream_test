//// Event-driven reporters for dream_test.
////
//// Reporters are state machines that consume `reporter_types.ReporterEvent`.
//// This allows the runner to drive progress (and other live output) without
//// requiring the caller to wire event handlers manually.
////
//// A reporter is responsible for printing any live output and for printing the
//// final report when it receives `RunFinished`.

import dream_test/reporter/bdd as bdd_reporter
import dream_test/reporter/json as json_reporter
import dream_test/reporter/progress as progress_reporter
import dream_test/reporter/types as reporter_types
import dream_test/types.{type TestResult}
import gleam/list

pub type Reporter {
  Bdd(
    write: fn(String) -> Nil,
    show_progress: Bool,
    results_rev: List(TestResult),
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
/// Set `show_progress` to `True` to include the live progress bar.
pub fn bdd(write: fn(String) -> Nil, show_progress: Bool) -> Reporter {
  Bdd(write: write, show_progress: show_progress, results_rev: [])
}

/// Construct a JSON reporter.
///
/// Set `show_progress` to `True` to include the live progress bar.
pub fn json(write: fn(String) -> Nil, show_progress: Bool) -> Reporter {
  Json(write: write, show_progress: show_progress, results_rev: [])
}

/// Construct a progress-only reporter.
pub fn progress(write: fn(String) -> Nil) -> Reporter {
  Progress(write: write)
}

pub fn handle_event(
  reporter: Reporter,
  event: reporter_types.ReporterEvent,
) -> Reporter {
  case reporter {
    Bdd(write: write, show_progress: show_progress, results_rev: results_rev) -> {
      let next_results_rev = accumulate_results(results_rev, event)

      case show_progress {
        True -> progress_reporter.handle_event(event, write)
        False -> Nil
      }

      case event {
        reporter_types.RunFinished(..) -> {
          let results = list.reverse(next_results_rev)
          write(bdd_reporter.format(results))
          Bdd(
            write: write,
            show_progress: show_progress,
            results_rev: next_results_rev,
          )
        }

        _ ->
          Bdd(
            write: write,
            show_progress: show_progress,
            results_rev: next_results_rev,
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
