import dream_test/unit.{describe, it}
import dream_test/assertions/should.{or_fail_with}
import dream_test/types.{type AssertionFailure, AssertionFailure, Location, Passed, Failed, status_from_failures}
import gleam/option.{None}

pub fn tests() {
  describe("Types", [
    describe("status_from_failures", [
      it("returns Passed for empty failures", fn() {
        // Arrange
        let empty_failures: List(AssertionFailure) = []
        let expected = Passed
        
        // Act
        let result = status_from_failures(empty_failures)
        
        // Assert
        result
        |> should.equal(expected)
        |> or_fail_with("Empty failures should yield Passed status")
      }),
      
      it("returns Failed for non-empty failures", fn() {
        // Arrange
        let failure = AssertionFailure(
          operator: "equal",
          message: "",
          location: Location("mod", "file.gleam", 10),
          payload: None,
        )
        let non_empty_failures = [failure]
        let expected = Failed
        
        // Act
        let result = status_from_failures(non_empty_failures)
        
        // Assert
        result
        |> should.equal(expected)
        |> or_fail_with("Non-empty failures should yield Failed status")
      }),
    ]),
  ])
}
