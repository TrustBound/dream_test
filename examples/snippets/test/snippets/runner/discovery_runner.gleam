//// Quick start: module discovery runner
////
//// This is the minimal “I don’t want to import 40 test modules” setup.
////
//// Note: module discovery is BEAM-only (Erlang target).

import dream_test/discover.{from_path, to_suites}
import dream_test/reporters
import dream_test/runner
import gleam/io

pub fn main() {
  let suites =
    discover.new()
    |> from_path("snippets/unit/**.gleam")
    |> to_suites()

  runner.new(suites)
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
