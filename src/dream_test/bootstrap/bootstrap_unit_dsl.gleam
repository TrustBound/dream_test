import dream_test/assertions/context.{type TestContext}
import dream_test/bootstrap/core_assert
import dream_test/unit.{describe, it, type UnitTest, to_test_cases}
import dream_test/runner.{type TestCase, run_all}

/// Bootstrap checks for the unit test DSL.
///
/// Verifies that describe/it trees are translated into TestCase values with
/// the expected names and full_name paths.
pub fn main() {
  let tests: UnitTest(Int) =
    describe("Math", [
      it("adds numbers", adds_numbers_test),
      it("subtracts numbers", subtracts_numbers_test),
    ])

  let test_cases = run_all(
    runner_test_cases_from_unit_tests("bootstrap_unit_dsl", tests),
  )

  case test_cases {
    [first, second] -> {
      core_assert.equal("adds numbers", first.name, "First test name should match it label")
      core_assert.equal(["Math", "adds numbers"], first.full_name, "First full_name should include describe and it")

      core_assert.equal("subtracts numbers", second.name, "Second test name should match it label")
      core_assert.equal(["Math", "subtracts numbers"], second.full_name, "Second full_name should include describe and it")
    }

    _ ->
      core_assert.is_true(False, "Expected exactly two translated test cases from unit DSL")
  }
}

fn runner_test_cases_from_unit_tests(module_name: String,
  root: UnitTest(Int),
) -> List(TestCase(Int)) {
  to_test_cases(module_name, root)
}

fn adds_numbers_test(context: TestContext(Int)) -> TestContext(Int) {
  context
}

fn subtracts_numbers_test(context: TestContext(Int)) -> TestContext(Int) {
  context
}
