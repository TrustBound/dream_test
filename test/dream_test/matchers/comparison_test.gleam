import dream_test/assertions/should.{
  be_at_least, be_at_most, be_between, be_greater_than, be_in_range,
  be_less_than, or_fail_with, should,
}
import dream_test/unit.{describe, group, it}
import matchers/be_match_failed_result.{be_match_failed_result}
import matchers/be_match_ok_result.{be_match_ok_result}

pub fn tests() {
  describe("Comparison Matchers", [
    group("be_greater_than", [
      it("returns MatchOk when value is greater", fn(_) {
        10
        |> should()
        |> be_greater_than(5)
        |> be_match_ok_result()
        |> or_fail_with("be_greater_than should pass when value is greater")
      }),
      it("returns MatchFailed when value is not greater", fn(_) {
        5
        |> should()
        |> be_greater_than(10)
        |> be_match_failed_result()
        |> or_fail_with("be_greater_than should fail when value is not greater")
      }),
    ]),

    group("be_less_than", [
      it("returns MatchOk when value is less", fn(_) {
        5
        |> should()
        |> be_less_than(10)
        |> be_match_ok_result()
        |> or_fail_with("be_less_than should pass when value is less")
      }),
      it("returns MatchFailed when value is not less", fn(_) {
        10
        |> should()
        |> be_less_than(5)
        |> be_match_failed_result()
        |> or_fail_with("be_less_than should fail when value is not less")
      }),
    ]),

    group("be_at_least", [
      it("returns MatchOk when value equals minimum", fn(_) {
        10
        |> should()
        |> be_at_least(10)
        |> be_match_ok_result()
        |> or_fail_with("be_at_least should pass for equal")
      }),
      it("returns MatchFailed when value is below minimum", fn(_) {
        9
        |> should()
        |> be_at_least(10)
        |> be_match_failed_result()
        |> or_fail_with("be_at_least should fail when below")
      }),
    ]),

    group("be_at_most", [
      it("returns MatchOk when value equals maximum", fn(_) {
        10
        |> should()
        |> be_at_most(10)
        |> be_match_ok_result()
        |> or_fail_with("be_at_most should pass for equal")
      }),
      it("returns MatchFailed when value is above maximum", fn(_) {
        11
        |> should()
        |> be_at_most(10)
        |> be_match_failed_result()
        |> or_fail_with("be_at_most should fail when above")
      }),
    ]),

    group("be_between", [
      it("returns MatchOk when value is between inclusive bounds", fn(_) {
        5
        |> should()
        |> be_between(1, 10)
        |> be_match_ok_result()
        |> or_fail_with("be_between should pass inside range")
      }),
      it("returns MatchFailed when value is outside bounds", fn(_) {
        0
        |> should()
        |> be_between(1, 10)
        |> be_match_failed_result()
        |> or_fail_with("be_between should fail outside range")
      }),
    ]),

    group("be_in_range", [
      it("returns MatchOk when value is inside range", fn(_) {
        5
        |> should()
        |> be_in_range(1, 10)
        |> be_match_ok_result()
        |> or_fail_with("be_in_range should pass inside range")
      }),
      it("returns MatchFailed when value is outside range", fn(_) {
        11
        |> should()
        |> be_in_range(1, 10)
        |> be_match_failed_result()
        |> or_fail_with("be_in_range should fail outside range")
      }),
    ]),
  ])
}
