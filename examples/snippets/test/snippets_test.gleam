//// Main test runner for all README snippets
////
//// Each snippet lives in its own file for easy linking from README.md

import chaining
import custom_matchers
import dream_test/reporter/api as reporter
import dream_test/runner
import execution_modes
import explicit_failures
import gherkin_discover
import gherkin_feature
import gherkin_file
import gherkin_hero
import gherkin_placeholders
import gherkin_step_handler
import gleam/io
import hero
import hook_failure
import hook_inheritance
import json_reporter
import lifecycle_hooks
import quick_start
import runner_config
import sequential_execution
import skipping_tests
import snapshot_testing

pub fn suites() {
  [
    quick_start.tests(),
    hero.tests(),
    chaining.tests(),
    custom_matchers.tests(),
    lifecycle_hooks.tests(),
    explicit_failures.tests(),
    hook_inheritance.tests(),
    hook_failure.tests(),
    runner_config.tests(),
    json_reporter.tests(),
    sequential_execution.tests(),
    execution_modes.tests(),
    skipping_tests.tests(),
    snapshot_testing.tests(),
    gherkin_hero.tests(),
    gherkin_feature.tests(),
    gherkin_step_handler.tests(),
    gherkin_placeholders.tests(),
    gherkin_file.tests(),
    gherkin_discover.tests(),
  ]
}

pub fn main() {
  runner.new(suites())
  |> runner.reporter(reporter.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
