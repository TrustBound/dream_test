import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context

pub fn tests() -> TestSuite {
  unit_context.describe(name: "a counter", initial: 41, children: [
    unit_context.it("starts from the initial value", fn(count: Int) {
      count
      |> should
      |> be_equal(41)
      |> or_fail_with("expected the initial value 41")
    }),
  ])
}
