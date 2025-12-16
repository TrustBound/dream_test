import dream_test/assertions/should.{
  be_none, be_some, equal, or_fail_with, should,
}
import dream_test/unit.{describe, group, it}
import gleam/option.{None, Some}
import matchers/be_match_failed_result.{be_match_failed_result}

pub fn tests() {
  describe("Option Matchers", [
    group("be_some", [
      it("returns MatchOk with inner value when value is Some", fn(_) {
        Some(42)
        |> should()
        |> be_some()
        |> equal(42)
        |> or_fail_with("should contain 42")
      }),
      it("returns MatchFailed when value is None", fn(_) {
        None
        |> should()
        |> be_some()
        |> be_match_failed_result()
        |> or_fail_with("be_some should fail for None")
      }),
    ]),

    group("be_none", [
      it("returns MatchOk when value is None", fn(_) {
        None
        |> should()
        |> be_none()
        |> or_fail_with("be_none should pass for None")
      }),
      it("returns MatchFailed when value is Some", fn(_) {
        Some(42)
        |> should()
        |> be_none()
        |> be_match_failed_result()
        |> or_fail_with("be_none should fail for Some")
      }),
    ]),

    group("chaining", [
      it("chains be_some with equal", fn(_) {
        Some(42)
        |> should()
        |> be_some()
        |> equal(42)
        |> or_fail_with("chaining be_some |> equal should pass")
      }),
      it("fails chain if inner value differs", fn(_) {
        Some(42)
        |> should()
        |> be_some()
        |> equal(100)
        |> be_match_failed_result()
        |> or_fail_with(
          "chaining be_some |> equal should fail if value differs",
        )
      }),
      it("fails chain if value is None", fn(_) {
        None
        |> should()
        |> be_some()
        |> equal(42)
        |> be_match_failed_result()
        |> or_fail_with("chaining be_some |> equal should fail for None")
      }),
    ]),
  ])
}
