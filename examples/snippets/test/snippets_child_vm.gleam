//// Run a function of a snippet module in a new BEAM (the child VM), and
//// see what it does: its exit status and what it prints.
////
//// Use it for an example that cannot run in the test run itself, because
//// it stops the VM (`runner.exit_on_failure()`), prints a report, or
//// starts a real coverage run.
////
//// This module is not under `test/snippets/`, so test discovery does not
//// treat it as a suite.

import dream_test/parallel
import dream_test/types.{type AssertionResult, NoInput, Test, Unit}
import dream_test/unit.{type UnitNode}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/regexp
import gleam/result
import gleam/string

/// What a child VM did.
///
/// - `status`: the exit status. It is 0 when the function returned, 1 when
///   it crashed, and the status that the function gave when it stopped the
///   VM itself.
/// - `output`: what the child wrote to its standard output.
/// - `error_output`: what the child wrote to the standard error IO device.
///   A crash writes its error here.
pub type ChildRun {
  ChildRun(status: Int, output: String, error_output: String)
}

/// The time that a child VM gets, in milliseconds. A child that does not
/// stop in time is killed, and its run is an `Error`.
pub const deadline_ms = 50_000

/// The time that a test gets after the deadline of its child VM, to kill
/// the child.
const kill_margin_ms = 10_000

/// Run `function` of the Gleam module `module` (for example
/// `snippets/doc/unit/describe`) in a child VM. The function is public and
/// has no arguments. The child uses the compiled code of this test run,
/// and the snippets project as its current folder. It does not get the
/// `DREAM_TEST_COVERAGE` variable of the test run.
///
/// Returns an `Error` with the output so far when the child does not stop
/// within `deadline_ms`, or when a name has a character other than `a-z`,
/// `0-9`, `_` and `/`.
pub fn run(module: String, function: String) -> Result(ChildRun, String) {
  child_run(module, function, [], deadline_ms)
  |> result.map(to_child_run)
}

/// `run`, while no other snippet test measures coverage, with the
/// environment variables in `environment` set in the child. Use it for a
/// function that starts a coverage run, because coverage runs write files
/// under `build/coverage`.
pub fn run_with_coverage_lock(
  module: String,
  function: String,
  environment: List(#(String, String)),
) -> Result(ChildRun, String) {
  child_run_with_coverage_lock(module, function, environment, deadline_ms)
  |> result.map(to_child_run)
}

/// A test, like `unit.it`, with a timeout long enough for one child VM.
pub fn it_runs_in_child_vm(
  name: String,
  run: fn() -> Result(AssertionResult, String),
) -> UnitNode {
  test_with_timeout(name, run, deadline_ms + kill_margin_ms)
}

/// A test, like `unit.it`, with a timeout long enough for one child VM
/// that first waits for the coverage lock. The lock goes to the tests in
/// the order that they ask, and at most `max_concurrency - 1` other tests
/// ask before this one. Each one holds the lock for at most `deadline_ms`.
pub fn it_runs_in_child_vm_with_coverage_lock(
  name: String,
  run: fn() -> Result(AssertionResult, String),
) -> UnitNode {
  let parallel.ParallelConfig(
    max_concurrency: concurrency,
    default_timeout_ms: _,
  ) = parallel.default_config()
  test_with_timeout(name, run, concurrency * deadline_ms + kill_margin_ms)
}

/// The output of a run with the progress reporter and the bdd reporter,
/// with the parts that change from run to run made fixed:
///
/// - The progress reporter rewrites its line with a carriage return for
///   each test, in the order that the tests finish. Only the last state of
///   the line, after the last carriage return, is kept.
/// - A test that takes 1ms or more shows its duration after its name, for
///   example `(2ms)`. These are removed.
/// - The duration of the run, as in `in 5ms` at the end of the summary
///   line, becomes `in <duration>`. In a coloured summary line the
///   duration keeps its colour codes around `<duration>`.
pub fn without_progress_and_durations(output: String) -> String {
  output
  |> last_progress_state
  |> replace(test_duration_pattern, "")
  |> replace(run_duration_pattern, " in <duration>")
  |> replace(
    run_duration_in_color_pattern,
    " in \u{001b}[36m<duration>\u{001b}[0m",
  )
}

/// `run` with `without_progress_and_durations` applied to its output.
pub fn without_progress_and_durations_in(run: ChildRun) -> ChildRun {
  ChildRun(..run, output: without_progress_and_durations(run.output))
}

/// The last state of the progress line for a run of `total` tests, as
/// the progress reporter writes it to an output that is not a terminal
/// (80 columns): the counts, a full bar, `100%` and `done`.
pub fn progress_done_line(total: Int) -> String {
  let counts = int.to_string(total) <> "/" <> int.to_string(total)
  let bar_width = 80 - string.length(counts <> " [] 100% done ")
  counts <> " [" <> string.repeat("█", bar_width) <> "] 100% done \n"
}

/// `run` with the ANSI colour codes removed from its error output. Gleam
/// `echo` colours its location line when the output supports colour.
pub fn without_colors_in_error_output(run: ChildRun) -> ChildRun {
  ChildRun(..run, error_output: replace(run.error_output, color_pattern, ""))
}

/// An ANSI colour code, such as `\u{001b}[90m`.
const color_pattern = "\u{001b}\\[[0-9;]*m"

/// A test duration after a test name, such as ` (2ms)` or ` (1.5s)`.
const test_duration_pattern = " \\([0-9]+(\\.[0-9]+)?m?s\\)"

/// The duration of a run at the end of a summary line, such as ` in 5ms`.
const run_duration_pattern = " in [0-9]+(\\.[0-9]+)?m?s(?=\\n|$)"

/// The duration of a run in a coloured summary line, such as
/// ` in \u{001b}[36m5ms\u{001b}[0m`.
const run_duration_in_color_pattern =
  " in \u{001b}\\[36m[0-9]+(\\.[0-9]+)?m?s\u{001b}\\[0m"

fn last_progress_state(output: String) -> String {
  case string.split_once(output, "\n") {
    Ok(#(first_line, rest)) -> last_carriage_return_part(first_line, rest)
    Error(Nil) -> output
  }
}

fn last_carriage_return_part(first_line: String, rest: String) -> String {
  case string.contains(first_line, "\r") {
    True -> last_part(string.split(first_line, "\r")) <> "\n" <> rest
    False -> first_line <> "\n" <> rest
  }
}

fn last_part(parts: List(String)) -> String {
  list.last(parts)
  |> result.unwrap("")
}

/// Replace each match of `pattern` in `text` with `replacement`.
pub fn replace(text: String, pattern: String, replacement: String) -> String {
  let assert Ok(compiled) = regexp.from_string(pattern)
  regexp.replace(each: compiled, in: text, with: replacement)
}

fn test_with_timeout(
  name: String,
  run: fn() -> Result(AssertionResult, String),
  timeout_ms: Int,
) -> UnitNode {
  Test(
    name: name,
    tags: [],
    kind: Unit,
    run: NoInput(run),
    timeout_ms: Some(timeout_ms),
    source: None,
  )
}

fn to_child_run(result: #(Int, String, String)) -> ChildRun {
  let #(status, output, error_output) = result
  ChildRun(status: status, output: output, error_output: error_output)
}

@external(erlang, "snippets_child_vm_ffi", "run")
fn child_run(
  module: String,
  function: String,
  environment: List(#(String, String)),
  deadline_ms: Int,
) -> Result(#(Int, String, String), String)

@external(erlang, "snippets_child_vm_ffi", "run_with_coverage_lock")
fn child_run_with_coverage_lock(
  module: String,
  function: String,
  environment: List(#(String, String)),
  deadline_ms: Int,
) -> Result(#(Int, String, String), String)
