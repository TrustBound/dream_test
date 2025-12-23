//// Process helpers for tests that need actors or async operations.
////
//// When Dream Test runs a test, it runs in an isolated BEAM process. Any
//// processes you spawn inside a test can be *linked* to that test process, so
//// they automatically die when the test ends (pass, fail, timeout, crash).
////
//// This module gives you a few “batteries included” patterns:
////
//// - A simple counter actor (`start_counter`) you can use to test stateful code.
//// - A generic actor starter (`start_actor`) + a pipe-friendly call helper (`call_actor`).
//// - “wait until ready” polling (`await_ready` / `await_some`) for async systems.
//// - A safe-ish random port helper (`unique_port`) for test servers.
////
//// ## Example
//// Use this inside an `it` block.
////
//// ```gleam
//// let counter = process.start_counter()
//// process.increment(counter)
//// process.increment(counter)
////
//// process.get_count(counter)
//// |> should
//// |> be_equal(2)
//// |> or_fail_with("expected counter to be 2")
//// ```

import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/otp/actor

/// Messages for the built-in counter actor.
///
/// Most of the time you’ll use the helpers (`increment`, `set_count`, etc), but
/// you can also send the messages directly when it’s convenient.
///
/// ## Example
/// Use this inside an `it` block.
///
/// ```gleam
/// let counter = process.start_counter()
///
/// erlang_process.send(counter, process.Increment)
/// erlang_process.send(counter, process.SetCount(10))
///
/// process.get_count(counter)
/// |> should
/// |> be_equal(10)
/// |> or_fail_with("expected counter to be 10 after SetCount")
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
/// The counter is linked to the test process and will be automatically cleaned
/// up when the test ends.
///
/// ## Returns
///
/// A `Subject(CounterMessage)` you can pass to the other counter helpers (or
/// send messages to directly).
///
/// ## Example
/// Use this inside an `it` block.
///
/// ```gleam
/// let counter = process.start_counter()
/// process.increment(counter)
/// process.increment(counter)
///
/// process.get_count(counter)
/// |> should
/// |> be_equal(2)
/// |> or_fail_with("expected counter to be 2")
/// ```
///
pub fn start_counter() -> Subject(CounterMessage) {
  start_counter_with(0)
}

/// Start a counter actor with a specific initial value.
///
/// ## Parameters
///
/// - `initial`: The initial count value.
///
/// ## Returns
///
/// A `Subject(CounterMessage)` for the started counter.
///
/// ## Example
/// Use this inside an `it` block.
///
/// ```gleam
/// let counter = process.start_counter_with(10)
/// process.decrement(counter)
///
/// process.get_count(counter)
/// |> should
/// |> be_equal(9)
/// |> or_fail_with("expected counter to be 9 after decrement")
/// ```
///
pub fn start_counter_with(initial initial: Int) -> Subject(CounterMessage) {
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
/// ## Parameters
///
/// - `counter`: The counter actor to query.
///
/// ## Returns
///
/// The current counter value.
///
/// ## Example
///
/// Use this inside an `it` block.
///
/// ```gleam
/// let counter = process.start_counter()
/// process.increment(counter)
///
/// process.get_count(counter)
/// |> should
/// |> be_equal(1)
/// |> or_fail_with("expected counter to be 1")
/// ```
///
pub fn get_count(counter counter: Subject(CounterMessage)) -> Int {
  actor.call(counter, waiting: 1000, sending: GetCount)
}

/// Increment a counter by 1.
///
/// This is an asynchronous send—it returns immediately.
///
/// ## Parameters
///
/// - `counter`: The counter actor to increment.
///
/// ## Returns
///
/// `Nil`. (The message is sent asynchronously.)
///
/// ## Example
///
/// Use this inside an `it` block.
///
/// ```gleam
/// let counter = process.start_counter()
/// process.increment(counter)
/// process.increment(counter)
///
/// process.get_count(counter)
/// |> should
/// |> be_equal(2)
/// |> or_fail_with("expected counter to be 2")
/// ```
///
pub fn increment(counter counter: Subject(CounterMessage)) -> Nil {
  process.send(counter, Increment)
}

/// Decrement a counter by 1.
///
/// This is an asynchronous send—it returns immediately.
///
/// ## Parameters
///
/// - `counter`: The counter actor to decrement.
///
/// ## Returns
///
/// `Nil`. (The message is sent asynchronously.)
///
/// ## Example
///
/// Use this inside an `it` block.
///
/// ```gleam
/// let counter = process.start_counter_with(10)
/// process.decrement(counter)
///
/// process.get_count(counter)
/// |> should
/// |> be_equal(9)
/// |> or_fail_with("expected counter to be 9 after decrement")
/// ```
///
pub fn decrement(counter counter: Subject(CounterMessage)) -> Nil {
  process.send(counter, Decrement)
}

/// Set a counter to a specific value.
///
/// This is an asynchronous send—it returns immediately.
///
/// ## Parameters
///
/// - `counter`: The counter actor to set.
/// - `value`: The new value to set.
///
/// ## Returns
///
/// `Nil`. (The message is sent asynchronously.)
///
/// ## Example
///
/// Use this inside an `it` block.
///
/// ```gleam
/// let counter = process.start_counter()
/// process.set_count(counter, 42)
///
/// process.get_count(counter)
/// |> should
/// |> be_equal(42)
/// |> or_fail_with("expected counter to be 42 after set_count")
/// ```
///
pub fn set_count(
  counter counter: Subject(CounterMessage),
  value value: Int,
) -> Nil {
  process.send(counter, SetCount(value))
}

/// Port selection strategies for test servers.
///
/// When starting test servers, you need to choose a port:
///
/// - `Port(n)` - Use a specific port number
/// - `RandomPort` - Pick a random available port (recommended)
///
/// ## Example
///
/// Use this anywhere you need a port selection value.
///
/// ```gleam
/// process.Port(1234)
/// |> should
/// |> be_equal(process.Port(1234))
/// |> or_fail_with("expected PortSelection to be constructible")
/// ```
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
/// Use this in test setup, before starting a server.
///
/// ```gleam
/// process.unique_port()
/// |> should
/// |> be_between(10_000, 60_000)
/// |> or_fail_with("expected unique_port to be within 10k..60k")
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
/// ## Returns
///
/// A `Subject(msg)` you can send messages to (or call with `call_actor`).
///
/// ## Example
///
/// ```gleam
/// let todos = process.start_actor([], handle_todo_message)
///
/// erlang_process.send(todos, Add("Write tests"))
/// erlang_process.send(todos, Add("Run tests"))
///
/// process.call_actor(todos, GetAll, 1000)
/// |> should
/// |> be_equal(["Write tests", "Run tests"])
/// |> or_fail_with("expected items to be preserved in insertion order")
/// ```
///
pub fn start_actor(
  initial_state initial_state: state,
  handler handler: fn(state, msg) -> actor.Next(state, msg),
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
/// ## Returns
///
/// The reply value from the actor.
///
/// ## Example
///
/// ```gleam
/// process.call_actor(todos, GetAll, 1000)
/// |> should
/// |> be_equal(["Write tests", "Run tests"])
/// |> or_fail_with("expected items to be preserved in insertion order")
/// ```
///
pub fn call_actor(
  subject subject: Subject(msg),
  make_message make_message: fn(Subject(reply)) -> msg,
  timeout_ms timeout_ms: Int,
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
/// process.default_poll_config()
/// |> should
/// |> be_equal(process.PollConfig(timeout_ms: 5000, interval_ms: 50))
/// |> or_fail_with("expected default_poll_config to be 5000ms/50ms")
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
/// ## Returns
///
/// `PollConfig(timeout_ms: 5000, interval_ms: 50)`.
///
/// ## Example
///
/// ```gleam
/// process.default_poll_config()
/// |> should
/// |> be_equal(process.PollConfig(timeout_ms: 5000, interval_ms: 50))
/// |> or_fail_with("expected default_poll_config to be 5000ms/50ms")
/// ```
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
/// ## Returns
///
/// `PollConfig(timeout_ms: 1000, interval_ms: 10)`.
///
/// ## Example
///
/// ```gleam
/// process.quick_poll_config()
/// |> should
/// |> be_equal(process.PollConfig(timeout_ms: 1000, interval_ms: 10))
/// |> or_fail_with("expected quick_poll_config to be 1000ms/10ms")
/// ```
///
pub fn quick_poll_config() -> PollConfig {
  PollConfig(timeout_ms: 1000, interval_ms: 10)
}

/// Result of a polling operation.
///
/// Either the condition was met (`Ready`) or we gave up (`TimedOut`).
///
/// ## Constructors
///
/// - `Ready(value)`: The condition was met.
/// - `TimedOut`: The timeout elapsed.
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
/// ## Parameters
///
/// - `config`: Poll timeout + interval.
/// - `check`: A zero-arg function returning `Bool`.
///
/// ## Returns
///
/// `Ready(True)` when the check returns `True`, otherwise `TimedOut`.
///
/// ## Example
///
/// ```gleam
/// process.await_ready(process.quick_poll_config(), always_true)
/// |> should
/// |> be_equal(process.Ready(True))
/// |> or_fail_with("expected await_ready to return Ready(True)")
/// ```
///
pub fn await_ready(
  config config: PollConfig,
  check check: fn() -> Bool,
) -> PollResult(Bool) {
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
/// ## Parameters
///
/// - `config`: Poll timeout + interval.
/// - `check`: A zero-arg function returning `Result(value, error)`.
///
/// ## Returns
///
/// `Ready(value)` when the check returns `Ok(value)`, otherwise `TimedOut`.
///
/// ## Example
///
/// ```gleam
/// process.await_some(process.default_poll_config(), always_ok_42)
/// |> should
/// |> be_equal(process.Ready(42))
/// |> or_fail_with("expected await_some to return Ready(42)")
/// ```
///
pub fn await_some(
  config config: PollConfig,
  check check: fn() -> Result(a, e),
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
