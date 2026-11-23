//// The "Don't" example of rule 1 of STANDARDS.md: no nested `case`
//// expressions. It compiles and works, but the nested `case` is hard to
//// read.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/option.{None, Some}

pub fn handle(value1, value2) {
  case value1 {
    Some(x) ->
      case value2 {
        Ok(y) -> do_something(x, y)
        Error(e) -> handle_error(e)
      }
    None -> handle_none()
  }
}

fn do_something(first: Int, second: Int) -> String {
  int.to_string(first + second)
}

fn handle_error(error: String) -> String {
  "error: " <> error
}

fn handle_none() -> String {
  "none"
}

pub fn tests() {
  describe("STANDARDS.md rule 1, Don't: a nested case", [
    it("handles two values", fn() {
      // Act
      let result = handle(Some(1), Ok(2))

      // Assert
      result
      |> should
      |> be_equal("3")
      |> or_fail_with("the nested case should add the two values")
    }),
  ])
}
