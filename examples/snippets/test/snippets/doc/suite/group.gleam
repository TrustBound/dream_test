import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/suite.{type TestSuite}
import dream_test/unit
import dream_test/unit_context

fn plain_suite() -> TestSuite {
  unit.describe("Plain", [unit.it("passes", fn() { Ok(succeed()) })])
}

fn number_suite() -> TestSuite {
  unit_context.describe("Numbers", context.value(41), [
    unit_context.it("is 41", fn(number: Int) {
      number
      |> should
      |> be_equal(41)
      |> or_fail_with("expected 41")
    }),
  ])
}

pub fn all_suites() -> TestSuite {
  suite.group(name: "all", suites: [plain_suite(), number_suite()])
}
