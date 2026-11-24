import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/types.{type SuiteInfo, type TestInfo}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/io
import gleam/list
import gleam/string

pub fn cart_tests() {
  describe("Cart", [
    it("starts empty", fn() { Ok(succeed()) }),
    it("adds an item", fn() { Ok(succeed()) }),
  ])
}

pub fn checkout_tests() {
  describe("Checkout", [
    it("charges the card", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  runner.new([cart_tests(), checkout_tests()])
  |> runner.max_concurrency(1)
  |> runner.before_all_suites(start_database)
  |> runner.after_all_suites(stop_database)
  |> runner.before_each_suite(create_schema)
  |> runner.before_each_test(log_test)
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

fn start_database(suites: List(SuiteInfo)) -> Result(Nil, String) {
  io.println(
    "start the database for " <> int.to_string(list.length(suites)) <> " suites",
  )
  Ok(Nil)
}

fn stop_database(_suites: List(SuiteInfo)) -> Result(Nil, String) {
  io.println("stop the database")
  Ok(Nil)
}

fn create_schema(suite: SuiteInfo) -> Result(Nil, String) {
  io.println("  create a schema for " <> suite.name)
  Ok(Nil)
}

fn log_test(info: TestInfo) -> Result(Nil, String) {
  io.println(
    "    run " <> string.join(types.full_name(info.groups, info.name), " > "),
  )
  Ok(Nil)
}
