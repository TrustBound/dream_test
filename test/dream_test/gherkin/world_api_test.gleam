import dream_test/gherkin/world
import dream_test/matchers.{be_equal, fail_with, or_fail_with, should}
import dream_test/types as test_types
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("dream_test/gherkin/world", [
    it("new_world stores scenario_id", fn() {
      let w = world.new_world("scenario-1")
      world.scenario_id(w)
      |> should
      |> be_equal("scenario-1")
      |> or_fail_with("scenario_id should be preserved")
    }),

    it("put + get roundtrip values", fn() {
      // Arrange
      let w = world.new_world("scenario-1")
      world.put(w, "count", 3)

      // Act
      let result = world.get(w, "count")

      // Assert
      result
      |> should
      |> be_equal(Ok(3))
      |> or_fail_with("should get the value that was put")
    }),

    it("has/delete reflect presence of keys", fn() {
      // Arrange
      let w = world.new_world("scenario-1")
      world.put(w, "count", 3)

      // Act
      let before = world.has(w, "count")
      world.delete(w, "count")
      let after = world.has(w, "count")

      // Assert
      case before, after {
        True, False -> Ok(test_types.AssertionOk)
        _, _ ->
          Ok(fail_with("expected has=True before delete and has=False after"))
      }
    }),

    it("get_or returns default for missing keys", fn() {
      let w = world.new_world("scenario-2")
      world.get_or(w, "missing", 9)
      |> should
      |> be_equal(9)
      |> or_fail_with("default should be returned")
    }),

    it("cleanup does not crash", fn() {
      let w = world.new_world("scenario-3")
      world.cleanup(w)
      Ok(test_types.AssertionOk)
    }),
  ])
}
