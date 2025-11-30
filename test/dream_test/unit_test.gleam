import dream_test/bootstrap/assertions
import dream_test/types.{type AssertionResult, AssertionOk}
import dream_test/unit.{describe, it, type UnitTest, to_test_cases}
import dream_test/runner.{type TestCase, run_all}

/// Bootstrap checks for the unit test DSL.
///
/// Verifies that describe/it trees are translated into TestCase values with
/// the expected names and full_name paths.
pub fn main() {
  let tests: UnitTest =
    describe("Math", [
      it("adds numbers", adds_numbers_test),
      it("subtracts numbers", subtracts_numbers_test),
    ])

  let test_cases = run_all(
    runner_test_cases_from_unit_tests("bootstrap_unit_dsl", tests),
  )

  case test_cases {
    [first, second] -> {
      assertions.equal("adds numbers", first.name, "First test name should match it label")
      assertions.equal(["Math", "adds numbers"], first.full_name, "First full_name should include describe and it")

      assertions.equal("subtracts numbers", second.name, "Second test name should match it label")
      assertions.equal(["Math", "subtracts numbers"], second.full_name, "Second full_name should include describe and it")
    }

    _ ->
      assertions.is_true(False, "Expected exactly two translated test cases from unit DSL")
  }
}

fn runner_test_cases_from_unit_tests(module_name: String,
  root: UnitTest,
) -> List(TestCase) {
  to_test_cases(module_name, root)
}

fn adds_numbers_test() -> AssertionResult {
  AssertionOk
}

fn subtracts_numbers_test() -> AssertionResult {
  AssertionOk
}
