import dream_test/assertions/should.{
  be_false, be_true, equal, fail_with, or_fail_with, should,
}
import dream_test/gherkin/world
import dream_test/types.{type AssertionResult, AssertionOk}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Gherkin World", [
    describe("new_world", [
      it("creates world with given scenario_id", fn() {
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
      it("creates independent worlds for different scenarios", fn() {
        // Arrange
        let w1 = world.new_world("scenario_a")
        let w2 = world.new_world("scenario_b")

        // Act
        world.put(w1, "key", "value_a")
        world.put(w2, "key", "value_b")
        let result1: Result(String, Nil) = world.get(w1, "key")
        let result2: Result(String, Nil) = world.get(w2, "key")

        // Assert & Cleanup
        world.cleanup(w1)
        world.cleanup(w2)
        case result1, result2 {
          Ok("value_a"), Ok("value_b") -> pass()
          _, _ -> fail_with("Each world should have independent storage")
        }
      }),
    ]),
    describe("put and get", [
      it("stores and retrieves string value", fn() {
        // Arrange
        let w = world.new_world("put_get_string")
        let key = "name"
        let value = "Alice"

        // Act
        world.put(w, key, value)
        let result: Result(String, Nil) = world.get(w, key)

        // Assert & Cleanup
        world.cleanup(w)
        case result {
          Ok("Alice") -> pass()
          Ok(_) -> fail_with("Retrieved wrong string value")
          Error(_) -> fail_with("Should retrieve stored string")
        }
      }),
      it("stores and retrieves integer value", fn() {
        // Arrange
        let w = world.new_world("put_get_int")
        let key = "count"
        let value = 42

        // Act
        world.put(w, key, value)
        let result: Result(Int, Nil) = world.get(w, key)

        // Assert & Cleanup
        world.cleanup(w)
        case result {
          Ok(42) -> pass()
          Ok(_) -> fail_with("Retrieved wrong integer value")
          Error(_) -> fail_with("Should retrieve stored integer")
        }
      }),
      it("stores and retrieves list value", fn() {
        // Arrange
        let w = world.new_world("put_get_list")
        let key = "items"
        let value = ["apple", "banana", "cherry"]

        // Act
        world.put(w, key, value)
        let result: Result(List(String), Nil) = world.get(w, key)

        // Assert & Cleanup
        world.cleanup(w)
        case result {
          Ok(["apple", "banana", "cherry"]) -> pass()
          Ok(_) -> fail_with("Retrieved wrong list value")
          Error(_) -> fail_with("Should retrieve stored list")
        }
      }),
      it("returns Error for non-existent key", fn() {
        // Arrange
        let w = world.new_world("get_missing")

        // Act
        let result: Result(String, Nil) = world.get(w, "non_existent")

        // Assert & Cleanup
        world.cleanup(w)
        case result {
          Error(Nil) -> pass()
          Ok(_) -> fail_with("Should return Error for non-existent key")
        }
      }),
      it("overwrites value when key already exists", fn() {
        // Arrange
        let w = world.new_world("put_overwrite")
        let key = "value"

        // Act
        world.put(w, key, "first")
        world.put(w, key, "second")
        let result: Result(String, Nil) = world.get(w, key)

        // Assert & Cleanup
        world.cleanup(w)
        case result {
          Ok("second") -> pass()
          Ok(_) -> fail_with("Should have overwritten value")
          Error(_) -> fail_with("Key should exist")
        }
      }),
      it("stores multiple keys", fn() {
        // Arrange
        let w = world.new_world("multiple_keys")

        // Act
        world.put(w, "a", 1)
        world.put(w, "b", 2)
        world.put(w, "c", 3)
        let a: Result(Int, Nil) = world.get(w, "a")
        let b: Result(Int, Nil) = world.get(w, "b")
        let c: Result(Int, Nil) = world.get(w, "c")

        // Assert & Cleanup
        world.cleanup(w)
        case a, b, c {
          Ok(1), Ok(2), Ok(3) -> pass()
          _, _, _ -> fail_with("All keys should be retrievable")
        }
      }),
    ]),
    describe("get_or", [
      it("returns stored value when key exists", fn() {
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
      it("returns default when key does not exist", fn() {
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
      it("returns default empty list when key does not exist", fn() {
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
    describe("has", [
      it("returns True when key exists", fn() {
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
      it("returns False when key does not exist", fn() {
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
      it("returns True after put and False after delete", fn() {
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

        case before_put, after_put, after_delete {
          False, True, False -> pass()
          _, _, _ -> fail_with("has should track key existence correctly")
        }
      }),
    ]),
    describe("delete", [
      it("removes key from world", fn() {
        // Arrange
        let w = world.new_world("delete_key")
        world.put(w, "key", "value")

        // Act
        world.delete(w, "key")
        let result: Result(String, Nil) = world.get(w, "key")

        // Assert & Cleanup
        world.cleanup(w)
        case result {
          Error(Nil) -> pass()
          Ok(_) -> fail_with("Key should be deleted")
        }
      }),
      it("is no-op for non-existent key", fn() {
        // Arrange
        let w = world.new_world("delete_missing")
        world.put(w, "other", "value")

        // Act - deleting non-existent key should not error
        world.delete(w, "non_existent")
        let other_result: Result(String, Nil) = world.get(w, "other")

        // Assert & Cleanup
        world.cleanup(w)
        case other_result {
          Ok("value") -> pass()
          _ -> fail_with("Other keys should be unaffected")
        }
      }),
      it("only deletes specified key", fn() {
        // Arrange
        let w = world.new_world("delete_specific")
        world.put(w, "keep1", 1)
        world.put(w, "delete_me", 2)
        world.put(w, "keep2", 3)

        // Act
        world.delete(w, "delete_me")
        let k1: Result(Int, Nil) = world.get(w, "keep1")
        let dm: Result(Int, Nil) = world.get(w, "delete_me")
        let k2: Result(Int, Nil) = world.get(w, "keep2")

        // Assert & Cleanup
        world.cleanup(w)
        case k1, dm, k2 {
          Ok(1), Error(Nil), Ok(3) -> pass()
          _, _, _ -> fail_with("Only specified key should be deleted")
        }
      }),
    ]),
    describe("scenario_id", [
      it("returns the scenario id", fn() {
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
    describe("cleanup", [
      it("cleans up world without error", fn() {
        // Arrange
        let w = world.new_world("cleanup_test")
        world.put(w, "data", "value")

        // Act & Assert - cleanup should complete without error
        world.cleanup(w)
        pass()
      }),
    ]),
  ])
}

// =============================================================================
// Test Helpers
// =============================================================================

fn pass() -> AssertionResult {
  AssertionOk
}
