import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, type StepRegistry}
import dream_test/matchers.{be_equal, be_false, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types
import dream_test/unit
import dream_test/unit_context
import gleam/erlang/process.{type Subject}
import gleam/result
import snippets_outputs

// A small server: a process that answers each ping with "pong".

pub type Request {
  Ping(reply_to: Subject(String))
  Stop
}

pub type ServerState {
  ServerState(server: Subject(Request), reply: String)
}

fn start_server() -> Result(ServerState, String) {
  let started = process.new_subject()
  process.spawn(fn() { serve(started) })
  process.receive(started, 1000)
  |> result.replace_error("the server did not start")
  |> result.map(new_server_state)
}

fn stop_server(state: ServerState) -> Result(Nil, String) {
  process.send(state.server, Stop)
  Ok(Nil)
}

fn new_server_state(server: Subject(Request)) -> ServerState {
  ServerState(server: server, reply: "")
}

fn serve(started: Subject(Subject(Request))) -> Nil {
  let requests = process.new_subject()
  process.send(started, requests)
  answer(requests)
}

fn answer(requests: Subject(Request)) -> Nil {
  case process.receive_forever(requests) {
    Ping(reply_to: reply_to) -> {
      process.send(reply_to, "pong")
      answer(requests)
    }
    Stop -> Nil
  }
}

// The steps. The setup starts the server once, before the first scenario.
// Each scenario starts from its value. The teardown stops the server after
// the last scenario.

fn server_steps() -> StepRegistry(ServerState) {
  steps.new_with_setup(setup: start_server, teardown: stop_server)
  |> steps.given("the server is running", server_is_running)
  |> steps.when("I ping the server", ping)
  |> steps.then("the reply is {string}", reply_is)
}

fn server_is_running(state: ServerState, _context: StepContext) {
  Ok(state)
}

fn ping(
  state: ServerState,
  _context: StepContext,
) -> Result(ServerState, String) {
  let reply = process.call(state.server, 1000, Ping)
  Ok(ServerState(..state, reply: reply))
}

fn reply_is(state: ServerState, context: StepContext) {
  use expected <- result.try(steps.get_string(context.captures, 0))
  state.reply
  |> should
  |> be_equal(expected)
  |> or_fail_with("the server should answer")
}

pub fn server_feature() -> TestSuite {
  feature("Server", server_steps(), [
    scenario("Ping the server", [
      given("the server is running"),
      when("I ping the server"),
      then("the reply is \"pong\""),
    ]),
    scenario("Ping it again", [
      given("the server is running"),
      when("I ping the server"),
      then("the reply is \"pong\""),
    ]),
  ])
}

// Suites whose trees have other contexts run in the same `runner.new`.

pub fn math_suite() -> TestSuite {
  unit.describe("Math", [
    unit.it("adds", fn() {
      1 + 1
      |> should
      |> be_equal(2)
      |> or_fail_with("1 + 1 should be 2")
    }),
  ])
}

pub fn counter_suite() -> TestSuite {
  unit_context.describe("Counter", 41, [
    unit_context.it("starts at 41", fn(count: Int) {
      count
      |> should
      |> be_equal(41)
      |> or_fail_with("the counter should start at 41")
    }),
  ])
}

pub fn main() {
  runner.new([server_feature(), math_suite(), counter_suite()])
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

pub fn tests() {
  unit.describe("A feature with a server, mixed with other suites", [
    unit.it("runs every suite with its own context", fn() {
      runner.new([server_feature(), math_suite(), counter_suite()])
      |> runner.silent()
      |> runner.run()
      |> types.failed
      |> should
      |> be_false()
      |> or_fail_with("every suite should pass")
    }),
    unit.it("prints the report that the guide shows", fn() {
      // Act
      let report =
        runner.new([server_feature(), math_suite(), counter_suite()])
        |> runner.silent()
        |> runner.run()
        |> snippets_outputs.without_durations()
        |> render_as_bdd_new()

      // Assert
      Ok(report)
      |> should
      |> be_equal(snippets_outputs.read("gherkin_setup_report"))
      |> or_fail_with("expected test/outputs/gherkin_setup_report.txt")
    }),
  ])
}

/// The report as `bdd.new()` prints it: with no colour, every test.
fn render_as_bdd_new(report: types.RunReport) -> String {
  bdd.render(
    config: reporter_types.BddReporterConfig(
      color: False,
      mode: reporter_types.BddFull,
    ),
    report: report,
  )
}
