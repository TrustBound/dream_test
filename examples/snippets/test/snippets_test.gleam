//// Main test runner for all README snippets
////
//// Each snippet lives in its own file for easy linking from README.md

// Back-compat module name (now located at snippets/unit/chaining.gleam)
import dream_test/reporters
import dream_test/runner
import gleam/io
import snippets/gherkin/gherkin_discover
import snippets/gherkin/gherkin_feature
import snippets/gherkin/gherkin_file
import snippets/gherkin/gherkin_hero
import snippets/gherkin/gherkin_placeholders
import snippets/gherkin/gherkin_step_handler
import snippets/hooks/context_aware_tests
import snippets/hooks/hook_failure
import snippets/hooks/hook_inheritance
import snippets/hooks/lifecycle_hooks
import snippets/matchers/builtin_matchers
import snippets/matchers/custom_matchers
import snippets/matchers/snapshot_testing
import snippets/reporters/bdd_formatting
import snippets/reporters/bdd_reporter
import snippets/reporters/gherkin_reporter
import snippets/reporters/json_formatting
import snippets/reporters/json_reporter
import snippets/reporters/progress_reporter
import snippets/reporters/reporter_api_handle_event
import snippets/runner/execution_modes
import snippets/runner/minimal_test_runner
import snippets/runner/runner_config
import snippets/runner/sequential_execution
import snippets/unit/chaining
import snippets/unit/explicit_failures
import snippets/unit/hero
import snippets/unit/quick_start
import snippets/unit/skipping_tests
import snippets/unit/tagging
import snippets/utils/context_helpers
import snippets/utils/file_helpers
import snippets/utils/parallel_direct
import snippets/utils/process_helpers
import snippets/utils/sandboxing
import snippets/utils/timing_helpers
import snippets/utils/types_helpers

pub fn suites() {
  // This example suite uses a custom context type (not Nil), so it is not
  // included in the unified `runner.new([...])` run.
  let _ = context_aware_tests.compile_check()

  [
    builtin_matchers.tests(),
    context_helpers.tests(),
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
    json_formatting.tests(),
    progress_reporter.tests(),
    reporter_api_handle_event.tests(),
    sequential_execution.tests(),
    execution_modes.tests(),
    minimal_test_runner.tests(),
    skipping_tests.tests(),
    tagging.tests(),
    snapshot_testing.tests(),
    sandboxing.tests(),
    timing_helpers.tests(),
    file_helpers.tests(),
    process_helpers.tests(),
    types_helpers.tests(),
    parallel_direct.tests(),
    gherkin_hero.tests(),
    gherkin_feature.tests(),
    gherkin_step_handler.tests(),
    gherkin_placeholders.tests(),
    gherkin_file.tests(),
    gherkin_discover.tests(),
    gherkin_reporter.tests(),
    bdd_reporter.tests(),
    bdd_formatting.tests(),
  ]
}

pub fn main() {
  runner.new(suites())
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
