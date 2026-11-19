//// Black-box tests of runner paths: exit_on_failure without
//// failures, silent, filters with hooks, suite hooks and suite info.

import coverage_fixtures/sample
import dream_test/child_timeout.{with_child_timeout}
import dream_test/coverage.{type CoverageConfig}
import dream_test/coverage_project_support.{with_fixture_lock}
import dream_test/coverage_runner_mains
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/progress
import dream_test/runner
import dream_test/types.{
  type Status, type TestResult, AssertionOk, Passed, Root, Test, Unit,
}
import dream_test/unit.{describe, it}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

@external(erlang, "dream_test_coverage_test_ffi", "run_main_in_new_vm")
fn run_main_in_new_vm(module: String, function: String) -> #(Int, String)

@external(erlang, "dream_test_coverage_test_ffi", "run_main_like_new_gleam_in_new_vm")
fn run_main_like_new_gleam_in_new_vm(
  module: String,
  function: String,
) -> #(Int, String)

/// The exit status, and whether the output has the marker that the mains
/// write after a failed run.
fn status_and_marker(run: #(Int, String)) -> #(Int, Bool) {
  #(run.0, string.contains(run.1, coverage_runner_mains.after_run_marker))
}

pub fn tests() {
  describe("dream_test/runner paths", [
    it("exit_on_failure stops with status 1 for a tear-down failure only", fn() {
      run_main_in_new_vm(
        "dream_test@coverage_runner_mains",
        "teardown_failure_with_exit_on_failure",
      ).0
      |> should
      |> be_equal(1)
      |> or_fail_with("a tear-down failure should give exit status 1")
    })
      |> with_child_timeout,

    it(
      "a failed run ends the program before the next line (Gleam 1.13 and older)",
      fn() {
        run_main_in_new_vm(
          "dream_test@coverage_runner_mains",
          "failed_run_then_marker",
        )
        |> status_and_marker
        |> should
        |> be_equal(#(1, False))
        |> or_fail_with("expected status 1 and no line after runner.run")
      },
    )
      |> with_child_timeout,

    it(
      "a failed run ends the program before the next line (Gleam 1.14 and newer)",
      fn() {
        run_main_like_new_gleam_in_new_vm(
          "dream_test@coverage_runner_mains",
          "failed_run_then_marker",
        )
        |> status_and_marker
        |> should
        |> be_equal(#(1, False))
        |> or_fail_with("expected status 1 and no line after runner.run")
      },
    )
      |> with_child_timeout,

    it("a second run does not start after a failed run", fn() {
      run_main_in_new_vm(
        "dream_test@coverage_runner_mains",
        "failed_run_then_second_run",
      )
      |> status_and_marker
      |> should
      |> be_equal(#(1, False))
      |> or_fail_with("expected status 1 and no before_all of a second run")
    })
      |> with_child_timeout,

    it("exit_on_failure returns the results when every test passes", fn() {
      runner.new([describe("root", [it("passes", fn() { Ok(AssertionOk) })])])
      |> runner.exit_on_failure()
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> statuses
      |> should
      |> be_equal([Passed])
      |> or_fail_with("a passing run should return without halting")
    }),

    it("filter_tests drops a suite that has no selected test", fn() {
      runner.new([
        describe("kept", [it("keep", fn() { Ok(AssertionOk) })]),
        describe("dropped", [it("drop", fn() { Ok(AssertionOk) })]),
      ])
      |> runner.filter_tests(fn(info) { info.name == "keep" })
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> full_names
      |> should
      |> be_equal([["kept", "keep"]])
      |> or_fail_with("only the kept suite should run")
    }),

    it("filter_tests keeps a selected test in a nested group", fn() {
      runner.new([
        describe("root", [
          unit.group("inner", [
            it("keep", fn() { Ok(AssertionOk) }),
            it("drop", fn() { Ok(AssertionOk) }),
          ]),
        ]),
      ])
      |> runner.filter_tests(fn(info) { info.name == "keep" })
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> full_names
      |> should
      |> be_equal([["root", "inner", "keep"]])
      |> or_fail_with("only the kept test of the nested group should run")
    }),

    it("filter_tests keeps the hooks of a selected group", fn() {
      let suite =
        describe("root", [
          unit.before_all(fn() { Ok(Nil) }),
          unit.before_each(fn() { Ok(Nil) }),
          unit.after_each(fn() { Ok(Nil) }),
          unit.after_all(fn() { Ok(Nil) }),
          unit.group("empty", [it("drop", fn() { Ok(AssertionOk) })]),
          it("keep", fn() { Ok(AssertionOk) }),
        ])

      runner.new([suite])
      |> runner.filter_tests(fn(info) { info.name == "keep" })
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> full_names
      |> should
      |> be_equal([["root", "keep"]])
      |> or_fail_with("the kept test should run with the group's hooks")
    }),

    it("runs every before_all_suites hook in order", fn() {
      let calls = process.new_subject()
      let _ =
        runner.new([describe("root", [it("passes", fn() { Ok(AssertionOk) })])])
        |> runner.before_all_suites(fn(_suites) { record(calls, "first") })
        |> runner.before_all_suites(fn(_suites) { record(calls, "second") })
        |> runner.silent()
        |> runner.run()
        |> types.report_tests

      received(calls)
      |> should
      |> be_equal(["first", "second"])
      |> or_fail_with("both before_all_suites hooks should run in order")
    }),

    it("runs every after_all_suites hook in order", fn() {
      let calls = process.new_subject()
      let _ =
        runner.new([describe("root", [it("passes", fn() { Ok(AssertionOk) })])])
        |> runner.after_all_suites(fn(_suites) { record(calls, "first") })
        |> runner.after_all_suites(fn(_suites) { record(calls, "second") })
        |> runner.silent()
        |> runner.run()
        |> types.report_tests

      received(calls)
      |> should
      |> be_equal(["first", "second"])
      |> or_fail_with("both after_all_suites hooks should run in order")
    }),

    it("gives no suite source for a suite without tests", fn() {
      suite_source([])
      |> should
      |> be_equal("None")
      |> or_fail_with("a suite without tests has no source")
    }),

    it("gives the suite source when every test has the same source", fn() {
      suite_source([Some("a"), Some("a")])
      |> should
      |> be_equal("Some(\"a\")")
      |> or_fail_with("one shared source should be the suite source")
    }),

    it("gives no suite source when the first test has no source", fn() {
      suite_source([None, Some("a")])
      |> should
      |> be_equal("None")
      |> or_fail_with("a first test without a source gives no source")
    }),

    it("gives no suite source when two tests have different sources", fn() {
      suite_source([Some("a"), Some("b")])
      |> should
      |> be_equal("None")
      |> or_fail_with("different sources give no suite source")
    }),

    it("gives no suite source when a later test has no source", fn() {
      suite_source([Some("a"), None])
      |> should
      |> be_equal("None")
      |> or_fail_with("a later test without a source gives no source")
    }),

    it("reports a before_each_suite failure to the progress reporter", fn() {
      let lines = process.new_subject()
      let _ =
        runner.new([describe("root", [it("passes", fn() { Ok(AssertionOk) })])])
        |> runner.before_each_suite(fn(_info) { Error("no suite") })
        |> runner.progress_reporter(progress.new())
        |> runner.output(
          runner.Output(
            out: fn(text) { process.send(lines, text) },
            error: fn(text) { process.send(lines, text) },
          ),
        )
        |> runner.run()
        |> types.report_tests

      received(lines)
      |> list.map(after_bar)
      |> should
      |> be_equal(["0% ", "100% root › passes ", "100% done \n"])
      |> or_fail_with("the progress line of the failed test should be written")
    }),

    it("silent discards the progress output", fn() {
      runner.new([describe("root", [it("passes", fn() { Ok(AssertionOk) })])])
      |> runner.progress_reporter(progress.new())
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> statuses
      |> should
      |> be_equal([Passed])
      |> or_fail_with("a silent run should still return its results")
    }),

    it("coverage writes no error output when coverage succeeds", fn() {
      fixture_coverage_run(fixture_coverage())
      |> should
      |> be_equal(#([Passed], []))
      |> or_fail_with("a good coverage run should write no error")
    }),

    it("coverage reports a total below the minimum", fn() {
      fixture_coverage_run(
        fixture_coverage() |> coverage.minimum_percent(100.0),
      )
      |> should
      |> be_equal(
        #([Passed], [
          "\nCoverage failed\n  Coverage 33.3% is below the minimum 100.0% (needs 4 more lines).\n  Reason: 2 of 6 executable lines ran, and the minimum needs 6.\n  Fix: add tests for the lines that did not run (coverage.show_missing() lists them), or lower coverage.minimum_percent(...).\n\nTests: 1 passed. The exit status is not changed, because exit_on_failure is off.\n",
        ]),
      )
      |> or_fail_with("the total minimum failure should be written")
    }),

    it("coverage reports a file below the per-file minimum", fn() {
      fixture_coverage_run(
        fixture_coverage() |> coverage.minimum_percent_per_file(100.0),
      )
      |> should
      |> be_equal(
        #([Passed], [
          "\nCoverage failed\n  Coverage of 3 files is below the per-file minimum 100.0%:\n    test/coverage_fixtures/coverage_fixture_ffi.erl 0.0%, 0 of 1 lines ran (needs 1 more line)\n    test/coverage_fixtures/nested/deep.gleam 0.0%, 0 of 1 lines ran (needs 1 more line)\n    test/coverage_fixtures/sample.gleam 50.0%, 2 of 4 lines ran (needs 2 more lines)\n  Reason: coverage.minimum_percent_per_file(...) needs each measured file to reach the minimum, and too few executable lines ran in these files.\n  Fix: add tests for the lines that did not run in these files (coverage.show_missing() lists them), or lower coverage.minimum_percent_per_file(...).\n\nTests: 1 passed. The exit status is not changed, because exit_on_failure is off.\n",
        ]),
      )
      |> or_fail_with("the per-file minimum failure should be written")
    }),

    it("coverage reports a source directory it cannot start with", fn() {
      fixture_coverage_run(
        coverage.new()
        |> coverage.source_directory("test/no_such_coverage_directory")
        |> coverage.no_lcov(),
      )
      |> should
      |> be_equal(
        #([Passed], [
          "\nCoverage failed\n  Could not find the source directory \"test/no_such_coverage_directory\".\n  Reason: coverage measures the .gleam and .erl files in this directory, and no directory with this name exists where the tests run.\n  Fix: run `gleam test` from the project root, or set the path with coverage.source_directory(...).\n\nTests: 1 passed. The exit status is not changed, because exit_on_failure is off.\n",
        ]),
      )
      |> or_fail_with("the start failure should be written")
    }),

    it("coverage reports an error when it finishes", fn() {
      fixture_coverage_run(
        fixture_coverage()
        |> coverage.merge_lcov("build/coverage/runner_paths_none/*.info"),
      )
      |> should
      |> be_equal(
        #([Passed], [
          "\nCoverage failed\n  No LCOV files match \"build/coverage/runner_paths_none/*.info\".\n  Reason: coverage.merge_lcov(...) adds coverage written by other runs, and nothing has written a file that matches this pattern.\n  Fix: check that the other runs write their LCOV files to a path that matches before this run finishes, or remove coverage.merge_lcov(...).\n\nTests: 1 passed. The exit status is not changed, because exit_on_failure is off.\n",
        ]),
      )
      |> or_fail_with("the finish failure should be written")
    }),

    it("coverage_from_environment runs without coverage when unset", fn() {
      let errors = process.new_subject()
      runner.new([describe("root", [it("passes", fn() { Ok(AssertionOk) })])])
      |> runner.coverage_from_environment(fixture_coverage())
      |> runner.output(
        runner.Output(out: fn(_text) { Nil }, error: fn(text) {
          process.send(errors, text)
        }),
      )
      |> runner.run()
      |> types.report_tests
      |> statuses
      |> fn(result) { #(result, received(errors)) }
      |> should
      |> be_equal(#([Passed], []))
      |> or_fail_with("an unset variable should run without coverage")
    }),
  ])
}

/// Coverage of the fixture modules, without an LCOV file.
fn fixture_coverage() -> CoverageConfig {
  coverage.new()
  |> coverage.source_directory("test/coverage_fixtures")
  |> coverage.no_lcov()
}

/// Run one test that calls `sample.classify(1)` with `config`, and return
/// the statuses and the error output.
fn fixture_coverage_run(
  config: CoverageConfig,
) -> #(List(Status), List(String)) {
  with_fixture_lock(fn() {
    let errors = process.new_subject()
    let results =
      runner.new([
        describe("root", [
          it("classifies", fn() {
            let _ = sample.classify(1)
            Ok(AssertionOk)
          }),
        ]),
      ])
      |> runner.coverage(config)
      |> runner.output(
        runner.Output(out: fn(_text) { Nil }, error: fn(text) {
          process.send(errors, text)
        }),
      )
      |> runner.run()
      |> types.report_tests
    #(statuses(results), received(errors))
  })
}

/// The source the runner gives a suite whose tests have `sources`.
fn suite_source(sources: List(Option(String))) -> String {
  let tests =
    list.index_map(sources, fn(source, index) {
      Test(
        name: "t" <> string.inspect(index),
        tags: [],
        kind: Unit,
        run: types.WithInput(fn(_nil) { Ok(AssertionOk) }),
        timeout_ms: None,
        source: source,
      )
    })
  let seen = process.new_subject()
  let _ =
    runner.new([
      Root(seed: Nil, name: "s", tags: [], children: tests),
    ])
    |> runner.before_each_suite(fn(info) {
      record(seen, string.inspect(info.source))
    })
    |> runner.silent()
    |> runner.run()
    |> types.report_tests
  case received(seen) {
    [source] -> source
    other -> string.inspect(other)
  }
}

/// The text after the progress bar of a progress line.
fn after_bar(line: String) -> String {
  case string.split_once(line, "] ") {
    Ok(#(_bar, text)) -> text
    Error(Nil) -> line
  }
}

fn record(subject: Subject(String), text: String) -> Result(Nil, String) {
  process.send(subject, text)
  Ok(Nil)
}

/// Every message in `subject`'s queue, oldest first.
fn received(subject: Subject(String)) -> List(String) {
  received_loop(subject, [])
}

fn received_loop(subject: Subject(String), acc: List(String)) -> List(String) {
  case process.receive(subject, 0) {
    Ok(text) -> received_loop(subject, [text, ..acc])
    Error(Nil) -> list.reverse(acc)
  }
}

fn statuses(results: List(TestResult)) -> List(Status) {
  list.map(results, fn(result) { result.status })
}

fn full_names(results: List(TestResult)) -> List(List(String)) {
  list.map(results, fn(result) { types.full_name(result.groups, result.name) })
}
