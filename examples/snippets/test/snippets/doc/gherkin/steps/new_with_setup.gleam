import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, get_string, given, new_with_setup, then,
  when,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{type AssertionResult}
import gleam/result

pub type Server {
  Server(running: Bool, reply: String)
}

fn start_server() -> Result(Server, String) {
  Ok(Server(running: True, reply: ""))
}

fn stop_server(_server: Server) -> Result(Nil, String) {
  Ok(Nil)
}

fn step_server_running(
  server: Server,
  _context: StepContext,
) -> Result(Server, String) {
  case server.running {
    True -> Ok(server)
    False -> Error("the server is not running")
  }
}

fn step_ping(server: Server, _context: StepContext) -> Result(Server, String) {
  Ok(Server(..server, reply: "pong"))
}

fn step_reply_is(
  server: Server,
  context: StepContext,
) -> Result(AssertionResult, String) {
  use expected <- result.try(get_string(context.captures, 0))
  server.reply
  |> should
  |> be_equal(expected)
  |> or_fail_with("unexpected reply")
}

pub fn server_steps() -> StepRegistry(Server) {
  new_with_setup(setup: start_server, teardown: stop_server)
  |> given("the server is running", step_server_running)
  |> when("I ping the server", step_ping)
  |> then("the reply is {string}", step_reply_is)
}
