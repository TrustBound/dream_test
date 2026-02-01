//// Discover and load Gherkin `.feature` files.
////
//// Use this module to:
//// - find `.feature` files via a glob pattern
//// - parse them (`load`) for inspection, or
//// - convert them into runnable `TestSuite`s (`to_suite`) when you provide a
////   step registry (your Given/When/Then handlers).
////
//// ## Example
////
//// ```gleam
//// import dream_test/gherkin/discover
//// import dream_test/gherkin/steps.{type StepContext, get_int, step}
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
////     |> step("the server is running", step_server_running)
////     |> step("the cart is empty", step_empty_cart)
////     |> step("I add {int} items", step_add_items)
////     |> step("the cart should have {int} items", step_verify_count)
////
////   // Discover and load all .feature files
////   discover.features("test/*.feature")
////   |> discover.with_registry(steps)
////   |> discover.to_suite("cart_features")
//// }
//// ```

import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepRegistry}
import dream_test/gherkin/types as gherkin_types
import dream_test/types.{
  type AssertionResult, type Node, type TestSuite, AssertionFailed,
  AssertionFailure, Group, Root, Test, Unit,
}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// ============================================================================
// Types
// ============================================================================

/// Builder for discovering and loading feature files.
///
/// Use `features()` to create a discovery, then chain with `with_registry()` and
/// `to_suite()` to build a runnable `TestSuite`.
///
/// This is opaque so callers can’t depend on internal fields that may change.
pub opaque type FeatureDiscovery {
  FeatureDiscovery(
    /// Glob pattern for finding feature files
    pattern: String,
    /// Step registry (set via with_registry)
    registry: Option(StepRegistry),
    /// Parsed features (populated during to_suite)
    features: List(gherkin_types.Feature),
    /// Parse errors encountered
    errors: List(String),
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
/// - `errors`: parse errors as strings (typically `"path: message"`)
pub type LoadResult {
  LoadResult(features: List(gherkin_types.Feature), errors: List(String))
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
/// `list_files`, or `to_suite`.
pub fn features(pattern pattern: String) -> FeatureDiscovery {
  FeatureDiscovery(pattern: pattern, registry: None, features: [], errors: [])
}

/// Attach a step registry to the discovery.
///
/// The step registry is the set of step definitions (Given/When/Then handlers)
/// used to execute scenarios. It is required before calling `to_suite`.
///
/// ## Example
///
/// ```gleam
/// // Define step handlers
/// let steps =
///   steps.new()
///   |> step("the server is running", step_server_running)
///   |> step("the cart is empty", step_empty_cart)
///   |> step("I add {int} items", step_add_items)
///   |> step("the cart should have {int} items", step_verify_count)
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
/// The updated discovery.
pub fn with_registry(
  discovery discovery: FeatureDiscovery,
  registry registry: StepRegistry,
) -> FeatureDiscovery {
  FeatureDiscovery(..discovery, registry: Some(registry))
}

/// Build a TestSuite from discovered features.
///
/// Panics if `with_registry()` was not called.
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
/// - `discovery`: a `FeatureDiscovery` with a registry attached via `with_registry`
/// - `suite_name`: name to show for the top-level suite/group in reports
///
/// ## Returns
///
/// A `TestSuite(Nil)` containing one test per discovered scenario, plus failing
/// tests for any parse errors (tagged `"parse-error"`).
pub fn to_suite(
  discovery discovery: FeatureDiscovery,
  suite_name suite_name: String,
) -> TestSuite(Nil) {
  let registry = case discovery.registry {
    Some(r) -> r
    None ->
      panic as "FeatureDiscovery requires a registry. Call with_registry() first."
  }

  let files = discover_files(discovery.pattern)
  let load_result = load_all_features(files)

  let children = features_to_groups(load_result.features, registry, [])
  let error_nodes = errors_to_nodes(load_result.errors, [])
  Root(
    seed: Nil,
    tree: Group(
      name: suite_name,
      tags: [],
      children: list.append(children, error_nodes),
    ),
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
  let files = discover_files(discovery.pattern)
  load_all_features(files)
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

fn load_all_features(files: List(String)) -> LoadResult {
  load_all_features_loop(files, [], [])
}

fn load_all_features_loop(
  files: List(String),
  features_rev: List(gherkin_types.Feature),
  errors_rev: List(String),
) -> LoadResult {
  case files {
    [] ->
      LoadResult(
        features: list.reverse(features_rev),
        errors: list.reverse(errors_rev),
      )
    [path, ..rest] -> {
      case parse_feature_file(path) {
        Ok(feature) ->
          load_all_features_loop(rest, [feature, ..features_rev], errors_rev)
        Error(error) ->
          load_all_features_loop(rest, features_rev, [error, ..errors_rev])
      }
    }
  }
}

fn parse_feature_file(path: String) -> Result(gherkin_types.Feature, String) {
  case parser.parse_file(path) {
    Ok(feature) -> Ok(feature)
    Error(e) -> Error(path <> ": " <> e)
  }
}

fn error_to_node(error: String) -> Node(Nil) {
  Test(
    name: "Parse Error: " <> error,
    tags: ["parse-error"],
    kind: Unit,
    run: parse_error_test_run,
    timeout_ms: None,
    source: source_from_parse_error(error),
  )
}

fn source_from_parse_error(error: String) -> Option(String) {
  case string.split_once(error, ": ") {
    Ok(#(path, _message)) -> Some(path)
    Error(_) -> None
  }
}

fn parse_error_test_run(_nil: Nil) -> Result(AssertionResult, String) {
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
  errors: List(String),
  acc_rev: List(Node(Nil)),
) -> List(Node(Nil)) {
  case errors {
    [] -> list.reverse(acc_rev)
    [error, ..rest] -> errors_to_nodes(rest, [error_to_node(error), ..acc_rev])
  }
}

fn root_to_group(suite: TestSuite(Nil)) -> Node(Nil) {
  let Root(_seed, tree) = suite
  tree
}

// ============================================================================
// FFI
// ============================================================================

/// Find files matching a glob pattern using Erlang's filelib:wildcard/1.
@external(erlang, "dream_test_gherkin_discover_ffi", "wildcard")
fn wildcard(pattern: String) -> List(String)
