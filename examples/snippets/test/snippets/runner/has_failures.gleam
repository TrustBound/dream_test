import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/runner
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("has_failures", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

fn failing_suite() {
  describe("failing suite", [
    it("fails", fn() {
      1
      |> should
      |> be_equal(2)
      |> or_fail_with("intentional failure for has_failures example")
    }),
  ])
}

pub fn main() {
  let results = runner.new([failing_suite()]) |> runner.run()

  results
  |> runner.has_failures()
  |> should
  |> be_equal(True)
  |> or_fail_with("expected failures to be present")
}
