//// Main test runner for all README snippets
////
//// Each snippet lives in its own file for easy linking from README.md

import chaining
import dream_test/reporter/bdd.{report}
import dream_test/runner.{exit_on_failure, run_all, run_suite}
import dream_test/unit.{describe, to_test_cases}
import execution_modes
import explicit_failures
import gherkin_discover
import gherkin_feature
import gherkin_file
import gherkin_hero
import gherkin_placeholders
import gherkin_step_handler
import gleam/io
import gleam/list
import hero
import hook_failure
import hook_inheritance
import lifecycle_hooks
import quick_start
import runner_config
import sequential_execution
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
    sequential_execution.tests(),
    execution_modes.tests(),
    skipping_tests.tests(),
  ])
}

pub fn main() {
  // Run unit test snippets
  let unit_results =
    to_test_cases("snippets_test", tests())
    |> run_all()

  // Run Gherkin snippets (these return TestSuite, not UnitTest)
  let gherkin_results =
    [
      gherkin_hero.tests(),
      gherkin_feature.tests(),
      gherkin_step_handler.tests(),
      gherkin_placeholders.tests(),
      gherkin_file.tests(),
      gherkin_discover.tests(),
    ]
    |> list.flat_map(run_suite)

  let all_results = list.append(unit_results, gherkin_results)

  report(all_results, io.print)
  exit_on_failure(all_results)
}
