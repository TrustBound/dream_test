import dream_test/coverage
import dream_test/file
import dream_test/matchers.{succeed}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult, type RunReport}
import dream_test/unit.{after_all, before_all, describe, it}
import gleam/result

pub fn app_tests() -> TestSuite {
  describe("app", [
    before_all(fn() {
      file.delete("build/coverage/servers/app.info")
      |> result.map_error(file.error_to_string)
    }),
    before_all(start_server),
    after_all(stop_server_and_wait_for_exit),
    it("serves the home page", get_home_page),
  ])
}

pub fn main() -> RunReport {
  runner.new([app_tests()])
  |> runner.coverage(
    coverage.new()
    |> coverage.merge_lcov("build/coverage/servers/*.info"),
  )
  |> runner.run()
}

fn start_server() -> Result(Nil, String) {
  // Start the server as a separate OS process here.
  Ok(Nil)
}

fn stop_server_and_wait_for_exit() -> Result(Nil, String) {
  // Send the stop request and wait until the server has exited here.
  Ok(Nil)
}

fn get_home_page() -> Result(AssertionResult, String) {
  // Request the home page and check the response here.
  Ok(succeed())
}
