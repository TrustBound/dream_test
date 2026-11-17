//// Black-box tests of `runner.coverage`.
////
//// Each test runs a main from test/dream_test/coverage_runner_mains.gleam in
//// a new `erl` process (cover runs once per BEAM instance), then checks the
//// exact output (stdout and stderr together) and the exit status.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}

@external(erlang, "dream_test_coverage_test_ffi", "run_main_in_new_vm")
fn run_main_in_new_vm(module: String, function: String) -> #(Int, String)

fn run_main(function: String) -> #(Int, String) {
  run_main_in_new_vm("dream_test@coverage_runner_mains", function)
}

fn table() -> String {
  "\nCoverage\n"
  <> "File                                             Lines  Cover\n"
  <> "test/coverage_fixtures/coverage_fixture_ffi.erl  0/1    0.0%\n"
  <> "test/coverage_fixtures/nested/deep.gleam         0/1    0.0%\n"
  <> "test/coverage_fixtures/sample.gleam              2/4    50.0%\n"
  <> "Total                                            2/6    33.3%\n"
}

fn below_minimum() -> String {
  "\nCoverage failed\n"
  <> "  Coverage 33.3% is below the minimum 50.0% (needs 1 more line).\n"
  <> "  Reason: 2 of 6 executable lines ran, and the minimum needs 3.\n"
  <> "  Fix: add tests for the lines that did not run (coverage.show_missing() lists them), or lower coverage.minimum_percent(...).\n"
  <> "\n"
}

pub fn tests() {
  describe("runner.coverage", [
    it("prints the table with a Missing column and exits 0", fn() {
      run_main("passing_run_with_missing_lines")
      |> should
      |> be_equal(#(
        0,
        "\nCoverage\n"
          <> "File                                             Lines  Cover  Missing\n"
          <> "test/coverage_fixtures/coverage_fixture_ffi.erl  0/1    0.0%   6\n"
          <> "test/coverage_fixtures/nested/deep.gleam         0/1    0.0%   4\n"
          <> "test/coverage_fixtures/sample.gleam              2/4    50.0%  9, 14\n"
          <> "Total                                            2/6    33.3%\n",
      ))
      |> or_fail_with("expected the table and exit status 0")
    }),
    it("fails below the minimum and exits 1 with exit_on_failure", fn() {
      run_main("below_minimum_with_exit_on_failure")
      |> should
      |> be_equal(#(
        1,
        table()
          <> below_minimum()
          <> "Tests: 1 passed. Exit status 1, because coverage is below the minimum.\n",
      ))
      |> or_fail_with("expected the minimum failure and exit status 1")
    }),
    it("reports a minimum failure but exits 0 without exit_on_failure", fn() {
      run_main("below_minimum_without_exit_on_failure")
      |> should
      |> be_equal(#(
        0,
        table()
          <> below_minimum()
          <> "Tests: 1 passed. The exit status is not changed, because exit_on_failure is off.\n",
      ))
      |> or_fail_with("expected the minimum failure and exit status 0")
    }),
    it("reports a coverage error and exits 1 with exit_on_failure", fn() {
      run_main("missing_source_directory_with_exit_on_failure")
      |> should
      |> be_equal(#(
        1,
        "\nCoverage failed\n"
          <> "  Could not find the source directory \"test/no_such_coverage_directory\".\n"
          <> "  Reason: coverage measures the .gleam and .erl files in this directory, and no directory with this name exists where the tests run.\n"
          <> "  Fix: run `gleam test` from the project root, or set the path with coverage.source_directory(...).\n"
          <> "\n"
          <> "Tests: 1 passed. Exit status 1, because coverage was requested and did not complete.\n",
      ))
      |> or_fail_with("expected the coverage error and exit status 1")
    }),
    it("prints the table with colour, coverage order and hidden files", fn() {
      run_main("table_options")
      |> should
      |> be_equal(#(
        0,
        "\nCoverage\n"
          <> "File                                             Lines  Cover  Missing\n"
          <> "test/coverage_fixtures/coverage_fixture_ffi.erl  0/1    "
          <> "\u{1b}[31m0.0%\u{1b}[0m   \u{1b}[31m6\u{1b}[0m\n"
          <> "test/coverage_fixtures/sample.gleam              2/4    "
          <> "\u{1b}[33m50.0%\u{1b}[0m  \u{1b}[31m9, 14\u{1b}[0m\n"
          <> "Total                                            3/6    "
          <> "\u{1b}[33m50.0%\u{1b}[0m\n"
          <> "Hidden: 1 file at 100.0%\n",
      ))
      |> or_fail_with("expected the table options and exit status 0")
    }),
    it("prints the Excluded count line without show_excluded", fn() {
      run_main("excluded_summary_without_show_excluded")
      |> should
      |> be_equal(#(
        0,
        "\nCoverage\n"
          <> "File                                         Lines  Cover\n"
          <> "test/coverage_ignore_fixtures/ignored.gleam  0/3    0.0%\n"
          <> "Total                                        0/3    0.0%\n"
          <> "Excluded: 1 file, 6 lines in 1 file\n",
      ))
      |> or_fail_with("expected the table with the Excluded line and exit 0")
    }),
    it("fails an exclusion without a reason and exits 1", fn() {
      run_main("exclusion_without_reason_with_exit_on_failure")
      |> should
      |> be_equal(#(
        1,
        "\nCoverage failed\n"
          <> "  The exclude pattern \"test/coverage_fixtures/nested/**\" has no reason.\n"
          <> "  Reason: coverage.require_exclusion_reasons() is on, so every exclude pattern must say why its files are left out of coverage.\n"
          <> "  Fix: replace coverage.exclude(...) with coverage.exclude_with_reason(pattern: \"test/coverage_fixtures/nested/**\", reason: \"...\").\n"
          <> "\n"
          <> "Tests: 1 passed. Exit status 1, because coverage was requested and did not complete.\n",
      ))
      |> or_fail_with("expected the reason failure and exit status 1")
    }),
  ])
}
