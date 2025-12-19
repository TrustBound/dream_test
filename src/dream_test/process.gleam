//// Process helpers for tests that need actors or async operations.
////
//// When tests run in isolated BEAM processes, any processes spawned by the
//// test are automatically terminated when the test ends. This module provides
//// helpers for common patterns.
////
//// ## Auto-Cleanup
////
//// Processes started with these helpers are linked to the test process.
//// When the test completes (pass, fail, or timeout), all linked processes
//// are automatically cleaned up. No manual teardown needed.
////
//// ## Quick Start
////
//// ```gleam
//// import dream_test/process.{start_counter, get_count, increment}
//// import dream_test/unit.{describe, it}
//// import dream_test/assertions/should.{should, equal, or_fail_with}
////
//// pub fn tests() {
////   describe("Counter", [
////     it("increments correctly", fn() {
////       let counter = start_counter()
////       increment(counter)
////       increment(counter)
////
////       get_count(counter)
////       |> should
////       |> equal(2)
////       |> or_fail_with("Counter should be 2")
////     }),
////   ])
//// }
//// ```
////
//// ## Available Helpers
////
//// | Helper              | Purpose                                      |
//// |---------------------|----------------------------------------------|
//// | `start_counter`     | Simple counter actor for testing state       |
//// | `start_actor`       | Generic actor with custom state and handler  |
//// | `unique_port`       | Generate random port for test servers        |
//// | `await_ready`       | Poll until a condition is true               |
//// | `await_some`        | Poll until a function returns Ok             |

import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/otp/actor

/// Messages for the built-in counter actor.
///
/// Use these with the counter functions or send them directly:
///
/// ```gleam
/// let counter = start_counter()
/// import gleam/erlang/process
/// process.send(counter, Increment)
/// process.send(counter, SetCount(100))
/// ```
///
pub type CounterMessage {
  Increment
  Decrement
  SetCount(Int)
  GetCount(Subject(Int))
}

/// Start a counter actor initialized to 0.
///
/// The counter is linked to the test process and will be automatically
/// cleaned up when the test ends.
///
/// ## Example
///
/// ```gleam
/// let counter = start_counter()
/// increment(counter)
/// increment(counter)
/// get_count(counter)  // -> 2
/// ```
///
pub fn start_counter() -> Subject(CounterMessage) {
  start_counter_with(0)
}

/// Start a counter actor with a specific initial value.
///
/// ## Example
///
/// ```gleam
/// let counter = start_counter_with(100)
/// decrement(counter)
/// get_count(counter)  // -> 99
/// ```
///
pub fn start_counter_with(initial: Int) -> Subject(CounterMessage) {
  let assert Ok(started) =
    actor.new(initial)
    |> actor.on_message(handle_counter_message)
    |> actor.start

  started.data
}

fn handle_counter_message(
  state: Int,
  message: CounterMessage,
) -> actor.Next(Int, CounterMessage) {
  case message {
    Increment -> actor.continue(state + 1)
    Decrement -> actor.continue(state - 1)
    SetCount(value) -> actor.continue(value)
    GetCount(reply_to) -> {
      process.send(reply_to, state)
      actor.continue(state)
    }
  }
}

/// Get the current value from a counter.
///
/// This is a synchronous call that blocks until the counter responds.
///
/// ## Example
///
/// ```gleam
/// let counter = start_counter()
/// increment(counter)
/// let value = get_count(counter)  // -> 1
/// ```
///
pub fn get_count(counter: Subject(CounterMessage)) -> Int {
  actor.call(counter, waiting: 1000, sending: GetCount)
}

/// Increment a counter by 1.
///
/// This is an asynchronous send—it returns immediately.
///
/// ## Example
///
/// ```gleam
/// let counter = start_counter()
/// increment(counter)
/// increment(counter)
/// get_count(counter)  // -> 2
/// ```
///
pub fn increment(counter: Subject(CounterMessage)) -> Nil {
  process.send(counter, Increment)
}

/// Decrement a counter by 1.
///
/// This is an asynchronous send—it returns immediately.
///
/// ## Example
///
/// ```gleam
/// let counter = start_counter_with(10)
/// decrement(counter)
/// get_count(counter)  // -> 9
/// ```
///
pub fn decrement(counter: Subject(CounterMessage)) -> Nil {
  process.send(counter, Decrement)
}

/// Set a counter to a specific value.
///
/// This is an asynchronous send—it returns immediately.
///
/// ## Example
///
/// ```gleam
/// let counter = start_counter()
/// set_count(counter, 42)
/// get_count(counter)  // -> 42
/// ```
///
pub fn set_count(counter: Subject(CounterMessage), value: Int) -> Nil {
  process.send(counter, SetCount(value))
}

/// Port selection strategies for test servers.
///
/// When starting test servers, you need to choose a port:
///
/// - `Port(n)` - Use a specific port number
/// - `RandomPort` - Pick a random available port (recommended)
///
pub type PortSelection {
  /// Use a specific port number.
  Port(Int)
  /// Pick a random available port in a safe range (10000-60000).
  RandomPort
}

/// Generate a unique port number for test servers.
///
/// Returns a random port between 10,000 and 60,000. This range avoids:
/// - Well-known ports (0-1023)
/// - Registered ports commonly used by services (1024-9999)
/// - Ports near the upper limit that some systems reserve
///
/// Using random ports prevents conflicts when running tests in parallel.
///
/// ## Example
///
/// ```gleam
/// let port = unique_port()
/// start_server(port)
/// // port is something like 34521
/// ```
///
pub fn unique_port() -> Int {
  let base = 10_000
  let range = 50_000
  base + int.random(range)
}

/// Start a generic actor with custom state and message handler.
///
/// The actor is linked to the test process and will be automatically
/// cleaned up when the test ends.
///
/// ## Parameters
///
/// - `initial_state` - The actor's starting state
/// - `handler` - Function `fn(state, message) -> actor.Next(state, message)`
///
/// ## Example
///
/// ```gleam
/// import dream_test/process.{call_actor, start_actor}
/// import gleam/erlang/process.{type Subject}
/// import gleam/erlang/process as process
/// import gleam/otp/actor
///
/// pub type TodoMessage {
///   Add(String)
///   GetAll(Subject(List(String)))
/// }
///
/// let todos = start_actor([], fn(items, msg) {
///   case msg {
///     Add(item) -> actor.continue([item, ..items])
///     GetAll(reply) -> {
///       process.send(reply, items)
///       actor.continue(items)
///     }
///   }
/// })
///
/// process.send(todos, Add("Write tests"))
/// process.send(todos, Add("Run tests"))
/// let items = call_actor(todos, GetAll, 1000)
/// // items == ["Run tests", "Write tests"]
/// ```
///
pub fn start_actor(
  initial_state: state,
  handler: fn(state, msg) -> actor.Next(state, msg),
) -> Subject(msg) {
  let assert Ok(started) =
    actor.new(initial_state)
    |> actor.on_message(handler)
    |> actor.start

  started.data
}

/// Call an actor and wait for a response.
///
/// This is a convenience wrapper around `actor.call` that makes the parameter
/// order more ergonomic for piping.
///
/// ## Parameters
///
/// - `subject` - The actor to call
/// - `make_message` - Function that creates the message given a reply subject
/// - `timeout_ms` - How long to wait for a response
///
/// ## Example
///
/// ```gleam
/// pub type Msg {
///   GetValue(Subject(Int))
/// }
///
/// let value = call_actor(my_actor, GetValue, 1000)
/// ```
///
pub fn call_actor(
  subject: Subject(msg),
  make_message: fn(Subject(reply)) -> msg,
  timeout_ms: Int,
) -> reply {
  actor.call(subject, waiting: timeout_ms, sending: make_message)
}

// =============================================================================
// Polling / Await Helpers
// =============================================================================

/// Configuration for polling operations.
///
/// Controls how long to wait and how often to check.
///
/// ## Fields
///
/// - `timeout_ms` - Maximum time to wait before giving up
/// - `interval_ms` - How often to check the condition
///
/// ## Example
///
/// ```gleam
/// // Check every 100ms for up to 10 seconds
/// PollConfig(timeout_ms: 10_000, interval_ms: 100)
/// ```
///
pub type PollConfig {
  PollConfig(
    /// Maximum time to wait in milliseconds.
    timeout_ms: Int,
    /// How often to check the condition in milliseconds.
    interval_ms: Int,
  )
}

/// Default polling configuration.
///
/// - 5 second timeout
/// - Check every 50ms
///
/// Good for operations that might take a few seconds.
///
pub fn default_poll_config() -> PollConfig {
  PollConfig(timeout_ms: 5000, interval_ms: 50)
}

/// Quick polling configuration.
///
/// - 1 second timeout
/// - Check every 10ms
///
/// Good for fast local operations like servers starting.
///
pub fn quick_poll_config() -> PollConfig {
  PollConfig(timeout_ms: 1000, interval_ms: 10)
}

/// Result of a polling operation.
///
/// Either the condition was met (`Ready`) or we gave up (`TimedOut`).
///
pub type PollResult(a) {
  /// The condition was met and returned this value.
  Ready(a)
  /// Timed out waiting for the condition.
  TimedOut
}

/// Wait until a condition returns True.
///
/// Polls the check function at regular intervals until it returns `True`
/// or the timeout is reached.
///
/// ## Use Cases
///
/// - Waiting for a server to start accepting connections
/// - Waiting for a file to appear
/// - Waiting for a service to become healthy
///
/// ## Example
///
/// ```gleam
/// import dream_test/assertions/should.{be_ok, or_fail_with, should}
/// import dream_test/process.{await_ready, quick_poll_config}
///
/// // Wait for server to be ready
/// case await_ready(quick_poll_config(), fn() { is_port_open(port) }) {
///   Ready(True) -> {
///     // Server is up, proceed with test
///     make_request(port)
///     |> should
///     |> be_ok()
///     |> or_fail_with("Request should succeed")
///   }
///   TimedOut -> Ok(fail_with("Server didn't start in time"))
/// }
/// ```
///
pub fn await_ready(config: PollConfig, check: fn() -> Bool) -> PollResult(Bool) {
  poll_until_true(config.timeout_ms, config.interval_ms, check)
}

/// Wait until a function returns Ok.
///
/// Polls the check function at regular intervals until it returns `Ok(value)`
/// or the timeout is reached. The value is returned in `Ready(value)`.
///
/// ## Use Cases
///
/// - Waiting for a record to appear in a database
/// - Waiting for an async job to complete
/// - Waiting for a resource to become available
///
/// ## Example
///
/// ```gleam
/// import dream_test/assertions/should.{equal, or_fail_with, should}
/// import dream_test/process.{await_some, default_poll_config}
///
/// // Wait for user to appear in database
/// case await_some(default_poll_config(), fn() { find_user(user_id) }) {
///   Ready(user) -> {
///     user.name
///     |> should
///     |> equal("Alice")
///     |> or_fail_with("User should be Alice")
///   }
///   TimedOut -> Ok(fail_with("User never appeared in database"))
/// }
/// ```
///
pub fn await_some(
  config: PollConfig,
  check: fn() -> Result(a, e),
) -> PollResult(a) {
  poll_until_ok(config.timeout_ms, config.interval_ms, check)
}

fn poll_until_true(
  remaining_ms: Int,
  interval_ms: Int,
  check: fn() -> Bool,
) -> PollResult(Bool) {
  case remaining_ms <= 0 {
    True -> TimedOut
    False -> poll_check_bool(remaining_ms, interval_ms, check)
  }
}

fn poll_check_bool(
  remaining_ms: Int,
  interval_ms: Int,
  check: fn() -> Bool,
) -> PollResult(Bool) {
  case check() {
    True -> Ready(True)
    False -> {
      process.sleep(interval_ms)
      poll_until_true(remaining_ms - interval_ms, interval_ms, check)
    }
  }
}

fn poll_until_ok(
  remaining_ms: Int,
  interval_ms: Int,
  check: fn() -> Result(a, e),
) -> PollResult(a) {
  case remaining_ms <= 0 {
    True -> TimedOut
    False -> poll_check_result(remaining_ms, interval_ms, check)
  }
}

fn poll_check_result(
  remaining_ms: Int,
  interval_ms: Int,
  check: fn() -> Result(a, e),
) -> PollResult(a) {
  case check() {
    Ok(value) -> Ready(value)
    Error(_) -> {
      process.sleep(interval_ms)
      poll_until_ok(remaining_ms - interval_ms, interval_ms, check)
    }
  }
}
