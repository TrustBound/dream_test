import dream_test/discover.{LoadResult, from_path, list_modules}
import dream_test/matchers.{be_equal, contain, have_length, or_fail_with, should}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{
  type AssertionFailure, type Status, type TestResult, AssertionFailure, Failed,
  Passed,
}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// The load errors of the discovery fixture `name`.
fn load_errors(name: String) -> List(String) {
  let LoadResult(suites: _, errors: errors) =
    discover.new()
    |> from_path("discovery_fixtures/" <> name <> ".gleam")
    |> discover.load()
  errors
}

fn suite_test_sources(suite: TestSuite) -> List(Option(String)) {
  list.map(suite.tests(suite), test_source)
}

fn test_source(info: types.TestInfo) -> Option(String) {
  info.source
}

/// Whether the fixture has one load error, and it starts with the text.
fn has_one_load_error_starting_with(fixture: #(String, String)) -> Bool {
  case load_errors(fixture.0) {
    [error] -> string.starts_with(error, fixture.1)
    _ -> False
  }
}

/// The name, the status and the failure messages of a result.
fn name_status_and_messages(
  result: TestResult,
) -> #(String, Status, List(String)) {
  #(result.name, result.status, list.map(result.failures, failure_message))
}

fn failure_message(failure: AssertionFailure) -> String {
  failure.message
}

fn full_name_and_status(result: TestResult) -> #(List(String), Status) {
  #(types.full_name(result.groups, result.name), result.status)
}

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

    it("gives an error when only a module with no test source matches", fn() {
      discover.new()
      |> from_path("dream_test/file.gleam")
      |> list_modules()
      |> should
      |> be_equal(Error(
        "dream_test/file.gleam: no test module matches the pattern",
      ))
      |> or_fail_with("a src module should not be discovered")
    }),

    it("gives an error when only a module with no tests function matches", fn() {
      discover.new()
      |> from_path("fixtures/test_results.gleam")
      |> list_modules()
      |> should
      |> be_equal(Error(
        "fixtures/test_results.gleam: no test module matches the pattern",
      ))
      |> or_fail_with("a module without tests() should not be discovered")
    }),

    it("to_suites fails a run whose pattern matches no module", fn() {
      discover.new()
      |> from_path("no_such_folder/**_test.gleam")
      |> discover.to_suites()
      |> runner.new()
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> list.map(name_status_and_messages)
      |> should
      |> be_equal([
        #(
          "Discovery Error: no_such_folder/**_test.gleam: no test module matches the pattern",
          Failed,
          ["Failed to discover/load test modules (see test name for details)"],
        ),
      ])
      |> or_fail_with("a pattern with no module should fail the run")
    }),

    it("reports a pattern it cannot search", fn() {
      discover.new()
      |> from_path("{")
      |> list_modules()
      |> should
      |> be_equal(Error(
        "{: cannot search for test modules: error:{badpattern,missing_delimiter}",
      ))
      |> or_fail_with("a bad pattern should give an error")
    }),

    it("load gives a module whose suite has a context", fn() {
      load_errors("context_suite")
      |> should
      |> be_equal([])
      |> or_fail_with("load should accept a suite with a context")
    }),

    it("to_suites runs a context suite with its own context", fn() {
      runner.new(
        discover.new()
        |> from_path("discovery_fixtures/context_suite.gleam")
        |> discover.to_suites(),
      )
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> list.map(name_status_and_messages)
      |> should
      |> be_equal([#("gets the context", Passed, [])])
      |> or_fail_with("the context suite should get the context 41")
    }),

    it("keeps the .feature path as the source of a Gherkin suite", fn() {
      discover.new()
      |> from_path("discovery_fixtures/feature_suite.gleam")
      |> discover.to_suites()
      |> list.flat_map(suite_test_sources)
      |> should
      |> be_equal([Some("test/discovery_fixtures/feature_suite.feature")])
      |> or_fail_with("the source should stay the path of the .feature file")
    }),

    it("to_suite runs each suite with its own context", fn() {
      runner.new([
        discover.new()
        |> from_path("discovery_fixtures/context_suite.gleam")
        |> from_path("discovery_fixtures/hooked_suite.gleam")
        |> discover.to_suite("all"),
      ])
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> list.map(full_name_and_status)
      |> should
      |> be_equal([
        #(["all", "context_suite", "gets the context"], Passed),
        #(["all", "hooked_suite", "passes"], Passed),
        #(["all", "hooked_suite", "nested", "passes too"], Passed),
      ])
      |> or_fail_with("each suite should keep its context under the group")
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

      #(
        list.length(suites),
        list.map(errors, string.starts_with(
          _,
          "discovery_fixtures@crashing_suite: tests() crashed: error:#{",
        )),
        list.map(errors, string.contains(_, "crashing_suite fixture")),
      )
      |> should
      |> be_equal(#(0, [True], [True]))
      |> or_fail_with("load should give the crash with its reason")
    }),

    it("load reports a module whose tests function gives no suite", fn() {
      ["not_a_suite", "bad_root_tags_suite"]
      |> list.flat_map(load_errors)
      |> should
      |> be_equal([
        "discovery_fixtures@not_a_suite: tests() did not return a test suite: 42",
        "discovery_fixtures@bad_root_tags_suite: tests() did not return a test suite: {root,nil,<<\"bad_root_tags_suite\">>,[1],[]}",
      ])
      |> or_fail_with("load should name the module and the value")
    }),

    it("load reports a suite value with a part that is not a part", fn() {
      [
        #(
          "bad_part_suite",
          "discovery_fixtures@bad_part_suite: tests() did not return a test suite: {test_suite,<<\"bad_part_suite\">>,[nil]}",
        ),
        #(
          "bad_test_info_suite",
          "discovery_fixtures@bad_test_info_suite: tests() did not return a test suite: {test_suite,<<\"bad_test_info_suite\">>,[{part,{place,[],none},[nil],",
        ),
      ]
      |> list.map(has_one_load_error_starting_with)
      |> should
      |> be_equal([True, True])
      |> or_fail_with("load should name the module and the value")
    }),

    it("to_suites adds a failing test for each load error", fn() {
      discover.new()
      |> from_path("discovery_fixtures/not_a_suite.gleam")
      |> discover.to_suites()
      |> runner.new()
      |> runner.run()
      |> types.report_tests
      |> list.map(summary)
      |> should
      |> be_equal([
        #(
          [
            "Discovery Errors",
            "Discovery Error: discovery_fixtures@not_a_suite: tests() did not return a test suite: 42",
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
      |> from_path("discovery_fixtures/not_a_suite.gleam")
      |> discover.to_suite("all")
      |> list.wrap()
      |> runner.new()
      |> runner.run()
      |> types.report_tests
      |> list.map(fn(result) {
        #(types.full_name(result.groups, result.name), result.status)
      })
      |> should
      |> be_equal([
        #(
          [
            "all",
            "Discovery Error: discovery_fixtures@not_a_suite: tests() did not return a test suite: 42",
          ],
          Failed,
        ),
        #(["all", "hooked_suite", "passes"], Passed),
        #(["all", "hooked_suite", "nested", "passes too"], Passed),
      ])
      |> or_fail_with("to_suite should hold the error test and the suite")
    }),

    it("gives the module as the source of tests in nested groups", fn() {
      discover.new()
      |> from_path("discovery_fixtures/hooked_suite.gleam")
      |> discover.to_suites()
      |> list.flat_map(suite_test_sources)
      |> should
      |> be_equal([
        Some("discovery_fixtures@hooked_suite"),
        Some("discovery_fixtures@hooked_suite"),
      ])
      |> or_fail_with("every test should have the module as its source")
    }),

    it("reports a module whose beam file cannot be loaded", fn() {
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
      |> be_equal(Error(
        "discovery_fixtures@unloadable_suite: cannot load the module: badfile",
      ))
      |> or_fail_with("a module that cannot load should be an error")
    }),

    it("reports a module that cannot load once for two patterns", fn() {
      let directory = "build/discovery_broken_beams_twice"
      add_broken_beam_first_in_path(
        directory,
        "discovery_fixtures@unloadable_suite",
      )
      let result =
        discover.new()
        |> from_path("discovery_fixtures/unloadable_suite.gleam")
        |> from_path("discovery_fixtures/unloadable_*.gleam")
        |> list_modules()
      remove_from_path(directory)

      result
      |> should
      |> be_equal(Error(
        "discovery_fixtures@unloadable_suite: cannot load the module: badfile",
      ))
      |> or_fail_with("a module that cannot load should be one error")
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
  #(types.full_name(result.groups, result.name), result.status, result.failures)
}
