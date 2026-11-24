// ✅ Good: Explicit type import
import dream_test/types.{type Status, type TestResult}

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}

pub fn status_of(result: TestResult) -> Status {
  result.status
}

pub fn tests() {
  describe("STANDARDS.md rule 7, Good: an explicit type import", [
    it("uses the types in a signature", fn() {
      // Act
      let status = status_of(example_result())

      // Assert
      status
      |> should
      |> be_equal(types.Passed)
      |> or_fail_with("the result should have passed")
    }),
  ])
}

fn example_result() -> TestResult {
  types.TestResult(
    name: "adds",
    groups: ["math"],
    status: types.Passed,
    duration_ms: 0,
    tags: [],
    failures: [],
    kind: types.Unit,
  )
}
