// ❌ Bad: This imports constructors, not types
import dream_test/types.{TestResult}

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}

/// `TestResult` here is the constructor. A signature still needs
/// `types.TestResult` for the type.
pub fn example_result() -> types.TestResult {
  TestResult(
    name: "adds",
    groups: ["math"],
    status: types.Passed,
    duration_ms: 0,
    tags: [],
    failures: [],
    kind: types.Unit,
  )
}

pub fn tests() {
  describe("STANDARDS.md rule 7, Bad: a constructor import", [
    it("imports the constructor, not the type", fn() {
      // Act
      let result = example_result()

      // Assert
      result.name
      |> should
      |> be_equal("adds")
      |> or_fail_with("the constructor should make the result")
    }),
  ])
}
