import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/option.{None}

pub fn tests() {
  describe("dream_test/assertions/should", [
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
      |> equal(1)
      |> or_fail_with("should be 1")
    }),

    it("fail_with produces AssertionFailed with the message", fn() {
      should.fail_with("nope")
      |> should
      |> equal(
        types.AssertionFailed(types.AssertionFailure(
          operator: "fail_with",
          message: "nope",
          payload: None,
        )),
      )
      |> or_fail_with("fail_with should create the expected failure")
    }),

    it("succeed produces AssertionOk", fn() {
      should.succeed()
      |> should
      |> equal(types.AssertionOk)
      |> or_fail_with("succeed should return AssertionOk")
    }),
  ])
}
