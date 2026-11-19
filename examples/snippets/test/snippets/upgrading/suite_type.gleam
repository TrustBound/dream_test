import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import dream_test/unit_context

pub fn suite() -> TestSuite {
  describe("suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn context_suite() -> TestSuite {
  unit_context.describe("context suite", 41, [
    unit_context.it("gets 41", fn(number: Int) {
      number
      |> should
      |> be_equal(41)
      |> or_fail_with("expected 41")
    }),
  ])
}

pub fn main() {
  runner.new([suite(), context_suite()])
  |> runner.run()
}

pub fn tests() {
  context_suite()
}
