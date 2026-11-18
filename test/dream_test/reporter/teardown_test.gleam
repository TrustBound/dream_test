import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/teardown
import dream_test/types
import dream_test/unit.{describe, it}
import fixtures/test_results.{cleanup_failure}

pub fn tests() {
  describe("dream_test/reporters/teardown", [
    it("format gives no text when no tear-down failed", fn() {
      teardown.format([])
      |> should
      |> be_equal("")
      |> or_fail_with("no tear-down failures should give no text")
    }),

    it("format gives a header, the hook and scope, and the message", fn() {
      teardown.format([cleanup_failure()])
      |> should
      |> be_equal("Tear-down failures:\n  after_all in root\n    no cleanup\n")
      |> or_fail_with("each failure should show its hook, scope and message")
    }),

    it("format shows a hook of the whole run without a scope", fn() {
      teardown.format([
        types.TeardownFailure(
          hook: types.AfterAllSuitesHook,
          scope: [],
          message: "pool still running",
        ),
      ])
      |> should
      |> be_equal(
        "Tear-down failures:\n  after_all_suites\n    pool still running\n",
      )
      |> or_fail_with("a run-level hook should have no scope")
    }),

    it("format shows a lost scope with its set-up hook and reason", fn() {
      teardown.format([
        types.ScopeLost(
          set_up: types.BeforeAllHook,
          scope: ["root", "pool"],
          reason: "Boom",
        ),
      ])
      |> should
      |> be_equal(
        "Tear-down failures:\n  lost scope of before_all in root > pool\n    the owner process exited: Boom\n",
      )
      |> or_fail_with("a lost scope should name its set-up hook and reason")
    }),

    it("format shows a lost scope of the whole run without a scope", fn() {
      teardown.format([
        types.ScopeLost(
          set_up: types.BeforeAllSuitesHook,
          scope: [],
          reason: "Boom",
        ),
      ])
      |> should
      |> be_equal(
        "Tear-down failures:\n  lost scope of before_all_suites\n    the owner process exited: Boom\n",
      )
      |> or_fail_with("a lost run scope should have no scope names")
    }),

    it("format joins a scope of more than one name with >", fn() {
      teardown.format([
        types.TeardownFailure(
          hook: types.AfterEachHook,
          scope: ["root", "adds"],
          message: "no teardown",
        ),
      ])
      |> should
      |> be_equal(
        "Tear-down failures:\n  after_each in root > adds\n    no teardown\n",
      )
      |> or_fail_with("the scope names should be joined with >")
    }),

    it("format_in_color makes the header bold red and the hook red", fn() {
      teardown.format_in_color([cleanup_failure()])
      |> should
      |> be_equal(
        "\u{1b}[1m\u{1b}[31mTear-down failures:\u{1b}[0m\u{1b}[0m\n  \u{1b}[31mafter_all in root\u{1b}[0m\n    no cleanup\n",
      )
      |> or_fail_with("the header and the hook line should have colour")
    }),

    it("format_in_color gives no text when no tear-down failed", fn() {
      teardown.format_in_color([])
      |> should
      |> be_equal("")
      |> or_fail_with("no tear-down failures should give no text")
    }),
  ])
}
