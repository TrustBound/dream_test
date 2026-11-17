//// Black-box tests of `runner.coverage`.
////
//// Each test runs a main from test/dream_test/coverage_runner_mains.gleam in
//// a new `erl` process (cover runs once per BEAM instance), then checks the
//// exact output (stdout and stderr together) and the exit status.

import dream_test/coverage
import dream_test/coverage_child_support.{run_in_child}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner.{Output}
import dream_test/unit.{describe, group, it}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{type Option, None, Some}

@external(erlang, "dream_test_coverage_test_ffi", "run_main_in_new_vm")
fn run_main_in_new_vm(module: String, function: String) -> #(Int, String)

@external(erlang, "dream_test_coverage_test_ffi", "run_main_in_new_vm_with_environment")
fn run_main_in_new_vm_with_environment(
  module: String,
  function: String,
  environment: List(#(String, Option(String))),
) -> #(Int, String)

@external(erlang, "dream_test_coverage_test_ffi", "set_environment_variable")
fn set_environment_variable(name: String, value: String) -> Nil

@external(erlang, "dream_test_coverage_test_ffi", "unset_environment_variable")
fn unset_environment_variable(name: String) -> Nil

fn run_main(function: String) -> #(Int, String) {
  run_main_in_new_vm("dream_test@coverage_runner_mains", function)
}

/// Run the `coverage_from_environment` main with DREAM_TEST_COVERAGE set
/// to `value`, or removed for `None`.
fn run_with_coverage_variable(value: Option(String)) -> #(Int, String) {
  run_main_in_new_vm_with_environment(
    "dream_test@coverage_runner_mains",
    "coverage_from_environment_with_exit_on_failure",
    [#("DREAM_TEST_COVERAGE", value)],
  )
}

fn invalid_value_failure(value: String) -> String {
  "\nCoverage failed\n"
  <> "  The environment variable DREAM_TEST_COVERAGE has the value \""
  <> value
  <> "\", which does not turn coverage on or off.\n"
  <> "  Reason: runner.coverage_from_environment(...) turns coverage on for 1 or true and off for 0 or false, and it does not guess what other values mean.\n"
  <> "  Fix: set DREAM_TEST_COVERAGE to 1 or true to measure coverage, or set it to 0 or false (or remove it) to run without coverage.\n"
  <> "\n"
}

/// In a child node: set DREAM_TEST_COVERAGE to `value` (or remove it for
/// `None`), run one passing test with `coverage_from_environment`, and
/// return the error output.
fn error_output_in_child(value: Option(String)) -> List(String) {
  change_coverage_variable(value)
  let errors = process.new_subject()
  let _ =
    runner.new([
      describe("child", [it("passes", fn() { Ok(matchers.succeed()) })]),
    ])
    |> runner.output(
      Output(out: fn(_text) { Nil }, error: fn(text) {
        process.send(errors, text)
      }),
    )
    |> runner.coverage_from_environment(coverage.new())
    |> runner.run()
  received_texts(errors, [])
}

fn change_coverage_variable(value: Option(String)) -> Nil {
  case value {
    Some(text) -> set_environment_variable("DREAM_TEST_COVERAGE", text)
    None -> unset_environment_variable("DREAM_TEST_COVERAGE")
  }
}

fn received_texts(
  subject: Subject(String),
  texts: List(String),
) -> List(String) {
  case process.receive(subject, 0) {
    Ok(text) -> received_texts(subject, [text, ..texts])
    Error(Nil) -> list.reverse(texts)
  }
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

fn below_minimum_per_file() -> String {
  "\nCoverage failed\n"
  <> "  Coverage of 2 files is below the per-file minimum 50.0%:\n"
  <> "    test/coverage_fixtures/coverage_fixture_ffi.erl 0.0%, 0 of 1 lines ran (needs 1 more line)\n"
  <> "    test/coverage_fixtures/nested/deep.gleam 0.0%, 0 of 1 lines ran (needs 1 more line)\n"
  <> "  Reason: coverage.minimum_percent_per_file(...) needs each measured file to reach the minimum, and too few executable lines ran in these files.\n"
  <> "  Fix: add tests for the lines that did not run in these files (coverage.show_missing() lists them), or lower coverage.minimum_percent_per_file(...).\n"
  <> "\n"
}

fn below_minimum_exit_line() -> String {
  "Tests: 1 passed. Exit status 1, because coverage is below the minimum.\n"
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
    it("merges the LCOV file of a server that ran in its own BEAM", fn() {
      run_main("server_coverage_merged")
      |> should
      |> be_equal(#(
        0,
        "\nCoverage\n"
          <> "File                                             Lines  Cover   Missing\n"
          <> "test/coverage_fixtures/coverage_fixture_ffi.erl  0/1    0.0%    6\n"
          <> "test/coverage_fixtures/nested/deep.gleam         1/1    100.0%\n"
          <> "test/coverage_fixtures/sample.gleam              2/4    50.0%   9, 14\n"
          <> "Total                                            3/6    50.0%\n",
      ))
      |> or_fail_with("expected the server's lines in the table and exit 0")
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
    it("fails files below the per-file minimum and exits 1", fn() {
      run_main("below_minimum_per_file_with_exit_on_failure")
      |> should
      |> be_equal(#(
        1,
        table() <> below_minimum_per_file() <> below_minimum_exit_line(),
      ))
      |> or_fail_with("expected the per-file failure and exit status 1")
    }),
    it("prints the total and the per-file failure when both fail", fn() {
      run_main("below_both_minimums_with_exit_on_failure")
      |> should
      |> be_equal(#(
        1,
        table()
          <> below_minimum()
          <> below_minimum_exit_line()
          <> below_minimum_per_file()
          <> below_minimum_exit_line(),
      ))
      |> or_fail_with("expected two failure blocks and exit status 1")
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
    group("runner.coverage_from_environment", [
      it("measures coverage when DREAM_TEST_COVERAGE is 1", fn() {
        run_with_coverage_variable(Some("1"))
        |> should
        |> be_equal(#(0, table()))
        |> or_fail_with("expected the table and exit status 0")
      }),
      it("measures coverage when DREAM_TEST_COVERAGE is true", fn() {
        run_with_coverage_variable(Some("true"))
        |> should
        |> be_equal(#(0, table()))
        |> or_fail_with("expected the table and exit status 0")
      }),
      it("runs without coverage when DREAM_TEST_COVERAGE is not set", fn() {
        run_with_coverage_variable(None)
        |> should
        |> be_equal(#(0, ""))
        |> or_fail_with("expected no output and exit status 0")
      }),
      it("runs without coverage when DREAM_TEST_COVERAGE is 0", fn() {
        run_with_coverage_variable(Some("0"))
        |> should
        |> be_equal(#(0, ""))
        |> or_fail_with("expected no output and exit status 0")
      }),
      it("runs without coverage when DREAM_TEST_COVERAGE is false", fn() {
        run_with_coverage_variable(Some("false"))
        |> should
        |> be_equal(#(0, ""))
        |> or_fail_with("expected no output and exit status 0")
      }),
      it("fails an unknown value and exits 1", fn() {
        run_with_coverage_variable(Some("yes"))
        |> should
        |> be_equal(#(
          1,
          invalid_value_failure("yes")
            <> "Tests: 1 passed. Exit status 1, because coverage was requested and did not complete.\n",
        ))
        |> or_fail_with("expected the invalid value failure and exit status 1")
      }),
      it("writes an unknown value failure to the error output", fn() {
        run_in_child(fn() { error_output_in_child(Some("TRUE")) })
        |> should
        |> be_equal(
          Ok([
            invalid_value_failure("TRUE")
            <> "Tests: 1 passed. The exit status is not changed, because exit_on_failure is off.\n",
          ]),
        )
        |> or_fail_with("expected one failure block on the error output")
      }),
      it("writes an empty value failure to the error output", fn() {
        run_in_child(fn() { error_output_in_child(Some("")) })
        |> should
        |> be_equal(
          Ok([
            invalid_value_failure("")
            <> "Tests: 1 passed. The exit status is not changed, because exit_on_failure is off.\n",
          ]),
        )
        |> or_fail_with("expected one failure block on the error output")
      }),
      it(
        "writes nothing to the error output when the variable is not set",
        fn() {
          run_in_child(fn() { error_output_in_child(None) })
          |> should
          |> be_equal(Ok([]))
          |> or_fail_with("expected no error output")
        },
      ),
    ]),
  ])
}
