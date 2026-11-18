import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/list
import gleam/option.{None}

pub fn tests() {
  describe("dream_test/types", [
    it("to_assertion_result converts match results to assertion results", fn() {
      types.to_assertion_result(types.MatchOk(1))
      |> should
      |> be_equal(types.AssertionOk)
      |> or_fail_with("MatchOk should map to AssertionOk")
    }),

    it("to_assertion_result preserves failures", fn() {
      let failure =
        types.AssertionFailure(operator: "op", message: "msg", payload: None)

      types.to_assertion_result(types.MatchFailed(failure))
      |> should
      |> be_equal(types.AssertionFailed(failure))
      |> or_fail_with("MatchFailed should map to AssertionFailed(failure)")
    }),

    it("root builds a Root with a top-level Group", fn() {
      let suite = types.root("r", Nil, [])
      let types.Root(seed: seed, name: _, tags: _, children: _) = suite

      seed
      |> should
      |> be_equal(Nil)
      |> or_fail_with("seed should be preserved")
    }),

    it("root keeps the name, no tags and the children", fn() {
      let suite = types.root("r", Nil, [])

      #(suite.name, suite.tags, suite.children)
      |> should
      |> be_equal(#("r", [], []))
      |> or_fail_with("expected the name r, no tags and no children")
    }),

    it("full_name gives the group names, then the test name", fn() {
      types.full_name(["Cart", "totals"], "adds tax")
      |> should
      |> be_equal(["Cart", "totals", "adds tax"])
      |> or_fail_with("full_name should end with the test name")
    }),

    it("full_name gives the test name alone for no groups", fn() {
      types.full_name([], "adds tax")
      |> should
      |> be_equal(["adds tax"])
      |> or_fail_with("full_name should hold only the test name")
    }),

    it("status_from_failures returns Passed for empty failures", fn() {
      types.status_from_failures([])
      |> should
      |> be_equal(types.Passed)
      |> or_fail_with("empty failures should be Passed")
    }),

    it("status_from_failures returns Failed for non-empty failures", fn() {
      let failure =
        types.AssertionFailure(operator: "op", message: "msg", payload: None)

      types.status_from_failures([failure])
      |> should
      |> be_equal(types.Failed)
      |> or_fail_with("non-empty failures should be Failed")
    }),

    it("run_report keeps the tests", fn() {
      types.run_report(tests: [passed_result()], teardown_failures: [])
      |> types.report_tests
      |> should
      |> be_equal([passed_result()])
      |> or_fail_with("report_tests should give the tests")
    }),

    it("run_report keeps the tear-down failures", fn() {
      types.run_report(tests: [], teardown_failures: [cleanup_failure()])
      |> types.report_teardown_failures
      |> should
      |> be_equal([cleanup_failure()])
      |> or_fail_with("report_teardown_failures should give the failures")
    }),

    it("failed is False when every test passed and no tear-down failed", fn() {
      types.run_report(tests: [passed_result()], teardown_failures: [])
      |> types.failed
      |> should
      |> be_equal(False)
      |> or_fail_with("a clean run should not fail")
    }),

    it("failed is True for a tear-down failure only", fn() {
      types.run_report(tests: [passed_result()], teardown_failures: [
        cleanup_failure(),
      ])
      |> types.failed
      |> should
      |> be_equal(True)
      |> or_fail_with("a tear-down failure should fail the run")
    }),

    it("failed is True for a test that failed", fn() {
      types.run_report(
        tests: [types.TestResult(..passed_result(), status: types.TimedOut)],
        teardown_failures: [],
      )
      |> types.failed
      |> should
      |> be_equal(True)
      |> or_fail_with("a timed-out test should fail the run")
    }),

    it("is_failure is True for Failed, SetupFailed and TimedOut", fn() {
      [
        types.Passed,
        types.Failed,
        types.Skipped,
        types.Pending,
        types.TimedOut,
        types.SetupFailed,
      ]
      |> list.filter(types.is_failure)
      |> should
      |> be_equal([types.Failed, types.TimedOut, types.SetupFailed])
      |> or_fail_with("only the three failure statuses should be failures")
    }),

    it("teardown_hook_name gives the name of each tear-down hook", fn() {
      [
        types.AfterEachTestHook,
        types.AfterEachHook,
        types.AfterAllHook,
        types.AfterEachSuiteHook,
        types.AfterAllSuitesHook,
      ]
      |> list.map(types.teardown_hook_name)
      |> should
      |> be_equal([
        "after_each_test", "after_each", "after_all", "after_each_suite",
        "after_all_suites",
      ])
      |> or_fail_with("each hook should have its builder name")
    }),

    it("set_up_hook_name gives the name of each set-up hook of a scope", fn() {
      [
        types.BeforeAllHook,
        types.BeforeEachSuiteHook,
        types.BeforeAllSuitesHook,
      ]
      |> list.map(types.set_up_hook_name)
      |> should
      |> be_equal(["before_all", "before_each_suite", "before_all_suites"])
      |> or_fail_with("each set-up hook should have its builder name")
    }),

    it("setup_stopped_failure names the set-up hook, scope and reason", fn() {
      [
        types.setup_stopped_failure(
          set_up: types.BeforeAllHook,
          scope: ["root", "pool"],
          reason: "Boom",
        ),
        types.setup_stopped_failure(
          set_up: types.BeforeAllSuitesHook,
          scope: [],
          reason: "killed",
        ),
      ]
      |> list.map(fn(failure) { #(failure.operator, failure.message) })
      |> should
      |> be_equal([
        #(
          "before_all",
          "not run: the set-up from before_all in \"root > pool\" stopped (Boom)",
        ),
        #(
          "before_all_suites",
          "not run: the set-up from before_all_suites stopped (killed)",
        ),
      ])
      |> or_fail_with("the failure should say why the test was not run")
    }),
  ])
}

fn passed_result() -> types.TestResult {
  types.TestResult(
    name: "adds",
    groups: ["root"],
    status: types.Passed,
    duration_ms: 0,
    tags: [],
    failures: [],
    kind: types.Unit,
  )
}

fn cleanup_failure() -> types.TeardownFailure {
  types.TeardownFailure(
    hook: types.AfterAllHook,
    scope: ["root"],
    message: "no cleanup",
  )
}
