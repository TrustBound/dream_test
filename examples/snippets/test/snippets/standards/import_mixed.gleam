import dream_test/types.{type TestResult, full_name}

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}

pub fn name_of(result: TestResult) -> List(String) {
  full_name(groups: result.groups, name: result.name)
}

pub fn tests() {
  describe("STANDARDS.md rule 7: a type and a value from one module", [
    it("gives the full name of a result", fn() {
      // Act
      let name =
        name_of(types.TestResult(
          name: "adds",
          groups: ["math"],
          status: types.Passed,
          duration_ms: 0,
          tags: [],
          failures: [],
          kind: types.Unit,
        ))

      // Assert
      name
      |> should
      |> be_equal(["math", "adds"])
      |> or_fail_with("the full name should be the groups and the name")
    }),
  ])
}
