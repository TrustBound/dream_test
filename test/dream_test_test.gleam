import dream_test/assertions/should_test
import dream_test/file_test
import dream_test/gherkin/feature_test
import dream_test/gherkin/parser_test
import dream_test/gherkin/step_trie_test
import dream_test/gherkin/steps_test
import dream_test/gherkin/types_test as gherkin_types_test
import dream_test/gherkin/world_test
import dream_test/lifecycle_test
import dream_test/matchers/snapshot_test
import dream_test/process_test
import dream_test/reporter/bdd.{report}
import dream_test/reporter/bdd_test
import dream_test/reporter/json_test
import dream_test/runner.{exit_on_failure, run_all}
import dream_test/runner_test
import dream_test/sandbox_test
import dream_test/types_test
import dream_test/unit.{describe, to_test_cases}
import dream_test/unit_test
import gleam/io

pub fn main() {
  describe("dream_test", [
    types_test.tests(),
    should_test.tests(),
    runner_test.tests(),
    unit_test.tests(),
    bdd_test.tests(),
    json_test.tests(),
    sandbox_test.tests(),
    process_test.tests(),
    lifecycle_test.tests(),
    file_test.tests(),
    snapshot_test.tests(),
    // Gherkin module tests
    gherkin_types_test.tests(),
    step_trie_test.tests(),
    world_test.tests(),
    steps_test.tests(),
    parser_test.tests(),
    feature_test.tests(),
  ])
  |> to_test_cases("dream_test_test", _)
  |> run_all()
  |> report(io.print)
  |> exit_on_failure()
}
