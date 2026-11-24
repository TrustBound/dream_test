import dream_test/matchers.{succeed}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type RunReport, type TestInfo}
import dream_test/unit.{describe, it}
import gleam/io
import gleam/string

pub fn tests() -> TestSuite {
  describe("Example", [
    it("works", fn() { Ok(succeed()) }),
  ])
}

pub fn log_test(info: TestInfo) -> Result(Nil, String) {
  let name = string.join(types.full_name(info.groups, info.name), " > ")
  io.println("starting " <> name)
  Ok(Nil)
}

pub fn main() -> RunReport {
  runner.new([tests()])
  |> runner.before_each_test(log_test)
  |> runner.run()
}
