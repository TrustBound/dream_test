import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/teardown
import dream_test/types
import dream_test/unit.{describe, it}
import fixtures/test_results.{cleanup_failure, make_test}

pub fn tests() {
  describe("dream_test/reporters/teardown", [
    it("format gives no text when no tear-down failed", fn() {
      teardown.format(failures_report([]))
      |> should
      |> be_equal("")
      |> or_fail_with("no tear-down failures should give no text")
    }),

    it("format gives a header, the hook and scope, and the message", fn() {
      teardown.format(failures_report([cleanup_failure()]))
      |> should
      |> be_equal("Tear-down failures:\n  after_all in root\n    no cleanup\n")
      |> or_fail_with("each failure should show its hook, scope and message")
    }),

    it("format shows a hook of the whole run without a scope", fn() {
      teardown.format(
        failures_report([
          types.TeardownFailure(
            hook: types.AfterAllSuitesHook,
            scope: [],
            message: "pool still running",
          ),
        ]),
      )
      |> should
      |> be_equal(
        "Tear-down failures:\n  after_all_suites\n    pool still running\n",
      )
      |> or_fail_with("a run-level hook should have no scope")
    }),

    it("format shows a stopped set-up without a count when all tests ran", fn() {
      teardown.format(
        failures_report([
          types.SetupStopped(
            set_up: types.BeforeAllHook,
            scope: ["root", "pool"],
            reason: "Boom",
          ),
        ]),
      )
      |> should
      |> be_equal(
        "Tear-down failures:\n  before_all in \"root > pool\" stopped: the process that keeps its set-up alive exited with Boom.\n",
      )
      |> or_fail_with("a stopped set-up should name its set-up hook and reason")
    }),

    it("format counts the tests that a stopped set-up did not run", fn() {
      teardown.format(
        types.run_report(
          tests: [
            make_test("a", types.Passed),
            not_run_test("b", types.BeforeAllHook, ["root"]),
            not_run_test("c", types.BeforeAllHook, ["root"]),
            not_run_test("d", types.BeforeAllHook, ["other"]),
          ],
          teardown_failures: [
            types.SetupStopped(
              set_up: types.BeforeAllHook,
              scope: ["root"],
              reason: "Boom",
            ),
          ],
        ),
      )
      |> should
      |> be_equal(
        "Tear-down failures:\n  before_all in \"root\" stopped: the process that keeps its set-up alive exited with Boom.\n    2 tests in \"root\" that had not started were not run.\n",
      )
      |> or_fail_with("only the tests not run by this set-up should count")
    }),

    it("format says test, not tests, for one test that was not run", fn() {
      teardown.format(
        types.run_report(
          tests: [not_run_test("b", types.BeforeEachSuiteHook, ["suite"])],
          teardown_failures: [
            types.SetupStopped(
              set_up: types.BeforeEachSuiteHook,
              scope: ["suite"],
              reason: "Boom",
            ),
          ],
        ),
      )
      |> should
      |> be_equal(
        "Tear-down failures:\n  before_each_suite in \"suite\" stopped: the process that keeps its set-up alive exited with Boom.\n    1 test in \"suite\" that had not started was not run.\n",
      )
      |> or_fail_with("one test should be singular")
    }),

    it("format shows a stopped set-up of the whole run without a scope", fn() {
      teardown.format(
        types.run_report(
          tests: [
            not_run_test("a", types.BeforeAllSuitesHook, []),
            not_run_test("b", types.BeforeAllSuitesHook, []),
          ],
          teardown_failures: [
            types.SetupStopped(
              set_up: types.BeforeAllSuitesHook,
              scope: [],
              reason: "Boom",
            ),
          ],
        ),
      )
      |> should
      |> be_equal(
        "Tear-down failures:\n  before_all_suites stopped: the process that keeps its set-up alive exited with Boom.\n    2 tests that had not started were not run.\n",
      )
      |> or_fail_with("a stopped run set-up should have no scope names")
    }),

    it("format joins a scope of more than one name with >", fn() {
      teardown.format(
        failures_report([
          types.TeardownFailure(
            hook: types.AfterEachHook,
            scope: ["root", "adds"],
            message: "no teardown",
          ),
        ]),
      )
      |> should
      |> be_equal(
        "Tear-down failures:\n  after_each in root > adds\n    no teardown\n",
      )
      |> or_fail_with("the scope names should be joined with >")
    }),

    it("format_in_color makes the header bold red and the hook red", fn() {
      teardown.format_in_color(failures_report([cleanup_failure()]))
      |> should
      |> be_equal(
        "\u{1b}[1m\u{1b}[31mTear-down failures:\u{1b}[0m\u{1b}[0m\n  \u{1b}[31mafter_all in root\u{1b}[0m\n    no cleanup\n",
      )
      |> or_fail_with("the header and the hook line should have colour")
    }),

    it("format_in_color gives no text when no tear-down failed", fn() {
      teardown.format_in_color(failures_report([]))
      |> should
      |> be_equal("")
      |> or_fail_with("no tear-down failures should give no text")
    }),
  ])
}

fn failures_report(failures: List(types.TeardownFailure)) -> types.RunReport {
  types.run_report(tests: [], teardown_failures: failures)
}

/// A test that was not run because the set-up of `scope` stopped with
/// `Boom`.
fn not_run_test(
  name: String,
  set_up: types.SetUpHook,
  scope: List(String),
) -> types.TestResult {
  types.TestResult(..make_test(name, types.SetupFailed), failures: [
    types.setup_stopped_failure(set_up: set_up, scope: scope, reason: "Boom"),
  ])
}
