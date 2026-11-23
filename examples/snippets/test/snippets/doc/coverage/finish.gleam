import app/cart
import dream_test/coverage
import dream_test/coverage/report.{type CoverageReport}

pub fn measure_my_tests() -> #(Bool, CoverageReport) {
  let assert Ok(session) = coverage.start(coverage.new())
  let tests_passed = run_my_tests()
  let assert Ok(coverage_report) = coverage.finish(session)
  #(tests_passed, coverage_report)
}

fn run_my_tests() -> Bool {
  cart.total([10, 20]) == 30
}
