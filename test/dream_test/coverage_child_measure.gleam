//// Coverage of dream_test's own `src` in the `erl` processes that the
//// runner tests start with `run_measured_main_in_new_vm` (see
//// test/dream_test_coverage_test_ffi.erl).
////
//// Some runner lines run only in such a process: the values of
//// `DREAM_TEST_COVERAGE`, and the stop of the BEAM by
//// `runner.exit_on_failure`. Only these processes measure `src`, because
//// each measured process adds about 1.4 seconds to the test run. The
//// process measures `src` from before the test main until the BEAM stops,
//// and writes LCOV to `build/coverage/parts/<unique>.info`. The test run
//// (test/dream_test_test.gleam) deletes the old parts before it starts, and
//// merges the new parts with `coverage.merge_lcov`.
////
//// The part is written when the BEAM stops, by the application in
//// test/dream_test_coverage_part_application.erl. So a main that stops the
//// BEAM with `init:stop(1)` (`runner.exit_on_failure` with a failure) is
//// measured to its last line, the same as a main that returns.

import dream_test/coverage
import gleam/int

/// The directory of the LCOV parts.
pub const parts_directory = "build/coverage/parts"

/// The pattern that matches every LCOV part, for `coverage.merge_lcov`.
pub const parts_pattern = "build/coverage/parts/*.info"

/// Measure `src`, then call `module.function()`. The LCOV part is written
/// when the BEAM stops, after the main. Crashes when coverage cannot start,
/// so the test that started the process sees the failure in its output and
/// exit status.
pub fn run_measured(module: String, function: String) -> Nil {
  let assert Ok(session) =
    coverage.new()
    |> coverage.source_directory("src")
    |> coverage.lcov_path(part_path())
    |> coverage.start()
  hold_until_stop(session)
  call_main(module, function)
}

/// Write the LCOV part of `session`. The application in
/// test/dream_test_coverage_part_application.erl calls it when the BEAM
/// stops. A failure is written to the output of the process, so the test
/// that started it sees the failure.
pub fn finish(session: coverage.CoverageSession) -> Nil {
  let assert Ok(_) = coverage.finish(session)
  Nil
}

@external(erlang, "dream_test_coverage_part_application", "hold_until_stop")
fn hold_until_stop(session: coverage.CoverageSession) -> Nil

fn part_path() -> String {
  parts_directory
  <> "/child_"
  <> os_process_id()
  <> "_"
  <> int.to_string(unique_integer())
  <> ".info"
}

@external(erlang, "dream_test_coverage_test_ffi", "call_main")
fn call_main(module: String, function: String) -> Nil

@external(erlang, "os", "getpid")
fn os_process_id_charlist() -> Charlist

type Charlist

@external(erlang, "unicode", "characters_to_binary")
fn charlist_to_string(charlist: Charlist) -> String

fn os_process_id() -> String {
  charlist_to_string(os_process_id_charlist())
}

@external(erlang, "erlang", "unique_integer")
fn unique_integer() -> Int
