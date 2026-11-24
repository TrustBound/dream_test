import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/runner.{type TestInfo}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}
import gleam/list

pub fn only_migrations(info: TestInfo) -> Bool {
  list.contains(info.tags, "migration")
}

pub fn main() -> RunReport {
  runner.new([
    describe("Cart", [
      it("starts empty", fn() { Ok(succeed()) }),
    ]),
  ])
  |> runner.filter_tests(only_migrations)
  |> runner.results_reporters([bdd.new()])
  |> runner.allow_no_tests()
  |> runner.exit_on_failure()
  |> runner.run()
}
