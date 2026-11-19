//// Test module discovery for Dream Test.
////
//// This module provides an ergonomic way to discover test modules at runtime
//// (compiled `.beam` modules) and load their `tests/0` suites without having to
//// manually import every module.
////
//// ## Mental model
////
//// - You provide one or more **module path globs** (e.g. `"unit/**_test.gleam"`).
//// - Dream Test finds matching modules under `./test/` that export `tests/0`.
//// - It calls `tests/0` to get `TestSuite` values.
//// - A module can return any suite: from `unit`, from `unit_context` with
////   its own context, or a Gherkin feature. Each suite keeps its own
////   context and set-up.
////
//// ## Example
////
//// ```gleam
//// import dream_test/discover.{from_path, to_suites}
//// import dream_test/reporters/bdd
//// import dream_test/reporters/progress
//// import dream_test/runner.{exit_on_failure, progress_reporter, results_reporters, run}
////
//// pub fn main() {
////   let suites =
////     discover.new()
////     |> from_path("snippets/unit/**.gleam")
////     |> to_suites()
////
////   runner.new(suites)
////   |> progress_reporter(progress.new())
////   |> results_reporters([bdd.new()])
////   |> exit_on_failure()
////   |> run()
//// }
//// ```
////
//// <sub>Note: discovery requires compiled BEAM modules.</sub>

import dream_test/suite.{type TestSuite}
import dream_test/types.{
  type AssertionResult, type Node, AssertionFailed, AssertionFailure, NoInput,
  Root, Test, Unit,
}
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string

// ============================================================================
// Types
// ============================================================================

/// Builder for discovering test modules and loading their suites.
///
/// Discovery is built incrementally by adding one or more module-path glob
/// patterns (see `from_path` / `tests`).
///
/// `TestDiscovery` is **opaque**: you can only build/consume it through the
/// functions in this module.
///
/// ## Example
///
/// ```gleam
/// discover.tests("snippets/unit/**.gleam")
/// |> discover.load()
/// ```
pub opaque type TestDiscovery {
  TestDiscovery(patterns: List(String))
}

/// Result of loading suites, containing both successes and errors.
///
/// This is returned by `load` so callers can decide how to handle errors:
/// return them, log them, or convert them into failing suites via `to_suites`.
///
/// ## Fields
///
/// - `suites`: successfully loaded suites
/// - `errors`: discovery or load errors (human-readable strings)
///
/// ## Example
///
/// ```gleam
/// let discover.LoadResult(suites: suites, errors: _errors) =
///   discover.tests("snippets/**.gleam")
///   |> discover.load()
/// ```
pub type LoadResult {
  LoadResult(suites: List(TestSuite), errors: List(String))
}

// ============================================================================
// Builder API
// ============================================================================

/// Create an empty discovery builder.
///
/// Most users will start with `tests(pattern)` instead.
///
/// ## Returns
///
/// A new empty `TestDiscovery`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/discover.{from_path, to_suites}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner.{exit_on_failure, progress_reporter, results_reporters, run}
/// import gleam/io
///
/// pub fn main() {
///   let suites =
///     discover.new()
///     |> from_path("snippets/unit/**.gleam")
///     |> to_suites()
///
///   runner.new(suites)
///   |> progress_reporter(progress.new())
///   |> results_reporters([bdd.new()])
///   |> exit_on_failure()
///   |> run()
/// }
/// ```
pub fn new() -> TestDiscovery {
  TestDiscovery(patterns: [])
}

/// Add a glob pattern to the discovery set.
///
/// You can call this multiple times to build up a list of globs.
///
/// ## Parameters
///
/// - `discovery`: The current discovery builder
/// - `pattern`: A slash-separated module path glob (the `.gleam` extension is optional)
///
/// ## Returns
///
/// A new `TestDiscovery` with the pattern appended.
///
/// ## Example
///
/// ```gleam
/// import dream_test/discover.{from_path, to_suites}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner.{exit_on_failure, progress_reporter, results_reporters, run}
/// import gleam/io
///
/// pub fn main() {
///   let suites =
///     discover.new()
///     |> from_path("snippets/unit/**.gleam")
///     |> to_suites()
///
///   runner.new(suites)
///   |> progress_reporter(progress.new())
///   |> results_reporters([bdd.new()])
///   |> exit_on_failure()
///   |> run()
/// }
/// ```
pub fn from_path(
  discovery discovery: TestDiscovery,
  pattern pattern: String,
) -> TestDiscovery {
  TestDiscovery(patterns: list.append(discovery.patterns, [pattern]))
}

/// Start discovering tests matching a module path glob pattern.
///
/// The pattern is written using slash-separated module paths and may include
/// `*` / `**` globs. The `.gleam` extension is optional.
///
/// Examples:
/// - `"unit/**_test.gleam"`
/// - `"unit/errors/**_test.gleam"`
/// - `"dream_test/**_test.gleam"`
///
/// ## Parameters
///
/// - `pattern`: A slash-separated module path glob (the `.gleam` extension is optional)
///
/// ## Returns
///
/// A new `TestDiscovery` initialized with the pattern.
///
/// ## Example
///
/// ```gleam
/// import dream_test/discover
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner.{exit_on_failure, progress_reporter, results_reporters, run}
/// import gleam/io
///
/// pub fn main() {
///   let suites =
///     discover.tests("snippets/unit/**.gleam")
///     |> discover.to_suites()
///
///   runner.new(suites)
///   |> progress_reporter(progress.new())
///   |> results_reporters([bdd.new()])
///   |> exit_on_failure()
///   |> run()
/// }
/// ```
pub fn tests(pattern pattern: String) -> TestDiscovery {
  new() |> from_path(pattern)
}

/// List module names discovered for the configured pattern.
///
/// This returns the discovered module names (as strings) or an aggregated error
/// message if discovery failed. A pattern that matches no test module, and a
/// test module that does not load, are errors (see `load` for the texts).
///
/// ## Parameters
///
/// - `discovery`: The configured discovery builder
///
/// ## Returns
///
/// - `Ok(modules)`: A list of discovered module names
/// - `Error(message)`: A human-readable error message (may contain multiple causes)
///
/// ## Example
///
/// ```gleam
/// import dream_test/discover
///
/// pub fn main() {
///   discover.tests("snippets/unit/**.gleam")
///   |> discover.list_modules()
/// }
/// ```
pub fn list_modules(
  discovery discovery: TestDiscovery,
) -> Result(List(String), String) {
  let #(modules, errors) = discover_all_modules(discovery.patterns)
  case errors {
    [] -> Ok(modules)
    _ -> Error(string.join(errors, "; "))
  }
}

/// Load discovered suites and return both suites and errors.
///
/// This never panics; discovery errors are returned in `LoadResult.errors`.
/// Each error starts with the pattern or the module name and `: `, then
/// the cause:
///
/// - `<pattern>: no test module matches the pattern` when no test module
///   matches a pattern, so a wrong pattern never gives a run that passes
///   with no tests;
/// - `<pattern>: cannot search for test modules: <class>:<reason>` for a
///   pattern that cannot be searched;
/// - `<module>: cannot load the module: <reason>` for a test module whose
///   beam file does not load;
/// - `<module>: tests() crashed: <class>:<reason>` when `tests()` crashes;
/// - `<module>: tests() did not return a test suite: <value>` when its
///   value is not a test suite.
///
/// ## Parameters
///
/// - `discovery`: The configured discovery builder
///
/// ## Returns
///
/// A `LoadResult` with:
/// - `suites`: successfully loaded `TestSuite` values
/// - `errors`: discovery or load errors (as strings)
///
/// ## Example
///
/// ```gleam
/// import dream_test/discover
///
/// pub fn main() {
///   discover.tests("snippets/unit/**.gleam")
///   |> discover.load()
/// }
/// ```
pub fn load(discovery discovery: TestDiscovery) -> LoadResult {
  let #(module_names, discover_errors) =
    discover_all_modules(discovery.patterns)
  let LoadResult(suites: suites, errors: load_errors) =
    load_suites_from_modules(module_names, [], [])

  LoadResult(suites: suites, errors: list.append(discover_errors, load_errors))
}

/// Load discovered suites and return them as a list.
///
/// Any discovery/load errors are converted into failing unit tests tagged with
/// `"discovery-error"`, so missing coverage is visible.
///
/// ## Parameters
///
/// - `discovery`: The configured discovery builder
///
/// ## Returns
///
/// A list of suites. If any errors occurred, an additional failing suite tagged
/// `"discovery-error"` is appended.
///
/// ## Example
///
/// ```gleam
/// import dream_test/discover.{from_path, to_suites}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner.{exit_on_failure, progress_reporter, results_reporters, run}
/// import gleam/io
///
/// pub fn main() {
///   let suites =
///     discover.new()
///     |> from_path("snippets/unit/**.gleam")
///     |> to_suites()
///
///   runner.new(suites)
///   |> progress_reporter(progress.new())
///   |> results_reporters([bdd.new()])
///   |> exit_on_failure()
///   |> run()
/// }
/// ```
pub fn to_suites(discovery discovery: TestDiscovery) -> List(TestSuite) {
  let LoadResult(suites: suites, errors: errors) = load(discovery)

  case list.is_empty(errors) {
    True -> suites
    False -> list.append(suites, [errors_suite(errors)])
  }
}

/// Build a single suite from discovered suites.
///
/// Any discovery/load errors are converted into failing unit tests tagged with
/// `"discovery-error"`.
///
/// ## Parameters
///
/// - `discovery`: The configured discovery builder
/// - `suite_name`: Name to use for the outer group in the combined suite
///
/// ## Returns
///
/// A single `TestSuite` containing:
/// - each discovered suite as a group inside it, with its own context and
///   set-up, and
/// - any errors as failing tests tagged `"discovery-error"`.
///
/// ## Example
///
/// ```gleam
/// import dream_test/discover
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner.{exit_on_failure, progress_reporter, results_reporters, run}
/// import gleam/io
///
/// pub fn main() {
///   let suite =
///     discover.tests("snippets/unit/**.gleam")
///     |> discover.to_suite("discovered tests")
///
///   runner.new([suite])
///   |> progress_reporter(progress.new())
///   |> results_reporters([bdd.new()])
///   |> exit_on_failure()
///   |> run()
/// }
/// ```
pub fn to_suite(
  discovery discovery: TestDiscovery,
  suite_name suite_name: String,
) -> TestSuite {
  let LoadResult(suites: suites, errors: errors) = load(discovery)
  suite.join(
    name: suite_name,
    suites: list.append(errors_at_top(suite_name, errors), [
      suite.group(name: suite_name, suites: suites),
    ]),
  )
}

/// The load errors as failing tests directly inside the suite `name`, or
/// no suite when there is no error.
fn errors_at_top(name: String, errors: List(String)) -> List(TestSuite) {
  case errors {
    [] -> []
    _ -> [
      suite.from_tree(Root(
        seed: Nil,
        name: name,
        tags: [],
        children: errors_to_nodes(errors, []),
      )),
    ]
  }
}

// ============================================================================
// Internal helpers (no anonymous fns)
// ============================================================================

fn to_beam_glob(pattern: String) -> String {
  // Convert a module-path glob to a beam filename glob:
  // - "/" -> "@"
  // - "**" -> "*" (module names are flat strings with "@" separators)
  // - ".gleam" -> ".beam" (if present)
  // - otherwise append ".beam"
  let normalized = pattern |> string.trim() |> string.replace("/", "@")
  let flattened = normalized |> string.replace("**", "*")

  case string.ends_with(flattened, ".gleam") {
    True -> replace_gleam_extension(flattened)
    False -> ensure_beam_extension(flattened)
  }
}

fn replace_gleam_extension(path: String) -> String {
  path |> string.replace(".gleam", ".beam")
}

fn ensure_beam_extension(path: String) -> String {
  case string.ends_with(path, ".beam") {
    True -> path
    False -> path <> ".beam"
  }
}

fn load_suites_from_modules(
  module_names: List(String),
  suites_rev: List(TestSuite),
  errors_rev: List(String),
) -> LoadResult {
  case module_names {
    [] ->
      LoadResult(
        suites: list.reverse(suites_rev),
        errors: list.reverse(errors_rev),
      )

    [module_name, ..rest] ->
      load_suites_from_modules_next(module_name, rest, suites_rev, errors_rev)
  }
}

fn load_suites_from_modules_next(
  module_name: String,
  rest: List(String),
  suites_rev: List(TestSuite),
  errors_rev: List(String),
) -> LoadResult {
  case call_tests(module_name) {
    Ok(suite) ->
      load_suites_from_modules(
        rest,
        [suite.with_source(suite: suite, source: module_name), ..suites_rev],
        errors_rev,
      )
    Error(message) ->
      load_suites_from_modules(rest, suites_rev, [
        format_load_error(module_name, message),
        ..errors_rev
      ])
  }
}

fn format_load_error(module_name: String, message: String) -> String {
  module_name <> ": " <> message
}

fn format_discover_error(pattern: String, message: String) -> String {
  pattern <> ": " <> message
}

fn discover_all_modules(
  patterns: List(String),
) -> #(List(String), List(String)) {
  discover_all_modules_loop(patterns, [], [], [])
}

fn discover_all_modules_loop(
  patterns: List(String),
  seen: List(String),
  acc_rev: List(String),
  errors_rev: List(String),
) -> #(List(String), List(String)) {
  case patterns {
    [] -> #(list.reverse(acc_rev), list.reverse(errors_rev))
    [pattern, ..rest] ->
      discover_all_modules_loop_next(pattern, rest, seen, acc_rev, errors_rev)
  }
}

fn discover_all_modules_loop_next(
  pattern: String,
  rest: List(String),
  seen: List(String),
  acc_rev: List(String),
  errors_rev: List(String),
) -> #(List(String), List(String)) {
  let beam_glob = to_beam_glob(pattern)
  case discover_test_modules(beam_glob) {
    Ok([]) ->
      discover_all_modules_loop(rest, seen, acc_rev, [
        format_discover_error(pattern, "no test module matches the pattern"),
        ..errors_rev
      ])
    Ok(found) -> {
      let #(seen2, acc2) =
        add_unique_modules(result.values(found), seen, acc_rev)
      discover_all_modules_loop(
        rest,
        seen2,
        acc2,
        list.append(list.reverse(unloaded_modules(found)), errors_rev),
      )
    }
    Error(message) ->
      discover_all_modules_loop(rest, seen, acc_rev, [
        format_discover_error(pattern, message),
        ..errors_rev
      ])
  }
}

/// The error of each found module that does not load.
fn unloaded_modules(found: List(Result(String, String))) -> List(String) {
  case found {
    [] -> []
    [Ok(_module_name), ..rest] -> unloaded_modules(rest)
    [Error(message), ..rest] -> [message, ..unloaded_modules(rest)]
  }
}

fn add_unique_modules(
  modules: List(String),
  seen: List(String),
  acc_rev: List(String),
) -> #(List(String), List(String)) {
  case modules {
    [] -> #(seen, acc_rev)
    [m, ..rest] -> add_unique_modules_next(m, rest, seen, acc_rev)
  }
}

fn add_unique_modules_next(
  module_name: String,
  rest: List(String),
  seen: List(String),
  acc_rev: List(String),
) -> #(List(String), List(String)) {
  case list.contains(seen, module_name) {
    True -> add_unique_modules(rest, seen, acc_rev)
    False ->
      add_unique_modules(rest, [module_name, ..seen], [module_name, ..acc_rev])
  }
}

fn errors_to_nodes(
  errors: List(String),
  acc_rev: List(Node(Nil)),
) -> List(Node(Nil)) {
  case errors {
    [] -> list.reverse(acc_rev)
    [error, ..rest] -> errors_to_nodes(rest, [error_to_node(error), ..acc_rev])
  }
}

fn errors_suite(errors: List(String)) -> TestSuite {
  suite.from_tree(Root(
    seed: Nil,
    name: "Discovery Errors",
    tags: ["discovery-error"],
    children: errors_to_nodes(errors, []),
  ))
}

fn error_to_node(error: String) -> Node(Nil) {
  Test(
    name: "Discovery Error: " <> error,
    tags: ["discovery-error"],
    kind: Unit,
    run: NoInput(discovery_error_run),
    timeout_ms: None,
    source: None,
  )
}

fn discovery_error_run() -> Result(AssertionResult, String) {
  Ok(discovery_error_assertion())
}

fn discovery_error_assertion() -> AssertionResult {
  AssertionFailed(AssertionFailure(
    operator: "discover",
    message: "Failed to discover/load test modules (see test name for details)",
    payload: None,
  ))
}

// ============================================================================
// FFI
// ============================================================================

@external(erlang, "dream_test_test_discovery_ffi", "discover_test_modules")
fn discover_test_modules(
  beam_glob: String,
) -> Result(List(Result(String, String)), String)

@external(erlang, "dream_test_test_discovery_ffi", "call_tests")
fn call_tests(module_name: String) -> Result(TestSuite, String)
