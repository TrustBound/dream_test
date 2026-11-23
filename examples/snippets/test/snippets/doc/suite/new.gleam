import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult}
import dream_test/unit_context

pub type Server {
  Server(port: Int)
}

fn start_server() -> Result(Server, String) {
  Ok(Server(port: 8080))
}

fn stop_server(_server: Server) -> Result(Nil, String) {
  Ok(Nil)
}

fn answers(server: Server) -> Result(AssertionResult, String) {
  server.port
  |> should
  |> be_equal(8080)
  |> or_fail_with("expected the server on port 8080")
}

pub fn server_suite() -> TestSuite {
  suite.new(
    name: "server",
    tags: [],
    children: [unit_context.it("answers", answers)],
    context: types.ContextFromSetup(setup: start_server, teardown: stop_server),
  )
}
