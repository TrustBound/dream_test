import gleam/list
import gleam/string
import gleam/int
import gleam/option.{Some}
import dream_test/types.{type TestResult, type AssertionFailure, type Status, EqualityFailure, Passed, Failed, Skipped, Pending, TimedOut}

/// BDD-style reporter for dream_test.
///
/// This reporter prints grouped, spec-like output based on TestResult values.
/// It works for both unit tests (from `describe` / `it`) and, later,
/// Gherkin scenarios (via TestKind.GherkinScenario).
///
/// `format` returns the full report as a String, which is convenient for tests
/// or for composing with other output backends.
///
/// `report` applies a user-provided writer function to the formatted String, so
/// the caller decides whether to print to stdout, log, buffer, etc.
pub fn format(results: List(TestResult)) -> String {
  let suites = group_by_suite(results)
  let suites_text = format_suites(suites)
  let summary_text = format_summary(results)
  string.concat([suites_text, summary_text])
}

pub fn report(results: List(TestResult), write: fn(String) -> Nil) {
  write(format(results))
}

fn group_by_suite(results: List(TestResult)) -> List(#(String, List(TestResult))) {
  let suite_names =
    results
    |> list.map(first_full_name_segment)
    |> list.filter(fn(name) { name != "" })

  let unique_suites = unique_strings(suite_names, [])

  build_grouped_results(unique_suites, results, [])
}

fn first_full_name_segment(result: TestResult) -> String {
  case result.full_name {
    [head, .._] -> head
    [] -> ""
  }
}

fn unique_strings(values: List(String),
  accumulated: List(String),
) -> List(String) {
  case values {
    [] ->
      list.reverse(accumulated)

    [head, ..tail] -> {
      case list.contains(accumulated, head) {
        True ->
          unique_strings(tail, accumulated)

        False ->
          unique_strings(tail, [head, ..accumulated])
      }
    }
  }
}

fn build_grouped_results(suites: List(String),
  results: List(TestResult),
  accumulated: List(#(String, List(TestResult))),
) -> List(#(String, List(TestResult))) {
  case suites {
    [] ->
      list.reverse(accumulated)

    [suite, ..tail] -> {
      let suite_results = list.filter(results, fn(result) {
        case result.full_name {
          [head, .._] -> head == suite
          [] -> False
        }
      })

      build_grouped_results(tail, results, [#(suite, suite_results), ..accumulated])
    }
  }
}

fn format_suites(suites: List(#(String, List(TestResult)))) -> String {
  case suites {
    [] -> ""

    [head, ..tail] -> {
      let suite_name = case head { #(name, _) -> name }
      let suite_results = case head { #(_, results) -> results }

      let this_block =
        string.concat([
          suite_name,
          "\n",
          format_specs_in_suite(suite_results),
          "\n",
        ])

      string.concat([this_block, format_suites(tail)])
    }
  }
}

fn format_specs_in_suite(results: List(TestResult)) -> String {
  case results {
    [] -> ""

    [head, ..tail] -> {
      let name = spec_name_from_full_name(head.full_name)
      let marker = status_marker(head.status)

      let this_line = string.concat(["  ", marker, " ", name, "\n"])
      let failure_text = format_failure_details(head)

      string.concat([
        this_line,
        failure_text,
        format_specs_in_suite(tail),
      ])
    }
  }
}

fn spec_name_from_full_name(full_name: List(String)) -> String {
  case list.reverse(full_name) {
    [last, .._] -> last
    [] -> ""
  }
}

fn status_marker(status: Status) -> String {
  case status {
    Passed -> "✓"
    Failed -> "✗"
    Skipped -> "-"
    Pending -> "~"
    TimedOut -> "!"
  }
}

fn format_failure_details(result: TestResult) -> String {
  case result.status {
    Failed ->
      format_failure_list(result.failures)

    _ ->
      ""
  }
}

fn format_failure_list(failures: List(AssertionFailure)) -> String {
  case failures {
    [] -> ""

    [first, ..tail] -> {
      string.concat([
        format_one_failure(first),
        format_failure_list(tail),
      ])
    }
  }
}

fn format_one_failure(failure: AssertionFailure) -> String {
  let header = string.concat(["    ", failure.operator, "\n"]) 

  let message_text =
    case failure.message {
      "" -> ""
      message -> string.concat(["      Message: ", message, "\n"])
    }

  let payload_text =
    case failure.payload {
      Some(EqualityFailure(actual, expected)) ->
        string.concat([
          "      Expected: ", expected, "\n",
          "      Actual:   ", actual, "\n",
        ])

      _ -> ""
    }

  string.concat([header, message_text, payload_text])
}

fn format_summary(results: List(TestResult)) -> String {
  let total = list.length(results)
  let failed = count_status(results, Failed)
  let skipped = count_status(results, Skipped)
  let pending = count_status(results, Pending)
  let timed_out = count_status(results, TimedOut)
  let passed = total - failed - skipped - pending - timed_out

  string.concat([
    "Summary: ",
    int.to_string(total), " run, ",
    int.to_string(failed), " failed, ",
    int.to_string(passed), " passed",
    summary_suffix(skipped, pending, timed_out),
    "\n",
  ])
}

fn count_status(results: List(TestResult), wanted: Status) -> Int {
  count_status_from_list(results, wanted, 0)
}

fn count_status_from_list(results: List(TestResult),
  wanted: Status,
  count: Int,
) -> Int {
  case results {
    [] -> count

    [head, ..tail] -> {
      let next_count =
        case head.status == wanted {
          True -> count + 1
          False -> count
        }

      count_status_from_list(tail, wanted, next_count)
    }
  }
}

fn summary_suffix(skipped: Int, pending: Int, timed_out: Int) -> String {
  let parts =
    []
    |> add_summary_part(skipped, " skipped")
    |> add_summary_part(pending, " pending")
    |> add_summary_part(timed_out, " timed out")

  case parts {
    [] -> ""
    _ -> string.concat([", ", string.join(parts, ", ")])
  }
}

fn add_summary_part(parts: List(String),
  count: Int,
  label: String,
) -> List(String) {
  case count {
    0 -> parts
    _ -> [string.concat([int.to_string(count), label]), ..parts]
  }
}
