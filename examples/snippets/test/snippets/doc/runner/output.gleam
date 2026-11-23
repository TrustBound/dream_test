import dream_test/matchers.{succeed}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() -> TestSuite {
  describe("Example", [
    it("works", fn() { Ok(succeed()) }),
  ])
}

pub fn main() -> RunReport {
  runner.new([tests()])
  |> runner.output(runner.Output(out: io.print, error: io.print_error))
  |> runner.run()
}
