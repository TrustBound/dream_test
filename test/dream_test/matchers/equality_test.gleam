import dream_test/assertions/should.{equal, not_equal, or_fail_with, should}
import dream_test/unit.{describe, group, it}
import matchers/be_match_failed.{be_match_failed}
import matchers/be_match_ok.{be_match_ok}

pub fn tests() {
  describe("Equality Matchers", [
    group("equal", [
      it("returns MatchOk when values match", fn(_) {
        5
        |> should()
        |> equal(5)
        |> should()
        |> be_match_ok()
        |> or_fail_with("equal should pass for matching values")
      }),
      it("returns MatchFailed when values differ", fn(_) {
        5
        |> should()
        |> equal(10)
        |> should()
        |> be_match_failed()
        |> or_fail_with("equal should fail for non-matching values")
      }),
      it("works with strings", fn(_) {
        "hello"
        |> should()
        |> equal("hello")
        |> should()
        |> be_match_ok()
        |> or_fail_with("equal should work with strings")
      }),
      it("works with lists", fn(_) {
        [1, 2, 3]
        |> should()
        |> equal([1, 2, 3])
        |> should()
        |> be_match_ok()
        |> or_fail_with("equal should work with lists")
      }),
    ]),
    group("not_equal", [
      it("returns MatchOk when values differ", fn(_) {
        5
        |> should()
        |> not_equal(10)
        |> should()
        |> be_match_ok()
        |> or_fail_with("not_equal should pass for different values")
      }),
      it("returns MatchFailed when values match", fn(_) {
        5
        |> should()
        |> not_equal(5)
        |> should()
        |> be_match_failed()
        |> or_fail_with("not_equal should fail for matching values")
      }),
    ]),
  ])
}
