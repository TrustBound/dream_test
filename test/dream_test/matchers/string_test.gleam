import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/matchers/string
import dream_test/types.{AssertionFailure, MatchFailed, StringMatchFailure}
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}
import matchers/prior_failure.{prior_failure}

pub fn tests() {
  describe("dream_test/matchers/string", [
    it("start_with passes when the prefix matches", fn() {
      "hello world"
      |> should
      |> string.start_with("hello")
      |> or_fail_with("should start with hello")
    }),

    it("end_with passes when the suffix matches", fn() {
      "hello world"
      |> should
      |> string.end_with("world")
      |> or_fail_with("should end with world")
    }),

    it("contain_string passes when substring exists", fn() {
      "hello world"
      |> should
      |> string.contain_string("lo wo")
      |> or_fail_with("should contain substring")
    }),

    it("start_with reports a missing prefix", fn() {
      "hello world"
      |> should
      |> string.start_with("world")
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "start_with",
          message: "",
          payload: Some(StringMatchFailure(
            actual: "hello world",
            pattern: "world",
            operation: "start_with",
          )),
        )),
      )
      |> or_fail_with("start_with should report the failure")
    }),

    it("start_with passes an earlier failure through", fn() {
      prior_failure()
      |> string.start_with("a")
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("start_with should keep the earlier failure")
    }),

    it("end_with reports a missing suffix", fn() {
      "hello world"
      |> should
      |> string.end_with("hello")
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "end_with",
          message: "",
          payload: Some(StringMatchFailure(
            actual: "hello world",
            pattern: "hello",
            operation: "end_with",
          )),
        )),
      )
      |> or_fail_with("end_with should report the failure")
    }),

    it("end_with passes an earlier failure through", fn() {
      prior_failure()
      |> string.end_with("a")
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("end_with should keep the earlier failure")
    }),

    it("contain_string reports a missing substring", fn() {
      "hello world"
      |> should
      |> string.contain_string("xyz")
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "contain_string",
          message: "",
          payload: Some(StringMatchFailure(
            actual: "hello world",
            pattern: "xyz",
            operation: "contain_string",
          )),
        )),
      )
      |> or_fail_with("contain_string should report the failure")
    }),

    it("contain_string passes an earlier failure through", fn() {
      prior_failure()
      |> string.contain_string("a")
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("contain_string should keep the earlier failure")
    }),

    it("match_regex passes when the pattern matches", fn() {
      "order-42"
      |> should
      |> string.match_regex("^order-[0-9]+$")
      |> or_fail_with("order-42 should match the pattern")
    }),

    it("match_regex reports a value that does not match", fn() {
      "order-x"
      |> should
      |> string.match_regex("^order-[0-9]+$")
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "match_regex",
          message: "",
          payload: Some(StringMatchFailure(
            actual: "order-x",
            pattern: "^order-[0-9]+$",
            operation: "match_regex",
          )),
        )),
      )
      |> or_fail_with("match_regex should report the failure")
    }),

    it("match_regex reports an invalid pattern", fn() {
      "anything"
      |> should
      |> string.match_regex("(")
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "match_regex",
          message: "invalid regex pattern: \"(\" CompileError(\"missing closing parenthesis\", 1)",
          payload: None,
        )),
      )
      |> or_fail_with("match_regex should report the invalid pattern")
    }),

    it("match_regex passes an earlier failure through", fn() {
      prior_failure()
      |> string.match_regex("a")
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("match_regex should keep the earlier failure")
    }),
  ])
}
