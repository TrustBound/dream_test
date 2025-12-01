//// Comprehensive test suite demonstrating all Dream Test features.
////
//// This example follows AAA (Arrange-Act-Assert) black-box testing:
//// - Arrange: Set up test data and preconditions
//// - Act: Execute the behavior being tested
//// - Assert: Verify the expected outcome
////
//// Tests interact only with the public API — no internal state inspection.

import cache_app
import dream_test/assertions/should.{
  be_empty, be_error, be_false, be_greater_than, be_none, be_ok, be_some,
  be_true, contain, equal, have_length, or_fail_with, should,
}
import dream_test/reporter/bdd.{report}
import dream_test/runner.{exit_on_failure, run_suite}
import dream_test/types.{AssertionOk}
import dream_test/unit.{
  after_all, after_each, before_all, before_each, describe, it, to_test_suite,
}
import gleam/io
import gleam/option.{Some}

// ============================================================================
// Test Suite
// ============================================================================

pub fn tests() {
  describe("Cache", [
    // -------------------------------------------------------------------------
    // Basic Operations
    // -------------------------------------------------------------------------
    describe("get and set", [
      it("retrieves a stored value", fn() {
        // Arrange
        let cache = cache_app.start()
        cache_app.set(cache, "name", "Alice")

        // Act
        let result = cache_app.get(cache, "name")

        // Assert
        result
        |> should()
        |> be_some()
        |> equal("Alice")
        |> or_fail_with("get() should return the stored value")
      }),

      it("returns None for keys that were never set", fn() {
        // Arrange
        let cache = cache_app.start()

        // Act
        let result = cache_app.get(cache, "nonexistent")

        // Assert
        result
        |> should()
        |> be_none()
        |> or_fail_with("get() should return None for missing keys")
      }),

      it("overwrites previous values for the same key", fn() {
        // Arrange
        let cache = cache_app.start()
        cache_app.set(cache, "version", "1.0")

        // Act
        cache_app.set(cache, "version", "2.0")
        let result = cache_app.get(cache, "version")

        // Assert
        result
        |> should()
        |> be_some()
        |> equal("2.0")
        |> or_fail_with("set() should overwrite existing values")
      }),
    ]),

    describe("delete", [
      it("removes an existing key", fn() {
        // Arrange
        let cache = cache_app.start()
        cache_app.set(cache, "temp", "data")

        // Act
        cache_app.delete(cache, "temp")
        let result = cache_app.get(cache, "temp")

        // Assert
        result
        |> should()
        |> be_none()
        |> or_fail_with("delete() should remove the key")
      }),

      it("does nothing when deleting a nonexistent key", fn() {
        // Arrange
        let cache = cache_app.start()
        cache_app.set(cache, "keep", "this")

        // Act
        cache_app.delete(cache, "nonexistent")
        let kept = cache_app.get(cache, "keep")
        let size = cache_app.size(cache)

        // Assert
        kept
        |> should()
        |> be_some()
        |> or_fail_with("Other keys should be unaffected")

        size
        |> should()
        |> equal(1)
        |> or_fail_with("Size should remain unchanged")
      }),
    ]),

    describe("clear", [
      it("removes all entries", fn() {
        // Arrange
        let cache = cache_app.start()
        cache_app.set(cache, "a", "1")
        cache_app.set(cache, "b", "2")
        cache_app.set(cache, "c", "3")

        // Act
        cache_app.clear(cache)

        // Assert
        let size = cache_app.size(cache)
        size
        |> should()
        |> equal(0)
        |> or_fail_with("clear() should remove all entries")
      }),

      it("leaves cache usable after clearing", fn() {
        // Arrange
        let cache = cache_app.start()
        cache_app.set(cache, "old", "data")
        cache_app.clear(cache)

        // Act
        cache_app.set(cache, "new", "data")
        let result = cache_app.get(cache, "new")

        // Assert
        result
        |> should()
        |> be_some()
        |> equal("data")
        |> or_fail_with("Cache should work normally after clear()")
      }),
    ]),

    // -------------------------------------------------------------------------
    // Collection Operations
    // -------------------------------------------------------------------------
    describe("keys", [
      it("returns empty list for new cache", fn() {
        // Arrange
        let cache = cache_app.start()

        // Act
        let result = cache_app.keys(cache)

        // Assert
        result
        |> should()
        |> be_empty()
        |> or_fail_with("New cache should have no keys")
      }),

      it("returns all stored keys", fn() {
        // Arrange
        let cache = cache_app.start()
        cache_app.set(cache, "first", "1")
        cache_app.set(cache, "second", "2")
        cache_app.set(cache, "third", "3")

        // Act
        let result = cache_app.keys(cache)

        // Assert
        result
        |> should()
        |> have_length(3)
        |> or_fail_with("Should return all 3 keys")

        result
        |> should()
        |> contain("second")
        |> or_fail_with("Keys should include 'second'")
      }),
    ]),

    describe("size", [
      it("returns zero for empty cache", fn() {
        // Arrange
        let cache = cache_app.start()

        // Act
        let result = cache_app.size(cache)

        // Assert
        result
        |> should()
        |> equal(0)
        |> or_fail_with("Empty cache should have size 0")
      }),

      it("increases as items are added", fn() {
        // Arrange
        let cache = cache_app.start()

        // Act
        cache_app.set(cache, "one", "1")
        let after_one = cache_app.size(cache)
        cache_app.set(cache, "two", "2")
        let after_two = cache_app.size(cache)

        // Assert
        after_one
        |> should()
        |> equal(1)
        |> or_fail_with("Size should be 1 after first insert")

        after_two
        |> should()
        |> equal(2)
        |> or_fail_with("Size should be 2 after second insert")
      }),

      it("does not increase when overwriting", fn() {
        // Arrange
        let cache = cache_app.start()
        cache_app.set(cache, "key", "first")

        // Act
        cache_app.set(cache, "key", "second")
        let result = cache_app.size(cache)

        // Assert
        result
        |> should()
        |> equal(1)
        |> or_fail_with("Overwriting should not increase size")
      }),
    ]),

    // -------------------------------------------------------------------------
    // Convenience Functions
    // -------------------------------------------------------------------------
    describe("get_or", [
      it("returns stored value when key exists", fn() {
        // Arrange
        let cache = cache_app.start()
        cache_app.set(cache, "exists", "actual")

        // Act
        let result = cache_app.get_or(cache, "exists", "default")

        // Assert
        result
        |> should()
        |> equal("actual")
        |> or_fail_with("Should return actual value, not default")
      }),

      it("returns default when key is missing", fn() {
        // Arrange
        let cache = cache_app.start()

        // Act
        let result = cache_app.get_or(cache, "missing", "fallback")

        // Assert
        result
        |> should()
        |> equal("fallback")
        |> or_fail_with("Should return default for missing key")
      }),
    ]),

    describe("has", [
      it("returns true when key exists", fn() {
        // Arrange
        let cache = cache_app.start()
        cache_app.set(cache, "present", "here")

        // Act
        let result = cache_app.has(cache, "present")

        // Assert
        result
        |> should()
        |> be_true()
        |> or_fail_with("has() should return True for existing key")
      }),

      it("returns false when key is missing", fn() {
        // Arrange
        let cache = cache_app.start()

        // Act
        let result = cache_app.has(cache, "absent")

        // Assert
        result
        |> should()
        |> be_false()
        |> or_fail_with("has() should return False for missing key")
      }),
    ]),

    describe("update", [
      it("transforms existing value and returns Ok", fn() {
        // Arrange
        let cache = cache_app.start()
        cache_app.set(cache, "counter", 10)

        // Act
        let result = cache_app.update(cache, "counter", fn(n) { n * 2 })

        // Assert
        result
        |> should()
        |> be_ok()
        |> equal(20)
        |> or_fail_with("update() should return Ok with new value")
      }),

      it("persists the transformed value", fn() {
        // Arrange
        let cache = cache_app.start()
        cache_app.set(cache, "counter", 5)

        // Act
        let _ = cache_app.update(cache, "counter", fn(n) { n + 3 })
        let result = cache_app.get(cache, "counter")

        // Assert
        result
        |> should()
        |> be_some()
        |> equal(8)
        |> or_fail_with("Updated value should be persisted")
      }),

      it("returns Error for missing key", fn() {
        // Arrange
        let cache = cache_app.start()

        // Act
        let result = cache_app.update(cache, "missing", fn(n) { n + 1 })

        // Assert
        result
        |> should()
        |> be_error()
        |> or_fail_with("update() should return Error for missing key")
      }),
    ]),

    describe("pop", [
      it("returns and removes the value", fn() {
        // Arrange
        let cache = cache_app.start()
        cache_app.set(cache, "temp", "data")

        // Act
        let popped = cache_app.pop(cache, "temp")
        let after = cache_app.get(cache, "temp")

        // Assert
        popped
        |> should()
        |> be_some()
        |> equal("data")
        |> or_fail_with("pop() should return the value")

        after
        |> should()
        |> be_none()
        |> or_fail_with("Key should be removed after pop()")
      }),

      it("returns None for missing key", fn() {
        // Arrange
        let cache = cache_app.start()

        // Act
        let result = cache_app.pop(cache, "nonexistent")

        // Assert
        result
        |> should()
        |> be_none()
        |> or_fail_with("pop() should return None for missing key")
      }),
    ]),

    // -------------------------------------------------------------------------
    // Lifecycle Hooks (Suite Mode Demo)
    // -------------------------------------------------------------------------
    describe("lifecycle hooks demo", [
      before_all(fn() {
        // Arrange (once for entire describe block)
        io.println("  [before_all] Setting up shared test environment")
        AssertionOk
      }),

      before_each(fn() {
        // Arrange (before each test)
        io.println("  [before_each] Preparing fresh state")
        AssertionOk
      }),

      it("first test runs after hooks", fn() {
        // Act & Assert
        io.println("  [test] First test executing")
        True
        |> should()
        |> be_true()
        |> or_fail_with("Test should pass")
      }),

      it("second test also gets fresh setup", fn() {
        // Act & Assert
        io.println("  [test] Second test executing")
        42
        |> should()
        |> be_greater_than(0)
        |> or_fail_with("42 should be positive")
      }),

      after_each(fn() {
        // Cleanup (after each test)
        io.println("  [after_each] Cleaning up test state")
        AssertionOk
      }),

      after_all(fn() {
        // Cleanup (once for entire describe block)
        io.println("  [after_all] Tearing down shared environment")
        AssertionOk
      }),
    ]),

    // -------------------------------------------------------------------------
    // Nested Describe Blocks
    // -------------------------------------------------------------------------
    describe("nested organization", [
      describe("outer group", [
        it("test at outer level", fn() {
          // Arrange
          let value = Some("outer")

          // Act & Assert
          value
          |> should()
          |> be_some()
          |> equal("outer")
          |> or_fail_with("Should be Some(\"outer\")")
        }),

        describe("inner group", [
          it("test at inner level", fn() {
            // Arrange
            let list = [1, 2, 3]

            // Act & Assert
            list
            |> should()
            |> have_length(3)
            |> or_fail_with("List should have 3 elements")

            list
            |> should()
            |> contain(2)
            |> or_fail_with("List should contain 2")
          }),
        ]),
      ]),
    ]),
  ])
}

// ============================================================================
// Main Entry Point
// ============================================================================

pub fn main() {
  io.println("")
  io.println("Cache App — Dream Test Example")
  io.println("===============================")
  io.println("")

  // Use suite mode for full lifecycle hook support
  let results =
    to_test_suite("cache_app_test", tests())
    |> run_suite()

  report(results, io.print)
  exit_on_failure(results)
}
