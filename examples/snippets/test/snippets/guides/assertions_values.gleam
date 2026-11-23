import dream_test/matchers.{
  be_between, be_empty, be_equal, be_error, be_false, be_none, be_ok, be_some,
  contain, contain_string, fail_with, have_length, or_fail_with, should,
  start_with, succeed,
}
import dream_test/unit.{describe, group, it}
import gleam/dict
import gleam/list
import gleam/option
import gleam/string
import snippets.{divide}

pub fn tests() {
  describe("Matchers", [
    group("equality and booleans", [
      it("compares whole values", fn() {
        string.split("a,b,c", ",")
        |> should
        |> be_equal(["a", "b", "c"])
        |> or_fail_with("the string should split at each comma")
      }),
      it("checks a Bool", fn() {
        list.is_empty([1])
        |> should
        |> be_false()
        |> or_fail_with("a list with one item is not empty")
      }),
    ]),
    group("Result and Option", [
      it("unwraps an Ok, then checks the value", fn() {
        divide(10, 2)
        |> should
        |> be_ok()
        |> be_equal(5)
        |> or_fail_with("10 / 2 should be Ok(5)")
      }),
      it("unwraps an Error, then checks the error", fn() {
        divide(1, 0)
        |> should
        |> be_error()
        |> contain_string("zero")
        |> or_fail_with("the error should name the zero")
      }),
      it("unwraps a Some", fn() {
        dict.from_list([#("alice", 30)])
        |> dict.get("alice")
        |> option.from_result
        |> should
        |> be_some()
        |> be_equal(30)
        |> or_fail_with("alice should be 30")
      }),
      it("checks a None", fn() {
        option.from_result(dict.get(dict.new(), "bob"))
        |> should
        |> be_none()
        |> or_fail_with("an empty dict has no bob")
      }),
    ]),
    group("lists, strings and numbers", [
      it("finds an item and counts the items", fn() {
        [1, 2, 3]
        |> should
        |> contain(2)
        |> have_length(3)
        |> or_fail_with("the list should hold 2, and three items")
      }),
      it("checks an empty list", fn() {
        list.filter([1, 3, 5], int_is_even)
        |> should
        |> be_empty()
        |> or_fail_with("no odd number is even")
      }),
      it("checks the start of a string", fn() {
        string.uppercase("hello world")
        |> should
        |> start_with("HELLO")
        |> or_fail_with("the text should start with HELLO")
      }),
      it("checks a range", fn() {
        string.length("hello")
        |> should
        |> be_between(1, 10)
        |> or_fail_with("the length should be between 1 and 10")
      }),
    ]),
    group("your own logic", [
      it("passes or fails with a case", fn() {
        case divide(9, 3) {
          Ok(3) -> Ok(succeed())
          Ok(other) ->
            Ok(fail_with("expected 3, got " <> string.inspect(other)))
          Error(message) -> Ok(fail_with(message))
        }
      }),
    ]),
  ])
}

fn int_is_even(value: Int) -> Bool {
  value % 2 == 0
}
