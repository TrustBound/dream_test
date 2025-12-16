//// README: Lifecycle hooks

import dream_test/assertions/should.{be_empty, or_fail_with, should}
import dream_test/reporter/api as reporter
import dream_test/runner
import dream_test/unit.{
  after_all, after_each, before_all, before_each, describe, it,
}
import gleam/io

pub fn tests() {
  describe("Database tests", [
    before_all(fn() {
      // Start database once for all tests
      Ok(Nil)
    }),
    before_each(fn(_) {
      // Begin transaction before each test
      Ok(Nil)
    }),
    it("creates a record", fn(_) {
      []
      |> should()
      |> be_empty()
      |> or_fail_with("Placeholder test")
    }),
    it("queries records", fn(_) {
      []
      |> should()
      |> be_empty()
      |> or_fail_with("Placeholder test")
    }),
    after_each(fn(_) {
      // Rollback transaction after each test
      Ok(Nil)
    }),
    after_all(fn(_) {
      // Stop database after all tests
      Ok(Nil)
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporter.bdd(io.print, True))
  |> runner.run()
  |> runner.exit_results_on_failure
}
