//// Main test runner for all README snippets
////
//// Each snippet lives in its own file for easy linking from README.md

import chaining
import dream_test/reporter/bdd.{report}
import dream_test/runner.{exit_on_failure, run_all}
import dream_test/unit.{describe, to_test_cases}
import execution_modes
import explicit_failures
import gleam/io
import hero
import hook_failure
import hook_inheritance
import lifecycle_hooks
import quick_start
import runner_config
import skipping_tests

pub fn tests() {
  describe("README Snippets", [
    quick_start.tests(),
    hero.tests(),
    chaining.tests(),
    lifecycle_hooks.tests(),
    explicit_failures.tests(),
    hook_inheritance.tests(),
    hook_failure.tests(),
    runner_config.tests(),
    execution_modes.tests(),
    skipping_tests.tests(),
  ])
}

pub fn main() {
  let results =
    to_test_cases("snippets_test", tests())
    |> run_all()

  report(results, io.print)
  exit_on_failure(results)
}
