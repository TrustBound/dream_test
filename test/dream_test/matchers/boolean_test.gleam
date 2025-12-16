import dream_test/assertions/should.{be_false, be_true, or_fail_with, should}
import dream_test/unit.{describe, group, it}
import matchers/be_match_failed_result.{be_match_failed_result}
import matchers/be_match_ok_result.{be_match_ok_result}

pub fn tests() {
  describe("Boolean Matchers", [
    group("be_true", [
      it("returns MatchOk when value is True", fn(_) {
        True
        |> should()
        |> be_true()
        |> be_match_ok_result()
        |> or_fail_with("be_true should pass for True")
      }),
      it("returns MatchFailed when value is False", fn(_) {
        False
        |> should()
        |> be_true()
        |> be_match_failed_result()
        |> or_fail_with("be_true should fail for False")
      }),
    ]),
    group("be_false", [
      it("returns MatchOk when value is False", fn(_) {
        False
        |> should()
        |> be_false()
        |> be_match_ok_result()
        |> or_fail_with("be_false should pass for False")
      }),
      it("returns MatchFailed when value is True", fn(_) {
        True
        |> should()
        |> be_false()
        |> be_match_failed_result()
        |> or_fail_with("be_false should fail for True")
      }),
    ]),
  ])
}
