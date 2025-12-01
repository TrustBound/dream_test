import dream_test/assertions/should.{
  be_at_least, be_at_most, be_between, be_greater_than, be_in_range,
  be_less_than, fail_with, should,
}
import dream_test/types.{AssertionOk, MatchFailed, MatchOk}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Comparison Matchers", [
    describe("be_greater_than", [
      it("returns MatchOk when value is greater", fn() {
        let result = 10 |> should() |> be_greater_than(5)

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) ->
            fail_with("be_greater_than should pass when value is greater")
        }
      }),
      it("returns MatchFailed when value is not greater", fn() {
        let result = 5 |> should() |> be_greater_than(10)

        case result {
          MatchFailed(_) -> AssertionOk
          MatchOk(_) ->
            fail_with("be_greater_than should fail when value is not greater")
        }
      }),
    ]),
    describe("be_less_than", [
      it("returns MatchOk when value is less", fn() {
        let result = 5 |> should() |> be_less_than(10)

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) ->
            fail_with("be_less_than should pass when value is less")
        }
      }),
      it("returns MatchFailed when value is not less", fn() {
        let result = 10 |> should() |> be_less_than(5)

        case result {
          MatchFailed(_) -> AssertionOk
          MatchOk(_) ->
            fail_with("be_less_than should fail when value is not less")
        }
      }),
    ]),
    describe("be_at_least", [
      it("returns MatchOk when value is greater", fn() {
        let result = 10 |> should() |> be_at_least(5)

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) ->
            fail_with("be_at_least should pass when value is greater")
        }
      }),
      it("returns MatchOk when value is equal", fn() {
        let result = 5 |> should() |> be_at_least(5)

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) ->
            fail_with("be_at_least should pass when value is equal")
        }
      }),
      it("returns MatchFailed when value is less", fn() {
        let result = 3 |> should() |> be_at_least(5)

        case result {
          MatchFailed(_) -> AssertionOk
          MatchOk(_) -> fail_with("be_at_least should fail when value is less")
        }
      }),
    ]),
    describe("be_at_most", [
      it("returns MatchOk when value is less", fn() {
        let result = 5 |> should() |> be_at_most(10)

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) ->
            fail_with("be_at_most should pass when value is less")
        }
      }),
      it("returns MatchOk when value is equal", fn() {
        let result = 10 |> should() |> be_at_most(10)

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) ->
            fail_with("be_at_most should pass when value is equal")
        }
      }),
      it("returns MatchFailed when value is greater", fn() {
        let result = 15 |> should() |> be_at_most(10)

        case result {
          MatchFailed(_) -> AssertionOk
          MatchOk(_) ->
            fail_with("be_at_most should fail when value is greater")
        }
      }),
    ]),
    describe("be_between", [
      it("returns MatchOk when value is between min and max", fn() {
        let result = 7 |> should() |> be_between(5, 10)

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) ->
            fail_with("be_between should pass when value is in range")
        }
      }),
      it("returns MatchFailed when value equals min", fn() {
        let result = 5 |> should() |> be_between(5, 10)

        case result {
          MatchFailed(_) -> AssertionOk
          MatchOk(_) ->
            fail_with("be_between should fail when value equals min")
        }
      }),
      it("returns MatchFailed when value equals max", fn() {
        let result = 10 |> should() |> be_between(5, 10)

        case result {
          MatchFailed(_) -> AssertionOk
          MatchOk(_) ->
            fail_with("be_between should fail when value equals max")
        }
      }),
    ]),
    describe("be_in_range", [
      it("returns MatchOk when value is in range", fn() {
        let result = 7 |> should() |> be_in_range(5, 10)

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) ->
            fail_with("be_in_range should pass when value is in range")
        }
      }),
      it("returns MatchOk when value equals min", fn() {
        let result = 5 |> should() |> be_in_range(5, 10)

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) ->
            fail_with("be_in_range should pass when value equals min")
        }
      }),
      it("returns MatchOk when value equals max", fn() {
        let result = 10 |> should() |> be_in_range(5, 10)

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) ->
            fail_with("be_in_range should pass when value equals max")
        }
      }),
      it("returns MatchFailed when value is below range", fn() {
        let result = 3 |> should() |> be_in_range(5, 10)

        case result {
          MatchFailed(_) -> AssertionOk
          MatchOk(_) ->
            fail_with("be_in_range should fail when value is below range")
        }
      }),
    ]),
  ])
}
