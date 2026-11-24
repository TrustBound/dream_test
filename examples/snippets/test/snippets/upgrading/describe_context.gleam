import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context

pub fn tests() -> TestSuite {
  unit_context.describe(name: "a counter", context: context.value(41), tests: [
    unit_context.it("starts from the value of the context", fn(count: Int) {
      count
      |> should
      |> be_equal(41)
      |> or_fail_with("expected the start value 41")
    }),
  ])
}
