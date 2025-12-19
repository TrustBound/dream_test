//// README: Using `group` to organize a suite

import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, group, it}
import gleam/io

pub fn tests() {
  describe("Calculator", [
    group("addition", [
      it("adds small numbers", fn() {
        2 + 3
        |> should
        |> equal(5)
        |> or_fail_with("2 + 3 should equal 5")
      }),
      it("adds negative numbers", fn() {
        -2 + -3
        |> should
        |> equal(-5)
        |> or_fail_with("-2 + -3 should equal -5")
      }),
    ]),
    group("division", [
      it("integer division rounds toward zero", fn() {
        7 / 2
        |> should
        |> equal(3)
        |> or_fail_with("7 / 2 should equal 3")
      }),
    ]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
