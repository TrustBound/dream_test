import dream_test/assertions/should.{
  be_empty, contain, fail_with, have_length, not_contain, should,
}
import dream_test/types.{AssertionOk, MatchFailed, MatchOk}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Collection Matchers", [
    describe("contain", [
      it("returns MatchOk when list contains item", fn() {
        let result = [1, 2, 3] |> should() |> contain(2)

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) ->
            fail_with("contain should pass when item is in list")
        }
      }),
      it("returns MatchFailed when list does not contain item", fn() {
        let result = [1, 2, 3] |> should() |> contain(5)

        case result {
          MatchFailed(_) -> AssertionOk
          MatchOk(_) ->
            fail_with("contain should fail when item is not in list")
        }
      }),
    ]),
    describe("not_contain", [
      it("returns MatchOk when list does not contain item", fn() {
        let result = [1, 2, 3] |> should() |> not_contain(5)

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) ->
            fail_with("not_contain should pass when item is not in list")
        }
      }),
      it("returns MatchFailed when list contains item", fn() {
        let result = [1, 2, 3] |> should() |> not_contain(2)

        case result {
          MatchFailed(_) -> AssertionOk
          MatchOk(_) ->
            fail_with("not_contain should fail when item is in list")
        }
      }),
    ]),
    describe("have_length", [
      it("returns MatchOk when list has expected length", fn() {
        let result = [1, 2, 3] |> should() |> have_length(3)

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) ->
            fail_with("have_length should pass for correct length")
        }
      }),
      it("returns MatchFailed when list length differs", fn() {
        let result = [1, 2, 3] |> should() |> have_length(5)

        case result {
          MatchFailed(_) -> AssertionOk
          MatchOk(_) ->
            fail_with("have_length should fail for incorrect length")
        }
      }),
      it("works with empty list", fn() {
        let result = [] |> should() |> have_length(0)

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) -> fail_with("have_length should work with empty list")
        }
      }),
    ]),
    describe("be_empty", [
      it("returns MatchOk when list is empty", fn() {
        let result = [] |> should() |> be_empty()

        case result {
          MatchOk(_) -> AssertionOk
          MatchFailed(_) -> fail_with("be_empty should pass for empty list")
        }
      }),
      it("returns MatchFailed when list is not empty", fn() {
        let result = [1, 2, 3] |> should() |> be_empty()

        case result {
          MatchFailed(_) -> AssertionOk
          MatchOk(_) -> fail_with("be_empty should fail for non-empty list")
        }
      }),
    ]),
  ])
}
