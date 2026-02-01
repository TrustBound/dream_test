import dream_test/matchers.{succeed}
import dream_test/runner
import dream_test/types.{type SuiteInfo, type TestInfo}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/io
import gleam/list
import gleam/string

pub fn tests() {
  describe("Example", [
    it("a", fn() { Ok(succeed()) }),
    it("b", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.before_all_suites(before_all_suites_hook)
  |> runner.before_each_suite(before_each_suite_hook)
  |> runner.before_each_test(before_each_test_hook)
  |> runner.after_each_test(after_each_test_hook)
  |> runner.run()
}

fn before_all_suites_hook(suites: List(SuiteInfo)) -> Result(Nil, String) {
  io.println("suites: " <> int.to_string(list.length(suites)))
  Ok(Nil)
}

fn before_each_suite_hook(suite: SuiteInfo) -> Result(Nil, String) {
  io.println("suite: " <> suite.name)
  Ok(Nil)
}

fn before_each_test_hook(info: TestInfo, ctx: Nil) -> Result(Nil, String) {
  io.println("test: " <> string.join(info.full_name, " > "))
  Ok(ctx)
}

fn after_each_test_hook(_info: TestInfo, _ctx: Nil) -> Result(Nil, String) {
  Ok(Nil)
}
