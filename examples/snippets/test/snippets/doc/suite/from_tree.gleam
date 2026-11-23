import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import dream_test/unit_context

fn is_41(number: Int) -> Result(AssertionResult, String) {
  number
  |> should
  |> be_equal(41)
  |> or_fail_with("expected 41")
}

pub fn numbers_suite() -> TestSuite {
  suite.from_tree(types.tree("numbers", 41, [unit_context.it("is 41", is_41)]))
}
