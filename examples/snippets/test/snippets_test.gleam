//// README code examples - copy these verbatim into README.md
////
//// Each function corresponds to a README section.
//// If tests fail, update both here AND in README.md.

import dream_test/assertions/should.{
  be_empty, be_error, be_ok, be_some, equal, fail_with, or_fail_with, should,
}
import dream_test/reporter/bdd.{report}
import dream_test/runner.{RunnerConfig, run_all, run_all_with_config, run_suite}
import dream_test/types.{AssertionOk}
import dream_test/unit.{
  after_all, after_each, before_all, before_each, describe, it, to_test_cases,
  to_test_suite,
}
import gleam/io
import gleam/option.{Some}
import snippets.{add, divide}

// =============================================================================
// README: Hero Example
// Copy lines 24-42 into README hero section
// =============================================================================

pub fn hero_tests() {
  describe("Calculator", [
    it("adds two numbers", fn() {
      add(2, 3)
      |> should()
      |> equal(5)
      |> or_fail_with("2 + 3 should equal 5")
    }),
    it("handles division", fn() {
      divide(10, 2)
      |> should()
      |> be_ok()
      |> equal(5)
      |> or_fail_with("10 / 2 should equal 5")
    }),
    it("returns error for division by zero", fn() {
      divide(1, 0)
      |> should()
      |> be_error()
      |> or_fail_with("Division by zero should error")
    }),
  ])
}

// =============================================================================
// README: Chaining Matchers
// Copy lines 54-68 into README chaining section
// =============================================================================

pub fn chaining_tests() {
  describe("Chaining matchers", [
    // Unwrap Some, then check the value
    it("unwraps Option", fn() {
      Some(42)
      |> should()
      |> be_some()
      |> equal(42)
      |> or_fail_with("Should contain 42")
    }),
    // Unwrap Ok, then check the value
    it("unwraps Result", fn() {
      Ok("success")
      |> should()
      |> be_ok()
      |> equal("success")
      |> or_fail_with("Should be Ok with 'success'")
    }),
  ])
}

// =============================================================================
// README: Lifecycle Hooks
// Copy lines 77-101 into README lifecycle section
// =============================================================================

pub fn lifecycle_tests() {
  describe("Database tests", [
    before_all(fn() {
      // Start database once for all tests
      AssertionOk
    }),
    before_each(fn() {
      // Begin transaction before each test
      AssertionOk
    }),
    it("creates a record", fn() {
      []
      |> should()
      |> be_empty()
      |> or_fail_with("Placeholder test")
    }),
    it("queries records", fn() {
      []
      |> should()
      |> be_empty()
      |> or_fail_with("Placeholder test")
    }),
    after_each(fn() {
      // Rollback transaction after each test
      AssertionOk
    }),
    after_all(fn() {
      // Stop database after all tests
      AssertionOk
    }),
  ])
}

// =============================================================================
// README: Explicit Failures
// =============================================================================

pub fn explicit_failure_tests() {
  describe("Explicit failures", [
    it("fails explicitly when needed", fn() {
      let result = divide(10, 2)
      case result {
        Ok(_) -> AssertionOk
        Error(_) -> fail_with("Should have succeeded")
      }
    }),
  ])
}

// =============================================================================
// README: Hook Inheritance
// =============================================================================

pub fn hook_inheritance_tests() {
  describe("Outer", [
    before_each(fn() {
      io.println("1. outer setup")
      AssertionOk
    }),
    after_each(fn() {
      io.println("4. outer teardown")
      AssertionOk
    }),
    describe("Inner", [
      before_each(fn() {
        io.println("2. inner setup")
        AssertionOk
      }),
      after_each(fn() {
        io.println("3. inner teardown")
        AssertionOk
      }),
      it("test", fn() {
        io.println("(test)")
        AssertionOk
      }),
    ]),
  ])
}

// =============================================================================
// README: Hook Failure Behavior
// =============================================================================

fn connect_to_database() {
  Ok(Nil)
}

pub fn hook_failure_tests() {
  describe("Handles failures", [
    before_all(fn() {
      case connect_to_database() {
        Ok(_) -> AssertionOk
        Error(e) -> fail_with("Database connection failed: " <> e)
      }
    }),
    // If before_all fails, these tests are marked SetupFailed (not run)
    it("test1", fn() { AssertionOk }),
    it("test2", fn() { AssertionOk }),
  ])
}

// =============================================================================
// README: Runner Config
// =============================================================================

pub fn run_with_config() {
  let config = RunnerConfig(max_concurrency: 8, default_timeout_ms: 10_000)

  let test_cases = to_test_cases("my_test", tests())
  run_all_with_config(config, test_cases)
  |> report(io.print)
}

// =============================================================================
// README: Execution Modes
// =============================================================================

pub fn tests() {
  describe("README Snippets", [
    hero_tests(),
    chaining_tests(),
    explicit_failure_tests(),
  ])
}

// Flat mode - simpler, faster
pub fn run_flat_mode() {
  to_test_cases("my_test", tests())
  |> run_all()
  |> report(io.print)
}

// Suite mode - preserves group structure for before_all/after_all
pub fn run_suite_mode() {
  to_test_suite("my_test", tests())
  |> run_suite()
  |> report(io.print)
}

// =============================================================================
// Main
// =============================================================================

pub fn main() {
  to_test_cases("snippets_test", tests())
  |> run_all()
  |> report(io.print)
}
