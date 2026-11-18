//// Discover and load Gherkin `.feature` files.
////
//// Use this module to:
//// - find `.feature` files via a glob pattern
//// - parse them (`load`) for inspection, or
//// - convert them into runnable `TestSuite`s (`to_suite`) after you attach a
////   step registry (your Given/When/Then handlers) with `with_registry`.
////
//// ## Example
////
//// ```gleam
//// import dream_test/gherkin/discover
//// import dream_test/gherkin/steps.{type StepContext, get_int}
//// import dream_test/gherkin/world.{get_or, put}
//// import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
//// import gleam/result
////
//// fn step_server_running(context: StepContext) {
////   put(context.world, "server_running", True)
////   Ok(succeed())
//// }
////
//// fn step_empty_cart(context: StepContext) {
////   put(context.world, "cart", 0)
////   Ok(succeed())
//// }
////
//// fn step_add_items(context: StepContext) {
////   let current = get_or(context.world, "cart", 0)
////   let to_add = get_int(context.captures, 0) |> result.unwrap(0)
////   put(context.world, "cart", current + to_add)
////   Ok(succeed())
//// }
////
//// fn step_verify_count(context: StepContext) {
////   let expected = get_int(context.captures, 0) |> result.unwrap(0)
////   get_or(context.world, "cart", 0)
////   |> should
////   |> be_equal(expected)
////   |> or_fail_with("Cart count mismatch")
//// }
////
//// pub fn tests() {
////   // Define step handlers
////   let steps =
////     steps.new()
////     |> steps.given("the server is running", step_server_running)
////     |> steps.given("the cart is empty", step_empty_cart)
////     |> steps.when_("I add {int} items", step_add_items)
////     |> steps.then_("the cart should have {int} items", step_verify_count)
////
////   // Discover and load all .feature files
////   discover.features("test/*.feature")
////   |> discover.with_registry(steps)
////   |> discover.to_suite("cart_features")
//// }
//// ```

import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser.{type FeatureFileError}
import dream_test/gherkin/steps.{type StepRegistry}
import dream_test/gherkin/types as gherkin_types
import dream_test/types.{
  type AssertionResult, type Node, type TestSuite, AssertionFailed,
  AssertionFailure, Group, Root, Test, Unit,
}
import gleam/list
import gleam/option.{None, Some}

// ============================================================================
// Types
// ============================================================================

/// Builder for discovering and loading feature files.
///
/// Use `features()` to create a discovery. Pipe it into `list_files` or
/// `load` to inspect the files, or into `with_registry()` and then
/// `to_suite()` to build a runnable `TestSuite`.
///
/// This is opaque so callers can’t depend on internal fields that may change.
pub opaque type FeatureDiscovery {
  FeatureDiscovery(
    /// Glob pattern for finding feature files
    pattern: String,
  )
}

/// A feature discovery with a step registry attached.
///
/// `with_registry` gives this value, and `to_suite` takes it. A suite thus
/// always has the step definitions it needs to run its scenarios.
///
/// ## Example
///
/// ```gleam
/// discover.features("test/*.feature")
/// |> discover.with_registry(steps)
/// |> discover.to_suite("cart_features")
/// ```
///
/// This is opaque so callers can’t depend on internal fields that may change.
pub opaque type RunnableDiscovery {
  RunnableDiscovery(
    /// Glob pattern for finding feature files
    pattern: String,
    /// Step definitions used to run the scenarios
    registry: StepRegistry,
  )
}

/// Result of loading features, containing both successes and errors.
///
/// This is useful if you want to control how parse errors are handled rather
/// than converting them to failing tests.
///
/// ## Fields
///
/// - `features`: successfully parsed feature values
/// - `errors`: one `parser.FeatureFileError` for each file that could not be
///   read or parsed. Use `parser.feature_file_error_to_string` to get the
///   message (`"path: line N: ..."`).
pub type LoadResult {
  LoadResult(
    features: List(gherkin_types.Feature),
    errors: List(FeatureFileError),
  )
}

// ============================================================================
// Builder API
// ============================================================================

/// Start discovering features matching a glob pattern.
///
/// Use Erlang’s `filelib:wildcard/1` semantics (see `wildcard/1` below).
///
/// ## Example
///
/// ```gleam
/// discover.features("test/*.feature")
/// ```
///
/// ## Parameters
///
/// - `pattern`: glob pattern used to find `.feature` files
///
/// ## Returns
///
/// A `FeatureDiscovery` builder you can pipe into `with_registry`, `load`,
/// or `list_files`.
pub fn features(pattern pattern: String) -> FeatureDiscovery {
  FeatureDiscovery(pattern: pattern)
}

/// Attach a step registry to the discovery.
///
/// The step registry is the set of step definitions (Given/When/Then handlers)
/// used to execute scenarios. `to_suite` takes the `RunnableDiscovery` that
/// this function gives, so a suite cannot exist without step definitions.
///
/// ## Example
///
/// ```gleam
/// // Define step handlers
/// let steps =
///   steps.new()
///   |> steps.given("the server is running", step_server_running)
///   |> steps.given("the cart is empty", step_empty_cart)
///   |> steps.when_("I add {int} items", step_add_items)
///   |> steps.then_("the cart should have {int} items", step_verify_count)
///
/// // Discover and load all .feature files
/// discover.features("test/*.feature")
/// |> discover.with_registry(steps)
/// |> discover.to_suite("cart_features")
/// ```
///
/// ## Parameters
///
/// - `discovery`: a `FeatureDiscovery` created with `features`
/// - `registry`: step definitions used to execute scenarios
///
/// ## Returns
///
/// A `RunnableDiscovery` to pipe into `to_suite`.
pub fn with_registry(
  discovery discovery: FeatureDiscovery,
  registry registry: StepRegistry,
) -> RunnableDiscovery {
  RunnableDiscovery(pattern: discovery.pattern, registry: registry)
}

/// Build a TestSuite from discovered features.
///
/// Parse errors are converted into failing unit tests tagged with
/// `"parse-error"`.
///
/// ## What does this produce?
///
/// The returned suite contains one test per scenario. Each test runs the
/// scenario’s steps using the provided step registry.
///
/// ## Example
///
/// ```gleam
/// // Discover and load all .feature files
/// discover.features("test/*.feature")
/// |> discover.with_registry(steps)
/// |> discover.to_suite("cart_features")
/// ```
///
/// ## Parameters
///
/// - `discovery`: a `RunnableDiscovery` from `with_registry`
/// - `suite_name`: name to show for the top-level suite/group in reports
///
/// ## Returns
///
/// A `TestSuite(Nil)` containing one test per discovered scenario, plus failing
/// tests for any parse errors (tagged `"parse-error"`).
pub fn to_suite(
  discovery discovery: RunnableDiscovery,
  suite_name suite_name: String,
) -> TestSuite(Nil) {
  let files = discover_files(discovery.pattern)
  let parsed = parse_all_features(files)

  let children = features_to_groups(parsed.features, discovery.registry, [])
  let error_nodes = errors_to_nodes(parsed.failures, [])
  Root(
    seed: Nil,
    name: suite_name,
    tags: [],
    children: list.append(children, error_nodes),
  )
}

/// Load features and return detailed results.
///
/// This does **not** require a step registry because it only discovers files
/// and parses Gherkin syntax. Step definitions are only needed when you want to
/// execute scenarios (`to_suite`).
///
/// ## Example
///
/// ```gleam
/// let result = discover.features("test/*.feature") |> discover.load()
///
/// result.features
/// |> should
/// |> have_length(1)
/// |> or_fail_with("expected one parsed feature")
/// ```
///
/// ## Parameters
///
/// - `discovery`: a `FeatureDiscovery` created with `features`
///
/// ## Returns
///
/// A `LoadResult` containing parsed features and any parse errors.
pub fn load(discovery discovery: FeatureDiscovery) -> LoadResult {
  let parsed = parse_all_features(discover_files(discovery.pattern))
  LoadResult(
    features: parsed.features,
    errors: list.map(parsed.failures, failure_error),
  )
}

/// Get the list of files matching the discovery pattern.
///
/// This is a pure discovery step; files are not parsed.
///
/// ## Example
///
/// ```gleam
/// discover.features("test/*.feature")
/// |> discover.list_files()
/// |> should
/// |> contain("test/cart.feature")
/// |> or_fail_with("expected list_files to include test/cart.feature")
/// ```
///
/// ## Parameters
///
/// - `discovery`: a `FeatureDiscovery` created with `features`
///
/// ## Returns
///
/// A list of file paths matching the glob pattern.
pub fn list_files(discovery discovery: FeatureDiscovery) -> List(String) {
  discover_files(discovery.pattern)
}

// ============================================================================
// Internal Helpers
// ============================================================================

fn discover_files(pattern: String) -> List(String) {
  wildcard(pattern)
}

/// A feature file that did not parse: its path and the parser message.
type ParseFailure {
  ParseFailure(path: String, error: FeatureFileError)
}

/// The features that parsed and the files that did not, in file order.
type ParsedFeatures {
  ParsedFeatures(
    features: List(gherkin_types.Feature),
    failures: List(ParseFailure),
  )
}

fn parse_all_features(files: List(String)) -> ParsedFeatures {
  let reversed =
    list.fold(files, ParsedFeatures(features: [], failures: []), parse_into)
  ParsedFeatures(
    features: list.reverse(reversed.features),
    failures: list.reverse(reversed.failures),
  )
}

/// Parse one file and put the result at the front of the matching list.
fn parse_into(parsed: ParsedFeatures, path: String) -> ParsedFeatures {
  case parser.parse_file(path) {
    Ok(feature) ->
      ParsedFeatures(..parsed, features: [feature, ..parsed.features])
    Error(error) ->
      ParsedFeatures(..parsed, failures: [
        ParseFailure(path: path, error: error),
        ..parsed.failures
      ])
  }
}

fn failure_error(failure: ParseFailure) -> FeatureFileError {
  failure.error
}

/// A parse error starts with the path, and a read error names the path, so
/// the message is complete.
fn format_parse_failure(failure: ParseFailure) -> String {
  parser.feature_file_error_to_string(failure.error)
}

fn error_to_node(failure: ParseFailure) -> Node(Nil) {
  Test(
    name: "Parse Error: " <> format_parse_failure(failure),
    tags: ["parse-error"],
    kind: Unit,
    run: types.NoInput(parse_error_test_run),
    timeout_ms: None,
    source: Some(failure.path),
  )
}

fn parse_error_test_run() -> Result(AssertionResult, String) {
  Ok(parse_error_assertion())
}

fn parse_error_assertion() -> AssertionResult {
  AssertionFailed(AssertionFailure(
    operator: "parse",
    message: "Failed to parse feature file (see test name for details)",
    payload: None,
  ))
}

fn features_to_groups(
  features: List(gherkin_types.Feature),
  registry: StepRegistry,
  acc_rev: List(Node(Nil)),
) -> List(Node(Nil)) {
  case features {
    [] -> list.reverse(acc_rev)
    [feature, ..rest] -> {
      let group = feature_to_group(feature, registry)
      features_to_groups(rest, registry, [group, ..acc_rev])
    }
  }
}

fn feature_to_group(
  feature: gherkin_types.Feature,
  registry: StepRegistry,
) -> Node(Nil) {
  let config = FeatureConfig(feature: feature, step_registry: registry)
  let feature_suite = to_test_suite(config)
  root_to_group(feature_suite)
}

fn errors_to_nodes(
  failures: List(ParseFailure),
  acc_rev: List(Node(Nil)),
) -> List(Node(Nil)) {
  case failures {
    [] -> list.reverse(acc_rev)
    [failure, ..rest] ->
      errors_to_nodes(rest, [error_to_node(failure), ..acc_rev])
  }
}

fn root_to_group(suite: TestSuite(Nil)) -> Node(Nil) {
  Group(name: suite.name, tags: suite.tags, children: suite.children)
}

// ============================================================================
// FFI
// ============================================================================

/// Find files matching a glob pattern using Erlang's filelib:wildcard/1.
@external(erlang, "dream_test_gherkin_discover_ffi", "wildcard")
fn wildcard(pattern: String) -> List(String)
