import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/teardown
import dream_test/types
import dream_test/unit.{describe, it}
import fixtures/test_results.{cleanup_failure}

pub fn tests() {
  describe("dream_test/reporters/teardown", [
    it("format gives no text when no teardown failed", fn() {
      teardown.format([])
      |> should
      |> be_equal("")
      |> or_fail_with("no teardown failures should give no text")
    }),

    it("format gives a header, the hook and scope, and the message", fn() {
      teardown.format([cleanup_failure()])
      |> should
      |> be_equal(
        "Setup and teardown failures:\n  after_all in root\n    no cleanup\n",
      )
      |> or_fail_with("each failure should show its hook, scope and message")
    }),

    it("format shows a hook of the whole run without a scope", fn() {
      teardown.format([
        types.TeardownFailure(
          hook: types.AfterAllSuitesHook,
          groups: [],
          message: "pool still running",
        ),
      ])
      |> should
      |> be_equal(
        "Setup and teardown failures:\n  after_all_suites\n    pool still running\n",
      )
      |> or_fail_with("a run-level hook should have no scope")
    }),

    it("format shows a stopped setup without a list when all tests ran", fn() {
      teardown.format([
        types.SetupStopped(
          setup: types.BeforeAllHook,
          groups: ["root", "pool"],
          reason: "Boom",
          not_run: [],
        ),
      ])
      |> should
      |> be_equal(
        "Setup and teardown failures:\n  before_all in \"root > pool\" stopped: the process that keeps its setup alive exited with Boom.\n",
      )
      |> or_fail_with("a stopped setup should name its setup hook and reason")
    }),

    it("format lists the tests that a stopped setup did not run", fn() {
      teardown.format([
        types.SetupStopped(
          setup: types.BeforeAllHook,
          groups: ["root"],
          reason: "Boom",
          not_run: [["root", "b"], ["root", "c"]],
        ),
      ])
      |> should
      |> be_equal(
        "Setup and teardown failures:\n  before_all in \"root\" stopped: the process that keeps its setup alive exited with Boom.\n    These tests had not started and were not run:\n      root > b\n      root > c\n",
      )
      |> or_fail_with("each test that was not run should have its full name")
    }),

    it("format shows a stopped setup of the whole run without a scope", fn() {
      teardown.format([
        types.SetupStopped(
          setup: types.BeforeAllSuitesHook,
          groups: [],
          reason: "Boom",
          not_run: [["suite", "a"]],
        ),
      ])
      |> should
      |> be_equal(
        "Setup and teardown failures:\n  before_all_suites stopped: the process that keeps its setup alive exited with Boom.\n    These tests had not started and were not run:\n      suite > a\n",
      )
      |> or_fail_with("a stopped run setup should have no scope names")
    }),

    it("format joins a scope of more than one name with >", fn() {
      teardown.format([
        types.TeardownFailure(
          hook: types.AfterEachHook,
          groups: ["root", "adds"],
          message: "no teardown",
        ),
      ])
      |> should
      |> be_equal(
        "Setup and teardown failures:\n  after_each in root > adds\n    no teardown\n",
      )
      |> or_fail_with("the scope names should be joined with >")
    }),

    it("format_in_color makes the header bold red and the hook red", fn() {
      teardown.format_in_color([cleanup_failure()])
      |> should
      |> be_equal(
        "\u{1b}[1m\u{1b}[31mSetup and teardown failures:\u{1b}[0m\u{1b}[0m\n  \u{1b}[31mafter_all in root\u{1b}[0m\n    no cleanup\n",
      )
      |> or_fail_with("the header and the hook line should have colour")
    }),

    it("format_in_color makes a stopped setup red and its list plain", fn() {
      teardown.format_in_color([
        types.SetupStopped(
          setup: types.BeforeAllHook,
          groups: ["root"],
          reason: "Boom",
          not_run: [["root", "b"]],
        ),
      ])
      |> should
      |> be_equal(
        "\u{1b}[1m\u{1b}[31mSetup and teardown failures:\u{1b}[0m\u{1b}[0m\n  \u{1b}[31mbefore_all in \"root\" stopped: the process that keeps its setup alive exited with Boom.\u{1b}[0m\n    These tests had not started and were not run:\n      root > b\n",
      )
      |> or_fail_with("only the first line of the failure should have colour")
    }),

    it("format_in_color gives no text when no teardown failed", fn() {
      teardown.format_in_color([])
      |> should
      |> be_equal("")
      |> or_fail_with("no teardown failures should give no text")
    }),
  ])
}
