//// Where the tests of a context suite get their context.
////
//// `unit_context.describe` takes a `Context(a)`. Make it with one of two
//// functions:
////
//// - `value(a)`: each test starts from a fixed value.
//// - `setup(start, teardown)`: `start` makes the value once, before the
////   first test of the suite, and `teardown` gets the value after the last
////   test.
////
//// ## Example
////
//// ### Give a suite a fixed context <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/context/value.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/context
//// import dream_test/matchers.{be_equal, or_fail_with, should}
//// import dream_test/suite.{type TestSuite}
//// import dream_test/types.{type AssertionResult}
//// import dream_test/unit_context.{describe, it}
////
//// fn is_empty(items: List(String)) -> Result(AssertionResult, String) {
////   items
////   |> should
////   |> be_equal([])
////   |> or_fail_with("expected an empty cart")
//// }
////
//// pub fn cart_suite() -> TestSuite {
////   describe("Cart", context.value([]), [it("starts empty", is_empty)])
//// }
//// ```

import dream_test/types.{type SuiteContext, ContextFromSetup, FixedContext}

/// Where the tests of a context suite get their context: a fixed value
/// (`value`), or a value that a setup makes (`setup`).
///
/// Give it to `unit_context.describe`.
pub opaque type Context(a) {
  Context(suite_context: SuiteContext(a))
}

/// A context that is a fixed value.
///
/// Each test of the suite starts from `start`. A `before_all` or
/// `before_each` hook can change the value before a test gets it.
///
/// ## Parameters
///
/// - `start`: the value that each test starts from
///
/// ## Returns
///
/// A `Context(a)` for `unit_context.describe`.
///
/// ## Example
///
/// ### Give a suite a fixed context <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/context/value.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/suite.{type TestSuite}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit_context.{describe, it}
///
/// fn is_empty(items: List(String)) -> Result(AssertionResult, String) {
///   items
///   |> should
///   |> be_equal([])
///   |> or_fail_with("expected an empty cart")
/// }
///
/// pub fn cart_suite() -> TestSuite {
///   describe("Cart", context.value([]), [it("starts empty", is_empty)])
/// }
/// ```
pub fn value(start: a) -> Context(a) {
  Context(suite_context: FixedContext(start))
}

/// A context that a setup makes, and that a teardown gets after the last
/// test.
///
/// `start` runs once for the suite, before its first test, and only when
/// at least one of its tests runs. A `suite.join` or `suite.group` of two
/// such suites runs two setups. The value of `start` is the context of
/// every hook and test. `teardown` gets the same value after the last
/// test. The setup and the teardown run in one process that lives while
/// the tests run, so a process that `start` starts and links stays alive.
///
/// - When `start` returns `Error`, crashes or times out, each test is
///   `SetupFailed` with the operator `context setup` and the error text,
///   and `teardown` does not run.
/// - When the process of the setup stops, the tests that did not start
///   are `SetupFailed`, and the run report gets a `types.SetupStopped`
///   with the setup `types.ContextSetupHook`. `teardown` still runs when
///   `start` returned.
/// - When `teardown` returns `Error`, crashes or times out, the run report
///   gets a `types.TeardownFailed` with the hook `types.ContextTeardownHook`.
///
/// ## Parameters
///
/// - `start`: makes the context, or gives `Error` with a message
/// - `teardown`: gets the context after the last test
///
/// ## Returns
///
/// A `Context(a)` for `unit_context.describe`.
///
/// ## Example
///
/// ### Get the context from a setup <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/context/setup.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/context
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/suite.{type TestSuite}
/// import dream_test/types.{type AssertionResult}
/// import dream_test/unit_context.{describe, it}
///
/// pub type Server {
///   Server(port: Int)
/// }
///
/// fn start_server() -> Result(Server, String) {
///   Ok(Server(port: 8080))
/// }
///
/// fn stop_server(_server: Server) -> Result(Nil, String) {
///   Ok(Nil)
/// }
///
/// fn answers_a_ping(server: Server) -> Result(AssertionResult, String) {
///   server.port
///   |> should
///   |> be_equal(8080)
///   |> or_fail_with("expected the server on port 8080")
/// }
///
/// pub fn server_suite() -> TestSuite {
///   describe("Server", context.setup(start_server, teardown: stop_server), [
///     it("answers a ping", answers_a_ping),
///   ])
/// }
/// ```
pub fn setup(
  start start: fn() -> Result(a, String),
  teardown teardown: fn(a) -> Result(Nil, String),
) -> Context(a) {
  Context(suite_context: ContextFromSetup(setup: start, teardown: teardown))
}

/// The `types.SuiteContext` of a context, for `suite.new`.
@internal
pub fn to_suite_context(context: Context(a)) -> SuiteContext(a) {
  context.suite_context
}
