import dream_test/assertions/should.{
  be_false, be_true, equal, or_fail_with, should,
}
import dream_test/gherkin/world
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, group, it}

pub fn tests() {
  describe("Gherkin World", [
    group("new_world", [
      it("creates world with given scenario_id", fn(_) {
        // Arrange
        let id = "test_scenario_1"

        // Act
        let w = world.new_world(id)
        let result = world.scenario_id(w)

        // Assert & Cleanup
        let assertion =
          result
          |> should()
          |> equal(id)
          |> or_fail_with("World should have given scenario_id")
        world.cleanup(w)
        assertion
      }),
      it("creates independent worlds for different scenarios", fn(_) {
        // Arrange
        let w1 = world.new_world("scenario_a")
        let w2 = world.new_world("scenario_b")

        // Act
        world.put(w1, "key", "value_a")
        world.put(w2, "key", "value_b")
        let result1: Result(String, String) = world.get(w1, "key")
        let result2: Result(String, String) = world.get(w2, "key")

        // Assert & Cleanup
        world.cleanup(w1)
        world.cleanup(w2)
        let ok = result1 == Ok("value_a") && result2 == Ok("value_b")
        ok
        |> should()
        |> be_true()
        |> or_fail_with("Each world should have independent storage")
      }),
    ]),
    group("put and get", [
      it("stores and retrieves string value", fn(_) {
        // Arrange
        let w = world.new_world("put_get_string")
        let key = "name"
        let value = "Alice"

        // Act
        world.put(w, key, value)
        let result: Result(String, String) = world.get(w, key)

        // Assert & Cleanup
        world.cleanup(w)
        result
        |> should()
        |> equal(Ok("Alice"))
        |> or_fail_with("Should retrieve stored string")
      }),
      it("stores and retrieves integer value", fn(_) {
        // Arrange
        let w = world.new_world("put_get_int")
        let key = "count"
        let value = 42

        // Act
        world.put(w, key, value)
        let result: Result(Int, String) = world.get(w, key)

        // Assert & Cleanup
        world.cleanup(w)
        result
        |> should()
        |> equal(Ok(42))
        |> or_fail_with("Should retrieve stored integer")
      }),
      it("stores and retrieves list value", fn(_) {
        // Arrange
        let w = world.new_world("put_get_list")
        let key = "items"
        let value = ["apple", "banana", "cherry"]

        // Act
        world.put(w, key, value)
        let result: Result(List(String), String) = world.get(w, key)

        // Assert & Cleanup
        world.cleanup(w)
        result
        |> should()
        |> equal(Ok(["apple", "banana", "cherry"]))
        |> or_fail_with("Should retrieve stored list")
      }),
      it("returns Error for non-existent key", fn(_) {
        // Arrange
        let w = world.new_world("get_missing")

        // Act
        let result: Result(String, String) = world.get(w, "non_existent")

        // Assert & Cleanup
        world.cleanup(w)
        result
        |> should()
        |> equal(Error("World key not found: non_existent"))
        |> or_fail_with("Should return Error for non-existent key")
      }),
      it("overwrites value when key already exists", fn(_) {
        // Arrange
        let w = world.new_world("put_overwrite")
        let key = "value"

        // Act
        world.put(w, key, "first")
        world.put(w, key, "second")
        let result: Result(String, String) = world.get(w, key)

        // Assert & Cleanup
        world.cleanup(w)
        result
        |> should()
        |> equal(Ok("second"))
        |> or_fail_with("Should have overwritten value")
      }),
      it("stores multiple keys", fn(_) {
        // Arrange
        let w = world.new_world("multiple_keys")

        // Act
        world.put(w, "a", 1)
        world.put(w, "b", 2)
        world.put(w, "c", 3)
        let a: Result(Int, String) = world.get(w, "a")
        let b: Result(Int, String) = world.get(w, "b")
        let c: Result(Int, String) = world.get(w, "c")

        // Assert & Cleanup
        world.cleanup(w)
        let ok = a == Ok(1) && b == Ok(2) && c == Ok(3)
        ok
        |> should()
        |> be_true()
        |> or_fail_with("All keys should be retrievable")
      }),
    ]),
    group("get_or", [
      it("returns stored value when key exists", fn(_) {
        // Arrange
        let w = world.new_world("get_or_exists")
        world.put(w, "count", 42)

        // Act
        let result: Int = world.get_or(w, "count", 0)

        // Assert & Cleanup
        world.cleanup(w)
        result
        |> should()
        |> equal(42)
        |> or_fail_with("Should return stored value")
      }),
      it("returns default when key does not exist", fn(_) {
        // Arrange
        let w = world.new_world("get_or_missing")
        let default = 100

        // Act
        let result: Int = world.get_or(w, "missing", default)

        // Assert & Cleanup
        world.cleanup(w)
        result
        |> should()
        |> equal(default)
        |> or_fail_with("Should return default value")
      }),
      it("returns default empty list when key does not exist", fn(_) {
        // Arrange
        let w = world.new_world("get_or_empty_list")

        // Act
        let result: List(String) = world.get_or(w, "items", [])

        // Assert & Cleanup
        world.cleanup(w)
        result
        |> should()
        |> equal([])
        |> or_fail_with("Should return default empty list")
      }),
    ]),
    group("has", [
      it("returns True when key exists", fn(_) {
        // Arrange
        let w = world.new_world("has_exists")
        world.put(w, "key", "value")

        // Act
        let result = world.has(w, "key")

        // Assert & Cleanup
        world.cleanup(w)
        result
        |> should()
        |> be_true()
        |> or_fail_with("Should return True for existing key")
      }),
      it("returns False when key does not exist", fn(_) {
        // Arrange
        let w = world.new_world("has_missing")

        // Act
        let result = world.has(w, "missing")

        // Assert & Cleanup
        world.cleanup(w)
        result
        |> should()
        |> be_false()
        |> or_fail_with("Should return False for missing key")
      }),
      it("returns True after put and False after delete", fn(_) {
        // Arrange
        let w = world.new_world("has_lifecycle")

        // Act & Assert
        let before_put = world.has(w, "key")
        world.put(w, "key", "value")
        let after_put = world.has(w, "key")
        world.delete(w, "key")
        let after_delete = world.has(w, "key")

        // Cleanup
        world.cleanup(w)
        let ok =
          before_put == False && after_put == True && after_delete == False
        ok
        |> should()
        |> be_true()
        |> or_fail_with("has should track key existence correctly")
      }),
    ]),
    group("delete", [
      it("removes key from world", fn(_) {
        // Arrange
        let w = world.new_world("delete_key")
        world.put(w, "key", "value")

        // Act
        world.delete(w, "key")
        let result: Result(String, String) = world.get(w, "key")

        // Assert & Cleanup
        world.cleanup(w)
        result
        |> should()
        |> equal(Error("World key not found: key"))
        |> or_fail_with("Key should be deleted")
      }),
      it("is no-op for non-existent key", fn(_) {
        // Arrange
        let w = world.new_world("delete_missing")
        world.put(w, "other", "value")

        // Act - deleting non-existent key should not error
        world.delete(w, "non_existent")
        let other_result: Result(String, String) = world.get(w, "other")

        // Assert & Cleanup
        world.cleanup(w)
        other_result
        |> should()
        |> equal(Ok("value"))
        |> or_fail_with("Other keys should be unaffected")
      }),
      it("only deletes specified key", fn(_) {
        // Arrange
        let w = world.new_world("delete_specific")
        world.put(w, "keep1", 1)
        world.put(w, "delete_me", 2)
        world.put(w, "keep2", 3)

        // Act
        world.delete(w, "delete_me")
        let k1: Result(Int, String) = world.get(w, "keep1")
        let dm: Result(Int, String) = world.get(w, "delete_me")
        let k2: Result(Int, String) = world.get(w, "keep2")

        // Assert & Cleanup
        world.cleanup(w)
        let ok =
          k1 == Ok(1)
          && dm == Error("World key not found: delete_me")
          && k2 == Ok(3)
        ok
        |> should()
        |> be_true()
        |> or_fail_with("Only specified key should be deleted")
      }),
    ]),
    group("scenario_id", [
      it("returns the scenario id", fn(_) {
        // Arrange
        let id = "my_unique_scenario_123"
        let w = world.new_world(id)

        // Act
        let result = world.scenario_id(w)

        // Assert & Cleanup
        world.cleanup(w)
        result
        |> should()
        |> equal(id)
        |> or_fail_with("Should return original scenario_id")
      }),
    ]),
    group("cleanup", [
      it("cleans up world without error", fn(_) {
        // Arrange
        let w = world.new_world("cleanup_test")
        world.put(w, "data", "value")

        // Act & Assert - cleanup should complete without error
        world.cleanup(w)
        Ok(AssertionOk)
      }),
    ]),
  ])
}
// =============================================================================
// Test Helpers
// =============================================================================

// (No local pass/fail helpers needed; assertions return Result directly.)
