import dream_test/assertions/should_test
import dream_test/lifecycle_test
import dream_test/process_test
import dream_test/reporter/bdd.{report}
import dream_test/reporter/bdd_test
import dream_test/runner.{exit_on_failure, run_all}
import dream_test/runner_test
import dream_test/sandbox_test
import dream_test/types_test
import dream_test/unit.{describe, to_test_cases}
import dream_test/unit_test
import gleam/io

pub fn main() {
  let all_tests =
    describe("dream_test", [
      types_test.tests(),
      should_test.tests(),
      runner_test.tests(),
      unit_test.tests(),
      bdd_test.tests(),
      sandbox_test.tests(),
      process_test.tests(),
      lifecycle_test.tests(),
    ])

  let test_cases = to_test_cases("dream_test_test", all_tests)
  let results = run_all(test_cases)
  report(results, io.print)
  exit_on_failure(results)
}
