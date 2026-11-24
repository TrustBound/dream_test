//// Assertions that fail, one of each kind, for the report that the guide
//// on matchers shows. The failing suite is `failing_tests`, so test
//// discovery runs only `tests`, which checks that every example fails.

import dream_test/matchers.{
  be_equal, be_ok, be_some, contain, fail_with, or_fail_with, should, start_with,
}
import dream_test/reporters/summary
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/dict
import gleam/option
import gleam/result
import gleam/string
import snippets.{divide}

pub fn failing_tests() {
  describe("Failures", [
    it("a different value", fn() {
      string.split("a,b;c", ",")
      |> should
      |> be_equal(["a", "b", "c"])
      |> or_fail_with("the string should split at each separator")
    }),
    it("an Error where an Ok was expected", fn() {
      divide(1, 0)
      |> should
      |> be_ok()
      |> be_equal(0)
      |> or_fail_with("1 / 0 should be Ok(0)")
    }),
    it("a None where a Some was expected", fn() {
      dict.new()
      |> dict.get("alice")
      |> option.from_result
      |> should
      |> be_some()
      |> be_equal(30)
      |> or_fail_with("alice should be 30")
    }),
    it("a missing item", fn() {
      [1, 2, 3]
      |> should
      |> contain(4)
      |> or_fail_with("the list should hold 4")
    }),
    it("a string with another start", fn() {
      "hello world"
      |> should
      |> start_with("HELLO")
      |> or_fail_with("the text should start with HELLO")
    }),
    it("a failure from your own logic", fn() {
      case divide(9, 2) {
        Ok(4) -> Ok(fail_with("9 / 2 should not round down"))
        _ -> Ok(fail_with("9 / 2 should be Ok"))
      }
    }),
    it("an Error from the test body", fn() {
      use quotient <- result.try(divide(1, 0))
      quotient
      |> should
      |> be_equal(0)
      |> or_fail_with("1 / 0 should be 0")
    }),
  ])
}

pub fn tests() {
  describe("The failure examples", [
    it("fail every test", fn() {
      // Act
      let report =
        runner.new([failing_tests()])
        |> runner.silent()
        |> runner.run()

      // Assert
      summary.count(report).failed
      |> should
      |> be_equal(7)
      |> or_fail_with("each of the seven examples should fail")
    }),
  ])
}
