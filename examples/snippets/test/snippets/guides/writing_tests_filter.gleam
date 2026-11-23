import dream_test/reporters/bdd
import dream_test/runner
import dream_test/types.{type TestInfo}
import gleam/list
import snippets/guides/writing_tests_cart

pub fn only_smoke(info: TestInfo) -> Bool {
  list.contains(info.tags, "smoke")
}

pub fn without_integration(info: TestInfo) -> Bool {
  !list.contains(info.tags, "integration")
}

pub fn main() {
  runner.new([writing_tests_cart.tests()])
  |> runner.filter_tests(only_smoke)
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

/// A filter with a typo in its tag: it keeps no test.
pub fn only_smoek(info: TestInfo) -> Bool {
  list.contains(info.tags, "smoek")
}

pub fn main_with_typo() {
  runner.new([writing_tests_cart.tests()])
  |> runner.filter_tests(only_smoek)
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
