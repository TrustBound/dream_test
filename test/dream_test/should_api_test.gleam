import dream_test/matchers.{be_equal, fail_with, or_fail_with, should, succeed}
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/option.{None}

pub fn tests() {
  describe("dream_test/matchers", [
    it("should wraps values in a MatchOk", fn() {
      case should(123) {
        types.MatchOk(123) -> Ok(types.AssertionOk)
        _ ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "should",
              message: "expected MatchOk(123)",
              payload: None,
            )),
          )
      }
    }),

    it("or_fail_with turns MatchOk into Ok(AssertionOk)", fn() {
      should(1)
      |> be_equal(1)
      |> or_fail_with("should be 1")
    }),

    it("fail_with produces AssertionFailed with the message", fn() {
      fail_with("nope")
      |> should
      |> be_equal(
        types.AssertionFailed(types.AssertionFailure(
          operator: "fail_with",
          message: "nope",
          payload: None,
        )),
      )
      |> or_fail_with("fail_with should create the expected failure")
    }),

    it("succeed produces AssertionOk", fn() {
      succeed()
      |> should
      |> be_equal(types.AssertionOk)
      |> or_fail_with("succeed should return AssertionOk")
    }),
  ])
}
