import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/matchers/option as option_matcher
import dream_test/types.{AssertionFailure, MatchFailed, MatchOk, OptionFailure}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}
import matchers/prior_failure.{prior_failure}

pub fn tests() {
  describe("dream_test/matchers/option", [
    it("be_some passes for Some", fn() {
      Some(123)
      |> should
      |> option_matcher.be_some()
      |> or_fail_with("Some(123) should be some")
    }),

    it("be_some unwraps the inner value", fn() {
      Some(123)
      |> should
      |> option_matcher.be_some()
      |> should
      |> be_equal(MatchOk(123))
      |> or_fail_with("be_some should give the inner value")
    }),

    it("be_some reports an OptionFailure for None", fn() {
      None
      |> should
      |> option_matcher.be_some()
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_some",
          message: "",
          payload: Some(OptionFailure(actual: "None", expected_some: True)),
        )),
      )
      |> or_fail_with("be_some should fail for None")
    }),

    it("be_some passes an earlier failure through", fn() {
      prior_failure()
      |> option_matcher.be_some()
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_some should keep the earlier failure")
    }),

    it("be_none passes for None", fn() {
      None
      |> should
      |> option_matcher.be_none()
      |> or_fail_with("None should be none")
    }),

    it("be_none reports an OptionFailure for Some", fn() {
      Some("x")
      |> should
      |> option_matcher.be_none()
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_none",
          message: "",
          payload: Some(OptionFailure(
            actual: "Some(\"x\")",
            expected_some: False,
          )),
        )),
      )
      |> or_fail_with("be_none should fail for Some")
    }),

    it("be_none passes an earlier failure through", fn() {
      prior_failure()
      |> option_matcher.be_none()
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_none should keep the earlier failure")
    }),
  ])
}
