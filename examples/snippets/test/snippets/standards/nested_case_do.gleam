//// The "Do" example of rule 1 of STANDARDS.md: the inner `case` is in a
//// named helper function.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/option.{None, Some}

pub fn handle(value1, value2) {
  case value1 {
    Some(x) -> handle_with_value(x, value2)
    None -> handle_none()
  }
}

fn handle_with_value(x, value2) {
  case value2 {
    Ok(y) -> do_something(x, y)
    Error(e) -> handle_error(e)
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
  describe("STANDARDS.md rule 1, Do: a named helper", [
    it("handles an error of the second value", fn() {
      // Act
      let result = handle(Some(1), Error("no value"))

      // Assert
      result
      |> should
      |> be_equal("error: no value")
      |> or_fail_with("the helper should handle the error")
    }),
  ])
}
