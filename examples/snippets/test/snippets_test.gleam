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
import snippets/hooks/hook_failure
import snippets/hooks/hook_inheritance
import snippets/hooks/lifecycle_hooks
import snippets/matchers/api_be_at_least
import snippets/matchers/api_be_at_most
import snippets/matchers/api_be_between
import snippets/matchers/api_be_empty
import snippets/matchers/api_be_equal
import snippets/matchers/api_be_error
import snippets/matchers/api_be_false
import snippets/matchers/api_be_greater_than
import snippets/matchers/api_be_greater_than_float
import snippets/matchers/api_be_in_range
import snippets/matchers/api_be_less_than
import snippets/matchers/api_be_less_than_float
import snippets/matchers/api_be_none
import snippets/matchers/api_be_ok
import snippets/matchers/api_be_some
import snippets/matchers/api_be_true
import snippets/matchers/api_clear_snapshot
import snippets/matchers/api_clear_snapshots_in_directory
import snippets/matchers/api_contain
import snippets/matchers/api_contain_string
import snippets/matchers/api_end_with
import snippets/matchers/api_fail_with
import snippets/matchers/api_have_length
import snippets/matchers/api_match_snapshot
import snippets/matchers/api_match_snapshot_inspect
import snippets/matchers/api_not_contain
import snippets/matchers/api_not_equal
import snippets/matchers/api_or_fail_with
import snippets/matchers/api_should
import snippets/matchers/api_start_with
import snippets/matchers/api_succeed
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
import snippets/runner/filter_tests
import snippets/runner/has_failures
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
  [
    api_should.tests(),
    api_be_equal.tests(),
    api_not_equal.tests(),
    api_be_true.tests(),
    api_be_false.tests(),
    api_be_some.tests(),
    api_be_none.tests(),
    api_be_ok.tests(),
    api_be_error.tests(),
    api_contain.tests(),
    api_not_contain.tests(),
    api_have_length.tests(),
    api_be_empty.tests(),
    api_be_greater_than.tests(),
    api_be_less_than.tests(),
    api_be_at_least.tests(),
    api_be_at_most.tests(),
    api_be_between.tests(),
    api_be_in_range.tests(),
    api_be_greater_than_float.tests(),
    api_be_less_than_float.tests(),
    api_start_with.tests(),
    api_end_with.tests(),
    api_contain_string.tests(),
    api_or_fail_with.tests(),
    api_fail_with.tests(),
    api_succeed.tests(),
    api_match_snapshot.tests(),
    api_match_snapshot_inspect.tests(),
    api_clear_snapshot.tests(),
    api_clear_snapshots_in_directory.tests(),
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
    filter_tests.tests(),
    json_reporter.tests(),
    json_formatting.tests(),
    progress_reporter.tests(),
    reporter_api_handle_event.tests(),
    sequential_execution.tests(),
    execution_modes.tests(),
    minimal_test_runner.tests(),
    has_failures.tests(),
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
