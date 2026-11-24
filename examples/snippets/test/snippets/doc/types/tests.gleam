import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import gleam/list
import snippets/doc/types/allow_no_tests
import snippets/doc/types/assertion_result
import snippets/doc/types/call
import snippets/doc/types/callback
import snippets/doc/types/failed
import snippets/doc/types/failed_with_no_tests
import snippets/doc/types/full_name
import snippets/doc/types/hook_failure
import snippets/doc/types/is_failure
import snippets/doc/types/match_result
import snippets/doc/types/module
import snippets/doc/types/report_hook_failures
import snippets/doc/types/report_reporter_crashes
import snippets/doc/types/report_tests
import snippets/doc/types/reporter_crash
import snippets/doc/types/run_report
import snippets/doc/types/setup_hook_name
import snippets/doc/types/status
import snippets/doc/types/status_from_failures
import snippets/doc/types/teardown_hook_name
import snippets/doc/types/test_result
import snippets/doc/types/to_assertion_result
import snippets/doc/types/tree
import snippets/doc/types/tree_function

pub fn tests() {
  describe("Doc examples: types", [
    it("empty_math_tree has the name, the context and no tags", fn() {
      // Act
      let math = tree_function.empty_math_tree()

      // Assert
      math
      |> should
      |> be_equal(types.Tree(initial: 0, name: "math", tags: [], tests: []))
      |> or_fail_with("expected a tree named math with context 0")
    }),
    it("be_even keeps an even number", fn() {
      // Act
      let result = module.be_even(types.MatchOk(4))

      // Assert
      result
      |> should
      |> be_equal(types.MatchOk(4))
      |> or_fail_with("expected be_even to keep 4")
    }),
    it("handles_failures marks both tests SetupFailed", fn() {
      // Act
      let statuses =
        runner.new([status.handles_failures()])
        |> runner.silent()
        |> runner.run()
        |> types.report_tests
        |> list.map(fn(test_result) { test_result.status })

      // Assert
      statuses
      |> should
      |> be_equal([types.SetupFailed, types.SetupFailed])
      |> or_fail_with("expected both tests to be SetupFailed")
    }),
    it("read_the_test_results gives one passed test", fn() {
      // Act
      let results = test_result.read_the_test_results()

      // Assert
      results
      |> list.map(fn(result) { #(result.name, result.status) })
      |> should
      |> be_equal([#("passes", types.Passed)])
      |> or_fail_with("expected one passed test")
    }),
    it("math_tree holds one test in the math group", fn() {
      // Act
      let math = tree.math_tree()

      // Assert
      #(math.name, list.length(math.tests))
      |> should
      |> be_equal(#("math", 1))
      |> or_fail_with("expected the math group with one test")
    }),
    it("two_plus_three_is_five passes", fn() {
      // Act
      let result = assertion_result.two_plus_three_is_five()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected two_plus_three_is_five to pass")
    }),
    it("some_holds_forty_two passes", fn() {
      // Act
      let result = match_result.some_holds_forty_two()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected some_holds_forty_two to pass")
    }),
    it("match_ok_becomes_assertion_ok passes", fn() {
      // Act
      let result = to_assertion_result.match_ok_becomes_assertion_ok()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected match_ok_becomes_assertion_ok to pass")
    }),
    it("no_input_ignores_the_input passes", fn() {
      // Act
      let result = callback.no_input_ignores_the_input()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected no_input_ignores_the_input to pass")
    }),
    it("with_input_gets_the_input passes", fn() {
      // Act
      let result = call.with_input_gets_the_input()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected with_input_gets_the_input to pass")
    }),
    it("groups_then_test_name passes", fn() {
      // Act
      let result = full_name.groups_then_test_name()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected groups_then_test_name to pass")
    }),
    it("no_failures_means_passed passes", fn() {
      // Act
      let result = status_from_failures.no_failures_means_passed()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected no_failures_means_passed to pass")
    }),
    it("setup_failed_is_a_failure passes", fn() {
      // Act
      let result = is_failure.setup_failed_is_a_failure()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected setup_failed_is_a_failure to pass")
    }),
    it("after_each_suite_builder_name passes", fn() {
      // Act
      let result = teardown_hook_name.after_each_suite_builder_name()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected after_each_suite_builder_name to pass")
    }),
    it("before_all_suites_builder_name passes", fn() {
      // Act
      let result = setup_hook_name.before_all_suites_builder_name()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected before_all_suites_builder_name to pass")
    }),
    it("drop_schema_failure gives the expected value", fn() {
      // Act
      let result = hook_failure.drop_schema_failure()

      // Assert
      result
      |> should
      |> be_equal(types.TeardownFailed(
        hook: types.AfterAllHook,
        path: ["Database"],
        message: "could not drop the test schema",
      ))
      |> or_fail_with("expected drop_schema_failure to give the expected value")
    }),
    it("second_reporter_crash gives the expected value", fn() {
      // Act
      let result = reporter_crash.second_reporter_crash()

      // Assert
      result
      |> should
      |> be_equal(types.ReporterCrash(position: 2, reason: "error:badarith"))
      |> or_fail_with(
        "expected second_reporter_crash to give the expected value",
      )
    }),
    it("empty_run_fails passes", fn() {
      // Act
      let result = run_report.empty_run_fails()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected empty_run_fails to pass")
    }),
    it("allowed_empty_run_passes passes", fn() {
      // Act
      let result = allow_no_tests.allowed_empty_run_passes()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected allowed_empty_run_passes to pass")
    }),
    it("empty_run_failed_with_no_tests passes", fn() {
      // Act
      let result = failed_with_no_tests.empty_run_failed_with_no_tests()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected empty_run_failed_with_no_tests to pass")
    }),
    it("empty_run_has_no_tests passes", fn() {
      // Act
      let result = report_tests.empty_run_has_no_tests()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected empty_run_has_no_tests to pass")
    }),
    it("empty_run_has_no_hook_failures passes", fn() {
      // Act
      let result = report_hook_failures.empty_run_has_no_hook_failures()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected empty_run_has_no_hook_failures to pass")
    }),
    it("empty_run_has_no_crashed_reporters passes", fn() {
      // Act
      let result = report_reporter_crashes.empty_run_has_no_crashed_reporters()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected empty_run_has_no_crashed_reporters to pass")
    }),
    it("teardown_failure_fails_the_run passes", fn() {
      // Act
      let result = failed.teardown_failure_fails_the_run()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected teardown_failure_fails_the_run to pass")
    }),
  ])
}
