import dream_test/coverage.{NoSourceFiles}
import dream_test/reporters/coverage.{RunOutcome} as coverage_reporter

pub fn no_source_files_block() -> String {
  coverage_reporter.render_failure(
    error: NoSourceFiles("lib"),
    outcome: RunOutcome(
      passed: 3,
      failed: 0,
      teardown_failed: 0,
      setup_stopped: 0,
      reporters_crashed: 0,
      no_tests_ran: False,
      exit_on_failure: True,
    ),
  )
  // -> "\nCoverage failed\n"
  //    <> "  Found no .gleam or .erl files in the source directory \"lib\".\n"
  //    <> "  Reason: the directory exists, but coverage has nothing in it to measure.\n"
  //    <> "  Fix: set the directory that holds your code with coverage.source_directory(...).\n"
  //    <> "\nTests: 3 passed. Exit status 1, because coverage was requested and did not complete.\n"
}
