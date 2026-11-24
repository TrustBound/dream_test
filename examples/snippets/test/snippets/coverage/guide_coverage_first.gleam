import app/cart
import dream_test/coverage
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Cart", [
    it("totals an empty cart", fn() {
      cart.total([])
      |> should
      |> be_equal(0)
      |> or_fail_with("an empty cart should cost nothing")
    }),
    it("totals two prices", fn() {
      cart.total([250, 1000])
      |> should
      |> be_equal(1250)
      |> or_fail_with("the total should be the sum of the prices")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.coverage(
    coverage.new()
    |> coverage.source_directory("src/app")
    |> coverage.show_missing(),
  )
  |> runner.exit_on_failure()
  |> runner.run()
}
