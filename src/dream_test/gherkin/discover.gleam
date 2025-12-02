//// Feature discovery and loading for Gherkin tests.
////
//// Provides a builder pattern for discovering `.feature` files and
//// converting them to TestSuites without manual file parsing.
////
//// ## Example
////
//// ```gleam
//// import dream_test/gherkin/discover
//// import dream_test/gherkin/steps.{new_registry, step}
//// import dream_test/runner
////
//// pub fn main() {
////   let steps = new_registry()
////   |> step("I have {int} items", have_items)
////   |> step("I add {int} items", add_items)
////
////   discover.features("features/*.feature")
////   |> discover.with_registry(steps)
////   |> discover.to_suite("my_features")
////   |> runner.run_suite()
//// }
//// ```
////
//// ## Glob Patterns
////
//// Uses Erlang's `filelib:wildcard/1` for pattern matching:
////
//// - `features/*.feature` — all `.feature` files in `features/`
//// - `test/**/*.feature` — recursive search in `test/`
//// - `*.feature` — all `.feature` files in current directory
////

import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepRegistry}
import dream_test/gherkin/types.{type Feature}
import dream_test/types.{
  type AssertionResult, type TestSuite, type TestSuiteItem, AssertionFailed,
  AssertionFailure, SingleTestConfig, SuiteGroup, SuiteTest, TestCase, TestSuite,
  Unit,
} as _dream_types
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

// ============================================================================
// Types
// ============================================================================

/// Builder for discovering and loading feature files.
///
/// Use `features()` to create, then chain with `with_registry()` and
/// `to_suite()` to build a TestSuite.
///
pub opaque type FeatureDiscovery {
  FeatureDiscovery(
    /// Glob pattern for finding feature files
    pattern: String,
    /// Step registry (set via with_registry)
    registry: Option(StepRegistry),
    /// Parsed features (populated during to_suite)
    features: List(Feature),
    /// Parse errors encountered
    errors: List(String),
  )
}

/// Result of loading features, containing both successes and errors.
///
pub type LoadResult {
  LoadResult(
    /// Successfully parsed features
    features: List(Feature),
    /// Errors encountered during parsing
    errors: List(String),
  )
}

// ============================================================================
// Builder API
// ============================================================================

/// Start discovering features matching a glob pattern.
///
/// ## Parameters
///
/// - `pattern`: Glob pattern for `.feature` files
///
/// ## Example
///
/// ```gleam
/// discover.features("features/**/*.feature")
/// |> discover.with_registry(steps)
/// |> discover.to_suite("my_tests")
/// ```
///
pub fn features(pattern: String) -> FeatureDiscovery {
  FeatureDiscovery(pattern: pattern, registry: None, features: [], errors: [])
}

/// Attach a step registry to the discovery.
///
/// The registry contains all step definitions needed to execute the features.
///
/// ## Parameters
///
/// - `discovery`: The feature discovery builder
/// - `registry`: Step registry with step definitions
///
pub fn with_registry(
  discovery: FeatureDiscovery,
  registry: StepRegistry,
) -> FeatureDiscovery {
  FeatureDiscovery(..discovery, registry: Some(registry))
}

/// Build a TestSuite from discovered features.
///
/// Discovers all matching files, parses them, and creates a combined TestSuite.
/// Parse errors are collected but don't prevent other features from running.
///
/// ## Parameters
///
/// - `discovery`: The configured feature discovery
/// - `suite_name`: Name for the combined test suite
///
/// ## Returns
///
/// A TestSuite containing all successfully parsed features.
/// If there are parse errors, they're reported as failed tests.
///
/// ## Panics
///
/// Panics if `with_registry()` was not called.
///
pub fn to_suite(discovery: FeatureDiscovery, suite_name: String) -> TestSuite {
  let registry = case discovery.registry {
    Some(r) -> r
    None ->
      panic as "FeatureDiscovery requires a registry. Call with_registry() first."
  }

  // Discover and parse all matching files
  let files = discover_files(discovery.pattern)
  let load_result = load_all_features(files)

  // Convert each feature to a TestSuite, then combine as nested groups
  let suite_items =
    list.map(load_result.features, fn(feature) {
      let config = FeatureConfig(feature: feature, step_registry: registry)
      let feature_suite = to_test_suite(suite_name, config)
      SuiteGroup(feature_suite)
    })

  // Add error items for any parse failures
  let error_items = list.map(load_result.errors, error_to_suite_item)
  let all_items = list.append(suite_items, error_items)

  TestSuite(
    name: suite_name,
    full_name: [suite_name],
    before_all_hooks: [],
    after_all_hooks: [],
    items: all_items,
  )
}

/// Load features and return detailed results.
///
/// Use this when you need access to parse errors for custom handling.
///
/// ## Parameters
///
/// - `discovery`: The feature discovery builder
///
/// ## Returns
///
/// LoadResult with lists of successfully parsed features and errors.
///
pub fn load(discovery: FeatureDiscovery) -> LoadResult {
  let files = discover_files(discovery.pattern)
  load_all_features(files)
}

/// Get the list of files matching the discovery pattern.
///
/// Useful for debugging or custom file handling.
///
pub fn list_files(discovery: FeatureDiscovery) -> List(String) {
  discover_files(discovery.pattern)
}

// ============================================================================
// Internal Helpers
// ============================================================================

fn discover_files(pattern: String) -> List(String) {
  wildcard(pattern)
}

fn load_all_features(files: List(String)) -> LoadResult {
  let results = list.map(files, parse_feature_file)
  let features =
    results
    |> list.filter_map(fn(r) {
      case r {
        Ok(f) -> Ok(f)
        Error(_) -> Error(Nil)
      }
    })
  let errors =
    results
    |> list.filter_map(fn(r) {
      case r {
        Ok(_) -> Error(Nil)
        Error(e) -> Ok(e)
      }
    })
  LoadResult(features: features, errors: errors)
}

fn parse_feature_file(path: String) -> Result(Feature, String) {
  parser.parse_file(path)
  |> result.map_error(fn(e) { path <> ": " <> e })
}

fn error_to_suite_item(error: String) -> TestSuiteItem {
  // Create a failing test case for the parse error
  // The error message is in the test name since we can't use closures
  let error_test =
    TestCase(
      SingleTestConfig(
        name: "Parse Error: " <> error,
        full_name: ["Parse Error", error],
        tags: ["parse-error"],
        kind: Unit,
        run: parse_error_runner,
        timeout_ms: None,
        before_each_hooks: [],
        after_each_hooks: [],
      ),
    )
  SuiteTest(error_test)
}

fn parse_error_runner() -> AssertionResult {
  AssertionFailed(AssertionFailure(
    operator: "parse",
    message: "Failed to parse feature file (see test name for details)",
    payload: None,
  ))
}

// ============================================================================
// FFI
// ============================================================================

/// Find files matching a glob pattern using Erlang's filelib:wildcard/1.
@external(erlang, "dream_test_gherkin_discover_ffi", "wildcard")
fn wildcard(pattern: String) -> List(String)
