import dream_test/coverage
import dream_test/file
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/runner
import dream_test/unit.{after_all, before_all, describe, it}
import gleam/io
import gleam/option.{Some}
import gleam/result

// The server: it measures itself and writes an LCOV file when it stops.

pub fn server_main() {
  let config =
    coverage.new()
    |> coverage.lcov_path("build/coverage/servers/app.info")
  let assert Ok(session) = coverage.start(config)
  serve_until_stop_requested()
  let assert Ok(_) = coverage.finish(session)
}

fn serve_until_stop_requested() -> Nil {
  io.println("Serving until a stop request comes")
}

// The test run: it starts the server, stops it, and merges its LCOV file.

pub fn app_tests() {
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

pub fn main() {
  runner.new([app_tests()])
  |> runner.coverage(
    coverage.new()
    |> coverage.merge_lcov("build/coverage/servers/*.info"),
  )
  |> runner.exit_on_failure()
  |> runner.run()
}

fn start_server() -> Result(Nil, String) {
  Ok(Nil)
}

fn stop_server_and_wait_for_exit() -> Result(Nil, String) {
  Ok(Nil)
}

fn get_home_page() {
  Ok(succeed())
}

pub fn tests() {
  describe("Coverage from a server", [
    it("writes the server LCOV file to its own path", fn() {
      coverage.new()
      |> coverage.lcov_path("build/coverage/servers/app.info")
      |> coverage.lcov_file()
      |> should
      |> be_equal(Some("build/coverage/servers/app.info"))
      |> or_fail_with("the server should write build/coverage/servers/app.info")
    }),
  ])
}
