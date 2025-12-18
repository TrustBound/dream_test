import dream_test/context_api_test
import dream_test/file_api_test
import dream_test/gherkin/discover_api_test as gherkin_discover_api_test
import dream_test/gherkin/feature_api_test as gherkin_feature_api_test
import dream_test/gherkin/parser_api_test as gherkin_parser_api_test
import dream_test/gherkin/step_trie_api_test as gherkin_step_trie_api_test
import dream_test/gherkin/steps_api_test as gherkin_steps_api_test
import dream_test/gherkin/types_api_test as gherkin_types_api_test
import dream_test/gherkin/world_api_test as gherkin_world_api_test
import dream_test/matchers/boolean_test as matcher_boolean_test
import dream_test/matchers/collection_test as matcher_collection_test
import dream_test/matchers/comparison_test as matcher_comparison_test
import dream_test/matchers/equality_test as matcher_equality_test
import dream_test/matchers/option_test as matcher_option_test
import dream_test/matchers/result_test as matcher_result_test
import dream_test/matchers/snapshot_test as matcher_snapshot_test
import dream_test/matchers/string_test as matcher_string_test
import dream_test/parallel_api_test
import dream_test/process_api_test
import dream_test/reporter
import dream_test/reporter/api_test as reporter_api_test
import dream_test/reporter/bdd_test as reporter_bdd_test
import dream_test/reporter/gherkin_test as reporter_gherkin_test
import dream_test/reporter/json_test as reporter_json_test
import dream_test/reporter/progress_test as reporter_progress_test
import dream_test/runner
import dream_test/runner_api_test
import dream_test/sandbox_api_test
import dream_test/should_api_test
import dream_test/timing_api_test
import dream_test/types_api_test
import dream_test/unit_api_test
import dream_test/unit_context_api_test
import dream_test/unit_hooks_order_test
import gleam/io

pub fn main() {
  let suites = [
    unit_api_test.tests(),
    unit_context_api_test.tests(),
    unit_hooks_order_test.tests(),
    runner_api_test.tests(),
    sandbox_api_test.tests(),
    parallel_api_test.tests(),
    file_api_test.tests(),
    context_api_test.tests(),
    should_api_test.tests(),
    types_api_test.tests(),
    timing_api_test.tests(),
    process_api_test.tests(),
    reporter_api_test.tests(),
    reporter_bdd_test.tests(),
    reporter_json_test.tests(),
    reporter_progress_test.tests(),
    reporter_gherkin_test.tests(),
    matcher_boolean_test.tests(),
    matcher_collection_test.tests(),
    matcher_comparison_test.tests(),
    matcher_equality_test.tests(),
    matcher_option_test.tests(),
    matcher_result_test.tests(),
    matcher_string_test.tests(),
    matcher_snapshot_test.tests(),
    gherkin_types_api_test.tests(),
    gherkin_step_trie_api_test.tests(),
    gherkin_steps_api_test.tests(),
    gherkin_world_api_test.tests(),
    gherkin_parser_api_test.tests(),
    gherkin_feature_api_test.tests(),
    gherkin_discover_api_test.tests(),
  ]

  runner.new(suites)
  |> runner.reporter(reporter.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
