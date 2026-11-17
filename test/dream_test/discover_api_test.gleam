import dream_test/discover.{LoadResult, from_path, list_modules}
import dream_test/matchers.{be_equal, contain, have_length, or_fail_with, should}
import dream_test/runner
import dream_test/types.{
  type AssertionFailure, type Status, type TestResult, AssertionFailure, Failed,
  Passed,
}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/option.{None}

pub fn tests() {
  describe("dream_test/discover", [
    it("can discover a specific test module", fn() {
      let result =
        discover.new()
        |> from_path("dream_test/unit_api_test.gleam")
        |> list_modules()

      result
      |> should
      |> be_equal(Ok(["dream_test@unit_api_test"]))
      |> or_fail_with("expected discovery to find the unit_api_test module")
    }),

    it("dedupes modules when the same path is added twice", fn() {
      let result =
        discover.new()
        |> from_path("dream_test/unit_api_test.gleam")
        |> from_path("dream_test/unit_api_test.gleam")
        |> list_modules()

      let assert Ok(mods) = result

      mods
      |> should
      |> have_length(1)
      |> contain("dream_test@unit_api_test")
      |> or_fail_with("expected no duplicates")
    }),

    it("skips a module that has no test source", fn() {
      discover.new()
      |> from_path("dream_test/file.gleam")
      |> list_modules()
      |> should
      |> be_equal(Ok([]))
      |> or_fail_with("a src module should not be discovered")
    }),

    it("skips a test module that has no tests function", fn() {
      discover.new()
      |> from_path("fixtures/test_results.gleam")
      |> list_modules()
      |> should
      |> be_equal(Ok([]))
      |> or_fail_with("a module without tests() should not be discovered")
    }),

    it("reports a pattern it cannot search", fn() {
      discover.new()
      |> from_path("{")
      |> list_modules()
      |> should
      |> be_equal(Error("{: discover_test_modules_failed"))
      |> or_fail_with("a bad pattern should give an error")
    }),

    it("accepts a module path without an extension", fn() {
      discover.new()
      |> from_path("discovery_fixtures/hooked_suite")
      |> list_modules()
      |> should
      |> be_equal(Ok(["discovery_fixtures@hooked_suite"]))
      |> or_fail_with("a path without .gleam should be discovered")
    }),

    it("accepts a beam file name", fn() {
      discover.tests("discovery_fixtures/hooked_suite.beam")
      |> list_modules()
      |> should
      |> be_equal(Ok(["discovery_fixtures@hooked_suite"]))
      |> or_fail_with("a path with .beam should be discovered")
    }),

    it("load reports a module whose tests function crashes", fn() {
      let LoadResult(suites: suites, errors: errors) =
        discover.new()
        |> from_path("discovery_fixtures/crashing_suite.gleam")
        |> discover.load()

      #(list.length(suites), errors)
      |> should
      |> be_equal(
        #(0, ["discovery_fixtures@crashing_suite: call_tests_failed"]),
      )
      |> or_fail_with("load should give the call error")
    }),

    it("to_suites adds a failing test for each load error", fn() {
      discover.new()
      |> from_path("discovery_fixtures/crashing_suite.gleam")
      |> discover.to_suites()
      |> runner.new()
      |> runner.run()
      |> list.map(summary)
      |> should
      |> be_equal([
        #(
          [
            "Discovery Errors",
            "Discovery Error: discovery_fixtures@crashing_suite: call_tests_failed",
          ],
          Failed,
          [
            AssertionFailure(
              operator: "discover",
              message: "Failed to discover/load test modules (see test name for details)",
              payload: None,
            ),
          ],
        ),
      ])
      |> or_fail_with("to_suites should add a failing discovery error test")
    }),

    it("to_suite puts suites and load errors under one group", fn() {
      discover.new()
      |> from_path("discovery_fixtures/hooked_suite.gleam")
      |> from_path("discovery_fixtures/crashing_suite.gleam")
      |> discover.to_suite("all")
      |> list.wrap()
      |> runner.new()
      |> runner.run()
      |> list.map(fn(result) { #(result.full_name, result.status) })
      |> should
      |> be_equal([
        #(
          [
            "all",
            "Discovery Error: discovery_fixtures@crashing_suite: call_tests_failed",
          ],
          Failed,
        ),
        #(["all", "hooked_suite", "passes"], Passed),
      ])
      |> or_fail_with("to_suite should hold the error test and the suite")
    }),

    it("skips a module whose beam file cannot be loaded", fn() {
      let directory = "build/discovery_broken_beams"
      add_broken_beam_first_in_path(
        directory,
        "discovery_fixtures@unloadable_suite",
      )
      let result =
        discover.new()
        |> from_path("discovery_fixtures/unloadable_suite.gleam")
        |> list_modules()
      remove_from_path(directory)

      result
      |> should
      |> be_equal(Ok([]))
      |> or_fail_with("a module that cannot load should not be discovered")
    }),
  ])
}

/// Put `directory` first in the code path, with a broken `<module>.beam`.
@external(erlang, "dream_test_coverage_test_ffi", "add_broken_beam_first_in_path")
fn add_broken_beam_first_in_path(directory: String, module: String) -> Nil

@external(erlang, "dream_test_coverage_test_ffi", "remove_from_path")
fn remove_from_path(directory: String) -> Nil

fn summary(
  result: TestResult,
) -> #(List(String), Status, List(AssertionFailure)) {
  #(result.full_name, result.status, result.failures)
}
