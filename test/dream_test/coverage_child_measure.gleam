//// Coverage of dream_test's own `src` in the `erl` processes that the
//// runner tests start (see `run_main_in_new_vm` in
//// test/dream_test_coverage_test_ffi.erl).
////
//// Some runner lines run only in such a process, for example the values of
//// `DREAM_TEST_COVERAGE`. The process measures `src` around the test main
//// and writes LCOV to `build/coverage/parts/<unique>.info`. The test run
//// (test/dream_test_test.gleam) deletes the old parts before it starts, and
//// merges the new parts with `coverage.merge_lcov`.
////
//// A main that halts its BEAM (`runner.exit_on_failure` with a failure)
//// writes no part, because `erlang:halt` stops the BEAM before `finish`
//// can run. The lines that run only before such a halt are not measured.

import dream_test/coverage
import gleam/int

/// The directory of the LCOV parts.
pub const parts_directory = "build/coverage/parts"

/// The pattern that matches every LCOV part, for `coverage.merge_lcov`.
pub const parts_pattern = "build/coverage/parts/*.info"

/// Measure `src`, call `module.function()`, then write the LCOV part.
/// Crashes when coverage cannot start or finish, so the test that started
/// the process sees the failure in its output and exit status.
pub fn run_measured(module: String, function: String) -> Nil {
  let assert Ok(session) =
    coverage.new()
    |> coverage.source_directory("src")
    |> coverage.lcov_path(part_path())
    |> coverage.start()
  call_main(module, function)
  let assert Ok(_) = coverage.finish(session)
  Nil
}

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
