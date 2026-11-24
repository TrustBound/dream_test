//// Test mains for test/dream_test/no_tests_test.gleam.
////
//// Each function runs the dream_test runner on a run that runs no test.
//// The tests call them in a new `erl` process, so they can check the real
//// output and exit status.

import dream_test/reporters/bdd
import dream_test/runner
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}

fn cart_tests() {
  describe("Cart", [it("starts empty", fn() { Ok(AssertionOk) })])
}

fn keep_no_test(_info: runner.TestInfo) -> Bool {
  False
}

/// A filter that keeps no test, with `exit_on_failure`.
pub fn filter_keeps_nothing() -> Nil {
  let _ =
    runner.new([cart_tests()])
    |> runner.filter_tests(keep_no_test)
    |> runner.results_reporters([bdd.new()])
    |> runner.exit_on_failure()
    |> runner.run()
  Nil
}

/// A runner with no suites, with `exit_on_failure`.
pub fn no_suites() -> Nil {
  let _ =
    runner.new([])
    |> runner.results_reporters([bdd.new()])
    |> runner.exit_on_failure()
    |> runner.run()
  Nil
}

/// A filter that keeps no test, with `exit_on_failure` and
/// `allow_no_tests`.
pub fn filter_keeps_nothing_allowed() -> Nil {
  let _ =
    runner.new([cart_tests()])
    |> runner.filter_tests(keep_no_test)
    |> runner.results_reporters([bdd.new()])
    |> runner.allow_no_tests()
    |> runner.exit_on_failure()
    |> runner.run()
  Nil
}
