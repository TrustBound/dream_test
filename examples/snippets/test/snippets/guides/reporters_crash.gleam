import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}

pub fn main() {
  runner.new([cart_tests()])
  |> runner.results_reporters([
    bdd.new() |> bdd.summary_only(),
    reporter_types.Custom(broken_report),
  ])
  |> runner.exit_on_failure()
  |> runner.run()
}

/// A report that crashes, as one with a bug does.
fn broken_report(_report: RunReport) -> String {
  panic as "the report template is missing"
}

fn cart_tests() {
  describe("Cart", [
    it("starts empty", fn() { Ok(succeed()) }),
  ])
}
