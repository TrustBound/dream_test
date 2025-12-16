import dream_test/assertions/should.{
  be_empty, contain, have_length, not_contain, or_fail_with, should,
}
import dream_test/unit.{describe, group, it}
import matchers/be_match_failed.{be_match_failed}
import matchers/be_match_ok.{be_match_ok}

pub fn tests() {
  describe("Collection Matchers", [
    group("contain", [
      it("returns MatchOk when list contains item", fn(_) {
        [1, 2, 3]
        |> should()
        |> contain(2)
        |> should()
        |> be_match_ok()
        |> or_fail_with("contain should pass when item is in list")
      }),
      it("returns MatchFailed when list does not contain item", fn(_) {
        [1, 2, 3]
        |> should()
        |> contain(5)
        |> should()
        |> be_match_failed()
        |> or_fail_with("contain should fail when item is not in list")
      }),
    ]),
    group("not_contain", [
      it("returns MatchOk when list does not contain item", fn(_) {
        [1, 2, 3]
        |> should()
        |> not_contain(5)
        |> should()
        |> be_match_ok()
        |> or_fail_with("not_contain should pass when item is not in list")
      }),
      it("returns MatchFailed when list contains item", fn(_) {
        [1, 2, 3]
        |> should()
        |> not_contain(2)
        |> should()
        |> be_match_failed()
        |> or_fail_with("not_contain should fail when item is in list")
      }),
    ]),
    group("have_length", [
      it("returns MatchOk when list has expected length", fn(_) {
        [1, 2, 3]
        |> should()
        |> have_length(3)
        |> should()
        |> be_match_ok()
        |> or_fail_with("have_length should pass for correct length")
      }),
      it("returns MatchFailed when list length differs", fn(_) {
        [1, 2, 3]
        |> should()
        |> have_length(5)
        |> should()
        |> be_match_failed()
        |> or_fail_with("have_length should fail for incorrect length")
      }),
      it("works with empty list", fn(_) {
        []
        |> should()
        |> have_length(0)
        |> should()
        |> be_match_ok()
        |> or_fail_with("have_length should work with empty list")
      }),
    ]),
    group("be_empty", [
      it("returns MatchOk when list is empty", fn(_) {
        []
        |> should()
        |> be_empty()
        |> should()
        |> be_match_ok()
        |> or_fail_with("be_empty should pass for empty list")
      }),
      it("returns MatchFailed when list is not empty", fn(_) {
        [1, 2, 3]
        |> should()
        |> be_empty()
        |> should()
        |> be_match_failed()
        |> or_fail_with("be_empty should fail for non-empty list")
      }),
    ]),
  ])
}
