import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{before_each, describe, it}

pub fn suite() -> TestSuite {
  describe("Counter", 0, [
    before_each(fn(count) { Ok(count + 1) }),
    it("starts at one", fn(count: Int) {
      count
      |> should
      |> be_equal(1)
      |> or_fail_with("expected before_each to add one")
    }),
    it("starts at one again", fn(count: Int) {
      count
      |> should
      |> be_equal(1)
      |> or_fail_with("expected a new count for each test")
    }),
  ])
}
