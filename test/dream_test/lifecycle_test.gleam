import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/process.{get_count, increment, start_counter}
import dream_test/runner.{run_all, run_suite}
import dream_test/types.{AssertionOk, Passed, SetupFailed}
import dream_test/unit.{
  after_all, after_each, before_all, before_each, describe, it, to_test_cases,
  to_test_suite,
}

pub fn tests() {
  describe("Lifecycle Hooks", [
    describe("before_each", [
      it("runs before each test in flat mode", fn() {
        // Arrange: Create a counter that hooks will increment
        let counter = start_counter()

        // Create tests with a before_each hook
        let test_tree =
          describe("Suite", [
            before_each(fn() {
              increment(counter)
              AssertionOk
            }),
            it("test one", fn() { AssertionOk }),
            it("test two", fn() { AssertionOk }),
          ])

        // Act: Convert to test cases and run
        let test_cases = to_test_cases("lifecycle_test", test_tree)
        let _results = run_all(test_cases)

        // Assert: before_each should have run twice (once per test)
        get_count(counter)
        |> should()
        |> equal(2)
        |> or_fail_with("before_each should run once per test")
      }),
      it("inherits hooks from parent describe blocks", fn() {
        // Arrange
        let counter = start_counter()

        let test_tree =
          describe("Outer", [
            before_each(fn() {
              increment(counter)
              AssertionOk
            }),
            describe("Inner", [
              it("nested test", fn() { AssertionOk }),
            ]),
          ])

        // Act
        let test_cases = to_test_cases("lifecycle_test", test_tree)
        let _results = run_all(test_cases)

        // Assert: parent's before_each should run for nested test
        get_count(counter)
        |> should()
        |> equal(1)
        |> or_fail_with("Parent before_each should run for nested tests")
      }),
    ]),
    describe("after_each", [
      it("runs after each test in flat mode", fn() {
        // Arrange
        let counter = start_counter()

        let test_tree =
          describe("Suite", [
            after_each(fn() {
              increment(counter)
              AssertionOk
            }),
            it("test one", fn() { AssertionOk }),
            it("test two", fn() { AssertionOk }),
          ])

        // Act
        let test_cases = to_test_cases("lifecycle_test", test_tree)
        let _results = run_all(test_cases)

        // Assert
        get_count(counter)
        |> should()
        |> equal(2)
        |> or_fail_with("after_each should run once per test")
      }),
      it("runs even when test fails", fn() {
        // Arrange
        let counter = start_counter()

        let test_tree =
          describe("Suite", [
            after_each(fn() {
              increment(counter)
              AssertionOk
            }),
            it("failing test", fn() {
              1
              |> should()
              |> equal(2)
              |> or_fail_with("Intentional failure")
            }),
          ])

        // Act
        let test_cases = to_test_cases("lifecycle_test", test_tree)
        let _results = run_all(test_cases)

        // Assert: after_each should still run
        get_count(counter)
        |> should()
        |> equal(1)
        |> or_fail_with("after_each should run even when test fails")
      }),
    ]),
    describe("before_all / after_all (suite mode)", [
      it("before_all runs once per group", fn() {
        // Arrange
        let counter = start_counter()

        let test_tree =
          describe("Suite", [
            before_all(fn() {
              increment(counter)
              AssertionOk
            }),
            it("test one", fn() { AssertionOk }),
            it("test two", fn() { AssertionOk }),
          ])

        // Act: Use suite mode
        let suite = to_test_suite("lifecycle_test", test_tree)
        let _results = run_suite(suite)

        // Assert: before_all should run only once
        get_count(counter)
        |> should()
        |> equal(1)
        |> or_fail_with("before_all should run exactly once per group")
      }),
      it("after_all runs once per group", fn() {
        // Arrange
        let counter = start_counter()

        let test_tree =
          describe("Suite", [
            after_all(fn() {
              increment(counter)
              AssertionOk
            }),
            it("test one", fn() { AssertionOk }),
            it("test two", fn() { AssertionOk }),
          ])

        // Act
        let suite = to_test_suite("lifecycle_test", test_tree)
        let _results = run_suite(suite)

        // Assert
        get_count(counter)
        |> should()
        |> equal(1)
        |> or_fail_with("after_all should run exactly once per group")
      }),
      it("before_all failure skips all tests in group", fn() {
        // Arrange
        let test_tree =
          describe("Suite", [
            before_all(fn() {
              1
              |> should()
              |> equal(2)
              |> or_fail_with("Intentional before_all failure")
            }),
            it("test one", fn() { AssertionOk }),
            it("test two", fn() { AssertionOk }),
          ])

        // Act
        let suite = to_test_suite("lifecycle_test", test_tree)
        let results = run_suite(suite)

        // Assert: all tests should be marked as SetupFailed
        case results {
          [first, second] -> {
            case first.status == SetupFailed && second.status == SetupFailed {
              True -> AssertionOk
              False ->
                1
                |> should()
                |> equal(2)
                |> or_fail_with("Both tests should be SetupFailed")
            }
          }
          _ ->
            1
            |> should()
            |> equal(2)
            |> or_fail_with("Expected exactly 2 results")
        }
      }),
    ]),
    describe("hook execution order", [
      it("before_each runs outer-to-inner", fn() {
        // This test verifies the order by checking the final counter value
        // after incrementing in specific ways
        let counter = start_counter()

        let test_tree =
          describe("Outer", [
            // Outer hook: multiply by 10 (conceptually, we just increment)
            before_each(fn() {
              // First hook: add 10
              increment(counter)
              increment(counter)
              increment(counter)
              increment(counter)
              increment(counter)
              increment(counter)
              increment(counter)
              increment(counter)
              increment(counter)
              increment(counter)
              AssertionOk
            }),
            describe("Inner", [
              // Inner hook: add 1
              before_each(fn() {
                increment(counter)
                AssertionOk
              }),
              it("test", fn() { AssertionOk }),
            ]),
          ])

        // Act
        let test_cases = to_test_cases("lifecycle_test", test_tree)
        let _results = run_all(test_cases)

        // Assert: outer runs first (adds 10), then inner (adds 1) = 11
        get_count(counter)
        |> should()
        |> equal(11)
        |> or_fail_with("Hooks should run outer-to-inner")
      }),
    ]),
    describe("combined hooks", [
      it("all hook types work together", fn() {
        // Arrange
        let before_all_counter = start_counter()
        let before_each_counter = start_counter()
        let after_each_counter = start_counter()
        let after_all_counter = start_counter()

        let test_tree =
          describe("Suite", [
            before_all(fn() {
              increment(before_all_counter)
              AssertionOk
            }),
            before_each(fn() {
              increment(before_each_counter)
              AssertionOk
            }),
            after_each(fn() {
              increment(after_each_counter)
              AssertionOk
            }),
            after_all(fn() {
              increment(after_all_counter)
              AssertionOk
            }),
            it("test one", fn() { AssertionOk }),
            it("test two", fn() { AssertionOk }),
          ])

        // Act: use suite mode
        let suite = to_test_suite("lifecycle_test", test_tree)
        let results = run_suite(suite)

        // Assert: verify all hooks ran correct number of times
        let before_all_count = get_count(before_all_counter)
        let before_each_count = get_count(before_each_counter)
        let after_each_count = get_count(after_each_counter)
        let after_all_count = get_count(after_all_counter)

        // All tests should pass
        case results {
          [first, second] -> {
            case first.status == Passed && second.status == Passed {
              True -> {
                // Verify hook counts
                case
                  before_all_count == 1
                  && before_each_count == 2
                  && after_each_count == 2
                  && after_all_count == 1
                {
                  True -> AssertionOk
                  False ->
                    1
                    |> should()
                    |> equal(2)
                    |> or_fail_with(
                      "Hook counts: before_all="
                      <> int_to_string(before_all_count)
                      <> " before_each="
                      <> int_to_string(before_each_count)
                      <> " after_each="
                      <> int_to_string(after_each_count)
                      <> " after_all="
                      <> int_to_string(after_all_count),
                    )
                }
              }
              False ->
                1
                |> should()
                |> equal(2)
                |> or_fail_with("Tests should pass")
            }
          }
          _ ->
            1
            |> should()
            |> equal(2)
            |> or_fail_with("Expected 2 results")
        }
      }),
    ]),
  ])
}

fn int_to_string(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    _ -> "?"
  }
}
