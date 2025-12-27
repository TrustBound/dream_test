import dream_test/matchers.{
  be_between, be_equal, be_false, be_ok, be_some, be_true, contain,
  contain_string, have_length, match_regex, or_fail_with, should,
}
import dream_test/unit.{describe, it}
import gleam/option.{Some}

pub fn tests() {
  describe("Built-in matchers", [
    it("boolean: be_true", fn() {
      True
      |> should
      |> be_true()
      |> or_fail_with("expected True")
    }),
    it("boolean: be_false", fn() {
      False
      |> should
      |> be_false()
      |> or_fail_with("expected False")
    }),
    it("option: be_some + equal", fn() {
      Some(42)
      |> should
      |> be_some()
      |> be_equal(42)
      |> or_fail_with("expected Some(42)")
    }),
    it("result: be_ok + equal", fn() {
      Ok("hello")
      |> should
      |> be_ok()
      |> be_equal("hello")
      |> or_fail_with("expected Ok(\"hello\")")
    }),
    it("collection: have_length", fn() {
      [1, 2, 3]
      |> should
      |> have_length(3)
      |> or_fail_with("expected list length 3")
    }),
    it("collection: contain", fn() {
      [1, 2, 3]
      |> should
      |> contain(2)
      |> or_fail_with("expected list to contain 2")
    }),
    it("comparison: be_between", fn() {
      5
      |> should
      |> be_between(1, 10)
      |> or_fail_with("expected 5 to be between 1 and 10")
    }),
    it("string: contain_string", fn() {
      "hello world"
      |> should
      |> contain_string("world")
      |> or_fail_with("expected substring match")
    }),
    it("string: match_regex", fn() {
      "user-123"
      |> should
      |> match_regex("^user-\\d+$")
      |> or_fail_with("expected an id like user-123")
    }),
  ])
}
