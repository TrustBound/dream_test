//// README: Chaining matchers

import dream_test/matchers.{be_equal, be_ok, be_some, or_fail_with, should,}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io
import gleam/option.{Some}

pub fn tests() {
  describe("Chaining matchers", [
    // Unwrap Some, then check the value
    it("unwraps Option", fn() {
      Some(42)
      |> should
      |> be_some()
      |> be_equal(42)
      |> or_fail_with("Should contain 42")
    }),
    // Unwrap Ok, then check the value
    it("unwraps Result", fn() {
      Ok("success")
      |> should
      |> be_ok()
      |> be_equal("success")
      |> or_fail_with("Should be Ok with 'success'")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
