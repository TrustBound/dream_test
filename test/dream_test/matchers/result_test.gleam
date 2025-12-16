import dream_test/assertions/should.{
  be_error, be_ok, equal, or_fail_with, should,
}
import dream_test/unit.{describe, group, it}
import matchers/be_match_failed_result.{be_match_failed_result}

pub fn tests() {
  describe("Result Matchers", [
    group("be_ok", [
      it("returns MatchOk with inner value when value is Ok", fn(_) {
        let result: Result(Int, String) = Ok(42)
        result
        |> should()
        |> be_ok()
        |> equal(42)
        |> or_fail_with("should equal 42")
      }),
      it("returns MatchFailed when value is Error", fn(_) {
        let result: Result(Int, String) = Error("failed")
        result
        |> should()
        |> be_ok()
        |> be_match_failed_result()
        |> or_fail_with("be_ok should fail for Error")
      }),
    ]),

    group("be_error", [
      it("returns MatchOk with error value when value is Error", fn(_) {
        let result: Result(Int, String) = Error("failed")
        result
        |> should()
        |> be_error()
        |> equal("failed")
        |> or_fail_with("should equal 'failed'")
      }),
      it("returns MatchFailed when value is Ok", fn(_) {
        let result: Result(Int, String) = Ok(42)
        result
        |> should()
        |> be_error()
        |> be_match_failed_result()
        |> or_fail_with("be_error should fail for Ok")
      }),
    ]),

    group("chaining", [
      it("chains be_ok with equal", fn(_) {
        let result: Result(Int, String) = Ok(42)
        result
        |> should()
        |> be_ok()
        |> equal(42)
        |> or_fail_with("chaining be_ok |> equal should pass")
      }),
      it("fails chain if inner value differs", fn(_) {
        let result: Result(Int, String) = Ok(42)
        result
        |> should()
        |> be_ok()
        |> equal(100)
        |> be_match_failed_result()
        |> or_fail_with("chaining be_ok |> equal should fail if value differs")
      }),
      it("fails chain if value is Error", fn(_) {
        let result: Result(Int, String) = Error("failed")
        result
        |> should()
        |> be_ok()
        |> equal(42)
        |> be_match_failed_result()
        |> or_fail_with("chaining be_ok |> equal should fail for Error")
      }),
    ]),
  ])
}
