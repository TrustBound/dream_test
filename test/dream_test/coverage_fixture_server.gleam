//// A fixture server that measures its own coverage, for
//// test/dream_test/runner_coverage_test.gleam.
////
//// `coverage_runner_mains.server_coverage_merged` starts it in its own `erl`
//// process, the way integration tests start an application server. It reads
//// one request per line from standard input and writes one reply per line:
////
//// - `classify`: calls `sample.classify(1)`
//// - `answer`: calls `deep.answer()`
//// - `stop` (or the end of standard input): finishes coverage, which writes
////   the LCOV file, and replies `stopped`
////
//// The test run then merges the LCOV file with `coverage.merge_lcov`. This
//// module follows the recipe in the `dream_test/coverage` docs, "Coverage
//// from other BEAM instances".

import coverage_fixtures/nested/deep
import coverage_fixtures/sample
import dream_test/coverage.{type CoverageSession}
import gleam/int
import gleam/io
import gleam/string

/// The LCOV file the server writes when it stops.
pub fn lcov_path() -> String {
  "build/coverage/servers/fixture_server.info"
}

@external(erlang, "dream_test_coverage_test_ffi", "read_line")
fn read_line() -> Result(String, Nil)

/// Start coverage, then serve requests until `stop`.
pub fn main() -> Nil {
  let config =
    coverage.new()
    |> coverage.source_directory("test/coverage_fixtures")
    |> coverage.lcov_path(lcov_path())
  case coverage.start(config) {
    Ok(session) -> serve(session)
    Error(error) ->
      io.println("coverage did not start: " <> string.inspect(error))
  }
}

fn serve(session: CoverageSession) -> Nil {
  case read_line() {
    Ok("classify") -> reply_then_serve(session, sample.classify(1))
    Ok("answer") -> reply_then_serve(session, int.to_string(deep.answer()))
    Ok("stop") | Error(Nil) -> stop(session)
    Ok(request) -> reply_then_serve(session, "unknown request: " <> request)
  }
}

fn reply_then_serve(session: CoverageSession, reply: String) -> Nil {
  io.println(reply)
  serve(session)
}

/// The server's stop path: finish coverage before the BEAM halts, so the
/// LCOV file is written.
fn stop(session: CoverageSession) -> Nil {
  case coverage.finish(session) {
    Ok(_report) -> io.println("stopped")
    Error(error) -> io.println("coverage failed: " <> string.inspect(error))
  }
}
