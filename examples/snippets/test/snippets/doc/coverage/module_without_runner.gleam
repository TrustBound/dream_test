import app/cart
import dream_test/coverage
import dream_test/reporters/coverage as coverage_reporter
import gleam/bool
import gleam/io

pub fn measure_and_print_coverage() -> Nil {
  let config = coverage.new()
  let assert Ok(session) = coverage.start(config)
  let tests_passed = run_my_tests()
  let assert Ok(coverage_report) = coverage.finish(session)
  io.println("Tests passed: " <> bool.to_string(tests_passed))
  io.print(coverage_reporter.render(report: coverage_report, config: config))
}

fn run_my_tests() -> Bool {
  cart.total([10, 20]) == 30
}
