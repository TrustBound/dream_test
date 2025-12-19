//// README: Process helpers

import dream_test/matchers.{be_between, be_equal, or_fail_with, should}
import dream_test/process.{get_count, increment, start_counter, unique_port}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Process helpers", [
    it("start_counter + increment + get_count work", fn() {
      let counter = start_counter()
      increment(counter)
      increment(counter)

      get_count(counter)
      |> should
      |> be_equal(2)
      |> or_fail_with("expected counter to be 2")
    }),

    it("unique_port returns a value in the safe range", fn() {
      unique_port()
      |> should
      |> be_between(10_000, 60_000)
      |> or_fail_with("expected unique_port to be within 10k..60k")
    }),
  ])
}
