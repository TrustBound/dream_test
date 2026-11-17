import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/matchers/result
import dream_test/types.{AssertionFailure, MatchFailed, MatchOk, ResultFailure}
import dream_test/unit.{describe, it}
import gleam/option.{Some}
import matchers/prior_failure.{prior_failure}

pub fn tests() {
  describe("dream_test/matchers/result", [
    it("be_ok passes for Ok", fn() {
      Ok(1)
      |> should
      |> result.be_ok()
      |> or_fail_with("Ok(1) should be ok")
    }),

    it("be_ok unwraps the Ok value", fn() {
      Ok(1)
      |> should
      |> result.be_ok()
      |> should
      |> be_equal(MatchOk(1))
      |> or_fail_with("be_ok should give the Ok value")
    }),

    it("be_ok reports a ResultFailure for Error", fn() {
      Error("nope")
      |> should
      |> result.be_ok()
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_ok",
          message: "",
          payload: Some(ResultFailure(
            actual: "Error(\"nope\")",
            expected_ok: True,
          )),
        )),
      )
      |> or_fail_with("be_ok should fail for Error")
    }),

    it("be_ok passes an earlier failure through", fn() {
      prior_failure()
      |> result.be_ok()
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_ok should keep the earlier failure")
    }),

    it("be_error passes for Error", fn() {
      Error("nope")
      |> should
      |> result.be_error()
      |> or_fail_with("Error(\"nope\") should be error")
    }),

    it("be_error reports a ResultFailure for Ok", fn() {
      Ok(42)
      |> should
      |> result.be_error()
      |> should
      |> be_equal(
        MatchFailed(AssertionFailure(
          operator: "be_error",
          message: "",
          payload: Some(ResultFailure(actual: "Ok(42)", expected_ok: False)),
        )),
      )
      |> or_fail_with("be_error should fail for Ok")
    }),

    it("be_error passes an earlier failure through", fn() {
      prior_failure()
      |> result.be_error()
      |> should
      |> be_equal(prior_failure())
      |> or_fail_with("be_error should keep the earlier failure")
    }),
  ])
}
