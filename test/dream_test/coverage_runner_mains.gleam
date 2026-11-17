//// Test mains for test/dream_test/runner_coverage_test.gleam.
////
//// Each function runs the dream_test runner with coverage on the fixture
//// modules in test/coverage_fixtures. The tests call them in a new `erl`
//// process, so they can check the real output and exit status.

import coverage_fixtures/nested/deep
import coverage_fixtures/sample
import dream_test/coverage
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/unit.{describe, it}

fn fixture_tests() {
  describe("fixture", [
    it("classifies a positive number", fn() {
      sample.classify(1)
      |> should
      |> be_equal("positive")
      |> or_fail_with("expected positive")
    }),
  ])
}

fn fixture_coverage() {
  coverage.new()
  |> coverage.source_directory("test/coverage_fixtures")
  |> coverage.no_lcov()
}

pub fn passing_run_with_missing_lines() -> Nil {
  let _ =
    runner.new([fixture_tests()])
    |> runner.coverage(fixture_coverage() |> coverage.show_missing())
    |> runner.exit_on_failure()
    |> runner.run()
  Nil
}

pub fn below_minimum_with_exit_on_failure() -> Nil {
  let _ =
    runner.new([fixture_tests()])
    |> runner.coverage(fixture_coverage() |> coverage.minimum_percent(50.0))
    |> runner.exit_on_failure()
    |> runner.run()
  Nil
}

pub fn below_minimum_without_exit_on_failure() -> Nil {
  let _ =
    runner.new([fixture_tests()])
    |> runner.coverage(fixture_coverage() |> coverage.minimum_percent(50.0))
    |> runner.run()
  Nil
}

pub fn missing_source_directory_with_exit_on_failure() -> Nil {
  let _ =
    runner.new([fixture_tests()])
    |> runner.coverage(
      coverage.new()
      |> coverage.source_directory("test/no_such_coverage_directory"),
    )
    |> runner.exit_on_failure()
    |> runner.run()
  Nil
}

pub fn excluded_summary_without_show_excluded() -> Nil {
  let _ =
    runner.new([fixture_tests()])
    |> runner.coverage(
      coverage.new()
      |> coverage.source_directory("test/coverage_ignore_fixtures")
      |> coverage.exclude_with_reason(
        pattern: "test/coverage_ignore_fixtures/ignored_function.gleam",
        reason: "only old callers use it",
      )
      |> coverage.no_lcov(),
    )
    |> runner.exit_on_failure()
    |> runner.run()
  Nil
}

pub fn exclusion_without_reason_with_exit_on_failure() -> Nil {
  let _ =
    runner.new([fixture_tests()])
    |> runner.coverage(
      fixture_coverage()
      |> coverage.exclude("test/coverage_fixtures/nested/**")
      |> coverage.require_exclusion_reasons(),
    )
    |> runner.exit_on_failure()
    |> runner.run()
  Nil
}

fn fixture_tests_with_deep() {
  describe("fixture", [
    it("classifies a positive number", fn() {
      sample.classify(1)
      |> should
      |> be_equal("positive")
      |> or_fail_with("expected positive")
    }),
    it("gives the answer", fn() {
      deep.answer()
      |> should
      |> be_equal(42)
      |> or_fail_with("expected 42")
    }),
  ])
}

pub fn table_options() -> Nil {
  let _ =
    runner.new([fixture_tests_with_deep()])
    |> runner.coverage(
      fixture_coverage()
      |> coverage.show_missing()
      |> coverage.minimum_percent(30.0)
      |> coverage.color()
      |> coverage.sort_by_coverage()
      |> coverage.hide_complete(),
    )
    |> runner.exit_on_failure()
    |> runner.run()
  Nil
}

pub fn coverage_from_environment_with_exit_on_failure() -> Nil {
  let _ =
    runner.new([fixture_tests()])
    |> runner.coverage_from_environment(fixture_coverage())
    |> runner.exit_on_failure()
    |> runner.run()
  Nil
}
